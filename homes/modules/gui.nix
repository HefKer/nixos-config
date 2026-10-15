{ pkgs, ... }:
{
  # GUI home-manager config for workstation hosts.

  gtk = {
    enable = true;
    colorScheme = "dark";
    # Qt apps read this too (QT_QPA_PLATFORMTHEME=gtk3); a name with no installed theme blanks every icon.
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
  };
}
