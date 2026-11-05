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

    # Fuzzel's dmenu reads "text\0icon\x1fname" per line, so each row gets its app's icon.
    i=$(jq -j --argjson ws "$workspaces" "$rows"' |
          "\(.title // "")  ·  \(.app_id // "")  ·  \($where[.workspace_id | tostring] // "")"
          + "\u0000icon\u001f\(.app_id // "")\n"' <<<"$windows" |
      fuzzel --dmenu --index --prompt "window: ") || exit 0
    # Text typed without a match comes back as -1.
    if [[ $i =~ ^[0-9]+$ ]] && ((i < ''${#ids[@]})); then
      niri msg action focus-window --id "''${ids[$i]}"
    fi
  '';
}
