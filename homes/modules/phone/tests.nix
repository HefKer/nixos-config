{
  callPackage,
  runCommandLocal,
  shellcheck,
  writeShellScriptBin,
}:
let
  # Reaches the phone only while $PHONE/online exists.
  fakePhone = writeShellScriptBin "phone-connect" ''
    if [ -e "$PHONE/online" ]; then echo fake:5555; else exit 1; fi
  '';

  # Answers every call with $PHONE/history, as `settings get system settings_change_history` does.
  fakeAdb = writeShellScriptBin "adb" ''
    cat "$PHONE/history"
  '';

  # Answer as Termux:API does while $PHONE/api exists.
  fakeBattery = writeShellScriptBin "termux-battery-status" ''
    [ -e "$PHONE/api" ] || exit 1
    printf '{\n  "health": "GOOD",\n  "percentage": 87,\n  "plugged": "UNPLUGGED",\n  "status": "DISCHARGING"\n}\n'
  '';
  fakeWifi = writeShellScriptBin "termux-wifi-connectioninfo" ''
    [ -e "$PHONE/api" ] || exit 1
    printf '{\n  "rssi": -52,\n  "ssid": "Home Net",\n  "supplicant_state": "COMPLETED"\n}\n'
  '';
  termuxScripts = ../../../phone/termux;

  automations = callPackage ./automations.nix {
    android-tools = fakeAdb;
    phone = fakePhone;
  };
in
runCommandLocal "phone-automations-tests"
  {
    nativeBuildInputs = [
      automations.adbProbe
      automations.settingsChanges
      automations.termuxDeliver
      fakeBattery
      fakeWifi
      shellcheck
    ];
  }
  ''
    export HOME=$PWD/home PHONE=$PWD/phone
    mkdir -p "$HOME" "$PHONE"
    state=$HOME/.local/state/phone
    fail=0
    expect() {
      if [ "$1" != "$2" ]; then
        printf 'FAIL %s:\n  got      %s\n  expected %s\n' "$3" "$1" "$2"
        fail=1
      fi
    }

    finding() { echo "no adb connection since $1; check Wireless debugging and Tailscale on the phone"; }

    expect "$(health-probe-phone-adb)" "" "the first miss is not a finding"
    touch -d '23 hours ago' "$state/unreached-since"
    expect "$(health-probe-phone-adb)" "" "under a day out of reach is not either"
    touch -d '25 hours ago' "$state/unreached-since"
    since=$(date -d '25 hours ago' '+%F %R')
    expect "$(health-probe-phone-adb)" "$(finding "$since")" "over a day out of reach is a finding"
    expect "$(health-probe-phone-adb)" "$(finding "$since")" "the finding reads the same on every run, so it notifies once"

    phone-settings-changes
    [ ! -e "$state/settings-changes.tsv" ] || { echo "FAIL changes were written with the phone out of reach"; fail=1; }
    expect "$(health-probe-phone-adb)" "$(finding "$since")" "a run that missed the phone leaves the first miss dated"

    touch "$PHONE/online"
    echo '1794381836956|blue_light_filter|com.android.settings;1794380761782|toggle_adb_wireless|com.android.settings' >"$PHONE/history"
    phone-settings-changes
    expect "$(cat "$state/settings-changes.tsv")" \
      $'2026-11-11T07:06:01.782Z\ttoggle_adb_wireless\tcom.android.settings\n2026-11-11T07:23:56.956Z\tblue_light_filter\tcom.android.settings' \
      "entries are written oldest first with the phone's own timestamp"
    rm "$PHONE/online"
    expect "$(health-probe-phone-adb)" "" "any run that reached the phone restarts the day"
    [ -e "$state/unreached-since" ] || { echo "FAIL a miss after a reach is not dated"; fail=1; }

    touch "$PHONE/online"
    phone-settings-changes
    expect "$(wc -l <"$state/settings-changes.tsv")" 2 "a second run with the same history adds nothing"
    echo '1794381900007|blue_light_filter|com.android.settings;1794381836956|blue_light_filter|com.android.settings' >"$PHONE/history"
    phone-settings-changes
    expect "$(tail -n1 "$state/settings-changes.tsv")" $'2026-11-11T07:25:00.007Z\tblue_light_filter\tcom.android.settings' \
      "the same key changed again is a new entry"
    expect "$(wc -l <"$state/settings-changes.tsv")" 3 "and only that one is added"

    echo null >"$PHONE/history"
    phone-settings-changes
    expect "$(wc -l <"$state/settings-changes.tsv")" 3 "a phone without the history key adds nothing"

    touch -d '25 hours ago' "$state/unreached-since"
    expect "$(health-probe-phone-adb)" "" "a probe run that reaches the phone is clean"

    shellcheck ${termuxScripts}/*.sh || fail=1

    vault=$PWD/vault
    phone-termux-deliver ${termuxScripts} "$vault/.polaris/termux" 2>/dev/null
    [ ! -e "$vault" ] || { echo "FAIL delivering created a vault that wasn't there"; fail=1; }
    mkdir -p "$vault/.polaris/termux"
    echo stale >"$vault/.polaris/termux/gone.sh"
    echo old >"$vault/.polaris/termux/run.sh"
    phone-termux-deliver ${termuxScripts} "$vault/.polaris/termux"
    expect "$(cd "$vault/.polaris/termux" && echo *)" "run.sh selftest.sh" "delivering mirrors the scripts and drops one the repo no longer has"
    cmp -s ${termuxScripts}/run.sh "$vault/.polaris/termux/run.sh" || { echo "FAIL a changed script is not replaced"; fail=1; }
    [ -w "$vault/.polaris/termux/run.sh" ] || { echo "FAIL a delivered script is read-only, so Syncthing can't replace it"; fail=1; }

    # Termux's side: ~/.termux/tasker holds only the run.sh copied by hand, and the vault is the delivered copy.
    tasker=$HOME/.termux/tasker
    mkdir -p "$tasker"
    cp ${termuxScripts}/run.sh "$tasker/run.sh"
    chmod u+w "$tasker/run.sh"
    echo stale >"$tasker/gone.sh"
    run() { TERMUX_SCRIPTS_SOURCE=$vault/.polaris/termux bash "$tasker/run.sh" "$@"; }

    expect "$(run selftest)" "battery unknown (Termux:API did not answer), wifi off, scripts in sync" "selftest answers in one line without Termux:API"
    [ ! -e "$tasker/gone.sh" ] || { echo "FAIL a script no longer delivered stays installed"; fail=1; }
    touch "$PHONE/api"
    expect "$(run selftest)" "battery 87% discharging, wifi Home Net -52 dBm, scripts in sync" "selftest reports battery and Wi-Fi"

    echo 'echo "got $(cat)"' >"$vault/.polaris/termux/echo.sh"
    expect "$(echo "a b; 'c'" | run echo)" "got a b; 'c'" "a newly delivered script runs on the next call, with stdin as its data"

    for bad in "" run ../echo "echo extra" /bin/sh nope; do
      # shellcheck disable=SC2086
      if run $bad >/dev/null 2>&1; then echo "FAIL run accepted: $bad"; fail=1; fi
    done
    if run echo "; touch pwned" >/dev/null 2>&1; then echo "FAIL run accepted a second argument"; fail=1; fi

    mv "$vault" "$vault.away"
    expect "$(run selftest)" "battery 87% discharging, wifi Home Net -52 dBm, delivered scripts unreadable" "with the vault unreadable the installed scripts still run"

    if [ "$fail" != 0 ]; then exit 1; fi
    touch $out
  ''
