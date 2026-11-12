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
      project = (nixpkgs.lib.importTOML ./pyproject.toml).project;
    in
    {
      packages = forAll (pkgs: {
        default = pkgs.python3Packages.buildPythonApplication {
          pname = project.name;
          inherit (project) version;
          pyproject = true;
          src = ./.;
          build-system = [ pkgs.python3Packages.hatchling ];
        };
      });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            python3
            uv
            ruff
            pyright
          ];
          env.UV_PYTHON_DOWNLOADS = "never";
        };
      });
    };
}
