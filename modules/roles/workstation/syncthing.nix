{
  config,
  lib,
  consts,
  ...
}:
let
  inherit (import ../../../homes/modules/syncthing/table.nix) port;
in
{
  config = lib.mkIf config.custom.roles.workstation.enable {
    # The host's existing Syncthing identity, so its device ID survives a reinstall; the home service copies it in.
    sops.secrets = {
      syncthing-cert.owner = consts.username;
      syncthing-key.owner = consts.username;
    };

    # Peers dial each other's Tailscale address, so sync works without opening the port to the LAN.
    networking.firewall.interfaces.${config.services.tailscale.interfaceName} = {
      allowedTCPPorts = [ port ];
      allowedUDPPorts = [ port ];
    };
  };
}
