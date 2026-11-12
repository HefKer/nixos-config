{
  coreutils,
  gawk,
  jq,
  niri,
  pipewire,
  util-linux,
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
    util-linux
    wireplumber
  ];
  text = ''
    # One file per window pid holding "LEVEL MUTED", e.g. "0.85 0". Written whole by mv, so the watcher never reads half of one.
    held_dir=''${XDG_RUNTIME_DIR:?}/window-volume

    # Prints "LEVEL MUTED" for a pid with a held volume, and fails for one without.
    held_get() {
      local level muted
      [ -f "$held_dir/$1" ] && read -r level muted <"$held_dir/$1" && echo "$level $muted"
    }

    held_set() {
      local tmp
      tmp=$(mktemp "$held_dir/.tmp.XXXXXX")
      echo "$2 $3" >"$tmp"
      mv "$tmp" "$held_dir/$1"
    }

    # A jq def: output streams among pw-dump's objects, as "ID PID".
    streams_def='def streams: select(.type == "PipeWire:Interface:Node" and .info.props."media.class" == "Stream/Output/Audio")
      | "\(.id) \(.info.props."application.process.id" // 0)";'

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

    watch_streams() {
      local kind id pid p level muted status
      local -A seen=()
      mkdir -p "$held_dir"
      while true; do
        if read -r -t 5 kind id pid; then
          if [ "$kind" = gone ]; then
            unset "seen[$id]"
          # The first dump lists streams already playing, whose level may have changed since; a restart leaves them be.
          elif [ "$kind" = old ]; then
            seen[$id]=1
          # pw-dump repeats a node on each change; only its first appearance takes the held volume, so later tweaks stick.
          elif [ -z "''${seen[$id]-}" ]; then
            seen[$id]=1
            for p in $(ancestors "$pid"); do
              if read -r level muted < <(held_get "$p"); then
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
      done < <(pw-dump --monitor --no-colors | jq -n --unbuffered -r "$streams_def"'
        foreach inputs as $dump (0; . + 1; . as $n | $dump[]
          | if .info == null then "gone \(.id) 0" else streams | (if $n == 1 then "old " else "stream " end) + . end)')
    }

    case ''${1-} in
      up) step=5%+ delta=0.05 ;;
      down) step=5%- delta=-0.05 ;;
      mute) ;;
      watch)
        watch_streams
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
    done < <(pw-dump | jq -r "$streams_def"' .[] | streams')

    # Key repeat spawns presses close together; each must read the held volume the last one wrote.
    mkdir -p "$held_dir"
    exec 9>"$held_dir/.lock"
    flock 9

    if [ ''${#streams[@]} -eq 0 ]; then
      # Nothing playing: step the held volume alone, from 100% unmuted when the window has none yet.
      read -r level muted < <(held_get "$pid" || echo "1 0")
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
      level=$(awk '{ l = $2; if (l > 1) l = 1; printf "%.2f", l }' <<<"$reading")
      muted=0
      if [[ $reading == *MUTED* ]]; then muted=1; fi
      when=""
    fi

    held_set "$pid" "$level" "$muted"

    percent=$(awk -v l="$level" 'BEGIN { printf "%d", l * 100 + 0.5 }')
    if [ "$muted" = 1 ]; then toast infoWith "$app: muted$when"; else toast infoWith "$app: $percent%$when"; fi
  '';
}
