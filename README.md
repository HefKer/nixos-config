# NixOS Configuration

My beginner [NixOS](https://nixos.org/) configuration. NixOS is a declarative linux distribution -meaning that every system setting and program installation is written in code using the nix programming language. With the power of nix, this entire system configuration can be ported to another computer in a matter of minutes.

## Config Structure

This repository is structured in a modularized format, with each directory serving a specific purpose:

**modules**: Reusable chunks of configuration that can be toggled on or off.

- core contains the baseline configuration that apply to every machine.
- roles contains configurations that apply to specific types of machines- headless or workstation.
  - Workstation is further split into different use cases, development and gaming

**hosts**: Configurations for specific devices

**lib**: Utility functions and constants used throughout the flake.

**homes**: Home Manager (not set up yet)
