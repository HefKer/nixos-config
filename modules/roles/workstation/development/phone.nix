{
  config,
  lib,
  consts,
  ...
}:
let
  cfg = config.custom.roles.workstation.development;
  phone = config.home-manager.users.${consts.username}.custom.home.phone;
in
{
  config = lib.mkIf (cfg.enable && phone.enable) {
    # The phone's context posts come in over the tailnet only; the home service binds the tailnet address alone (nixos-issues#113).
    networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
      phone.contextPort
    ];
  };
}
