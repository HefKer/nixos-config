{ config, lib, ... }:
{
  config = lib.mkIf (config.custom.platform == "desktop") {
    services.xserver.videoDrivers = [ "nvidia" ]; # "amdgpu" when I become chad

    # Enable renderer
    hardware.nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      open = true;
    };
  };
}
