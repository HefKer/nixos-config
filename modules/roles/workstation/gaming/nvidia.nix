{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.roles.workstation.gaming.nvidia;
in
{
  options.custom.roles.workstation.gaming.nvidia = with lib; {
    enable = mkEnableOption "Enable nvidia GPU drivers for gaming";
  };

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ]; # "amdgpu" when I become chad

    # Enable renderer
    hardware.nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      open = true;
    };
  };
}
