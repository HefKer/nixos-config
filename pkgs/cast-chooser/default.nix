{
  coreutils,
  fuzzel,
  jq,
  niri,
  writeShellApplication,
}:
writeShellApplication {
  name = "cast-chooser";
  excludeShellChecks = [ "SC2016" ];
  runtimeInputs = [
    coreutils
    fuzzel
    jq
    niri
  ];
  text = ''
    # One-shot target an app (Vesktop's VcPresets) leaves just before it asks to share; stale ones are dropped.
    target=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/xdpw-cast-target
    if [ -f "$target" ]; then
      name=$(tr -d '[:space:]' <"$target")
      age=$(($(date +%s) - $(stat -c %Y "$target")))
      rm -f "$target"
      if [ -n "$name" ] && ((age < 30)); then
        echo "Monitor: $name"
        exit 0
      fi
    fi

    # Left to right, so the menu reads in the order the screens sit on the desk.
    outputs=$(niri msg --json outputs | jq -r '
      to_entries | map(select(.value.logical != null)) | sort_by(.value.logical.x)[]
      | "\(.key)  ·  \(.value.make) \(.value.model)  ·  at \(.value.logical.x),\(.value.logical.y)"')
    [ -n "$outputs" ] || exit 0
    pick=$(fuzzel --dmenu --prompt "share screen: " <<<"$outputs") || exit 0
    echo "Monitor: ''${pick%%  ·  *}"
  '';
}
