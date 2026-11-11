# Replays the last repeatable action, or records one: its argv, NUL-separated, so no argument is re-parsed by a shell.

record=${XDG_STATE_HOME:-$HOME/.local/state}/repeat/last

usage() {
  cat <<'USAGE'
repeat                  run the last recorded replay
repeat record CMD [ARG...]
                        make CMD ARG... the replay, overwriting the last; a repeatable action runs this when it completes
USAGE
}

nothing() {
  notify-send -a repeat "Nothing to repeat" "$1" || true
  exit 0
}

case ${1:-} in
  "")
    [ -s "$record" ] || nothing "no repeatable action has run yet"
    mapfile -d '' -t argv <"$record"
    command -v "${argv[0]}" >/dev/null || nothing "${argv[0]} is no longer installed"
    exec "${argv[@]}"
    ;;
  record)
    shift
    [ $# -gt 0 ] || { usage >&2 && exit 1; }
    mkdir -p "$(dirname "$record")"
    printf '%s\0' "$@" >"$record.tmp"
    mv -f "$record.tmp" "$record"
    ;;
  -h | --help | help) usage ;;
  *) usage >&2 && exit 1 ;;
esac
