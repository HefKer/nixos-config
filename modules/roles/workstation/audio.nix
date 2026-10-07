{ config, lib, ... }:
let
  cfg = config.custom.roles.workstation;
in
{
  config = lib.mkIf cfg.enable {
    services = {
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };
    };

    security.rtkit.enable = true;
  };
}
