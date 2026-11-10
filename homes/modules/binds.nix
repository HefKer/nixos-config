{
  dotfilesRoot,
  pkgs,
  ...
}:
{
  home.packages = [
    # One fuzzy search over every scope's binds (HefKer/nixos-issues#108).
    (pkgs.callPackage ../../pkgs/bind-palette { kanataKeymap = "${dotfilesRoot}/kanata/keymap.kbd"; })
  ];
}
