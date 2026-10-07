{
  config,
  lib,
  consts,
  ...
}:
let
  cfg = config.custom.roles.workstation;
in
{
  config = lib.mkIf cfg.enable {
    networking.networkmanager.enable = true;
    users.users.${consts.username}.extraGroups = [ "networkmanager" ];
  };
}
