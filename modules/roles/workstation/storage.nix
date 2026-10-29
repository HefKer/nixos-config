{ config, lib, ... }:
let
  cfg = config.custom.roles.workstation;
in
{
  config = lib.mkIf cfg.enable {
    services = {
      udisks2.enable = true;
      gvfs.enable = true; # nautilus' drive sidebar
    };
  };
}
