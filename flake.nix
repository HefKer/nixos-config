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
      pkgs = import nixpkgs { inherit system; };
      consts = import ./lib/consts.nix;
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs consts; };
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          ./modules/core/nixos.nix
          ./modules/core/packages.nix
          ./modules/core/services.nix
          ./modules/core/users.nix
          ./modules/roles/workstation/packages.nix
          ./modules/roles/workstation/development/packages.nix
          ./modules/roles/workstation/gaming/packages.nix
          inputs.home-manager.nixosModules.default
        ];
      };
    };
}
