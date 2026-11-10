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
    ./modules/health.nix
  ] # default to CLI group
  ++ lib.optionals isWorkstation [
    ./modules/alarm.nix
    ./modules/chromium.nix
    ./modules/gui.nix
    ./modules/kanata-keymap.nix
    ./modules/privoxy.nix
    ./modules/spotify.nix
    ./modules/syncthing
    ./modules/udiskie.nix
  ]
  ++ lib.optional isDevelopment ./modules/claude-hulio.nix
  ++ lib.optional isDevelopment ./modules/collie.nix
  ++ lib.optional isDevelopment ./modules/herdr-plugins.nix
  ++ lib.optional isDevelopment ./modules/hunk-extensions.nix
  ++ lib.optional isGaming ./modules/game-focus-watcher.nix;

  home = {
    inherit username;
    homeDirectory = home;
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
