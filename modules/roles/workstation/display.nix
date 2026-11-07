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

    # The portal Qt theme ignores GTK's icon theme, so the bar's tray icons fall back to hicolor
    systemd.user.services.dms.environment.QS_ICON_THEME = "Papirus-Dark";

    xdg.portal = {
      extraPortals = [
        pkgs.xdg-desktop-portal-termfilechooser
        pkgs.xdg-desktop-portal-wlr
      ];
      config.niri = {
        "org.freedesktop.impl.portal.FileChooser" = "termfilechooser";
        # Monitors only (niri lacks ext-image-copy-capture), but a chooser script can answer without a dialog.
        "org.freedesktop.impl.portal.ScreenCast" = "wlr";
      };
    };

    environment.etc."xdg/xdg-desktop-portal-wlr/config".text = ''
      [screencast]
      chooser_type=simple
      chooser_cmd=${
        lib.getExe (pkgs.callPackage ../../../pkgs/cast-chooser { niri = config.programs.niri.package; })
      }
    '';

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
