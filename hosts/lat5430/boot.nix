{ lib, ... }:
{
  boot.loader = {
    # The machine was installed with GRUB; the laptop platform's systemd-boot would leave both on the ESP.
    systemd-boot.enable = lib.mkForce false;

    grub = {
      enable = true;
      devices = [ "nodev" ];
      efiSupport = true;
    };
  };
}
