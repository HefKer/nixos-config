{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  cfg = config.custom.platforms.desktop.kernel;
in
{
  options.custom.platforms.desktop.kernel = with lib; {
    enable = mkEnableOption "Enable Desktop kernel settings";
  };

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  config = lib.mkIf cfg.enable {
    boot.loader = {
      systemd-boot.enable = false;
      efi.canTouchEfiVariables = true;

      grub = {
        enable = true;
        devices = [ "nodev" ];
        efiSupport = true;
        useOSProber = false;
        extraEntries = ''
          menuentry "Windows" {
            insmod part_gpt
            insmod fat
            insmod search_fs_uuid
            insmod chain
            sleep 5
            search --no-floppy --fs-uuid --set=root CE76-3D21
            chainloader /EFI/Microsoft/Boot/bootmgfw.efi
          }
        '';
      };

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ ];
      boot.extraModulePackages = [ ];

      hardware = {
        bluetooth.enable = true;
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };

      services = {
        # Enable sound with pipewire.
        pulseaudio.enable = false;
        rtkit.enable = true;
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          jack.enable = true; # for JACK apps (MIDI/adv audio)
        };

      };
    };
  };

}
