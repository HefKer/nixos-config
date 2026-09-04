{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.custom.roles.workstation.gaming.packages;
in
{
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  options.custom.roles.workstation.gaming.packages = with lib; {
    enable = mkEnableOption "Enable gaming role packages";
  };

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
      };

      sunshine = {
        enable = true;
        autoStart = false;
        capSysAdmin = true; # only needed for Wayland -- omit this when using with Xorg
        # Don't open Sunshine's ports to the whole LAN; stream over Tailscale.
        # Flip back to true if you need LAN clients (e.g. Moonlight on the couch).
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

    environment.systemPackages = with pkgs; [
      # Gaming utils/deps
      mangohud
      xremap
      wine

      # AI - Here because my laptop is a potato with no gpu
      lmstudio # todo: move somewhere else

      # Games
      osu-lazer-bin

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
