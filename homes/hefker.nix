{ consts, lib, osConfig, ... }:
let
  inherit (consts) username home;
  isWorkstation = osConfig.custom.roles.workstation.packages.enable or false;
in
{
  imports =
    [ ./modules/cli.nix ] # default to CLI group
    ++ lib.optional isWorkstation ./modules/gui.nix;

  home = {
    inherit username;
    homeDirectory = home;
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
