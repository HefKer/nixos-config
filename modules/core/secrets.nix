{ config, inputs, ... }:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops.defaultSopsFile = ../../secrets + "/${config.networking.hostName}.yaml";
}
