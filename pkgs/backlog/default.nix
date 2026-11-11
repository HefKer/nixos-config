{
  callPackage,
  coreutils,
  fuzzel,
  gawk,
  gh,
  gnugrep,
  jq,
  libnotify,
  niri,
  util-linux,
  wl-clipboard,
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
    (callPackage ../repeat { })
    util-linux
    wl-clipboard
    yq-go
  ];
  text = builtins.readFile ./backlog.sh;
}
