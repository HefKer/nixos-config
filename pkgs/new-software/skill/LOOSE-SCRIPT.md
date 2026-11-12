# Loose script

Two repos change: `~/dots` holds the file, `~/nixos` places the link.

1. **Script**: `~/dots/scripts/<name>`, executable, with a shebang. It calls only what is already installed.
2. **Link**: in a branch worktree of `~/nixos`, add to the link set in `homes/modules/dotfiles.nix`, in order beside the other scripts:

   ```nix
   {
     source = "scripts/<name>";
     target = ".local/bin/<name>";
   }
   ```

   and to both hosts' `expectedLinks` in `checks/default.nix`: `".local/bin/<name>" = "scripts/<name>";`.
3. **Document**: name it in the `scripts` row of `~/dots/README.md`'s Packages table, with what it does.
4. **Commit** in `~/dots` (straight to `main`) and in `~/nixos` per its `AGENTS.md`.

Done when `nix flake check` passes (the dotfiles check confirms the link) and the script runs by its path. The user then runs `nixos-rebuild switch` once; from then on the script is on `PATH` and edits apply without a rebuild.
