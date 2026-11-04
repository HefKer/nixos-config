{ pkgs, ... }:
{
  # GUI home-manager config for workstation hosts.

  gtk = {
    enable = true;
    colorScheme = "dark";
    # A name with no installed theme blanks every icon; DMS's tray gets it via QS_ICON_THEME.
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
  };
}
