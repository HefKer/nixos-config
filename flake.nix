{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      consts = import ./lib/consts.nix;
      inherit (consts) username home;
    in
    {
      nixosConfigurations = {
        desktop = lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs consts;
          };
          modules = [
            ./modules
            ./hosts/desktop.nix
            inputs.home-manager.nixosModules.default
          ];
        };

        lenovo = lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs consts;
          };
          modules = [
            ./modules
            ./hosts/lenovo.nix
            inputs.home-manager.nixosModules.default
          ];
        };
      };
    };
}
