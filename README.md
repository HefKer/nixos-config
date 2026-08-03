# NixOS Configuration

My beginner [NixOS](https://nixos.org/) configuration. NixOS is a declarative Linux distribution — meaning that every system setting and program installation is written in code using the Nix programming language. With the power of Nix, this entire system configuration can be ported to another computer in a matter of minutes.

Two machines are built from this flake: `desktop` and `lenovo`.

## Config Structure

This repository is structured in a modularized format, with each directory serving a specific purpose:

**modules**: Reusable chunks of configuration that can be toggled on or off.

- `core` contains the baseline configuration that applies to every machine.
- `platforms` contains hardware-specific setup for a particular machine.
- `roles` contains configurations that apply to specific types of machines — headless or workstation.
  - Workstation is further split into different use cases: development and gaming.

**hosts**: Configurations for specific devices. Each host file picks the platform and roles it wants and turns them on.

**lib**: Utility functions and constants used throughout the flake.

**homes**: Home Manager — user-level packages and dotfiles.

**docs**: Notes to myself. Architecture decisions, research, and things I've learned along the way. `docs/agents/` documents the workflows I use with AI coding agents.

## How it fits together

Every toggle in this flake is a custom option under the `custom.*` namespace — `custom.platforms.lenovo.networking.enable`, `custom.roles.workstation.development.enable`, and so on. Modules declare their options and keep their config behind `lib.mkIf`, so nothing takes effect until a host asks for it.

That makes `hosts/desktop.nix` and `hosts/lenovo.nix` the main files: they're the only place anything is switched on, so each one reads as a short description of what that machine actually is.
