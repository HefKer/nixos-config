# CLAUDE.md

## Rules

- **Never apply changes to the running system.** No `nixos-rebuild`, `home-manager switch`, `nix-collect-garbage`, or writes to `/etc/nixos`. Propose and explain; let the user run it. (`nix flake check` / `nix flake update` are fine — they don't mutate the system.)
- **Explain every change in chat** — what it does, why, which NixOS concept. Goal is the user understands the config, not just that it works. Keep code comments minimal — one line, only for a non-obvious invariant or gotcha — the full explanation belongs in the chat reply, not the file.

## Module system conventions

- Custom options live under `custom.*`, declared with `mkEnableOption`, gated behind `lib.mkIf cfg.enable`.
- `hosts/*.nix` are the **only** place options are set `enable = true`.
- Use `consts` (from `lib/consts.nix`, passed via `specialArgs`) for username/timezone/locale — never hardcode.
- `system.stateVersion = "25.11"` — do not change without understanding implications.

## Agent skills

### Issue tracker

Issues live in the **separate private repo `HefKer/nixos-issues`**, so every `gh` command
needs `--repo HefKer/nixos-issues`; efforts about the homelab stay as markdown in `.scratch/`.
See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, under their canonical names. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## More

See `README.md` for repo layout.
