# NixOS Configuration

My beginner [NixOS](https://nixos.org/) configuration. NixOS is a declarative Linux distribution — meaning that every system setting and program installation is written in code using the Nix programming language. With the power of Nix, this entire system configuration can be ported to another computer in a matter of minutes.

Two machines are built from this flake: `desktop` and `lenovo`.

## Config Structure

This repository is structured in a modularized format, with each directory serving a specific purpose:

**modules**: Reusable chunks of configuration that can be toggled on or off.

- `core` contains the baseline configuration that applies to every machine.
- `platforms` contains setup shared by a class of hardware (desktop, laptop); each host picks exactly one, and several hosts may share it.
- `roles` contains configurations that apply to specific types of machines — currently just workstation.
  - Workstation is further split into sub-roles: development, gaming, local-ai and virtualization.

**hosts**: One directory per machine. `default.nix` picks the platform and roles and turns them on; the other files hold facts unique to that one machine, such as its disk layout and site-specific wifi profiles.

**lib**: Utility functions and constants used throughout the flake.

**checks**: Tests `nix flake check` runs on top of evaluating every host: formatting (`nix fmt`) and the module conventions. `.githooks/pre-commit` runs them on every commit once enabled with `git config core.hooksPath .githooks`.

**scripts**: `same-system` proves a refactor leaves every host's build unchanged.

**homes**: Home Manager — the home layer. It *wires* dotfiles into `$HOME`; it does not hold them. Their content lives in a separate dotfiles root, and packages stay at the system layer, in `modules`. See [Dotfiles](#dotfiles).

**secrets**: Secrets encrypted with sops-nix, one file per host plus a shared one; `.sops.yaml` at the root says which keys can read which file. See [Secrets](#secrets).

**docs**: Notes to myself. Architecture decisions, research, and things I've learned along the way. `docs/agents/` documents the workflows I use with AI coding agents — including where issues live, which is the private `nixos-issues` repo rather than this one (see `docs/adr/0002-issues-live-in-a-separate-private-repo.md`).

## How it fits together

Every toggle in this flake is a custom option under the `custom.*` namespace — `custom.platform = "laptop"`, `custom.roles.workstation.development.enable`, and so on. Modules declare their options and keep their config behind `lib.mkIf`, so nothing takes effect until a host asks for it.

That makes `hosts/desktop/default.nix` and `hosts/lenovo/default.nix` the main files: they're the only place anything is switched on, so each one reads as a short description of what that machine actually is.

## Dotfiles

Application config — fish, niri, nvim, wezterm and the rest — is not in this repository. It lives as ordinary hand-edited files in the dotfiles root, `~/dots`, a repository of its own. `homes/modules/dotfiles.nix` declares the **link set**: which paths under the dotfiles root appear where in `$HOME`, with a per-host layer on top of a shared one.

The links are **out-of-store symlinks**, deliberately. Editing a dotfile takes effect straight away, with no rebuild, and applications that rewrite their own config keep working. The cost is that `flake.lock` does not pin dotfile content, so a rollback restores the links but not the files they point at. Store copies were considered and rejected for machines I sit at — don't "fix" this by pointing the links at store copies. The reasoning is in [ADR-0001](docs/adr/0001-dotfiles-wired-by-home-manager-as-out-of-store-symlinks.md), and the vocabulary (dotfiles root, link set, write-back application, drift) in [GLOSSARY.md](GLOSSARY.md).

### Bootstrapping a new machine

The dotfiles root must exist **before the first rebuild**. Syncthing is what puts it there: share `~/dots` to the new machine and let it finish syncing, then run `nixos-rebuild`.

Nix cannot check this. The links point outside the store, so the build succeeds and activation places them whether or not their targets exist. If `~/dots` is missing, every link dangles silently and the applications fail obscurely — starting with defaults or erroring on a config they can't read — rather than the rebuild failing loudly. If something looks unconfigured after a fresh install, check `ls -L ~/.config/<app>` first.

### Making a new host a recipient

A new host must be able to read its secrets **before its first rebuild that needs one**, and Nix can't check this either: the build succeeds, then decryption fails at activation. From a machine that holds the user's age key:

1. Read the host's public key: `ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub` on the new host.
2. Add it to `.sops.yaml`, with a path rule for `secrets/<host>.yaml` and in the `secrets/shared.yaml` rule.
3. Re-encrypt for the new recipient list: `SOPS_AGE_KEY_CMD="rbw get sops-age-key" sops updatekeys secrets/shared.yaml`, likewise for the host's file.
4. Commit, then run `nixos-rebuild` on the new host.

## Secrets

Secrets live in `secrets/` as ciphertext: `secrets/<host>.yaml` for one machine, `secrets/shared.yaml` for all of them. `modules/core/secrets.nix` imports sops-nix, which decrypts them at activation to `/run/secrets`, outside the Nix store. Each host decrypts with an age key derived from its SSH host key; the user is a recipient of everything through an age key kept in Bitwarden, so no machine's disk has to survive. Only secrets that can be rotated belong here, because git history keeps every encrypted version for good. The reasoning is in [ADR-0006](docs/adr/0006-secrets-are-sops-encrypted-in-the-public-repo.md).

Edit a file with `SOPS_AGE_KEY_CMD="rbw get sops-age-key" sops secrets/shared.yaml`, and declare `sops.secrets.<name>` next to the module that consumes it. `nix flake check` fails on any file in `secrets/` that isn't encrypted.
