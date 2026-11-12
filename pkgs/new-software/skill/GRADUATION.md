# Graduation

A flake package or loose script that now passes test 1 becomes a project, keeping its history. Config it reads stays in `~/dots`.

1. **Split the history** into `~/dev/<name>`:
   - Flake package, from a worktree of `~/nixos`:

     ```sh
     git subtree split -P pkgs/<name> -b split/<name>
     git init -b main ~/dev/<name> && git -C ~/dev/<name> pull <worktree> split/<name>
     git branch -D split/<name>
     ```

   - Loose script (one file, which `subtree split` can't extract): `git clone ~/dots ~/dev/<name>`, then in it `nix run nixpkgs#git-filter-repo -- --path scripts/<name> --path-rename scripts/<name>:<name>.sh`.
2. **Make it a project**: copy the baseline files from `~/nixos/main/templates/<lang>/` (rename `new-project` as in [`PROJECT.md`](PROJECT.md)), with its `flake.nix` exporting the old `default.nix` as `packages.default` and its tests as `checks`. Then follow [`PROJECT.md`](PROJECT.md) from step 3.
3. **Consume it** in `~/nixos`: a flake input, as `qutewarden` is (`url = "github:HefKer/<name>"`, `inputs.nixpkgs.follows = "nixpkgs"`), installed as `inputs.<name>.packages.${system}.default`. When the build stays in `~/nixos`, the input is a `flake = false` source instead, as the `vc-*` inputs are. Delete `pkgs/<name>` and its check, or for a loose script its link entries as in [`PROMOTION.md`](PROMOTION.md) step 3, and point its Worth stealing entry at the project.

Done when `nix flake check` passes in both repos and the project's `nix run` works. The user then runs `nixos-rebuild switch`.
