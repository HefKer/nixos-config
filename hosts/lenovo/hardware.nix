{ pkgs, ... }:
{
  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "thunderbolt"
      "nvme"
      "usb_storage"
      "sd_mod"
    ];
    initrd.kernelModules = [ ];
    extraModulePackages = [ ];
  };

  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
}
