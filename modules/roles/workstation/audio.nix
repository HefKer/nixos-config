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
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
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
            # DeepFilterNet then gain on the mic alone, so voice chat's noise filter can be off and stop eating the sounds.
            name = "libpipewire-module-filter-chain";
            args = {
              "node.description" = "Mic into soundboard";
              "media.name" = "Mic into soundboard";
              "filter.graph" = {
                nodes = [
                  {
                    type = "ladspa";
                    name = "denoise";
                    plugin = "${pkgs.deepfilternet}/lib/ladspa/libdeep_filter_ladspa.so";
                    label = "deep_filter_mono";
                    # How far noise is pushed down; 100 removes it outright, lower sounds more natural.
                    control."Attenuation Limit (dB)" = 100.0;
                  }
                  {
                    type = "builtin";
                    name = "gain";
                    label = "linear";
                    # Output = input x Mult; 4.0 is +12 dB, set so friends no longer boost the mic (and the sounds with it) by 200%.
                    control.Mult = 4.0;
                  }
                ];
                links = [
                  {
                    output = "denoise:Audio Out";
                    input = "gain:In";
                  }
                ];
              };
              # Passive, so the real mic stays suspended until something records the soundboard mic.
              "capture.props" = {
                "audio.rate" = 48000;
                "node.name" = "soundboard-pass";
                "node.passive" = true;
                "stream.capture.sink" = false;
              };
              "playback.props" = {
                "node.name" = "soundboard-pass.out";
                "node.passive" = true;
                "audio.rate" = 48000;
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
