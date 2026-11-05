app=$1
shift
state=${XDG_RUNTIME_DIR:-/tmp}/summon/$app

windows=$(niri msg --json windows)
# The app's window ids, most recently focused first; never-focused windows last.
recent=$(jq -c --arg app "$app" '[.[] | select(.app_id == $app)]
  | sort_by(.focus_timestamp.secs // -1, .focus_timestamp.nanos // 0) | reverse | map(.id)' <<<"$windows")
focused=$(jq -r --arg app "$app" '.[] | select(.is_focused and .app_id == $app) | .id' <<<"$windows")

if [ "$recent" = "[]" ]; then
  rm -f "$state"
  exec niri msg action spawn -- "$@"
fi

if [ -z "$focused" ]; then
  rm -f "$state"
  target=$(jq '.[0]' <<<"$recent")
else
  # Focusing a window makes it the most recent, so a cycle walks the order saved when it began.
  order=$recent
  if [ -r "$state" ] && [ "$(head -n1 "$state")" = "$focused" ]; then
    order=$(tail -n +2 "$state")
  fi
  # Drop closed windows, append ones opened mid-cycle.
  order=$(jq -c --argjson open "$recent" '[.[] | select(IN($open[]))] + ($open - .)' <<<"$order")
  target=$(jq --argjson f "$focused" '.[((index($f) // -1) + 1) % length]' <<<"$order")
  mkdir -p "${state%/*}"
  printf '%s\n%s\n' "$target" "$order" >"$state"
fi

niri msg action focus-window --id "$target"
