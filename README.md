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

**homes**: Home Manager — user-level packages and dotfiles.

**docs**: Notes to myself. Architecture decisions, research, and things I've learned along the way. `docs/agents/` documents the workflows I use with AI coding agents — including where issues live, which is the private `nixos-issues` repo rather than this one (see `docs/adr/0002-issues-live-in-a-separate-private-repo.md`).

## How it fits together

Every toggle in this flake is a custom option under the `custom.*` namespace — `custom.platform = "laptop"`, `custom.roles.workstation.development.enable`, and so on. Modules declare their options and keep their config behind `lib.mkIf`, so nothing takes effect until a host asks for it.

That makes `hosts/desktop/default.nix` and `hosts/lenovo/default.nix` the main files: they're the only place anything is switched on, so each one reads as a short description of what that machine actually is.
