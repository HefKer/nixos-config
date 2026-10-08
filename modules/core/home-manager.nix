{ inputs, consts, ... }:
{
  imports = [ inputs.home-manager.nixosModules.default ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs consts;
      # A string, never a path literal: under flakes a path resolves inside the store (ADR-0001).
      dotfilesRoot = "${consts.home}/dots";
    };
    backupFileExtension = "hm-bak";
    users.${consts.username} = import ../../homes/hefker.nix;
  };
}
