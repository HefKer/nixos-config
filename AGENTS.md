# AGENTS.md

## Rules

- **Never apply changes to the running system.** No `nixos-rebuild`, `home-manager switch`, `nix-collect-garbage`, or writes to `/etc/nixos`. Propose and explain; let the user run it. Moving a file Home Manager doesn't manage out of a link's way (`scripts/link-drift` lists them) into a dated backup is fine. Evaluating and building into the store is fine: `nix flake check`, `nix flake update`, `nix eval`, `nix build --no-link`.
- **Explain every change in chat** — what it does, why, which NixOS concept. Goal is the user understands the config, not just that it works.
- **Verify** with `nix flake check`; a change meant to leave what gets built untouched (a move, rename or split) also runs `scripts/same-system [base-rev]`. Review against `CODING_STANDARDS.md`.
- **Commit small sets of changes straight to `main`.** Branch for anything larger.
- **The repo is public; features are shared through `README.md`'s Worth stealing list.** A commit that adds something reusable adds its entry in the same commit, in the existing entries' format with the anchor, linking only the file, since the commit has no hash yet.

## Agent skills

### Issue tracker

Issues live in the **separate private repo `HefKer/nixos-issues`**, so every `gh` command
needs `--repo HefKer/nixos-issues`; efforts about the homelab stay as markdown in `.scratch/`.
See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, under their canonical names. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## More

See `README.md` for repo layout.
