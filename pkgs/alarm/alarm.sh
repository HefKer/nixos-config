# The package sets store (the synced folder, one file per alarm) and sound above this line.
# Each host's `alarm sync` mirrors the files as transient systemd timers, so a file is the alarm everywhere.

self=$(readlink -f "$0")
# How long an alarm rings, and how late it may start ringing before it counts as missed.
ring_secs=120

usage() {
  cat <<'EOF'
alarm WHEN [LABEL]         set one: 10m, 1h30m, 90s, 25 (minutes), 7:30, 9pm, tomorrow 8am
alarm ls [--json]          list pending alarms, soonest first
alarm rm ID... | --all     cancel
alarm snooze ID [DUR]      push back by DUR (default 5m)
alarm prompt               fuzzel: type WHEN [LABEL] to set, or pick one to cancel or snooze
alarm sync                 mirror the alarm files as systemd timers (run by alarm-sync.path)
EOF
}

die() {
  echo "alarm: $*" >&2
  exit 1
}

ids() {
  find "$store" -maxdepth 1 -type f -regextype posix-extended -regex '.*/[0-9a-f]{8}' -printf '%f\n' 2>/dev/null
}

# Reads alarm $1 into at and label.
load() {
  local k v
  at="" label=""
  [ -f "$store/$1" ] || return 1
  while IFS='=' read -r k v; do
    case $k in
      at) at=$v ;;
      label) label=$v ;;
    esac
  done <"$store/$1"
  [[ $at =~ ^[0-9]+$ ]]
}

# Written beside and renamed over, so Syncthing and the path unit never see half a file.
save() {
  mkdir -p "$store"
  printf 'at=%s\nlabel=%s\n' "$2" "$(tr -d '\t\n' <<<"$3")" >"$store/.$1.tmp"
  mv -f -- "$store/.$1.tmp" "$store/$1"
}

# Seconds in a duration word (10m, 1h30m, 90s; a bare number is minutes), or fails.
seconds() {
  local re='^(([0-9]+)h)?(([0-9]+)m)?(([0-9]+)s)?$'
  if [[ $1 =~ ^[0-9]+$ ]]; then
    echo $((10#$1 * 60))
  elif [ -n "$1" ] && [[ $1 =~ $re ]]; then
    echo $((10#${BASH_REMATCH[2]:-0} * 3600 + 10#${BASH_REMATCH[4]:-0} * 60 + 10#${BASH_REMATCH[6]:-0}))
  else
    return 1
  fi
}

# Sets when (epoch), kind and rest (the label words) from "$@": a duration, or the longest
# prefix of up to 3 words that date(1) reads as a time, rolled to tomorrow if already past.
parse() {
  local now s k spec t
  now=$(date +%s)
  if s=$(seconds "$1"); then
    when=$((now + s)) kind=timer
    shift
    rest=$*
    return
  fi
  for ((k = $# < 3 ? $# : 3; k > 0; k--)); do
    spec=${*:1:k}
    # A lone letter is a military time zone to date(1); require a digit.
    [[ $spec =~ [0-9] ]] || continue
    t=$(date -d "$spec" +%s 2>/dev/null) || continue
    if [ "$t" -le "$now" ]; then
      t=$(date -d "tomorrow $spec" +%s 2>/dev/null) || die "$spec is in the past"
      [ "$t" -gt "$now" ] || die "$spec is in the past"
    fi
    when=$t kind=alarm
    shift "$k"
    rest=$*
    return
  done
  die "can't read a time in: $*"
}

# "14:32 (in 8m)", with the weekday when not today.
describe() {
  local d left
  d=$(date -d "@$1" +%H:%M)
  [ "$(date -d "@$1" +%F)" = "$(date +%F)" ] || d="$(date -d "@$1" +%a) $d"
  left=$(($1 - $(date +%s)))
  if [ "$left" -lt 60 ]; then
    left="$((left < 0 ? 0 : left))s"
  elif [ "$left" -lt 3600 ]; then
    left="$((left / 60))m"
  else
    left="$((left / 3600))h$(((left % 3600) / 60))m"
  fi
  echo "$d (in $left)"
}

# id, at and label per pending alarm, tab-separated, soonest first.
rows() {
  local id
  for id in $(ids); do
    load "$id" && printf '%s\t%s\t%s\n' "$id" "$at" "$label"
  done | sort -t$'\t' -k2,2n
}

cmd_add() {
  local id
  [ $# -gt 0 ] || die "usage: alarm WHEN [LABEL]"
  parse "$@"
  id=$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')
  save "$id" "$when" "${rest:-$kind}"
  cmd_sync
  printf '%s\t%s\t%s\n' "$id" "$(describe "$when")" "${rest:-$kind}"
}

cmd_ls() {
  if [ "${1:-}" = --json ]; then
    rows | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") | {id: .[0], at: (.[1] | tonumber), label: .[2]})'
    return
  fi
  local id at label
  while IFS=$'\t' read -r id at label; do
    printf '%s\t%s\t%s\n' "$id" "$(describe "$at")" "$label"
  done < <(rows)
}

cmd_rm() {
  local id all
  [ $# -gt 0 ] || die "usage: alarm rm ID... | --all"
  if [ "$1" = --all ]; then
    mapfile -t all < <(ids)
    set -- "${all[@]}"
  fi
  for id in "$@"; do
    [ -f "$store/$id" ] || die "no alarm $id"
    rm -f -- "${store:?}/$id"
  done
  cmd_sync
}

cmd_snooze() {
  local s
  [ $# -ge 1 ] || die "usage: alarm snooze ID [DUR]"
  load "$1" || die "no alarm $1"
  s=$(seconds "${2:-5m}") || die "not a duration: $2"
  save "$1" $(($(date +%s) + s)) "$label"
  cmd_sync
}

cmd_prompt() {
  local out id label choice line desc
  # Exact matching, so typing "10m tea" doesn't fuzzy-match a pending "tea"; Shift+Enter always sets.
  out=$(
    while IFS=$'\t' read -r r_id r_at r_label; do
      printf '%s  ·  %s\t%s\n' "$r_label" "$(describe "$r_at")" "$r_id"
    done < <(rows) | fuzzel --dmenu --match-mode exact --with-nth 1 --accept-nth 2 \
      --prompt "alarm> " --placeholder "10m tea · 7:30 standup · pick one to cancel" --width 50
  ) || exit 0
  [ -n "$out" ] || exit 0
  if [[ $out =~ ^[0-9a-f]{8}$ ]] && load "$out"; then
    id=$out
    choice=$(printf 'Cancel\nSnooze 5 min\nSnooze 15 min\n' |
      fuzzel --dmenu --only-match --index --prompt "$label> " --lines 3 --width 40) || exit 0
    case $choice in
      0) cmd_rm "$id" ;;
      1) cmd_snooze "$id" 5m ;;
      2) cmd_snooze "$id" 15m ;;
    esac
    return
  fi
  # shellcheck disable=SC2086 # the typed line splits into words
  if line=$(cmd_add $out 2>&1); then
    IFS=$'\t' read -r _ desc label <<<"$line"
    notify-send -a Alarm -i alarm -t 3000 "$label" "$desc"
  else
    notify-send -a Alarm -i dialog-error "Alarm not set" "${line#alarm: }"
  fi
}

# Starts a timer for each alarm file that has none, and stops units whose file is gone or moved.
cmd_sync() {
  local now id unit base
  local -A want have
  now=$(date +%s)
  while read -r unit _; do
    have[$unit]=1
  done < <(systemctl --user list-units --all --plain --no-legend 'alarm-*-*.timer' 'alarm-*-*.service')
  for id in $(ids); do
    load "$id" || continue
    base=alarm-$id-$at
    want[$base]=1
    [ -z "${have[$base.timer]:-}${have[$base.service]:-}" ] || continue
    if [ "$at" -gt "$now" ]; then
      systemd-run --user --quiet --collect --unit="$base" \
        --on-calendar="$(date -d "@$at" '+%F %T')" --timer-property=AccuracySec=1s \
        -- "$self" ring "$id" "$at"
    else
      systemd-run --user --quiet --collect --unit="$base" -- "$self" ring "$id" "$at"
    fi
  done
  for unit in "${!have[@]}"; do
    base=${unit%.*}
    [[ $base =~ ^alarm-[0-9a-f]{8}-[0-9]+$ ]] || continue
    [ -n "${want[$base]:-}" ] || systemctl --user stop "$unit" 2>/dev/null || true
  done
}

# Run by an alarm's timer: sound and a notification until dismissed, snoozed or ring_secs pass.
cmd_ring() {
  local id=$1 late nid="" loop="" action="" rc=0
  load "$id" || exit 0
  [ "$at" = "$2" ] || exit 0
  late=$(($(date +%s) - at))
  if [ "$late" -gt "$ring_secs" ]; then
    rm -f -- "${store:?}/$id"
    notify-send -a Alarm -i alarm "Missed: $label" "Due $(date -d "@$at" '+%a %H:%M') while this machine was off or asleep"
    exit 0
  fi

  # Also run when another host's dismiss deletes the file and sync stops this unit.
  quiet() {
    if [ -n "$loop" ]; then
      pkill -P "$loop" 2>/dev/null || true
      kill "$loop" 2>/dev/null || true
    fi
    [ -z "$nid" ] || gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications \
      --method org.freedesktop.Notifications.CloseNotification "$nid" >/dev/null 2>&1 || true
  }
  trap quiet EXIT
  trap 'exit 0' TERM INT

  (while :; do
    pw-play "$sound" || sleep 1
    sleep 0.5
  done) &
  loop=$!

  coproc NOTE {
    notify-send -p -u critical -a Alarm -i alarm -A dismiss=Dismiss -A snooze="Snooze 5 min" \
      "$label" "$(date -d "@$at" +%H:%M)"
  }
  read -r nid <&"${NOTE[0]}" || true
  read -r -t "$ring_secs" action <&"${NOTE[0]}" || rc=$?
  # Unanswered: the notification stays up to be seen later, the sound stops.
  [ "$rc" -le 128 ] || nid=""
  quiet
  case $action in
    snooze) save "$id" $(($(date +%s) + 300)) "$label" ;;
    *) rm -f -- "${store:?}/$id" ;;
  esac
}

case ${1:-ls} in
  -h | --help | help) usage ;;
  ls | rm | snooze | prompt | sync | ring)
    c=$1
    shift
    "cmd_$c" "$@"
    ;;
  add)
    shift
    cmd_add "$@"
    ;;
  *) cmd_add "$@" ;;
esac
