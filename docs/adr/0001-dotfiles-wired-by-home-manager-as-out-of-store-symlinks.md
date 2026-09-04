# Dotfiles are wired by home-manager as out-of-store symlinks

Status: accepted

Application config lives as ordinary hand-edited files in a dotfiles root
outside the flake, and home-manager links it into `$HOME` with
`mkOutOfStoreSymlink` rather than interning it into the Nix store. This keeps
the edit loop free of `nixos-rebuild` — evaluation, not building, dominates that
loop, and no amount of tuning makes it fast enough to iterate on a colourscheme
— while making the *link set* declarative, host-conditional, and reproducible on
a fresh machine.

## Considered options

- **Store copies via `home.file.<t>.source`.** Fully reproducible; every dotfile
  rolls back with the generation. Rejected for machines we sit at: a rebuild per
  edit, and read-only config directories break every write-back application.
  This is still the right treatment for deploy-only hosts, which is why the
  dotfiles root is threaded through as a parameter rather than hardcoded — see
  Consequences.
- **Nix-generated config via `programs.*`.** Rejected as the default. Reserved
  for config whose *content* must reference something only Nix knows, such as a
  store path or a port. Everything else stays in its native format so that
  editors, formatters and language servers understand it, and so the files
  remain portable to non-NixOS machines.
- **Continue with GNU Stow.** The link mechanism is identical, so this costs
  nothing at runtime. Rejected because the link set stays undeclared: a fresh
  host needs a remembered sequence of `stow` invocations, and nothing can vary
  the set per host.

## Consequences

- The dotfiles root must be referred to as a **string**, never a Nix path
  literal and never `toString ./x`. Under flakes the source tree is copied to
  the store before evaluation, so a path literal resolves *inside* the store and
  `mkOutOfStoreSymlink` silently produces an immutable store link that appears
  to work. This is the single most likely way to break this design.
- Links are made at **directory** granularity except where a directory holds
  runtime state that must not enter the repository. File-level links are
  destroyed by write-back applications, silently and permanently.
- Because directories are linked, applications write their own state into the
  dotfiles repository by design. That is accepted; it is contained with
  ignore rules, not by changing the link granularity.
- Nix cannot verify the target exists. On a fresh host the links dangle until
  Syncthing has replicated the dotfiles root, so cloning or syncing it is a
  documented bootstrap step.
- The dotfiles content is not pinned by `flake.lock`, so a rollback restores the
  link set but not the files it points at.
