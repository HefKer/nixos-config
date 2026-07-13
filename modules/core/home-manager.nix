{ inputs, consts, ... }:
{
  imports = [ inputs.home-manager.nixosModules.default ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs consts; };
    backupFileExtension = "hm-bak";
    users.${consts.username} = import ../../homes/hefker.nix;
  };
}
