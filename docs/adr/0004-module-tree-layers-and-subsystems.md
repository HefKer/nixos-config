# Configuration is placed by layer, then by subsystem

Status: accepted

"Where does this setting live?" had no reliable answer, so settings landed
wherever a `services` or `systemPackages` block was already open: audio in
`kernel.nix`, the compositor among development tools, keyboard layout in both
core and a platform. Every setting is now placed by asking two questions in
order. **Who gets it?** picks the layer: the host (this one machine), its
platform (this class of hardware), core (every host, including a headless
server), or a role or sub-role (this kind of machine). **What is it?** picks
the file: one named for the subsystem it drives (`audio.nix`, `input.nix`,
`display.nix`, `boot.nix`), or the layer's `packages.nix` for applications.

## Considered options

- **Subsystem as a fourth top-level axis** (`modules/subsystems/audio.nix`,
  toggled by hosts independently of platform and role). Rejected: it adds a
  toggle per subsystem, and toggles with no second consumer were already the
  problem. The layer already says who gets a setting; the subsystem only needs
  to say what it is, and a file name does that.
- **Platform as a specific machine**, as it was: one platform per host, named
  after the host. Rejected because it duplicates Host. Every setting it held
  was either unique to one machine (so it belongs to the host) or shared by a
  class of hardware (so the platform should be named for the class). The
  planned homelab puts two Raspberry Pi 4s on one `pi` platform, which is the
  second consumer the class reading needs.
- **Keep an `enable` option on every module.** Rejected: of twelve, only
  `gaming.tablet` and `virtualization.libvirt` distinguished one host from
  another once the NVIDIA driver moved to its platform. The rest were set
  identically on both hosts, and the workstation role itself had no switch, so
  the home layer read `workstation.packages.enable` as a proxy for it.

## Decisions

- **Platform is a hardware class** (`desktop`, `laptop`, later `pi`) and a host
  picks exactly one through a single enum option, `custom.platform`. Choosing
  two is an evaluation error rather than a convention.
- **Core is what a headless server would also want.** Keyboard layout,
  bluetooth and GUI applications fail that test and belong to the workstation
  role.
- **Machine-unique facts live in a host directory**, `hosts/<name>/`: disk
  layout, the `nixos-generate-config` hardware scan (initrd modules), the GRUB
  entry that chainloads Windows by filesystem UUID, and site-specific network
  profiles. `hosts/<name>/default.nix` stays the only file that switches
  anything on.
- **Roles and sub-roles each have one switch.** A finer-grained toggle exists
  only where two hosts actually differ. Enabling a sub-role without its parent
  role fails an assertion.
- **A hardware-dependent use is still a use.** The NVIDIA driver is platform
  (the machine needs it to drive a display at all). Local AI is a `local-ai`
  sub-role that only the desktop enables: the hardware explains why just one
  host turns it on, but it doesn't move an application into the platform
  layer.

## Consequences

- This revises two conventions in `CLAUDE.md`. `mkEnableOption` becomes the
  default form rather than the only one (the platform is an enum), and
  `hosts/*.nix` becomes `hosts/*/default.nix`.
- The restructure is provably behavior-neutral. Relocating settings between
  modules that the same hosts enable doesn't change what gets built. Moving
  scalar settings and declaring new options leaves each host's
  `system.build.toplevel.drvPath` byte-identical, measured against the same
  `flake.lock`. Moving entries of a list-valued option (`systemPackages`,
  `extraGroups`) between modules reorders the merged list and so changes the
  drvPath. In that case the sorted contents of the list must match instead.
  Both behaviours were verified on 2026-09-21. There are exactly two
  deliberate exceptions, both on the laptop: PipeWire's JACK layer is enabled
  on every workstation, and `lmstudio` leaves the laptop, which has no
  discrete GPU to run models on.
- Out of scope: the split between NixOS and home-manager (owned by the
  `hm-dotfiles` effort and ADR-0001), and the future of the laptop's
  `caps:escape`, which is a per-keyboard question rather than a per-host one
  (HefKer/nixos-issues#51).
