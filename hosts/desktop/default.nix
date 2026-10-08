{ consts, ... }:
let
  hostName = "desktop";
in
{
  imports = [
    ./boot.nix
    ./disks.nix
    ./hardware.nix
  ];

  system.stateVersion = "25.11";
  networking.hostName = hostName;

  custom = {
    platform = "desktop";
    roles.workstation = {
      enable = true;

      gaming = {
        enable = true;
        tablet.enable = true;
      };

      development.enable = true;
      local-ai.enable = true;
    };
  };

  home-manager.users.${consts.username}.custom.home.dotfiles = {
    enable = true;
    host = hostName;
  };
}
