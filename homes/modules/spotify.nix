{
  inputs,
  osConfig,
  pkgs,
  ...
}:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  soloist-mpris = pkgs.callPackage ../../pkgs/soloist-mpris { };
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

  # The full client, for browsing; it installs spotify itself.
  programs.spicetify = {
    enable = true;
    wayland = true;
    theme = spicePkgs.themes.text;
    colorScheme = "EverforestDarkHard";
    enabledExtensions = with spicePkgs.extensions; [
      keyboardShortcut
      shuffle
      beautifulLyrics
      wikify
      madeForYouShortcut
      aiBandBlocker
      copyLyrics
    ];
    # For browsing only: what it installs lives in Spotify's localStorage; keepers move to enabledExtensions.
    enabledCustomApps = with spicePkgs.apps; [ marketplace ];
  };

  # Soloist: this host as a headless Spotify Connect speaker; soloist-mpris shows it to DMS and the media keys.
  systemd.user.services.soloist = {
    Unit = {
      Description = "Spotify Soloist: this computer as a Spotify Connect speaker";
      After = [
        "pipewire.service"
        "pipewire-pulse.service"
      ];
    };
    Service = {
      EnvironmentFile = osConfig.sops.templates."soloist.env".path;
      # Soloist restores its login once, at start, so wait (up to 2 min) for Spotify to resolve.
      ExecStartPre = toString (
        pkgs.writeShellScript "soloist-wait-online" ''
          end=$(( $(${pkgs.coreutils}/bin/date +%s) + 120 ))
          while [ "$(${pkgs.coreutils}/bin/date +%s)" -lt "$end" ]; do
            ${pkgs.coreutils}/bin/timeout 3 ${pkgs.getent}/bin/getent ahosts apresolve.spotify.com >/dev/null && exit 0
            sleep 2
          done
        ''
      );
      TimeoutStartSec = "3min";
      # The WebSocket API has no auth, so it stays on loopback; soloist-mpris finds its port in ws.port.
      ExecStart = "${pkgs.soloist}/bin/soloist --device-name %H --api-key \${SOLOIST_API_KEY} --cache-size 2048 --ws 127.0.0.1:0";
      Restart = "on-failure";
      RestartSec = 10;
      # Exit 10 means the build expired: only a nixpkgs bump fixes that.
      RestartPreventExitStatus = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.soloist-mpris = {
    Unit = {
      Description = "Spotify Soloist as an MPRIS player";
      PartOf = [ "soloist.service" ];
      After = [ "soloist.service" ];
    };
    Service = {
      ExecStart = "${soloist-mpris}/bin/soloist-mpris";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "soloist.service" ];
  };
}
