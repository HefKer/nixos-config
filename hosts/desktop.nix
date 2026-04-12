{
  config,
  ...
}:
let
  hostName = "desktop";
in
{
  system.stateVersion = "25.11"; # Did you read the comment?
  networking.hostName = hostName;

  custom = {
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
