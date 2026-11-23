{
  coreutils,
  gnugrep,
  jq,
  niri,
  procps,
  steam,
  systemd,
  writeShellApplication,
}:
writeShellApplication {
  name = "steam-update";
  runtimeInputs = [
    coreutils
    gnugrep
    jq
    niri
    procps
    steam
    systemd
  ];
  text = builtins.readFile ./steam-update.sh;
}
