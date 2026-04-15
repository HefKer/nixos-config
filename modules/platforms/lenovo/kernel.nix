{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  cfg = config.custom.platforms.lenovo.kernel;
in
{
  options.custom.platforms.lenovo.kernel = with lib; {
    enable = mkEnableOption "Enable lenovo kernel settings";
  };

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  config = lib.mkIf cfg.enable {
    boot = {
      initrd.availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "usb_storage"
        "sd_mod"
      ];
      initrd.kernelModules = [ ];
      kernelModules = [ "kvm-intel" ];
      extraModulePackages = [ ];
      kernelPackages = pkgs.linuxPackages_latest;

      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };

    };

    hardware = {
      cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };

    # todo: move this out
    services = {
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      xserver.xkb = {
        layout = "us";
        variant = "";
        options = "caps:escape";
      };
    };

    security.rtkit.enable = true;
  };
}
