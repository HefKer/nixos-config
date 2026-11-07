{
  config,
  lib,
  consts,
  ...
}:
{
  config = lib.mkIf config.custom.roles.workstation.enable {
    # The host's existing Syncthing identity, so its device ID survives a reinstall; the home service copies it in.
    sops.secrets = {
      syncthing-cert.owner = consts.username;
      syncthing-key.owner = consts.username;
    };

    # Peers dial each other's Tailscale address, so sync works without opening 22000 to the LAN.
    networking.firewall.interfaces.${config.services.tailscale.interfaceName} = {
      allowedTCPPorts = [ 22000 ];
      allowedUDPPorts = [ 22000 ];
    };
  };
}
