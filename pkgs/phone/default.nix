{
  android-tools,
  nmap,
  coreutils,
  gawk,
  gnugrep,
  jq,
  tailscale,
  symlinkJoin,
  writeShellApplication,
  writeTextDir,
}:
let
  phone-connect = writeShellApplication {
    name = "phone-connect";
    runtimeInputs = [
      android-tools
      nmap
      coreutils
      gawk
      gnugrep
      jq
      tailscale
    ];
    text = builtins.readFile ./phone-connect.sh;
  };
in
symlinkJoin {
  name = "phone";
  paths = [
    phone-connect
    (writeShellApplication {
      name = "phone-set";
      runtimeInputs = [
        android-tools
        coreutils
        phone-connect
      ];
      text = builtins.readFile ./phone-set.sh;
    })
    (writeTextDir "share/skills/phone/phone/SKILL.md" (builtins.readFile ./SKILL.md))
  ];
}
