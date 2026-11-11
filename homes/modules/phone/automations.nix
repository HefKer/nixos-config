{
  android-tools,
  coreutils,
  gnugrep,
  phone,
  writeShellApplication,
}:
let
  reaching =
    name: inputs: script:
    writeShellApplication {
      inherit name;
      runtimeInputs = [
        coreutils
        phone
      ]
      ++ inputs;
      text = builtins.readFile ./reach.sh + builtins.readFile script;
    };
in
{
  adbProbe = reaching "health-probe-phone-adb" [ ] ./adb-probe.sh;

  settingsChanges = reaching "phone-settings-changes" [
    android-tools
    gnugrep
  ] ./settings-changes.sh;
}
