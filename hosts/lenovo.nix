{ ... }:
let
  hostName = "lenovo";
in
{
  system.stateVersion = "25.11";
  networking.hostName = hostName;

  custom = {
    platform = "laptop";
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
