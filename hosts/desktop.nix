{
  _,
  ...
}:
let
  hostName = "desktop";
in
{
  system.stateVersion = "25.11";
  networking.hostName = hostName;

  custom = {
    platforms.desktop = {
      disks.enable = true;
      kernel.enable = true;
    };
    roles.workstation = {
      packages.enable = true;
      gaming = {
        packages.enable = true;
        nvidia.enable = true;
        tablet.enable = true;
      };

      development = {
        packages.enable = true;
      };
    };
  };
}
