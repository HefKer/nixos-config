{
  gawk,
  jq,
  niri,
  pipewire,
  wireplumber,
  writeShellApplication,
}:
writeShellApplication {
  name = "window-volume";
  runtimeInputs = [
    gawk
    jq
    niri
    pipewire
    wireplumber
  ];
  text = ''
    # DMS toasts rather than notifications: they show under do-not-disturb, and dismissing the last one keeps repeats from queueing.
    toast() {
      dms ipc call toast dismiss window-volume >/dev/null
      dms ipc call toast "$1" "$2" "" "" window-volume >/dev/null
    }

    case ''${1-} in
      up) step=5%+ ;;
      down) step=5%- ;;
      mute) ;;
      *)
        echo "usage: window-volume up|down|mute" >&2
        exit 2
        ;;
    esac

    window=$(niri msg --json focused-window)
    pid=$(jq -r '.pid // empty' <<<"$window")
    app=$(jq -r '.app_id // "This window"' <<<"$window")

    # Browsers and Electron apps play audio from a child process, so match streams by descent.
    descends_from() {
      local p=$1 stat
      while [ "$p" -gt 1 ]; do
        [ "$p" = "$2" ] && return 0
        stat=$(<"/proc/$p/stat") || return 1
        # The command name in field 2 may hold spaces; ppid is the second field after it.
        stat=''${stat##*) }
        read -r _ p _ <<<"$stat"
      done
      return 1
    }

    streams=()
    if [ -n "$pid" ]; then
      while read -r id stream_pid; do
        if descends_from "$stream_pid" "$pid"; then
          streams+=("$id")
        fi
      done < <(pw-dump | jq -r '.[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props."media.class" == "Stream/Output/Audio")
        | "\(.id) \(.info.props."application.process.id" // 0)"')
    fi

    if [ ''${#streams[@]} -eq 0 ]; then
      toast warnWith "$app isn't playing anything"
      exit 0
    fi

    # One app can have several streams; muting toggles them together, by whether any is still audible.
    if [ "$1" = mute ]; then
      muted=1
      for id in "''${streams[@]}"; do
        [[ $(wpctl get-volume "$id") == *MUTED* ]] || muted=0
      done
      for id in "''${streams[@]}"; do
        wpctl set-mute "$id" "$((1 - muted))"
      done
    else
      for id in "''${streams[@]}"; do
        wpctl set-volume --limit 1.0 "$id" "$step"
      done
    fi

    level=$(wpctl get-volume "''${streams[0]}")
    percent=$(awk '{ printf "%d", $2 * 100 + 0.5 }' <<<"$level")
    if [[ $level == *MUTED* ]]; then toast infoWith "$app: muted"; else toast infoWith "$app: $percent%"; fi
  '';
}
