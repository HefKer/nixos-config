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
        wooting.enable = true;
      };

      development.enable = true;
      local-ai.enable = true;
    };
  };

  # Read-only osu! gacha API key for ~/dev/_osu/osugacha; only this host's secrets file holds it.
  sops.secrets.osugacha-testing-api.owner = consts.username;
  # Second osu! gacha API key for the same project.
  sops.secrets.osugacha-api2.owner = consts.username;
  # osu! OAuth app client for osugacha's `osu-login` (reads osu! mutuals).
  sops.secrets.osu-client-id.owner = consts.username;
  sops.secrets.osu-client-secret.owner = consts.username;

  # The user manager starts at boot, so Syncthing (a user service) syncs before anyone logs in.
  users.users.${consts.username}.linger = true;

  home-manager.users.${consts.username}.custom.home = {
    dotfiles = {
      enable = true;
      host = hostName;
    };
    phone.enable = true;
  };
}
