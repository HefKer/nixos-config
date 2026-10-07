{ ... }:
{
  services = {
    openssh = {
      enable = true;

      # Don't punch port 22 through the host firewall. Tailscale SSH
      # (services.tailscale.extraSetFlags = ["--ssh"]) handles remote access
      # over the tailnet, so the classic daemon never needs LAN exposure.
      openFirewall = false;

      settings = {
        # Keys only — no password brute-force surface.
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        # Root cannot log in at all (default is "prohibit-password").
        PermitRootLogin = "no";
      };
    };

    tailscale = {
      enable = true;
      extraSetFlags = [ "--ssh" ];
    };
  };

  # nsncd queues every lookup behind its workers; a DNS burst starved passwd lookups (nixos-issues#46).
  systemd.services.nscd.environment.NSNCD_WORKER_COUNT = "32";
}
