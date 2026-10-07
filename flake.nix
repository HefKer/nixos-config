{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helium = {
      url = "github:AlvaroParker/helium-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    # Not `follows`-ed: cache.numtide.com only hits against its own nixpkgs pin.
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Not `follows`-ed: its cachix cache is built against its own nixpkgs pin.
    nix-gaming.url = "github:fufexan/nix-gaming";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    pyroclear = {
      url = "github:shreyanth-sureshkrishnaa/pyroclear";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      consts = import ./lib/consts.nix;
      inherit (consts) username home;

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
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
            ./hosts/desktop
          ];
        };

        lenovo = lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs consts;
          };
          modules = [
            ./modules
            ./hosts/lenovo
          ];
        };
      };
    };
}
