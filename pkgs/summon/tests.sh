export XDG_RUNTIME_DIR=$PWD/run WINDOWS=$PWD/windows.json LOG=$PWD/log
fail=0

# win ID APP SECS FOCUSED
win() { printf '{"id":%s,"app_id":"%s","focus_timestamp":{"secs":%s,"nanos":0},"is_focused":%s}' "$@"; }
windows() { local IFS=,; echo "[$*]" >"$WINDOWS"; }
expect() {
  : >"$LOG"
  summon spotify spotify --flag
  if [ "$(cat "$LOG")" != "$1" ]; then
    echo "FAIL $2: got '$(cat "$LOG")', expected '$1'"
    fail=1
  fi
}
# Applies the last focus to the fake window list, as niri would.
focus() {
  jq --argjson id "$1" --argjson t "$2" \
    'map(.is_focused = (.id == $id) | if .id == $id then .focus_timestamp.secs = $t else . end)' \
    "$WINDOWS" >tmp && mv tmp "$WINDOWS"
}

windows "$(win 1 wez 50 true)"
expect "action spawn -- spotify --flag" "launches when absent"

windows "$(win 1 spotify 10 false)" "$(win 2 spotify 30 false)" "$(win 3 spotify 20 false)" "$(win 4 wez 40 true)"
expect "action focus-window --id 2" "focuses the most recent"
focus 2 41
expect "action focus-window --id 3" "cycles to the next most recent"
focus 3 42
expect "action focus-window --id 1" "keeps the order saved at cycle start"
focus 1 43
expect "action focus-window --id 2" "wraps around"
focus 2 44

windows "$(win 1 spotify 43 false)" "$(win 2 spotify 44 true)" "$(win 5 spotify null false)"
expect "action focus-window --id 1" "drops closed windows from the cycle"
focus 1 45
expect "action focus-window --id 5" "appends windows opened mid-cycle"

windows "$(win 1 spotify 10 false)" "$(win 2 spotify 30 true)"
rm -rf "$XDG_RUNTIME_DIR"
expect "action focus-window --id 1" "a focused app window starts a fresh cycle"

[ "$fail" = 0 ] && touch "$out"
