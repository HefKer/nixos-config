# Coding standards

Read at review time. `nix flake check` (the `checks/` directory) already enforces formatting,
where `custom.*` gets switched on, plain host files, and `consts` over literals: run it rather
than re-checking those by eye. The rules below are the judgement calls no check can make.

## Layering

- New config sits in the right layer, per the Core / Platform / Role / Sub-role / Subsystem
  terms in `GLOSSARY.md` and `docs/adr/0004-module-tree-layers-and-subsystems.md`. Core is what a
  headless server would also want; a hardware fact belongs to the platform; a fact true of one
  machine only belongs in its host directory.
- Options live under `custom.*`, with config gated behind `lib.mkIf`. `mkEnableOption` is the
  default form; the enums are `custom.platform` and the home layer's `custom.home.dotfiles.host`.
  Roles and sub-roles get one switch each, never one per file.

## Behavior

- A change described as behavior-neutral (a move, rename or split) carries `scripts/same-system`
  output showing each host `identical`, or a reorder with matching sorted lists. Any other
  difference is one the ticket asked for, named in the commit or the hand-back.
- An existing host's `system.stateVersion` never changes. It records the release the machine was
  installed with, not the release it runs.

## Docs and comments

- A change that moves or renames a file updates every doc naming the old path (`README.md`,
  `GLOSSARY.md`, `AGENTS.md`, `docs/agents/`) in the same branch. ADRs are historical
  records and keep their original paths.
- Code comments are one line, only for a non-obvious invariant or gotcha. The explanation of a
  change belongs in the commit message and the chat, not the file.
