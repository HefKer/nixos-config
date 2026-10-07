{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.custom.platform == "laptop") {
    boot = {
      kernelModules = [ "kvm-intel" ];
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
      };
    };

    security.rtkit.enable = true;
  };
}
