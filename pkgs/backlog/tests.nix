{
  callPackage,
  jq,
  runCommandLocal,
  writeShellScriptBin,
}:
let
  # Fake GitHub: $FAKE/offline drops the network, $FAKE/broken fails a label, $FAKE/public/<owner>_<repo> is public.
  fakeGh = writeShellScriptBin "gh" ''
    net() { echo "error connecting to api.github.com" >&2; exit 1; }
    case "$1 $2" in
      "api "*)
        [ -e "$FAKE/offline" ] && net
        r=''${2#repos/}
        if [ -e "$FAKE/public/''${r//\//_}" ]; then echo false; else echo true; fi
        echo "api $r" >>"$FAKE/api-calls"
        ;;
      "issue create")
        [ -e "$FAKE/offline" ] && net
        [ -e "$FAKE/broken" ] && { echo "could not add label: 'capture' not found" >&2; exit 1; }
        shift 2
        echo "create $*" >>"$LOG"
        n=$(($(cat "$FAKE/n" 2>/dev/null || echo 0) + 1))
        echo "$n" >"$FAKE/n"
        while [ "$1" != --repo ]; do shift; done
        echo "Creating issue in $2"
        echo "https://github.com/$2/issues/$n"
        ;;
      "label list") cat "$FAKE/labels" 2>/dev/null || true ;;
      "label create") echo "label $3 $5" >>"$LOG" ;;
      *) echo "fake gh: unexpected $*" >&2; exit 1 ;;
    esac
  '';

  fakeNotify = writeShellScriptBin "notify-send" ''
    echo "notify $*" >>"$FAKE/notes"
  '';

  backlog = callPackage ./. {
    gh = fakeGh;
    libnotify = fakeNotify;
  };
in
runCommandLocal "backlog-tests"
  {
    nativeBuildInputs = [
      backlog
      jq
    ];
  }
  ''
    export HOME=$PWD/home FAKE=$PWD/fake LOG=$PWD/log
    export BACKLOG_CONFIG=$PWD/projects.yaml
    mkdir -p "$HOME" "$FAKE/public"
    touch "$LOG"
    queue=$HOME/.local/state/backlog/queue.jsonl
    cat >"$BACKLOG_CONFIG" <<'EOF'
    projects:
      - name: nixos
        repo: o/nixos-issues
        match: [homelab]
      - name: dots
        repo: o/dots-issues
      - name: open
        repo: o/open
      - name: openok
        repo: o/openok
        public_ok: true
        labels: [idea]
    EOF
    touch "$FAKE/public/o_open" "$FAKE/public/o_openok"
    fail=0
    expect() {
      if [ "$1" != "$2" ]; then
        printf 'FAIL %s:\n  got      %s\n  expected %s\n' "$3" "$1" "$2"
        fail=1
      fi
    }

    expect "$(backlog add nixos 'img viewer // see https://x.y/z' </dev/null)" \
      "https://github.com/o/nixos-issues/issues/1" "add prints the issue URL"
    expect "$(tail -n 1 "$LOG")" \
      "create --repo o/nixos-issues --title img viewer --body see https://x.y/z --label needs-triage --label capture" \
      "text after // is the body, and both default labels are set"

    backlog add dots 'see https://a.b/c' </dev/null >/dev/null
    expect "$(tail -n 1 "$LOG")" \
      "create --repo o/dots-issues --title see https://a.b/c --body  --label needs-triage --label capture" \
      "a URL's :// stays in the title"

    echo "from stdin" | backlog add dots 'one // two' >/dev/null
    expect "$(tail -n 3 "$LOG")" \
      "create --repo o/dots-issues --title one --body two"$'\n\n'"from stdin --label needs-triage --label capture" \
      "stdin is appended to the body"

    mkdir -p "$PWD/dev/homelab-thing"
    (cd "$PWD/dev/homelab-thing" && backlog add 'guessed' </dev/null >/dev/null)
    expect "$(tail -n 1 "$LOG" | cut -d' ' -f3)" "o/nixos-issues" "the cwd picks the project by its match words"
    expect "$(cd "$PWD/dev/homelab-thing" && backlog projects | head -n 2 | tr '\n' ' ')" "nixos dots " \
      "projects lists the guess, then the most recent"

    before=$(wc -l <"$LOG")
    expect "$(backlog add open 'leak' </dev/null 2>&1 || echo "rc=$?")" \
      "backlog: refused: o/open is public; set public_ok: true in $BACKLOG_CONFIG to allow it"$'\n'"rc=1" \
      "a public repo without public_ok is refused"
    expect "$(wc -l <"$LOG")" "$before" "a refused idea files nothing"
    expect "$([ -e "$queue" ] && echo queued || echo none)" none "a refused idea is not queued"

    backlog add openok 'fine' </dev/null >/dev/null
    expect "$(tail -n 1 "$LOG")" "create --repo o/openok --title fine --body  --label idea" \
      "public_ok allows a public repo, and labels override the default"

    printf 'projects:\n  - name: x\n    repo: xo/dots-issues\n' >"$PWD/x.yaml"
    touch "$FAKE/public/xo_dots-issues"
    expect "$(BACKLOG_CONFIG=$PWD/x.yaml backlog add x 'leak' </dev/null 2>&1 | cut -d' ' -f1-3 || true)" \
      "backlog: refused: xo/dots-issues" "a cached private repo doesn't vouch for one whose name ends the same"

    mkdir -p "$PWD/elsewhere"
    expect "$(cd "$PWD/elsewhere" && backlog add 'fallback' </dev/null 2>&1 >/dev/null)" \
      "backlog: nothing matches $PWD/elsewhere; using the most recent project, openok" \
      "with no match the CLI falls back to the most recent project and says so"

    calls=$(wc -l <"$FAKE/api-calls")
    backlog add nixos 'again' </dev/null >/dev/null
    expect "$(wc -l <"$FAKE/api-calls")" "$calls" "a repo's visibility is cached"

    touch "$FAKE/offline"
    expect "$(backlog add --notify nixos 'offline idea // b' </dev/null 2>/dev/null; echo "rc=$?")" "rc=0" \
      "an offline add succeeds by queueing"
    expect "$(jq -r '"\(.repo) \(.title) \(.body)"' "$queue")" "o/nixos-issues offline idea b" "the idea is queued"
    expect "$(tail -n 1 "$FAKE/notes")" "notify -a backlog -u normal backlog: queued (offline) offline idea" \
      "offline is a normal-urgency notification"
    backlog flush
    expect "$(wc -l <"$queue")" 1 "a flush while offline keeps the line"
    rm "$FAKE/offline"
    expect "$(backlog flush)" "https://github.com/o/nixos-issues/issues/8" "a flush back online files it"
    expect "$([ -e "$queue" ] && echo queued || echo none)" none "and empties the queue"

    touch "$FAKE/broken"
    backlog add --notify dots 'broken' </dev/null >/dev/null 2>&1 || true
    expect "$(tail -n 1 "$FAKE/notes" | cut -d' ' -f1-6)" "notify -a backlog -u critical backlog:" \
      "any other failure is critical"
    backlog flush 2>/dev/null
    backlog flush 2>/dev/null
    expect "$(jq -r .fails "$queue")" 3 "each failed flush counts against the line"
    expect "$(grep -c 'failed' "$FAKE/notes" || true)" 0 "a quiet flush can't raise the notification"
    backlog flush --notify 2>/dev/null
    expect "$(grep -c 'failed 4 times' "$FAKE/notes")" 1 "the next notifying run past the limit raises it"
    backlog flush --notify 2>/dev/null
    expect "$(grep -c 'failed' "$FAKE/notes")" 1 "and only once"
    expect "$(backlog queue | cut -d' ' -f3-)" "o/dots-issues  broken  (failed 5x)" "queue lists the line"
    rm "$FAKE/broken"
    backlog add dots 'next' </dev/null >/dev/null
    expect "$(tail -n 2 "$LOG" | cut -d' ' -f5 | tr '\n' ' ')" "broken next " "a capture flushes the queue first"

    printf 'needs-triage\n' >"$FAKE/labels"
    : >"$LOG"
    backlog setup >/dev/null
    expect "$(sort "$LOG" | tr '\n' ' ')" \
      "label capture o/dots-issues label capture o/nixos-issues label capture o/open label idea o/openok " \
      "setup creates only the missing labels in each repo"

    if [ "$fail" != 0 ]; then exit 1; fi
    touch $out
  ''
