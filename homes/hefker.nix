{
  consts,
  lib,
  osConfig,
  ...
}:
let
  inherit (consts) username home;
  isWorkstation = osConfig.custom.roles.workstation.enable or false;
  isDevelopment = osConfig.custom.roles.workstation.development.enable or false;
  isGaming = osConfig.custom.roles.workstation.gaming.enable or false;
in
{
  imports = [
    ./modules/cli.nix
    ./modules/dotfiles.nix
  ] # default to CLI group
  ++ lib.optionals isWorkstation [
    ./modules/gui.nix
    ./modules/kanata-keymap.nix
  ]
  ++ lib.optional isDevelopment ./modules/claude-hulio.nix
  ++ lib.optional isGaming ./modules/osu-watcher.nix;

  home = {
    inherit username;
    homeDirectory = home;
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
