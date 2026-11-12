{
  coreutils,
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
    coreutils
    gawk
    jq
    niri
    pipewire
    wireplumber
  ];
  text = ''
    # One file per window pid holding "LEVEL MUTED", e.g. "0.85 0". Written whole by mv, so the watcher never reads half of one.
    held_dir=''${XDG_RUNTIME_DIR:?}/window-volume

    # DMS toasts rather than notifications: they show under do-not-disturb, and dismissing the last one keeps repeats from queueing.
    toast() {
      dms ipc call toast dismiss window-volume >/dev/null
      dms ipc call toast "$1" "$2" "" "" window-volume >/dev/null
    }

    # Browsers and Electron apps play audio from a child process, so streams are matched by descent.
    ancestors() {
      local p=$1 stat
      while [ "$p" -gt 1 ]; do
        echo "$p"
        stat=$(<"/proc/$p/stat") || return 0
        # The command name in field 2 may hold spaces; ppid is the second field after it.
        stat=''${stat##*) }
        read -r _ p _ <<<"$stat"
      done
    }

    descends_from() {
      local p
      for p in $(ancestors "$1"); do
        if [ "$p" = "$2" ]; then return 0; fi
      done
      return 1
    }

    # The user service: gives each new stream its window's held volume, and drops held volumes whose window is gone.
    watch() {
      local kind id pid p level muted status
      local -A seen=()
      mkdir -p "$held_dir"
      while true; do
        if read -r -t 5 kind id pid; then
          if [ "$kind" = gone ]; then
            unset "seen[$id]"
          # pw-dump repeats a node on each change; only its first appearance takes the held volume, so later tweaks stick.
          elif [ -z "''${seen[$id]-}" ]; then
            seen[$id]=1
            for p in $(ancestors "$pid"); do
              if [ -f "$held_dir/$p" ] && read -r level muted <"$held_dir/$p"; then
                wpctl set-volume "$id" "$level" || true
                wpctl set-mute "$id" "$muted" || true
                break
              fi
            done
          fi
        else
          status=$?
          # Above 128 is read's timeout; anything else means pw-dump ended, and systemd restarts the watch.
          if [ "$status" -le 128 ]; then exit 1; fi
        fi
        for p in "$held_dir"/*; do
          if [ -f "$p" ] && [ ! -d "/proc/''${p##*/}" ]; then rm -f "$p"; fi
        done
      done < <(pw-dump --monitor --no-colors | jq --unbuffered -r '.[]
        | if .info == null then "gone \(.id) 0"
          elif .type == "PipeWire:Interface:Node" and .info.props."media.class" == "Stream/Output/Audio"
          then "stream \(.id) \(.info.props."application.process.id" // 0)"
          else empty end')
    }

    case ''${1-} in
      up) step=5%+ delta=0.05 ;;
      down) step=5%- delta=-0.05 ;;
      mute) ;;
      watch)
        watch
        exit
        ;;
      *)
        echo "usage: window-volume up|down|mute" >&2
        exit 2
        ;;
    esac

    window=$(niri msg --json focused-window)
    pid=$(jq -r '.pid // empty' <<<"$window")
    app=$(jq -r '.app_id // "This window"' <<<"$window")

    if [ -z "$pid" ]; then
      toast warnWith "$app isn't playing anything"
      exit 0
    fi

    streams=()
    while read -r id stream_pid; do
      if descends_from "$stream_pid" "$pid"; then
        streams+=("$id")
      fi
    done < <(pw-dump | jq -r '.[]
      | select(.type == "PipeWire:Interface:Node")
      | select(.info.props."media.class" == "Stream/Output/Audio")
      | "\(.id) \(.info.props."application.process.id" // 0)"')

    if [ ''${#streams[@]} -eq 0 ]; then
      # Nothing playing: step the held volume alone, from 100% unmuted when the window has none yet.
      level=1 muted=0
      if [ -f "$held_dir/$pid" ]; then read -r level muted <"$held_dir/$pid"; fi
      if [ "$1" = mute ]; then
        muted=$((1 - muted))
      else
        level=$(awk -v l="$level" -v d="$delta" 'BEGIN { l += d; if (l > 1) l = 1; if (l < 0) l = 0; printf "%.2f", l }')
      fi
      when=" (when it plays)"
    else
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
      reading=$(wpctl get-volume "''${streams[0]}")
      level=$(awk '{ printf "%.2f", $2 }' <<<"$reading")
      muted=0
      if [[ $reading == *MUTED* ]]; then muted=1; fi
      when=""
    fi

    mkdir -p "$held_dir"
    tmp=$(mktemp "$held_dir/.tmp.XXXXXX")
    echo "$level $muted" >"$tmp"
    mv "$tmp" "$held_dir/$pid"

    percent=$(awk -v l="$level" 'BEGIN { printf "%d", l * 100 + 0.5 }')
    if [ "$muted" = 1 ]; then toast infoWith "$app: muted$when"; else toast infoWith "$app: $percent%$when"; fi
  '';
}
