{
  android-tools,
  coreutils,
  diffutils,
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

  termuxDeliver = writeShellApplication {
    name = "phone-termux-deliver";
    runtimeInputs = [
      coreutils
      diffutils
    ];
    text = builtins.readFile ./termux-deliver.sh;
  };
}
