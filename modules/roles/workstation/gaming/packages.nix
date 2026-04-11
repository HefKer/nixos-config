{
  config,
  pkgs,
  ...
}:

{
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

  # Required by OpenTabletDriver
  boot.kernelModules = [ "uinput" ];

  hardware = {
    # Required by OpenTabletDriver
    opentabletdriver.enable = true;
    uinput.enable = true;
    # Enable opengl
    graphics.enable = true;
    opengl.enable = true;

    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      open = true;
    };
  };
  services.xserver.videoDrivers = [ "nvidia" ]; # "amdgpu" when I become chad

  programs = {
    steam = {
      enable = true;
      gamescopeSession.enable = true;
    };
    # to execute appimage games via steam
    appimage = {
      enable = true;
      binfmt = true;
    };
  };

  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    # Gaming utils/deps
    mangohud
    protonup-ng

    # AI - Here because my laptop is a potato with no gpu
    lmstudio

    # Games
    osu-lazer-bin

    # Game launchers
    lutris
    heroic # for the high seas
    bottles # can run windows .exe games
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

  environment.sessionVariables = {
    # used for proton. Install proton with the command protonup
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
    # proton can then be enabled inside steam -> compatibility -> proton {latest}
    # note to self: move to homemanager later
  };
}
