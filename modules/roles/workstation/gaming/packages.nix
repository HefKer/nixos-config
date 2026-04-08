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

  environment.systemPackages = with pkgs; [
    appimage-run # can't remember if req by osu
    
    # AI
    lmstudio

    # Games
    osu-lazer-bin
  ];
}
