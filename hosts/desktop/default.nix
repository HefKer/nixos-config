{ ... }:
let
  hostName = "desktop";
in
{
  system.stateVersion = "25.11";
  networking.hostName = hostName;

  custom = {
    platform = "desktop";
    roles.workstation = {
      enable = true;

      gaming = {
        enable = true;
        nvidia.enable = true;
        tablet.enable = true;
      };

      development.enable = true;
    };
  };
}
