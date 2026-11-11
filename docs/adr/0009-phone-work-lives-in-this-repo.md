# Phone work lives in this repo

Status: accepted

The phone is not built from this flake, yet everything that touches it lives
here: the host-side tools that reach it, phone automations that run on a host,
the probes that watch it, the phone baseline, the exports of phone automations
that run on the phone, and the `phone` skill. Nearly all of it is Nix the hosts
install, and the phone is already a peer of this flake through Syncthing, so a
separate repo would split one system across two places and cost a flake-input
bump on every change.

## Considered options

- **A sibling repo, pulled in as a flake input.** Rejected for the cost above:
  two places to look, and a lock bump between editing a phone tool and the
  hosts installing it, for no build of its own to justify the split.
- **On-phone exports in the dotfiles root.** Rejected: a dotfile is linked into
  `$HOME` by the link set, and a phone export is never linked anywhere; it is
  imported into an app on the phone.

## Consequences

- The repo is public, so the phone baseline publishes the phone's profile.
  Settings and ordinary apps are accepted as profile; the baseline names no
  payment or health app, leaving them unmanaged or naming them only in sops.
- Reopen this if a rooted second phone runs a declarative Android build
  (Nixup): that would be a build of its own, the case a separate repo is for.
