{ consts, ... }:
let
  inherit (consts) username home;
in
{
  home = {
    inherit username;
    homeDirectory = home;

    stateVersion = "25.11";
  };
  programs.home-manager.enable = true;
}
