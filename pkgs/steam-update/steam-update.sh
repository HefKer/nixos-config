# Starts Steam windowless so it installs any client update, then quits it unless a Steam window has opened since.

log=${XDG_DATA_HOME:-$HOME/.local/share}/Steam/logs/console_log.txt
unit=steam-update-client
timeout=${STEAM_UPDATE_TIMEOUT:-600}

if pgrep -u "$(id -u)" -x steam >/dev/null; then
  echo "Steam is already running; nothing to do"
  exit 0
fi

offset=$(stat -c %s "$log" 2>/dev/null || echo 0)

# Its own unit, so a Steam you take over keeps running after this service exits.
systemd-run --user --unit="$unit" --collect --quiet -- steam -silent

# The client logs this once per start, after the updater has finished.
started() {
  local size
  size=$(stat -c %s "$log" 2>/dev/null || echo 0)
  if ((size < offset)); then offset=0; fi
  tail -c +"$((offset + 1))" "$log" 2>/dev/null | grep -q "System startup time"
}

for ((i = 0; i < timeout; i += 5)); do
  started && break
  systemctl --user is-active --quiet "$unit" || {
    echo "Steam exited before it finished starting"
    exit 0
  }
  sleep 5
done
started || echo "Steam didn't finish starting in ${timeout}s"
# The client checks for further updates and logs in shortly after it starts.
sleep 30

if niri msg -j windows | jq -e 'any(.[]; .app_id == "steam" or ((.app_id // "") | startswith("steam_app_")))' >/dev/null; then
  echo "A Steam window is open; leaving Steam running"
  exit 0
fi

steam -shutdown >/dev/null 2>&1 || true
for ((i = 0; i < 60; i++)); do
  systemctl --user is-active --quiet "$unit" || exit 0
  sleep 1
done
systemctl --user stop "$unit"
