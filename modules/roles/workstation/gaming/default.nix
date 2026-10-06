{ lib, ... }:
{
  imports = [
    ./packages.nix
    ./nvidia.nix
    ./tablet.nix
  ];

  options.custom.roles.workstation.gaming = with lib; {
    enable = mkEnableOption "the gaming sub-role";
  };
}
