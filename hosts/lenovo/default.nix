{ consts, ... }:
let
  hostName = "lenovo";
in
{
  imports = [
    ./disks.nix
    ./hardware.nix
    ./input.nix
    ./networking.nix
  ];

  system.stateVersion = "25.11";
  networking.hostName = hostName;

  custom = {
    platform = "laptop";
    roles.workstation = {
      enable = true;

      development.enable = true;
      gaming.enable = true;
      virtualization.enable = true;
    };
  };

  home-manager.users.${consts.username}.custom.home.dotfiles = {
    enable = true;
    host = hostName;
  };
}
