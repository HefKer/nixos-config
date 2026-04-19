{
  _,
  ...
}:
{
  services = {
    openssh.enable = true;

    xserver.xkb = {
      layout = "us";
      variant = ""; # Selects a sub-variant of the layout. "" = default. Other options (for "us"): "dvorak", "colemak", "altgr-intl", "intl", "mac", "workman"
      # options = "caps:escape";
    };

    tailscale.enable = true;
  };
}
