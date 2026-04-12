{ lib, pkgs, ... }:
let
  inherit (lib) mkDefault;
in
{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
