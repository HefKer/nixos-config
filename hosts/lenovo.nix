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
    };
    roles.workstation = {
      packages.enable = true;
      development = {
        packages.enable = true;
      };
    };
  };
}
