{
  config,
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
      gaming = {
        packages.enable = true;
        hardware.enable = true;
      };

      development = {
        packages.enable = true;
      };
    };

    services = { };
  };
}
