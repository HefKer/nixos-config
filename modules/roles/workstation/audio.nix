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
        # sound-pick plays into soundboard-in beside a copy of the mic; priority.session 0 keeps WirePlumber from defaulting to either.
        extraConfig.pipewire."90-soundboard"."context.modules" = [
          {
            name = "libpipewire-module-loopback";
            args = {
              "node.description" = "Soundboard mic";
              "capture.props" = {
                "node.name" = "soundboard-in";
                "media.class" = "Audio/Sink";
                "audio.position" = [
                  "FL"
                  "FR"
                ];
                "priority.session" = 0;
              };
              "playback.props" = {
                "node.name" = "soundboard-mic";
                "media.class" = "Audio/Source";
                "audio.position" = [
                  "FL"
                  "FR"
                ];
                "priority.session" = 0;
              };
            };
          }
          {
            name = "libpipewire-module-loopback";
            args = {
              "node.description" = "Mic into soundboard";
              # Passive, so the real mic stays suspended until something records the soundboard mic.
              "capture.props" = {
                "node.name" = "soundboard-pass";
                "node.passive" = true;
                "stream.capture.sink" = false;
              };
              "playback.props" = {
                "node.name" = "soundboard-pass.out";
                "node.passive" = true;
                "target.object" = "soundboard-in";
                "node.dont-reconnect" = true;
              };
            };
          }
        ];
      };
    };

    security.rtkit.enable = true;
  };
}
