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
symlinkJoin {
  name = "phone";
  paths = [
    (writeShellApplication {
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
    })
    (writeTextDir "share/skills/phone/phone/SKILL.md" (builtins.readFile ./SKILL.md))
  ];
}
