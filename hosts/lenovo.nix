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
      enable = true;

      development.enable = true;
      gaming.enable = true;
      virtualization.enable = true;
    };
  };
}
