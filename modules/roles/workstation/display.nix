{ config, lib, ... }:
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
      dms-shell = {
        enable = true;

        systemd = {
          enable = true;
          restartIfChanged = true;
        };
      };
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
