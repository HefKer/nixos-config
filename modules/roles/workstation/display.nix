{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.roles.workstation;
in
{
  config = lib.mkIf cfg.enable {
    services = {
      xserver.enable = true; # xkb, libinput, nvidia driver attach

      displayManager.sddm = {
        enable = true;
        wayland.enable = true;
      };
      xserver.displayManager.lightdm.enable = lib.mkForce false;
      gnome.gnome-keyring.enable = true; # req by niri's secret portal
    };

    programs = {
      niri.enable = true;
      xwayland.enable = true; # required by onlyoffice
      dux-shell = {
        enable = true;

        systemd = {
          enable = true;
          restartIfChanged = true;
        };
      };
    };

    xdg.portal = {
      extraPortals = [ pkgs.xdg-desktop-portal-termfilechooser ];
      config.niri."org.freedesktop.impl.portal.FileChooser" = "termfilechooser";
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      # Outside a sandbox GTK3, Firefox and Qt open their own file dialogs instead of the portal's
      GTK_USE_PORTAL = "1";
      QT_QPA_PLATFORMTHEME = "xdgdesktopportal";
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
