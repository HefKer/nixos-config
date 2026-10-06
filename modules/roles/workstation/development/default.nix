{ lib, ... }:
{
  imports = [
    ./packages.nix
  ];

  options.custom.roles.workstation.development = with lib; {
    enable = mkEnableOption "the development sub-role";
  };
}
