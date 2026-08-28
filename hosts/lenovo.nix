{ ... }:
let
  hostName = "lenovo";
in
{
  system.stateVersion = "25.11";
  networking.hostName = hostName;

  custom = {
    platforms.lenovo = {
      disks.enable = true;
      kernel.enable = true;
      networking.enable = true;
    };
    roles.workstation = {
      packages.enable = true;
      chromium.enable = true;
      virtualization.libvirt.enable = true;

      development = {
        packages.enable = true;
      };

      gaming = {
        packages.enable = true;
      };
    };
  };
}
