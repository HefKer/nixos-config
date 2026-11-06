{
  fuzzel,
  jq,
  niri,
  writeShellApplication,
}:
writeShellApplication {
  name = "window-pick";
  # The jq programs are single-quoted on purpose.
  excludeShellChecks = [ "SC2016" ];
  runtimeInputs = [
    fuzzel
    jq
    niri
  ];
  text = ''
    windows=$(niri msg --json windows)
    workspaces=$(niri msg --json workspaces)

    # One row per window, most recently focused first; the same order feeds the ids and the menu.
    rows='
      ($ws | map({key: (.id | tostring), value: "\(.output) \(.name // .idx)"}) | from_entries) as $where
      | sort_by(-(.focus_timestamp.secs // 0), -(.focus_timestamp.nanos // 0))[]
    '
    mapfile -t ids < <(jq -r --argjson ws "$workspaces" "$rows | .id" <<<"$windows")
    [ "''${#ids[@]}" -gt 0 ] || exit 0

    # Icons come from each app's .desktop Icon=, which can differ from its app-id (spotify-client).
    IFS=: read -ra dirs <<<"''${XDG_DATA_HOME:-$HOME/.local/share}:''${XDG_DATA_DIRS:-/usr/share}"
    icons='{}'
    while read -r app; do
      icon=$app
      for d in "''${dirs[@]}"; do
        if [ -f "$d/applications/$app.desktop" ]; then
          icon=$(sed -n 's/^Icon=//p' "$d/applications/$app.desktop" | head -n1)
          break
        fi
      done
      icons=$(jq --arg k "$app" --arg v "''${icon:-$app}" '. + {($k): $v}' <<<"$icons")
    done < <(jq -r '[.[].app_id // empty] | unique[]' <<<"$windows")

    # Fuzzel's dmenu reads "text\0icon\x1fname" per line, so each row gets its app's icon.
    i=$(jq -j --argjson ws "$workspaces" --argjson icons "$icons" "$rows"' |
          "\(.title // "")  ·  \(.app_id // "")  ·  \($where[.workspace_id | tostring] // "")"
          + "\u0000icon\u001f\($icons[.app_id // ""] // .app_id // "")\n"' <<<"$windows" |
      fuzzel --dmenu --index --prompt "window: ") || exit 0
    # Text typed without a match comes back as -1.
    if [[ $i =~ ^[0-9]+$ ]] && ((i < ''${#ids[@]})); then
      niri msg action focus-window --id "''${ids[$i]}"
    fi
  '';
}
