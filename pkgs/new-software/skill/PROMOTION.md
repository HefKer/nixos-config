# Promotion

A loose script becomes a flake package once it needs a dependency, a test or a second file.

1. **Move** `~/dots/scripts/<name>` to `pkgs/<name>/<name>.sh` in a branch worktree of `~/nixos`, dropping the shebang (`writeShellApplication` writes its own).
2. **Package** it per [`FLAKE-PACKAGE.md`](FLAKE-PACKAGE.md): `default.nix` with the new dependency in `runtimeInputs`, `tests.nix`, the check, the install, the Worth stealing entry.
3. **Unlink**: remove its entry from `homes/modules/dotfiles.nix`, from both hosts' `expectedLinks` in `checks/default.nix`, and its mention in `~/dots/README.md`'s `scripts` row. Delete the file from `~/dots` and name the dots commit in the nixos commit message, since the history stays there.

Done when `nix flake check` passes. The user then runs `nixos-rebuild switch`: the `~/.local/bin` link goes, and the packaged command takes its place on `PATH`.
