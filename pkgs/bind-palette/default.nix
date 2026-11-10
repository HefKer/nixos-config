{
  coreutils,
  fuzzel,
  gawk,
  gnused,
  jq,
  lib,
  libnotify,
  util-linux,
  wl-clipboard,
  writeShellApplication,
  yq-go,
  # kanata's keymap, read in place from the dotfiles.
  kanataKeymap,
}:
# dms, niri, nvim and qutebrowser come from PATH: the palette asks the running, configured ones for their binds.
writeShellApplication {
  name = "bind-palette";
  runtimeInputs = [
    coreutils
    fuzzel
    gawk
    gnused
    jq
    libnotify
    util-linux
    wl-clipboard
    yq-go
  ];
  text = ''
    kanata_keymap=${lib.escapeShellArg kanataKeymap}
  ''
  + builtins.readFile ./bind-palette.sh;
}
