{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.custom.roles.workstation.gaming;
in
{
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  config = lib.mkIf cfg.enable {
    /*
      Launch options for steam:
      gamemoderun %command%
      - Launches game with GameMode (temporary CPU/GPU optimizations)
      mangohud %command%
      - System resource overlay using Vulkan/OpenGL layer
      - optionally launch steam with env MANGOHUD=1
      gamescope %command%
      - Runs game inside a nested Wayland compositor (forces a resolution/refresh rate, upscaling, session)
    */
    services = {
      flatpak = {
        enable = true;
        packages = [ "com.usebottles.bottles" ];
        # Flatpak's NVIDIA GL runtime must match the host driver version exactly.
        update.onActivation = true;
      };

      sunshine = {
        enable = true;
        # Without CUDA the build gets no driver runpath, libcuda.so.1 never loads and NVENC falls back to libx264.
        package = pkgs.sunshine.override { cudaSupport = true; };
        autoStart = false;
        capSysAdmin = true; # only needed for Wayland -- omit this when using with Xorg
        # Stream over Tailscale only (ports opened on tailscale0 below); flip to true for LAN clients.
        openFirewall = false;
      };
    };

    programs = {
      gamemode.enable = true;

      steam = {
        enable = true;
        gamescopeSession.enable = true;

        # Set here, not systemPackages: this wrapping is what lets protontricks see extraCompatPackages below.
        protontricks.enable = true;

        extraCompatPackages = with pkgs; [ proton-ge-bin ];
      };
      # to execute appimage games via steam
      appimage = {
        enable = true;
        binfmt = true;
      };
    };

    # Tailscale SSH is answered inside tailscaled, but Sunshine's ports go through the NixOS firewall; offsets mirror the module's.
    networking.firewall.interfaces.${config.services.tailscale.interfaceName} =
      let
        sunshinePorts = map (offset: config.services.sunshine.settings.port + offset);
      in
      {
        allowedTCPPorts = sunshinePorts [
          (-5)
          0
          1
          21
        ];
        allowedUDPPorts = sunshinePorts [
          9
          10
          11
          13
          21
        ];
      };

    # nix-flatpak's unit only orders after multi-user.target, so its first run at boot can race DNS.
    systemd.services.flatpak-managed-install = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };

    # No modalias, so it's never autoloaded; Wine/Proton falls back to fsync without /dev/ntsync.
    boot.kernelModules = [ "ntsync" ];

    # nix-gaming tracks osu releases within a day; nixpkgs lags by weeks.
    nixpkgs.overlays = [ inputs.nix-gaming.overlays.default ];

    environment.systemPackages = with pkgs; [
      # Gaming utils/deps
      mangohud
      xremap
      wine
      me3

      # osu-stable deps
      zenity
      desktop-file-utils
      cabextract

      # Games
      (osu-lazer-bin.override { gmrun_enable = false; }) # gamemoderun's LD_PRELOAD aborts bwrap on exit (FeralInteractive/gamemode#577)
      osu-stable # self-installing wine/proton wrapper; first run downloads ~400MB

      # Game launchers
      lutris
      heroic # Epic/GOG/Amazon
      cemu
      # https://www.protondb.com/ to verify if games run on loonix
      (prismlauncher.override {
        # Add binary required by some mod
        additionalPrograms = [ ffmpeg ];

        # Change Java runtimes available to Prism Launcher
        jdks = [
          graalvmPackages.graalvm-ce
          zulu8
          zulu17
          zulu
        ];
      })
    ];

    # Steam's wrapper assigns STEAM_EXTRA_COMPAT_TOOLS_PATHS itself, overriding sessionVariables, so it isn't set here.
  };
}
