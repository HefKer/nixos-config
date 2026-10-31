{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.custom.platform == "desktop") {
    services.xserver.videoDrivers = [ "nvidia" ]; # "amdgpu" when I become chad

    # Without the driver runpath OBS can't load libnvidia-encode, so NVENC is missing
    programs.obs-studio.package = pkgs.obs-studio.override { cudaSupport = true; };

    # Enable renderer
    hardware.nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      open = true;
      # Save VRAM across suspend, else resume comes back black
      powerManagement.enable = true;
    };
  };
}
