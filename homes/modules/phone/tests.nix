{
  callPackage,
  runCommandLocal,
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

    if [ "$fail" != 0 ]; then exit 1; fi
    touch $out
  ''
