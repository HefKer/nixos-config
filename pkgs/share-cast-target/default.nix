{
  coreutils,
  jq,
  niri,
  writeShellApplication,
  wtype,
}:
writeShellApplication {
  name = "share-cast-target";
  runtimeInputs = [
    coreutils
    jq
    niri
    wtype
  ];
  text = ''
    # Answers the next GNOME "Share Screen" dialog with niri's Dynamic Cast Target by keyboard, then runs the given niri action to aim it.
    timeout=''${SHARE_TIMEOUT:-15}
    [ $# -gt 0 ] || {
      echo "usage: share-cast-target <niri dynamic-cast action...>" >&2
      exit 2
    }

    focused() {
      [ "$(niri msg --json focused-window | jq -r '.app_id // empty')" = xdg-desktop-portal-gnome ]
    }

    deadline=$((SECONDS + timeout))
    until focused; do
      ((SECONDS < deadline)) || {
        echo "share-cast-target: no Share Screen dialog within ''${timeout}s" >&2
        exit 1
      }
      sleep 0.1
    done
    sleep 0.3

    # Window tab, into its list, the target (always last), select, then Tab past Cancel to Share.
    for key in Left space Tab End space Tab Tab space; do
      focused || {
        echo "share-cast-target: dialog lost focus before $key" >&2
        exit 1
      }
      wtype -k "$key"
      sleep 0.15
    done

    # niri holds each new dynamic cast until a target is set after it starts, and Chromium opens a second session right after the first.
    for _ in $(seq 40); do
      niri msg action "$@"
      sleep 0.15
    done
  '';
}
