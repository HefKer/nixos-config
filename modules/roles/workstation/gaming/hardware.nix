{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.roles.workstation.gaming.hardware;
in
{
  options.custom.roles.workstation.gaming.hardware = with lib; {
    enable = mkEnableOption "Enable gaming hardware options";
  };

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ]; # "amdgpu" when I become chad
    boot.kernelModules = [ "uinput" ]; # Required by OpenTabletDriver

    hardware = {
      # Required by OpenTabletDriver
      opentabletdriver.enable = true;
      uinput.enable = true;
      # Enable renderer
      graphics.enable = true;

      nvidia = {
        modesetting.enable = true;
        nvidiaSettings = true;
        open = true;
      };
    };

  };
}
