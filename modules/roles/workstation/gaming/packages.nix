{
  config,
  pkgs,
  ...
}:

{
  # Required by OpenTabletDriver
  hardware.opentabletdriver.enable = true;
  hardware.uinput.enable = true;
  boot.kernelModules = [ "uinput" ];
  hardware.graphics.enable = true;
  # Osu
  hardware.opengl.enable = true;
  hardware.nvidia.modesetting.enable = true;

  environment.systemPackages = with pkgs; [
    appimage-run # can't remember if req by osu

    # AI
    lmstudio

    # Games
    osu-lazer-bin
  ];
}
