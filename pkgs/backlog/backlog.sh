# Files an idea as an issue in a project's GitHub tracker, queueing it locally when filing fails.

self=$(readlink -f "$0")
config=${BACKLOG_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/backlog/projects.yaml}
state=${XDG_STATE_HOME:-$HOME/.local/state}/backlog
queue=$state/queue.jsonl
recent=$state/recent
visibility=$state/visibility
# A queued line failing this many times for a reason other than the network raises one notification.
max_fails=3
# How long a repo's private/public answer is trusted before gh is asked again.
visibility_ttl=86400
notify=0

usage() {
  cat <<'EOF'
backlog add [PROJECT] "TITLE // BODY"   file an idea; " //" splits title from body (a URL's :// doesn't);
                                        stdin, if not a terminal, is appended to the body
backlog prompt                          fuzzel: pick a project, type a line, file it in the background
backlog flush [--notify]                re-send the offline queue
backlog queue                           list what is queued
backlog setup                           create the configured labels in every configured repo
backlog projects                        list the configured projects, best guess first
EOF
}

die() {
  echo "backlog: $*" >&2
  exit 1
}

# The config as JSON, with each project's defaults filled in.
projects_json() {
  [ -f "$config" ] || die "no config at $config"
  yq -o=json '.' "$config" | jq -c '[.projects[] | {
    name, repo,
    match: ([.name] + (.match // []) | map(ascii_downcase)),
    labels: (.labels // ["needs-triage", "capture"]),
    public_ok: (.public_ok // false)
  }]'
}

project() {
  projects_json | jq -ce --arg n "$1" '.[] | select(.name == $n)' || die "no project '$1' (see: backlog projects)"
}

# Names of the projects whose match words appear in $1, in config order.
guess() {
  projects_json | jq -r --arg h "${1,,}" '.[] | select(any(.match[]; . as $w | $h | contains($w))) | .name'
}

# Every project name once: the guesses for $1, then the most recently used, then the rest.
ordered() {
  {
    guess "$1"
    [ -f "$recent" ] && cat "$recent"
    projects_json | jq -r '.[].name'
  } | awk 'NF && !seen[$0]++' | grep -Fxf <(projects_json | jq -r '.[].name')
}

remember() {
  mkdir -p "$state"
  { echo "$1"; [ -f "$recent" ] && grep -Fxv -- "$1" "$recent"; } | head -n 20 >"$recent.tmp" || true
  mv -f "$recent.tmp" "$recent"
}

focused_window() {
  niri msg -j focused-window 2>/dev/null | jq -r '"\(.title // "") \(.app_id // "")"' 2>/dev/null || true
}

# Splits $1 at the first " //" followed by a space or the end, so a URL's "://" stays in the title.
split_line() {
  local s=$1 pre=""
  title=$1 body=""
  while [[ $s == *" //"* ]]; do
    pre+=${s%%" //"*}
    s=${s#*" //"}
    if [[ -z $s || $s == [[:space:]]* ]]; then
      title=$pre body=$s
      break
    fi
    pre+=" //"
  done
  title=$(trim "$title")
  body=$(trim "$body")
}

trim() {
  local s=$1
  s=${s#"${s%%[![:space:]]*}"}
  printf '%s\n' "${s%"${s##*[![:space:]]}"}"
}

# gh's message for a failure that retrying with a network would fix.
is_network() {
  grep -qiE 'error connecting|dial tcp|connection refused|no such host|i/o timeout|TLS handshake|network is unreachable|temporary failure in name resolution|context deadline exceeded|could not resolve host' <<<"$1"
}

note() {
  [ "$notify" = 1 ] || return 0
  notify-send -a backlog "$@" || true
}

# Low urgency, with an action that opens the issue; waits for the action, so callers background it.
note_filed() {
  local repo=$1 url=$2
  echo "$url"
  [ "$notify" = 1 ] || return 0
  [ "$(notify-send -a backlog -u low -A open="Open" "$repo#${url##*/} filed" 2>/dev/null)" = open ] &&
    qutebrowser "$url" >/dev/null 2>&1
  return 0
}

# Prints true or false for whether $1 is private, from the cache when fresh; fails with gh's error.
is_private() {
  local repo=$1 now line answer at
  now=$(date +%s)
  mkdir -p "$state"
  if [ -f "$visibility" ] && line=$(awk -F'\t' -v r="$repo" '$1 == r' "$visibility" | tail -n 1) && [ -n "$line" ]; then
    IFS=$'\t' read -r _ answer at <<<"$line"
    if ((now - at < visibility_ttl)); then
      echo "$answer"
      return 0
    fi
  fi
  if ! answer=$(gh api "repos/$repo" --jq .private 2>"$state/gh.err"); then
    cat "$state/gh.err"
    return 1
  fi
  { [ -f "$visibility" ] && awk -F'\t' -v r="$repo" '$1 != r' "$visibility"; printf '%s\t%s\t%s\n' "$repo" "$answer" "$now"; } >"$visibility.tmp" || true
  mv -f "$visibility.tmp" "$visibility"
  echo "$answer"
}

# Files one issue. Exit 0 filed (URL on stdout), 2 refused as public, 3 network, 4 any other failure (message on stdout).
send() {
  local repo=$1 title=$2 body=$3 labels=$4 public_ok=$5 private out
  local -a args=(issue create --repo "$repo" --title "$title" --body "$body")
  if ! private=$(is_private "$repo"); then
    echo "$private"
    is_network "$private" && return 3
    return 4
  fi
  if [ "$private" != true ] && [ "$public_ok" != true ]; then
    echo "$repo is public; set public_ok: true in $config to allow it"
    return 2
  fi
  while read -r l; do args+=(--label "$l"); done < <(jq -r '.[]' <<<"$labels")
  if out=$(gh "${args[@]}" 2>&1); then
    tail -n 1 <<<"$out"
    return 0
  fi
  echo "$out"
  is_network "$out" && return 3
  return 4
}

enqueue() {
  mkdir -p "$state"
  jq -nc --arg repo "$1" --arg title "$2" --arg body "$3" --argjson labels "$4" --argjson public_ok "$5" --argjson fails "$6" \
    '{repo: $repo, title: $title, body: $body, labels: $labels, public_ok: $public_ok, at: (now | todate), fails: $fails}' >>"$queue"
}

lock() {
  mkdir -p "$state"
  exec 9>"$state/lock"
  flock -w 120 9 || die "another backlog run holds $state/lock"
}

flush_locked() {
  local line repo title body labels public_ok fails out rc offline=0 pending=()
  [ -s "$queue" ] || return 0
  while IFS= read -r -u 3 line; do
    [ -n "$line" ] || continue
    if [ "$offline" = 1 ]; then
      pending+=("$line")
      continue
    fi
    repo=$(jq -r .repo <<<"$line")
    title=$(jq -r .title <<<"$line")
    body=$(jq -r .body <<<"$line")
    labels=$(jq -c .labels <<<"$line")
    public_ok=$(jq -r '.public_ok // false' <<<"$line")
    rc=0
    out=$(send "$repo" "$title" "$body" "$labels" "$public_ok") || rc=$?
    case $rc in
      0) note_filed "$repo" "$out" 9>&- & ;;
      2)
        echo "backlog: dropped '$title': $out" >&2
        note -u critical "backlog: dropped from queue" "$title — $out"
        ;;
      3)
        offline=1
        pending+=("$line")
        ;;
      *)
        fails=$(($(jq -r '.fails // 0' <<<"$line") + 1))
        echo "backlog: '$title' failed ($fails): $out" >&2
        line=$(jq -c --argjson f "$fails" '.fails = $f' <<<"$line")
        # Raised by the first notifying run at or past the limit, so a quiet CLI flush can't use it up.
        if ((fails >= max_fails)) && [ "$notify" = 1 ] && [ "$(jq -r '.notified // false' <<<"$line")" != true ]; then
          note -u critical "backlog: '$title' failed $fails times" "$repo: $out"
          line=$(jq -c '.notified = true' <<<"$line")
        fi
        pending+=("$line")
        ;;
    esac
  done 3<"$queue"
  if [ ${#pending[@]} -gt 0 ]; then printf '%s\n' "${pending[@]}"; fi >"$queue.tmp"
  mv -f "$queue.tmp" "$queue"
  [ -s "$queue" ] || rm -f "$queue"
}

cmd_flush() {
  [ "${1:-}" = --notify ] && notify=1
  [ -s "$queue" ] || return 0
  lock
  flush_locked
}

cmd_add() {
  local p name repo labels public_ok out rc=0 extra=""
  [ "${1:-}" = --notify ] && notify=1 && shift
  case $# in
    1)
      name=$(ordered "$PWD" | head -n 1)
      [ -n "$(guess "$PWD")" ] || echo "backlog: nothing matches $PWD; using the most recent project, $name" >&2
      ;;
    2) name=$1 && shift ;;
    *) die "usage: backlog add [PROJECT] \"TITLE // BODY\"" ;;
  esac
  [ -n "$name" ] || die "no projects in $config"
  p=$(project "$name")
  split_line "$1"
  [ -t 0 ] || extra=$(cat)
  if [ -n "$extra" ]; then body=${body:+$body$'\n\n'}$extra; fi
  [ -n "$title" ] || die "empty title"
  repo=$(jq -r .repo <<<"$p")
  labels=$(jq -c .labels <<<"$p")
  public_ok=$(jq -r .public_ok <<<"$p")
  lock
  remember "$name"
  flush_locked
  out=$(send "$repo" "$title" "$body" "$labels" "$public_ok") || rc=$?
  case $rc in
    3) enqueue "$repo" "$title" "$body" "$labels" "$public_ok" 0 ;;
    4) enqueue "$repo" "$title" "$body" "$labels" "$public_ok" 1 ;;
  esac
  # Released before any notification waits on its action, so the next capture needn't wait for it.
  exec 9>&-
  case $rc in
    0) note_filed "$repo" "$out" ;;
    2)
      note -u critical "backlog: refused" "$out"
      die "refused: $out"
      ;;
    3)
      note -u normal "backlog: queued (offline)" "$title"
      echo "backlog: queued (offline): $title" >&2
      ;;
    *)
      note -u critical "backlog: queued after an error" "$repo: $out"
      echo "backlog: queued after an error: $out" >&2
      wait
      exit 1
      ;;
  esac
  wait
}

cmd_prompt() {
  local names name idx line
  mapfile -t names < <(ordered "$(focused_window)")
  [ ${#names[@]} -gt 0 ] || die "no projects in $config"
  idx=$(printf '%s\n' "${names[@]}" |
    fuzzel --dmenu --only-match --index --prompt "backlog> " --lines "${#names[@]}" --width 40) || exit 0
  [ -n "$idx" ] || exit 0
  name=${names[$idx]}
  line=$(fuzzel --dmenu --prompt-only "$name> " --placeholder "title // body" --width 60 </dev/null) || exit 0
  [ -n "$(trim "$line")" ] || exit 0
  setsid -f "$self" add --notify "$name" "$line" </dev/null >/dev/null 2>&1
}

cmd_queue() {
  [ -s "$queue" ] || {
    echo "queue empty"
    return 0
  }
  jq -r '"\(.at)  \(.repo)  \(.title)\(if (.fails // 0) > 0 then "  (failed \(.fails)x)" else "" end)"' "$queue"
}

# Labels gh doesn't know get these; any other label gets a plain grey.
label_spec() {
  case $1 in
    needs-triage) echo "FBCA04|Maintainer needs to evaluate this issue" ;;
    capture) echo "C2E0C6|Raw idea from backlog quick capture, not yet reviewed" ;;
    *) echo "EDEDED|" ;;
  esac
}

cmd_setup() {
  local repo labels label have spec
  while IFS=$'\t' read -r repo labels; do
    have=$(gh label list --repo "$repo" --limit 500 --json name --jq '.[].name') || die "can't list labels in $repo"
    while read -r label; do
      if grep -Fxq -- "$label" <<<"$have"; then
        echo "$repo: $label exists"
        continue
      fi
      spec=$(label_spec "$label")
      gh label create "$label" --repo "$repo" --color "${spec%%|*}" --description "${spec#*|}" >/dev/null
      echo "$repo: $label created"
    done < <(jq -r '.[]' <<<"$labels")
  done < <(projects_json | jq -r 'group_by(.repo)[] | [.[0].repo, (map(.labels[]) | unique | tojson)] | @tsv')
}

case ${1:-} in
  add) shift && cmd_add "$@" ;;
  prompt) cmd_prompt ;;
  flush) shift && cmd_flush "$@" ;;
  queue) cmd_queue ;;
  setup) cmd_setup ;;
  projects) ordered "$PWD" ;;
  -h | --help | help) usage ;;
  *) usage >&2 && exit 1 ;;
esac
