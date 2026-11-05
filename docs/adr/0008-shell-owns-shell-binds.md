# The shell owns shell binds; the niri config owns the rest

Status: accepted

niri's `config.kdl` includes DMS's `dms/binds.kdl` and then declares its own
`binds` block, which wins every conflict. It had grown into a near-copy of
DMS's file: 100 conflicts, each one silently overriding a DMS default, a DMS
update, or an edit made in DMS's rebinder. Shell binds (launcher, clipboard,
notifications, media, volume, lock, cheatsheet) now live only in
`dms/binds.kdl` and are edited through DMS. `config.kdl` holds window-manager
binds and personal ones (summon, window picker, keymap viewer, per-window
volume), and never redeclares a key DMS binds unless the override is
deliberate.

## Considered options

- **`config.kdl` owns every bind, include dropped.** Rejected: DMS's rebinder
  and the binds new DMS releases add would stop having any effect.
- **Leave both.** Rejected: which action a key runs depends on an accidental
  override, and media keys were broken by one (playerctl binds shadowing DMS's
  mpris ones, with playerctl not installed).

## Consequences

- DMS rewrites `dms/binds.kdl` on updates. It is tracked in the dotfiles
  root, so those changes show up as diffs to review.
- `dms keybinds show niri` lists every remaining conflict; it should stay near
  zero.
