{ pkgs, ... }:
{
  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "thunderbolt"
      "nvme"
      "usb_storage"
      "sd_mod"
      "sdhci_pci"
    ];
    initrd.kernelModules = [ ];
    extraModulePackages = [ ];
  };

  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
}
