{
  lib,
  writeShellApplication,
  coreutils,
  libnotify,
  util-linux,
  probes,
}:
writeShellApplication {
  name = "health";
  runtimeInputs = [
    coreutils
    libnotify
    util-linux
  ];
  text = ''
    export LC_ALL=C
    state=''${XDG_STATE_HOME:-$HOME/.local/state}/health
    findings=$state/findings
    notified=$state/notified

    usage() {
      echo "usage: health [--greeting | --notify]" >&2
      exit 2
    }
    [ $# -le 1 ] || usage
    mode=''${1-}

    case $mode in
      "" | --notify) ;;
      --greeting)
        if [ -s "$findings" ]; then
          n=$(wc -l <"$findings")
          if [ "$n" = 1 ]; then noun=finding; else noun=findings; fi
          echo "⚠ $n health $noun — run 'health'"
        fi
        exit 0
        ;;
      *) usage ;;
    esac

    # Prefixes each stdout line with the probe name; a probe that exits non-zero is a finding itself.
    run() {
      local name=$1 out status=0 line
      out=$("$2") || status=$?
      while IFS= read -r line; do
        if [ -n "$line" ]; then printf '%s %s\n' "$name" "$line"; fi
      done <<<"$out"
      if [ "$status" != 0 ]; then printf '%s probe exited %s\n' "$name" "$status"; fi
    }

    mkdir -p "$state"
    exec 9>"$state/lock"
    flock 9
    next=$(mktemp "$state/.findings.XXXXXX")
    trap 'rm -f "$next"' EXIT

    {
    ${lib.concatStrings (
      lib.mapAttrsToList (name: exe: ''
        run ${lib.escapeShellArg name} ${lib.escapeShellArg exe}
      '') probes
    )}
    } | sort -u >"$next"

    # Compared against the last set a notification went out for, so a failed send retries and a manual run doesn't swallow one.
    if [ "$mode" = --notify ]; then
      [ -e "$notified" ] || : >"$notified"
      new=$(comm -13 "$notified" "$next")
      sent=1
      if [ -n "$new" ]; then
        n=$(wc -l <<<"$new")
        if [ "$n" = 1 ]; then noun=finding; else noun=findings; fi
        notify-send -a health "$n new health $noun" "$(head -n 5 <<<"$new")" || sent=0
      fi
      if [ "$sent" = 1 ]; then cp "$next" "$notified"; else echo "health: notify-send failed; retrying next run" >&2; fi
    fi

    mv "$next" "$findings"
    trap - EXIT

    if [ "$mode" = "" ]; then
      if [ -s "$findings" ]; then cat "$findings"; else echo "no health findings"; fi
    fi
  '';
}
