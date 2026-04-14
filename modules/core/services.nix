{
  _,
  ...
}:
{
  services = {
    openssh.enable = true;

    xserver.xkb = {
      layout = "us";
      variant = ""; # ?
      # options = "caps:escape";
    };
  };
}
