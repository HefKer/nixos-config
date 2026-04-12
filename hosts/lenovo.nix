{
  config,
  ...
}:
let
  hostName = "lenovo";
in
{
  system.stateVersion = ""; # set this
  networking.hostName = hostName;

  custom = {
    roles.workstation = {
      packages.enable = true;

      development = {
        packages.enable = true;
      };
    };

    services = { };
  };
}
