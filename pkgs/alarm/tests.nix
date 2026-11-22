{
  callPackage,
  jq,
  libfaketime,
  runCommandLocal,
  writeShellScriptBin,
  symlinkJoin,
}:
let
  # Timers are logged, not started; a ring's notification runs $WHILE_RINGING, answers Dismiss and is logged.
  fakeSystemd = symlinkJoin {
    name = "fake-systemd";
    paths = [
      (writeShellScriptBin "systemctl" "true")
      (writeShellScriptBin "systemd-run" ''echo "systemd-run $*" >>"$LOG"'')
    ];
  };
  fakeNotify = writeShellScriptBin "notify-send" ''
    echo "notify $*" >>"$LOG"
    if [ "$1" = -p ]; then
      echo 1
      [ -z "''${WHILE_RINGING:-}" ] || $WHILE_RINGING >/dev/null
      echo dismiss
    fi
  '';
  fakePipewire = writeShellScriptBin "pw-play" "sleep 0.1";
  fakeGlib = writeShellScriptBin "gdbus" "true";
  # The store path is baked into the script, so it names the Linux sandbox's build dir.
  alarm = callPackage ./. {
    store = "/build/store";
    systemd = fakeSystemd;
    libnotify = fakeNotify;
    pipewire = fakePipewire;
    glib = fakeGlib;
  };
in
runCommandLocal "alarm-tests"
  {
    nativeBuildInputs = [
      alarm
      jq
      libfaketime
    ];
  }
  ''
    export HOME=$PWD/home LOG=$PWD/log TZ=UTC
    mkdir -p "$HOME" /build/store
    touch "$LOG"
    fail=0
    expect() {
      if [ "$1" != "$2" ]; then
        printf 'FAIL %s:\n  got      %s\n  expected %s\n' "$3" "$1" "$2"
        fail=1
      fi
    }
    on() { faketime "$1" "''${@:2}"; }
    epoch() { date -d "$1" +%s; }
    field() { sed -n "s/^$2=//p" "/build/store/$1"; }

    # 2026-11-25 is a Wednesday.
    id=$(on '2026-11-25 12:00:00' alarm weekdays 7:30 gym | cut -f1)
    tag=r$(cksum <<<"Mon,Tue,Wed,Thu,Fri 07:30" | cut -d' ' -f1)

    on '2026-11-25 12:00:00' alarm skip "$id" >/dev/null
    expect "$(field "$id" handled)" "$(epoch '2026-11-26 07:30')" "skip marks the next occurrence handled"
    on '2026-11-25 12:00:00' alarm skip "$id" >/dev/null
    expect "$(field "$id" handled)" "$(epoch '2026-11-26 07:30')" "skipping again skips the same occurrence"

    expect "$(on '2026-11-25 12:00:00' alarm ls --json | jq '.[0].at')" "$(epoch '2026-11-27 07:30')" \
      "ls --json shows the occurrence after the skipped one"
    expect "$(on '2026-11-25 12:00:00' alarm ls | cut -f2)" "Fri 07:30 (in 43h30m) ⟳ weekdays 07:30" \
      "ls shows the occurrence after the skipped one"

    : >"$LOG"
    on '2026-11-26 07:30:03' alarm ring "$id" "$tag"
    expect "$(grep -c notify "$LOG")" 0 "the skipped occurrence doesn't ring"
    on '2026-11-27 07:30:03' alarm ring "$id" "$tag"
    expect "$(grep -c 'notify -p' "$LOG")" 1 "the occurrence after it rings"
    expect "$(field "$id" handled)" "$(epoch '2026-11-27 07:30')" "and is handled once dismissed"

    # A skip landing while the previous occurrence rings, as from another host.
    late=$(on '2026-11-30 12:00:00' alarm weekdays 8:00 late | cut -f1)
    WHILE_RINGING="alarm skip $late" on '2026-12-01 08:00:01' alarm ring "$late" "r$(cksum <<<"Mon,Tue,Wed,Thu,Fri 08:00" | cut -d' ' -f1)"
    expect "$(field "$late" handled)" "$(epoch '2026-12-02 08:00')" "a ring ending after a skip doesn't undo it"

    snoozed=$(on '2026-11-25 12:00:00' alarm daily 9:00 tea | cut -f1)
    printf 'at=%s\n' "$(epoch '2026-11-25 12:05')" >>"/build/store/$snoozed"
    on '2026-11-25 12:00:00' alarm skip "$snoozed" >/dev/null
    expect "$(field "$snoozed" at)" "$(epoch '2026-11-25 12:05')" "a pending snoozed ring is left alone"
    expect "$(field "$snoozed" handled)" "$(epoch '2026-11-26 09:00')" "while the next occurrence is skipped"

    once=$(on '2026-11-25 12:00:00' alarm 10m tea | cut -f1)
    if msg=$(on '2026-11-25 12:00:00' alarm skip "$once" 2>&1); then
      echo "FAIL skip on a one-shot fails"; fail=1
    fi
    expect "$msg" "alarm: tea rings once; cancel it with alarm rm $once" "and points to alarm rm"
    if on '2026-11-25 12:00:00' alarm skip deadbeef 2>/dev/null; then
      echo "FAIL skip on an unknown id fails"; fail=1
    fi

    if [ "$fail" != 0 ]; then exit 1; fi
    touch $out
  ''
