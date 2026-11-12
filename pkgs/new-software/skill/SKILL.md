---
name: new-software
description: "Place and scaffold new software: a project in ~/dev, a flake package in ~/nixos, or a loose script in ~/dots. Use when asked to build a tool, script or app, or when one outgrows where it lives."
---

# New software

The rule is `~/nixos/main/docs/adr/0010-where-new-software-goes.md`; its terms are in `~/nixos/main/GLOSSARY.md`. Apply the tests in order and take the first that fits; an audience is shared through the README's Worth stealing list from any of the three:

1. **Project** (`~/dev/<name>`): it isn't about the user's machines (a site, game, mod, work), or it carries its own build, versions or release cadence.
2. **Flake package** (`~/nixos`, `pkgs/<name>`): it is coupled to this setup (niri, herdr, hosts, paths), however large.
3. **Loose script** (`~/dots/scripts/<name>`): one file, no dependencies beyond what is installed, no tests, worth editing without a rebuild.

Code an app's own config runs (nvim lua, qutebrowser userscripts, herdr local plugins) is that config, and goes beside it in `~/dots`.

State the placement in one line with the test that decided it ("Flake package: it drives niri."), then build. Ask only when the tests disagree, such as a coupled tool with its own toolchain; name both tests in the question.

## Wiring

Each destination has its recipe. Read the one you need before touching files:

- Project: [`PROJECT.md`](PROJECT.md)
- Flake package: [`FLAKE-PACKAGE.md`](FLAKE-PACKAGE.md)
- Loose script: [`LOOSE-SCRIPT.md`](LOOSE-SCRIPT.md)
- Promotion (loose script → flake package): [`PROMOTION.md`](PROMOTION.md)
- Graduation (flake package or loose script → project): [`GRADUATION.md`](GRADUATION.md)

Every change in `~/nixos` or `~/dots` follows that repo's `AGENTS.md` (branching, checks, commits, Worth stealing entries, never rebuilding). Each recipe ends with what the user runs on the machine; hand that back.
