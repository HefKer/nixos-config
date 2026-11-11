{
  coreutils,
  fuzzel,
  gawk,
  gh,
  gnugrep,
  jq,
  libnotify,
  niri,
  util-linux,
  writeShellApplication,
  yq-go,
}:
writeShellApplication {
  name = "backlog";
  runtimeInputs = [
    coreutils
    fuzzel
    gawk
    gh
    gnugrep
    jq
    libnotify
    niri
    util-linux
    yq-go
  ];
  text = builtins.readFile ./backlog.sh;
}
