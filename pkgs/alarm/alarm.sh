# The package sets store (the synced folder, one file per alarm) and sound above this line.
# Each host's `alarm sync` mirrors the files as transient systemd timers, so a file is the alarm everywhere.
# A file holds label= and either at= (one ring, epoch) or repeat= (days and HH:MM, an OnCalendar spec) or both:
# a repeating alarm's at= is a snoozed ring, and handled= is the last occurrence dismissed or snoozed.

self=$(readlink -f "$0")
# How long an alarm rings, and how late it may start ringing before it counts as missed.
ring_secs=120

usage() {
  cat <<'EOF'
alarm WHEN [LABEL]         set one: 10m, 1h30m, 90s, 25 (minutes), 7:30, 9pm, tomorrow 8am
alarm DAYS TIME [LABEL]    set a repeating one: daily, weekdays or mon,wed,fri, then 7:30 or 9pm
alarm ls [--json]          list pending alarms, soonest first
alarm rm ID... | --all     cancel (a repeating alarm's whole series)
alarm snooze ID [DUR]      push back by DUR (default 5m); a repeating alarm only while it rings
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

day_names=(Mon Tue Wed Thu Fri Sat Sun)
repeat_re='^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)(,(Mon|Tue|Wed|Thu|Fri|Sat|Sun))* ([01][0-9]|2[0-3]):[0-5][0-9]$'

# Reads alarm $1 into at, label, repeat and handled.
load() {
  local k v
  at="" label="" repeat="" handled=0
  [ -f "$store/$1" ] || return 1
  while IFS='=' read -r k v; do
    case $k in
      at) at=$v ;;
      label) label=$v ;;
      repeat) repeat=$v ;;
      handled) handled=$v ;;
    esac
  done <"$store/$1"
  [[ $handled =~ ^[0-9]+$ ]] || handled=0
  if [ -n "$repeat" ]; then
    [[ $repeat =~ $repeat_re ]] && [[ -z $at || $at =~ ^[0-9]+$ ]]
  else
    [[ $at =~ ^[0-9]+$ ]]
  fi
}

# Writes alarm $1 from at, label, repeat and handled, beside and renamed over, so Syncthing and the
# path unit never see half a file. A one-shot stays two lines, readable by a host still on the old alarm.
save() {
  mkdir -p "$store"
  {
    [ -z "$at" ] || printf 'at=%s\n' "$at"
    printf 'label=%s\n' "$(tr -d '\t\n' <<<"$label")"
    [ -z "$repeat" ] || printf 'repeat=%s\nhandled=%s\n' "$repeat" "$handled"
  } >"$store/.$1.tmp"
  mv -f -- "$store/.$1.tmp" "$store/$1"
}

# Sets prev and next, the occurrences of $repeat around now (0 if none in the window).
occurrences() {
  local now t d days=${repeat% *} hm=${repeat#* }
  now=$(date +%s)
  prev=0 next=0
  # One date(1) call for all days. A day whose HH:MM falls in a DST gap fails alone and is skipped,
  # as systemd's calendar timer skips it; the window spans two of every weekday on each side.
  while read -r t d; do
    [[ ,$days, == *",$d,"* ]] || continue
    if [ "$t" -le "$now" ]; then
      prev=$t
    elif [ "$next" -eq 0 ]; then
      next=$t
    fi
  done < <(for i in $(seq -14 14); do echo "today $i days"; done | LC_ALL=C date -f - +%F |
    sed "s/\$/ $hm/" | LC_ALL=C date -f - '+%s %a' 2>/dev/null || true)
}

# The soonest ring of the loaded alarm: its at=, or a repeating alarm's next occurrence if sooner.
next_ring() {
  [ -n "$repeat" ] || {
    echo "$at"
    return
  }
  occurrences
  [[ -n $at && $at -lt $next ]] && echo "$at" || echo "$next"
}

# "weekdays 07:30" for a repeat= spec.
repeat_words() {
  local days=${repeat% *}
  case $days in
    Mon,Tue,Wed,Thu,Fri,Sat,Sun) days=daily ;;
    Mon,Tue,Wed,Thu,Fri) days=weekdays ;;
  esac
  echo "$days ${repeat#* }"
}

# Sets repeat from a day word ($1) and a time ($2, or $2 $3 when $3 is am or pm), or fails with why.
# Sets time_words to how many words the time took.
parse_repeat() {
  local w d n hm days="" spec=${2:-}
  time_words=1
  if [[ ${3:-} =~ ^[aApP][mM]$ ]]; then
    spec+=" $3" time_words=2
  fi
  case ${1,,} in
    daily) days=Mon,Tue,Wed,Thu,Fri,Sat,Sun ;;
    weekdays) days=Mon,Tue,Wed,Thu,Fri ;;
    *)
      IFS=, read -ra w <<<"${1,,}"
      for n in "${!day_names[@]}"; do
        for d in "${w[@]}"; do
          [ "$d" != "${day_names[n],,}" ] || {
            days+=,${day_names[n]}
            break
          }
        done
      done
      for d in "${w[@]}"; do
        [[ ,${days,,}, == *",$d,"* ]] || die "not a day: '$d' (use daily, weekdays, or mon,tue,wed,thu,fri,sat,sun)"
      done
      days=${days#,}
      ;;
  esac
  if ! [[ $spec =~ ^[0-9]{1,2}(:[0-9]{2})?\ ?([aApP][mM])?$ ]] || ! hm=$(date -d "$spec" +%H:%M 2>/dev/null); then
    die "can't read a time of day in: ${spec:-(nothing after $1)}"
  fi
  repeat="$days $hm"
}

# Whether $1 is a repeating alarm's day word: daily, weekdays, a day abbreviation, or a comma list.
is_day_word() {
  [[ ${1,,} =~ ^(daily|weekdays|mon|tue|wed|thu|fri|sat|sun)$ || $1 == *,* ]]
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
# A leading day word sets repeat instead, with when its first ring.
parse() {
  local now s k spec t
  now=$(date +%s)
  repeat=""
  if is_day_word "$1"; then
    parse_repeat "$1" "${2:-}" "${3:-}"
    occurrences
    when=$next kind=alarm
    shift $((1 + time_words))
    rest=$*
    return
  fi
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

# describe, plus "⟳ weekdays 07:30" for a repeating alarm.
describe_ring() {
  if [ -n "$2" ]; then
    echo "$(describe "$1") ⟳ $(repeat="$2" repeat_words)"
  else
    describe "$1"
  fi
}

# id, next ring, label and repeat per pending alarm, tab-separated, soonest first.
rows() {
  local id
  for id in $(ids); do
    load "$id" && printf '%s\t%s\t%s\t%s\n' "$id" "$(next_ring)" "$label" "$repeat"
  done | sort -t$'\t' -k2,2n
}

cmd_add() {
  local id line
  [ $# -gt 0 ] || die "usage: alarm WHEN [LABEL] | alarm DAYS TIME [LABEL]"
  parse "$@"
  id=$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')
  label=${rest:-$kind} handled=$(date +%s)
  if [ -n "$repeat" ]; then at=""; else at=$when; fi
  save "$id"
  # Before sync, which loads every alarm over these globals.
  line=$(printf '%s\t%s\t%s' "$id" "$(describe_ring "$when" "$repeat")" "$label")
  cmd_sync
  echo "$line"
}

cmd_ls() {
  if [ "${1:-}" = --json ]; then
    rows | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t")
      | {id: .[0], at: (.[1] | tonumber), label: .[2], repeat: (if (.[3] // "") == "" then null else .[3] end)})'
    return
  fi
  local id at label rep
  while IFS=$'\t' read -r id at label rep; do
    printf '%s\t%s\t%s\n' "$id" "$(describe_ring "$at" "$rep")" "$label"
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

# A repeating alarm snoozes only the ring going off now: a snoozed ring, or an occurrence not yet handled.
cmd_snooze() {
  local s now
  [ $# -ge 1 ] || die "usage: alarm snooze ID [DUR]"
  load "$1" || die "no alarm $1"
  s=$(seconds "${2:-5m}") || die "not a duration: $2"
  now=$(date +%s)
  if [[ -n $repeat && -z $at ]]; then
    occurrences
    [[ $prev -gt $handled && $((now - prev)) -le $ring_secs ]] ||
      die "$label isn't ringing; snoozing a repeating alarm delays only the ring going off now"
    handled=$prev
  fi
  at=$((now + s))
  save "$1"
  cmd_sync
}

cmd_prompt() {
  local out id label choice line desc
  # Exact matching, so typing "10m tea" doesn't fuzzy-match a pending "tea"; Shift+Enter always sets.
  # No --accept-nth: fuzzel applies it to typed text too, and a line with no 2nd column comes out as a literal "{2}".
  out=$(
    while IFS=$'\t' read -r r_id r_at r_label r_repeat; do
      printf '%s  ·  %s\t%s\n' "$r_label" "$(describe_ring "$r_at" "$r_repeat")" "$r_id"
    done < <(rows) | fuzzel --dmenu --match-mode exact --with-nth 1 \
      --prompt "alarm> " --placeholder "10m tea · 7:30 standup · weekdays 7:30 gym · pick one to cancel" --width 60
  ) || exit 0
  [ -n "$out" ] || exit 0
  # A picked row ends in a tab and its id; typed text has no tab.
  if [[ $out =~ $'\t'([0-9a-f]{8})$ ]] && load "${BASH_REMATCH[1]}"; then
    id=${BASH_REMATCH[1]}
    choice=$(printf '%s\nSnooze 5 min\nSnooze 15 min\n' "Cancel${repeat:+ series}" |
      fuzzel --dmenu --only-match --index --prompt "$label> " --lines 3 --width 40) || exit 0
    case $choice in
      0) cmd_rm "$id" ;;
      1 | 2)
        line=$(cmd_snooze "$id" "$([ "$choice" = 1 ] && echo 5m || echo 15m)" 2>&1) ||
          notify-send -a Alarm -i dialog-error "Not snoozed" "${line#alarm: }"
        ;;
    esac
    return
  fi
  # shellcheck disable=SC2086 # the typed line splits into words
  if line=$(cmd_add $out 2>&1); then
    IFS=$'\t' read -r _ desc label <<<"$line"
    notify-send -a Alarm -i alarm -t 3000 "$label" "$desc"
    # Replaying a one-shot sets it again (another 10m tea); replaying a repeating one would duplicate its series.
    # shellcheck disable=SC2086 # the typed line splits into words
    if [[ $desc == *⟳* ]]; then repeat record alarm prompt; else repeat record alarm add $out; fi
  else
    notify-send -a Alarm -i dialog-error "Alarm not set" "${line#alarm: }"
  fi
}

# A repeating alarm's unit tag: r and a checksum of its spec, so a changed spec gets a new timer.
repeat_tag() {
  echo "r$(cksum <<<"$repeat" | cut -d' ' -f1)"
}

# Starts a timer for each alarm file that has none, and stops units whose file is gone or moved.
# A repeating alarm has a calendar timer, alarm-ID-rTAG, plus a one-shot alarm-ID-AT while snoozed.
cmd_sync() {
  local now id unit base
  local -A want have
  now=$(date +%s)
  while read -r unit _; do
    have[$unit]=1
  done < <(systemctl --user list-units --all --plain --no-legend 'alarm-*-*.timer' 'alarm-*-*.service')
  for id in $(ids); do
    load "$id" || continue
    if [ -n "$repeat" ]; then
      base=alarm-$id-$(repeat_tag)
      want[$base]=1
      if [ -z "${have[$base.timer]:-}" ]; then
        systemd-run --user --quiet --collect --unit="$base" \
          --on-calendar="$repeat" --timer-property=AccuracySec=1s \
          -- "$self" ring "$id" "${base##*-}"
      elif [ -n "${have[$base.service]:-}" ]; then
        # Another host dismissed or snoozed the occurrence ringing here.
        occurrences
        [ "$handled" -lt "$prev" ] || systemctl --user stop "$base.service" 2>/dev/null || true
      fi
    fi
    [ -n "$at" ] || continue
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
    [[ $base =~ ^alarm-[0-9a-f]{8}-r?[0-9]+$ ]] || continue
    [ -n "${want[$base]:-}" ] || systemctl --user stop "$unit" 2>/dev/null || true
  done
}

# Ends ring $2 (an epoch, or a repeat tag) of the loaded alarm $1, due at $3: a one-shot is deleted,
# a snoozed ring of a repeating alarm clears its at=, and an occurrence is marked handled.
# Every host that timed out writes the same bytes, so Syncthing sees no conflict.
finish() {
  if [ -z "$repeat" ]; then
    rm -f -- "${store:?}/$1"
  elif [[ $2 == r* ]]; then
    handled=$3
    save "$1"
  else
    at=""
    save "$1"
  fi
}

# Run by an alarm's timer: sound and a notification until dismissed, snoozed or ring_secs pass.
# $2 is the at= it was set for, or for a repeating alarm's calendar timer its repeat tag.
cmd_ring() {
  local id=$1 due late nid="" loop="" action="" rc=0 body
  load "$id" || exit 0
  if [[ $2 == r* ]]; then
    [[ -n $repeat && $(repeat_tag) == "$2" ]] || exit 0
    occurrences
    due=$prev
    # Dismissed or snoozed on another host before this one woke (or no occurrence: a DST gap).
    [ "$handled" -lt "$due" ] || exit 0
  else
    [ "$at" = "$2" ] || exit 0
    due=$at
  fi
  late=$(($(date +%s) - due))
  if [ "$late" -gt "$ring_secs" ]; then
    [[ $2 == r* ]] || finish "$id" "$2" "$due"
    notify-send -a Alarm -i alarm "Missed: $label" "Due $(date -d "@$due" '+%a %H:%M') while this machine was off or asleep"
    exit 0
  fi
  body=$(date -d "@$due" +%H:%M)
  [ -z "$repeat" ] || body+=" ⟳ $(repeat_words)"

  # Also run when another host's dismiss deletes the file and sync stops this unit.
  quiet() {
    if [ -n "${loop:-}" ]; then
      pkill -P "$loop" 2>/dev/null || true
      kill "$loop" 2>/dev/null || true
    fi
    [ -z "${nid:-}" ] || gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications \
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
      "$label" "$body"
  }
  read -r nid <&"${NOTE[0]}" || true
  read -r -t "$ring_secs" action <&"${NOTE[0]}" || rc=$?
  # Unanswered: the notification stays up to be seen later, the sound stops.
  [ "$rc" -le 128 ] || nid=""
  quiet
  # The file may have changed while ringing, such as a snooze from another host.
  load "$id" || exit 0
  case $action in
    snooze)
      at=$(($(date +%s) + 300))
      [[ $2 != r* ]] || handled=$due
      save "$id"
      ;;
    *) finish "$id" "$2" "$due" ;;
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
