{ lib, ... }:
{
  imports = [
    ./packages.nix
  ];

  options.custom.roles.workstation.local-ai = with lib; {
    enable = mkEnableOption "the local-ai sub-role (running models on a local GPU)";
  };
}
