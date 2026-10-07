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
        # JACK apps (MIDI/adv audio); desktop-only until Phase 4 of ADR-0004.
        jack.enable = lib.mkIf (config.custom.platform == "desktop") true;
      };
    };

    security.rtkit.enable = true;
  };
}
