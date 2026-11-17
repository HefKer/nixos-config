{ lib, ... }:
{
  imports = [
    ./packages.nix
    ./phone.nix
  ];

  options.custom.roles.workstation.development = with lib; {
    enable = mkEnableOption "the development sub-role";
  };
}
