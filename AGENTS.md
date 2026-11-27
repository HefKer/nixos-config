# AGENTS.md

## Rules

- **Never apply changes to the running system.** No `nixos-rebuild`, `home-manager switch`, `nix-collect-garbage`, or writes to `/etc/nixos`. Propose and explain; let the user run it. They run root commands in their own fish terminal, since Claude Code's `!` prefix has no tty for sudo: ask for output as `… > ~/out.txt 2>&1`, then read the file. Moving a file Home Manager doesn't manage out of a link's way (`scripts/link-drift` lists them) into a dated backup is fine. Evaluating and building into the store is fine: `nix flake check`, `nix flake update`, `nix eval`, `nix build --no-link`.
- **Explain every change in chat**: open with a one-line summary, then what each change does, why, and which NixOS concept. Goal is the user understands the config, not just that it works.
- **Verify** with `nix flake check`; a change meant to leave what gets built untouched (a move, rename or split) also runs `scripts/same-system [base-rev]`. Review against `CODING_STANDARDS.md`.
- **Commit small sets of changes straight to `main`.** Branch for anything larger.
- **The repo is public; features are shared through `README.md`'s Worth stealing list.** A commit that adds something reusable adds its entry in the same commit, in the existing entries' format with the anchor, linking only the file, since the commit has no hash yet.

## Agent skills

### Issue tracker

Issues live in the **separate private repo `HefKer/nixos-issues`**, so every `gh` command
needs `--repo HefKer/nixos-issues`, homelab included.
See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, under their canonical names. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## More

See `README.md` for repo layout.

`docs/research/` is gitignored notes living only in the main checkout: from any worktree, read and write `/home/hefker/nixos/main/docs/research/`, and keep it out of commits.

Commit X is live when `git merge-base --is-ancestor X <rev>` succeeds, `<rev>` being `nixos-version --configuration-revision` minus any `-dirty` suffix (a build from uncommitted changes).

Each drive's SMART data, refreshed daily by root, is world-readable at `/var/lib/smart-status/<dev>.json` (`smartctl -j -a`).
