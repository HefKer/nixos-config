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

    xserver.xkb = {
      layout = "us";
      variant = ""; # Selects a sub-variant of the layout. "" = default. Other options (for "us"): "dvorak", "colemak", "altgr-intl", "intl", "mac", "workman"
      # options = "caps:escape";
    };

    tailscale = {
      enable = true;
      extraSetFlags = [ "--ssh" ];
    };
  };
}
