{ lib, ... }:
{
  imports = [
    ./packages.nix
    ./tablet.nix
  ];

  options.custom.roles.workstation.gaming = with lib; {
    enable = mkEnableOption "the gaming sub-role";
  };
}
