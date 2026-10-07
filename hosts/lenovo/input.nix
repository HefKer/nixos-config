{ lib, ... }:
{
  # todo: per-keyboard remapping instead of per-host (HefKer/nixos-issues#51).
  services.xserver.xkb.options = lib.mkForce "caps:escape";
}
