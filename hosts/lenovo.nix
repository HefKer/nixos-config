{
  _,
  ...
}:
let
  hostName = "lenovo";
in
{
  system.stateVersion = "25.11"; # set this
  networking.hostName = hostName;

  custom = {
    roles.workstation = {
      packages.enable = true;

      development = {
        packages.enable = true;
      };
    };
  };
}
