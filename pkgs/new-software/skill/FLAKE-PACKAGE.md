# Flake package

Model the files on an existing package of the same shape: `pkgs/repeat` (a shell tool with a test), `pkgs/phone` (several commands and a bundled skill).

1. **Package**: `pkgs/<name>/default.nix`, a `callPackage` function. A shell tool is `writeShellApplication` reading `./<name>.sh`, with every command it calls in `runtimeInputs`.
2. **Test**: `pkgs/<name>/tests.nix`, a `runCommandLocal` that runs the tool against fakes in a temp `$HOME` and fails on the first wrong result. Register it in `checks/default.nix`: `<name> = pkgs.callPackage ../pkgs/<name>/tests.nix { };`.
3. **Install** it where it is used: `modules/roles/workstation/packages.nix` for desktop tools, `modules/roles/workstation/development/packages.nix` for dev tools, or the home module that runs it as a user service (`homes/modules/`).
4. **Share** it: its Worth stealing entry in `README.md`.

Done when `nix flake check` passes and `scripts/same-system main` shows only the new package's differences. The user then runs `nixos-rebuild switch`.
