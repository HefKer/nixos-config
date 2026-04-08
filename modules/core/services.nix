{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  services = {
    xserver.xkb = {
      layout = "us";
      variant = ""; # ?
      # options = "caps:escape";
    };
  };
}
