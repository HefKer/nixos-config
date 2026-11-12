{
  description = "new-project";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forAll =
        f:
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
          system: f nixpkgs.legacyPackages.${system}
        );
    in
    {
      packages = forAll (pkgs: {
        default = pkgs.writeShellApplication {
          name = "new-project";
          text = builtins.readFile ./new-project.sh;
        };
      });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [ ];
        };
      });
    };
}
