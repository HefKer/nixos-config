{
  dotfilesRoot,
  pkgs,
  ...
}:
{
  home.packages = [
    # One fuzzy search over every scope's binds.
    (pkgs.callPackage ../../pkgs/bind-palette { kanataKeymap = "${dotfilesRoot}/kanata/keymap.kbd"; })
    # The desktop leader's which-key popup, on niri's Mod+Ctrl+Space; its menu is a dotfile.
    pkgs.wlr-which-key
  ];
}
