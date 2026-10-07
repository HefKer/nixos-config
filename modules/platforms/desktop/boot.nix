{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.custom.platform == "desktop") {
    boot.loader.efi.canTouchEfiVariables = true;

    hardware = {
      # Was nixpkgs' not-detected.nix; inlined so the enable gate actually covers it.
      enableRedistributableFirmware = lib.mkDefault true;
      cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
  };
}
