{
  android-tools,
  coreutils,
  gnugrep,
  phone,
  writeShellApplication,
}:
let
  automation =
    name: inputs: text:
    writeShellApplication {
      inherit name;
      runtimeInputs = [
        coreutils
        phone
      ]
      ++ inputs;
      text = builtins.readFile ./reach.sh + text;
    };
in
{
  # A finding once no automation has reached the phone for `maxHours`.
  adbProbe =
    maxHours:
    automation "health-probe-phone-adb" [ ] ''
      MAX_HOURS=${toString maxHours}
      ${builtins.readFile ./adb-probe.sh}
    '';

  settingsLog = automation "phone-settings-log" [
    android-tools
    gnugrep
  ] (builtins.readFile ./settings-log.sh);
}
