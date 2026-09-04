# NixOS Configuration

A Nix flake that builds two machines, `desktop` and `lenovo`, and wires the
user's home directory. This glossary fixes the vocabulary for how system
configuration, user configuration, and hand-edited dotfiles relate.

## Language

### Configuration layers

**System layer**:
Configuration owned by NixOS — anything outside `$HOME` or needed before login.
Hardware, services, bootloader, installed packages.

**Home layer**:
Configuration owned by home-manager for a single user: the contents of `$HOME`.
Evaluated as part of the system build, not activated separately.
_Avoid_: user layer, HM layer

**Role**:
A named capability a machine can have, toggled on by a host. Roles are the unit
of "what kind of machine is this".

**Host**:
A single named machine built from this flake. The only place capabilities are
switched on.
_Avoid_: node, box, device

### Dotfiles

**Dotfile**:
An application config file authored by hand in its own native format, living
outside the flake. Distinct from configuration that Nix generates.

**Dotfiles root**:
The directory holding every dotfile. Referred to as an absolute string, never a
Nix path literal, so that it stays outside the Nix store.
_Avoid_: dots dir, dotfiles repo

**Link set**:
The declared mapping from dotfiles-root-relative sources to targets in `$HOME`.
Composed in layers, where a later layer replaces an earlier entry for the same
target.
_Avoid_: file list, mappings

**Canonical name**:
The target filename an application actually reads, when several interchangeable
variants of a file exist side by side and one is chosen. The mechanism by which
configuration varies per host without being generated.

**Out-of-store symlink**:
A link whose chain terminates at a path inside `$HOME` rather than in the Nix
store, leaving the file editable without a rebuild.
_Avoid_: mutable link, live link

**Store copy**:
The opposite treatment: the file is interned into the Nix store and the target
is read-only, so changing it requires a rebuild. Reproducible, and correct for
machines that are deployed to rather than edited on.

**Write-back application**:
An application that rewrites its own configuration file at runtime, typically by
writing a temporary file and renaming it over the target. The rename destroys a
file-level symlink, which is why such applications are linked at directory
granularity.
_Avoid_: stateful app, self-modifying config

**Drift**:
Divergence between the declared link set and what is actually on disk. Splits
into *content drift* (tracked files changed but uncommitted) and *link drift* (a
managed target is no longer the link that was placed).
