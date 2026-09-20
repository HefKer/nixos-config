{
  config,
  lib,
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
      # Was nixpkgs' not-detected.nix; inlined so the enable gate actually covers it.
      enableRedistributableFirmware = lib.mkDefault true;
      cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };

    services = {
      libinput.enable = true;
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
        # todo: replace with services.keyd for per-device remapping (see TODO.md).
        options = lib.mkForce "caps:escape";
      };
    };

    security.rtkit.enable = true;
  };
}
