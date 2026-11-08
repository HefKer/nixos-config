# nixos-config

The [NixOS](https://nixos.org/) flake behind my two machines, `desktop` and
`lenovo`: [niri] + [DankMaterialShell], [kanata] on every keyboard, and
[herdr] for coding agents. The application configs themselves live in
[dots]; this repo installs the packages and places those files.

[niri]: https://github.com/YaLTeR/niri
[DankMaterialShell]: https://github.com/AvengeMedia/DankMaterialShell
[kanata]: https://github.com/jtroo/kanata
[herdr]: https://herdr.dev
[dots]: https://github.com/HefKer/dots

Feel free to take whatever's useful. The **Worth stealing** list below has one
entry per feature, linked to the file it lives in and the commit that added it.
The commit message says why it's built that way.

## Highlights

- **[`same-system`][same-system]**: proves a refactor changes nothing any host
  builds
- **[Dotfiles as out-of-store symlinks][dotfiles-links]**: edit in place with
  no rebuild, with [a flake check][dotfiles-check] that each host gets exactly
  the links it should
- **[kanata misfire tooling][kanata-misfires]**: flag a home-row-mod misfire
  from a bind, then replay and fuzz the keymap in kanata's own simulator
- **[Reboot-required warning][reboot-required]**: says when the kernel or
  initrd changed under you, at switch time and as a notification
- **[herdr plugins from Nix][herdr-plugins]**: packaged plugins merged into a
  registry herdr rewrites itself

[same-system]: #same-system
[dotfiles-links]: #dotfiles-links
[dotfiles-check]: #dotfiles-check
[kanata-misfires]: #kanata-misfires
[reboot-required]: #reboot-required
[herdr-plugins]: #herdr-plugins

## Worth stealing

Each entry is self-contained enough to copy on its own. Its links point to the
file as it is now and to the commit that added it, which explains why. Options
sit under my `custom.*` namespace; see [How it fits
together](#how-it-fits-together) for what that means when you copy one.

### Repo tooling

- <a id="same-system"></a>**Prove a refactor is a no-op.** `scripts/same-system
  [base] [rev]` evaluates every host at both revisions and reports each as
  identical, a reorder (same sorted package and group lists) or different.
  [`scripts/same-system`](scripts/same-system) ·
  [5b35dde](https://github.com/HefKer/nixos-config/commit/5b35dde),
  [db8c9e8](https://github.com/HefKer/nixos-config/commit/db8c9e8)
- <a id="convention-checks"></a>**Conventions as flake checks.** Grep-based
  checks fail `nix flake check` when a `custom.*` switch is set outside a host
  file, a host file declares options, a literal duplicates `lib/consts.nix`, or
  a comment runs past one line. [`checks/default.nix`](checks/default.nix) ·
  [81de6a9](https://github.com/HefKer/nixos-config/commit/81de6a9),
  [75cefaa](https://github.com/HefKer/nixos-config/commit/75cefaa)
- <a id="pre-commit"></a>**Pre-commit on the staged files only.** The hook
  exports the index with `git checkout-index` and builds the checks from that,
  so an unstaged edit (yours, or another agent's in the same tree) can't pass
  or fail the commit. [`.githooks/pre-commit`](.githooks/pre-commit) ·
  [1b6af37](https://github.com/HefKer/nixos-config/commit/1b6af37),
  [06a77f1](https://github.com/HefKer/nixos-config/commit/06a77f1)
- <a id="link-drift"></a>**Catch link collisions before a switch.** With
  `backupFileExtension` unset, a real file where Home Manager wants a link
  aborts activation. `scripts/link-drift [host]` evaluates the host's
  `home.file` targets and lists any in `$HOME` that aren't Home Manager's
  links. [`scripts/link-drift`](scripts/link-drift)

### Dotfile links

- <a id="dotfiles-links"></a>**Out-of-store symlinks with host layers.**
  Entries like `"mpv/.config/mpv"` link to `~/.config/mpv` from the dotfiles
  repo, so edits apply without a rebuild. A shared layer plus a per-host one
  gives each machine its own file at one canonical name (`niri-host.kdl`).
  [`homes/modules/dotfiles.nix`](homes/modules/dotfiles.nix) ·
  [3c4de7a](https://github.com/HefKer/nixos-config/commit/3c4de7a),
  [bc28c66](https://github.com/HefKer/nixos-config/commit/bc28c66)
- <a id="dotfiles-check"></a>**Check the link set home-manager actually
  produces.** Each host's `home.file` is compared to an expected list, and
  every link must point outside the store, so a swapped host variant or a
  forgotten entry fails the flake check.
  [`checks/default.nix`](checks/default.nix) ·
  [af5d3d4](https://github.com/HefKer/nixos-config/commit/af5d3d4),
  [895f32f](https://github.com/HefKer/nixos-config/commit/895f32f)
- <a id="no-backups"></a>**Fail on collisions instead of hiding them.** No
  `backupFileExtension`, so a file in the way of a link aborts activation
  rather than turning into a forgotten `.hm-bak`.
  [`modules/core/home-manager.nix`](modules/core/home-manager.nix) ·
  [a1619fc](https://github.com/HefKer/nixos-config/commit/a1619fc)

### Keyboard (kanata)

- <a id="kanata-instances"></a>**One kanata per keyboard, keymap from
  dotfiles.** Two instances share one `keymap.kbd` read from `$HOME` through a
  read-only bind, so live-reload works without a rebuild. They wait for udev's
  coldplug and restart on failure, and a polkit rule lets a bind restart them
  without a password.
  [`modules/roles/workstation/input.nix`](modules/roles/workstation/input.nix) ·
  [c5c429b](https://github.com/HefKer/nixos-config/commit/c5c429b),
  [31150ef](https://github.com/HefKer/nixos-config/commit/31150ef),
  [f11861b](https://github.com/HefKer/nixos-config/commit/f11861b)
- <a id="kanata-misfires"></a>**Catch and test home-row-mod misfires.**
  `kanata-flag` asks through fuzzel what you meant and what came out, and logs
  it with each instance's layer and the keymap's git rev. `kanata-test` replays
  `.sim` cases, or fuzzes word lists as fast rolls, in a simulator built from
  the same kanata the service runs.
  [`pkgs/kanata-misfires/`](pkgs/kanata-misfires/),
  [`pkgs/kanata-sim/`](pkgs/kanata-sim/) ·
  [2b71808](https://github.com/HefKer/nixos-config/commit/2b71808),
  [7cbf756](https://github.com/HefKer/nixos-config/commit/7cbf756)
- <a id="kanata-keymap"></a>**A keymap viewer that redraws itself.** A path
  unit watches `keymap.kbd` and redraws it as an SVG with keymap-drawer, and a
  bind toggles it in swayimg.
  [`homes/modules/kanata-keymap.nix`](homes/modules/kanata-keymap.nix),
  [`pkgs/kanata-keymap/`](pkgs/kanata-keymap/) ·
  [ad8ab11](https://github.com/HefKer/nixos-config/commit/ad8ab11)
- <a id="osu-passthrough"></a>**A keyboard layer per focused game.** A user
  service follows niri's event stream and switches every kanata instance over
  TCP to the layer an app-id regex maps it to, passthrough for osu! and a game
  layer for Steam games, restoring the previous layer after.
  [`homes/modules/game-focus-watcher.nix`](homes/modules/game-focus-watcher.nix),
  [`pkgs/game-focus-watcher/`](pkgs/game-focus-watcher/) ·
  [22545a7](https://github.com/HefKer/nixos-config/commit/22545a7)

### Coding agents

- <a id="herdr-plugins"></a>**herdr plugins packaged in Nix.** Plugins are
  built into the store and merged into herdr's `plugins.json` at activation,
  since herdr rewrites that file itself. The merge validates every entry first,
  because one bad entry makes herdr drop them all.
  [`homes/modules/herdr-plugins.nix`](homes/modules/herdr-plugins.nix),
  [`pkgs/herdr-plugins-sync/`](pkgs/herdr-plugins-sync/) ·
  [df23f3c](https://github.com/HefKer/nixos-config/commit/df23f3c)
- <a id="claude-second-account"></a>**A second Claude Code account sharing
  your setup.** Links the read-only pieces into a second config dir: skills
  and agents from `~/.claude`, commands, keybindings and `CLAUDE.md` straight
  from the dotfiles root, leaving everything Claude writes per-account.
  [`homes/modules/claude-hulio.nix`](homes/modules/claude-hulio.nix) ·
  [35bca13](https://github.com/HefKer/nixos-config/commit/35bca13)
- <a id="package-skills"></a>**Skills bundled with packages.** Linking
  `/share/skills` into the system profile gives skills that ship with packages
  (like hunk's) a path that survives upgrades.
  [`modules/roles/workstation/development/packages.nix`](modules/roles/workstation/development/packages.nix) ·
  [2f0f5eb](https://github.com/HefKer/nixos-config/commit/2f0f5eb)
- <a id="hunk-extensions"></a>**Pinned, patched hunk extensions.** Fetches an
  extension at a commit, patches it, and places `installed/` as one store
  directory, since hunk skips symlinked extension folders.
  [`homes/modules/hunk-extensions.nix`](homes/modules/hunk-extensions.nix) ·
  [0baa182](https://github.com/HefKer/nixos-config/commit/0baa182)

### Desktop

- <a id="reboot-required"></a>**Know when to reboot.** Compares the kernel,
  initrd and kernel modules against `/run/booted-system`, printing a warning
  during the switch and, through the [health](#health) probes, notifying
  after each switch.
  [`pkgs/reboot-required/`](pkgs/reboot-required/),
  [`modules/core/reboot-required.nix`](modules/core/reboot-required.nix) ·
  [0891279](https://github.com/HefKer/nixos-config/commit/0891279)
- <a id="rebuild-notify"></a>**Notify when a rebuild finishes.** A
  high-priority `nixos-rebuild` wrapper runs the real one, then sends a
  notification with the action, duration and, on failure, the exit code,
  reaching the invoking user's session bus even under `sudo`.
  [`modules/roles/workstation/rebuild-notify.nix`](modules/roles/workstation/rebuild-notify.nix)
- <a id="stale-apps"></a>**Know which apps to restart.** Whenever
  `/run/current-system` changes, scans your processes' executables and
  command lines for store paths the new system no longer ships but whose
  package it still has under another hash, and notifies with their names.
  `stale-apps` prints the list on demand.
  [`pkgs/stale-apps/`](pkgs/stale-apps/),
  [`modules/roles/workstation/stale-apps-notify.nix`](modules/roles/workstation/stale-apps-notify.nix)
- <a id="health"></a>**Probes for silent breakage.** A daily user timer, and
  every home-manager switch, runs each `custom.health.probes.<name>` script
  into `~/.local/state/health/findings`, notifying only for findings the last
  run didn't have. Probes cover link drift, Syncthing conflict files, unseen
  peers and folder errors, failed units, a pending reboot, low disk space,
  an old nixpkgs, SMART trouble (read from a root timer's file), build output
  untouched for a month, and repos with uncommitted or unpushed work left
  idle. `health` re-runs them, and `health --greeting` prints a one-line
  count for a shell greeting.
  [`homes/modules/health.nix`](homes/modules/health.nix),
  [`pkgs/health/`](pkgs/health/),
  [`modules/roles/workstation/smart-status.nix`](modules/roles/workstation/smart-status.nix)
- <a id="summon"></a>**Summon an app from anywhere.** `summon <app-id>
  <command>` focuses the app's most recently focused window across workspaces
  and monitors, cycles through its others on repeats in the order the cycle
  began with, and launches it if none is open; bound to niri's Mod+Alt keys.
  [`pkgs/summon/`](pkgs/summon/)
- <a id="yazi-picker"></a>**yazi as the system file picker.** Uses
  xdg-desktop-portal-termfilechooser on niri, with the environment variables
  that make unsandboxed GTK, Firefox and Qt apps actually use the portal.
  [`modules/roles/workstation/display.nix`](modules/roles/workstation/display.nix) ·
  [255b483](https://github.com/HefKer/nixos-config/commit/255b483)
- <a id="memes"></a>**A meme library with a picker.** `meme-add` saves a URL,
  file or the clipboard into `~/memes` (Tenor and Giphy as looping mp4s), named
  by tags asked through fuzzel. `meme-pick` shows thumbnails in fuzzel and
  copies the pick as a file reference that Discord, Signal and WhatsApp accept.
  `sound-add` and `sound-pick` do the same for sound clips, played into a
  PipeWire "Soundboard mic" that carries your voice too: a soundboard with no app.
  [`pkgs/memes/`](pkgs/memes/) ·
  [`audio.nix`](modules/roles/workstation/audio.nix) ·
  [b50e756](https://github.com/HefKer/nixos-config/commit/b50e756)
- <a id="share-cast-target"></a>**Unattended screen sharing on niri.**
  `share-cast-target` waits for the GNOME portal's Share Screen dialog and
  picks niri's Dynamic Cast Target by keyboard (wtype), checking the dialog
  still has focus before every key, then aims it with the niri action it was
  given (`share-cast-target set-dynamic-cast-monitor DP-3`), so an app can go
  live hands-free and later `set-dynamic-cast-*` calls switch what's shown.
  [`pkgs/share-cast-target/`](pkgs/share-cast-target/)
- <a id="vencord-userplugins"></a>**Vencord userplugins built into Vesktop.**
  `pkgs/vencord-userplugins` copies plugin sources (here
  [VcPresets](https://github.com/HefKer/vc-presets): one-command Go Live
  presets, and [VcActions](https://github.com/HefKer/vc-actions): slash
  commands and hotkeys) into Vencord's `src/userplugins` and builds it, and
  Vesktop's `withSystemVencord` loads that instead of downloading Vencord.
  [`pkgs/vencord-userplugins/`](pkgs/vencord-userplugins/)
- <a id="window-pick"></a>**A picker over every open niri window.** `window-pick`
  lists all windows across workspaces and monitors in fuzzel, most recently
  focused first with their app icons, searchable by title or app-id, and
  focuses the pick. [`pkgs/window-pick/`](pkgs/window-pick/)
- <a id="window-volume"></a>**Volume keys for the focused window.**
  `window-volume up|down|mute` finds the PipeWire streams of the app in niri's
  focused window, including browsers' and Electron's child processes, and steps
  or mutes only those, showing the new level in a DMS toast, which
  do-not-disturb leaves alone.
  [`pkgs/window-volume/`](pkgs/window-volume/)
- <a id="removable-drives"></a>**Removable drives mounted as you.** udisks2
  and a udiskie user service, so FAT and exFAT files aren't owned by root.
  [`modules/roles/workstation/storage.nix`](modules/roles/workstation/storage.nix),
  [`homes/modules/udiskie.nix`](homes/modules/udiskie.nix) ·
  [ea64d1a](https://github.com/HefKer/nixos-config/commit/ea64d1a)

- <a id="soloist"></a>**Spotify without librespot or Electron.** Spotify's
  official headless Soloist runs as a user service and shows up as a Connect
  speaker, with the API key rendered from sops and the `soloist-mpris` bridge
  giving DMS and the media keys a player, for accounts librespot can no longer
  decrypt. [`homes/modules/spotify.nix`](homes/modules/spotify.nix),
  [`pkgs/soloist-mpris/`](pkgs/soloist-mpris/)

### Sync

- <a id="syncthing"></a>**Syncthing with no first-scan gap.** One table of
  peers and folder rows builds every host's devices and folders, and each
  folder's whole `.stignore` is composed from shared lists and written by
  activation before the service starts, since `ignorePatterns` only lands
  after the first scan. App-state folders sync only named paths, and the
  host's identity comes from sops.
  [`homes/modules/syncthing/`](homes/modules/syncthing/)
- <a id="sync-resolve"></a>**Settle sync conflicts without the busywork.**
  `sync-resolve` deletes conflict copies that are identical, stale app state
  or a git index, or Claude transcripts whose every message the live one
  has, keeps a diverged git ref as a `sync-conflict/<host>/<ref>` branch, and 3-way merges a git-tracked file against the last commit before
  the conflict (not HEAD, which would revert everything since). The rest it
  asks about one by one, naming the peer each copy came from; `--dry-run`
  shows the plan.
  [`pkgs/sync-resolve/`](pkgs/sync-resolve/)

### Secret management

- <a id="secrets"></a>**sops-nix in a public repo.** One encrypted file per
  host plus a shared one. Hosts decrypt with their SSH host key and you with
  an age key kept in Bitwarden, and a flake check fails on any plaintext.
  [`modules/core/secrets.nix`](modules/core/secrets.nix),
  [`.sops.yaml`](.sops.yaml),
  [`checks/default.nix`](checks/default.nix) ·
  [d16d4f7](https://github.com/HefKer/nixos-config/commit/d16d4f7),
  [f91c2ca](https://github.com/HefKer/nixos-config/commit/f91c2ca)

## How this repo is wired

The rest is for me and for agents working in this repo.

### Config Structure

This repository is structured in a modularized format, with each directory serving a specific purpose:

**modules**: Reusable chunks of configuration that can be toggled on or off.

- `core` contains the baseline configuration that applies to every machine.
- `platforms` contains setup shared by a class of hardware (desktop, laptop); each host picks exactly one, and several hosts may share it.
- `roles` contains configurations that apply to specific types of machines — currently just workstation.
  - Workstation is further split into sub-roles: development, gaming, local-ai and virtualization.

**hosts**: One directory per machine. `default.nix` picks the platform and roles and turns them on; the other files hold facts unique to that one machine, such as its disk layout and site-specific wifi profiles.

**lib**: Utility functions and constants used throughout the flake.

**checks**: Tests `nix flake check` runs on top of evaluating every host: formatting (`nix fmt`) and the module conventions. `.githooks/pre-commit` runs them on every commit once enabled with `git config core.hooksPath .githooks`.

**scripts**: `same-system` proves a refactor leaves every host's build unchanged; `link-drift` lists files in `$HOME` that would block Home Manager's links.

**homes**: Home Manager — the home layer. It *wires* dotfiles into `$HOME`; it does not hold them. Their content lives in a separate dotfiles root, and packages stay at the system layer, in `modules`. See [Dotfiles](#dotfiles).

**secrets**: Secrets encrypted with sops-nix, one file per host plus a shared one; `.sops.yaml` at the root says which keys can read which file. See [Secrets](#secrets).

**docs**: Notes to myself. Architecture decisions, research, and things I've learned along the way. `docs/agents/` documents the workflows I use with AI coding agents — including where issues live, which is the private `nixos-issues` repo rather than this one (see `docs/adr/0002-issues-live-in-a-separate-private-repo.md`).

### How it fits together

Every toggle in this flake is a custom option under the `custom.*` namespace — `custom.platform = "laptop"`, `custom.roles.workstation.development.enable`, and so on. Modules declare their options and keep their config behind `lib.mkIf`, so nothing takes effect until a host asks for it.

That makes `hosts/desktop/default.nix` and `hosts/lenovo/default.nix` the main files: they're the only place anything is switched on, so each one reads as a short description of what that machine actually is.

### Dotfiles

Application config — fish, niri, nvim, wezterm and the rest — is not in this repository. It lives as ordinary hand-edited files in the dotfiles root, `~/dots`, a repository of its own. `homes/modules/dotfiles.nix` declares the **link set**: which paths under the dotfiles root appear where in `$HOME`, with a per-host layer on top of a shared one.

The links are **out-of-store symlinks**, deliberately. Editing a dotfile takes effect straight away, with no rebuild, and applications that rewrite their own config keep working. The cost is that `flake.lock` does not pin dotfile content, so a rollback restores the links but not the files they point at. Store copies were considered and rejected for machines I sit at — don't "fix" this by pointing the links at store copies. The reasoning is in [ADR-0001](docs/adr/0001-dotfiles-wired-by-home-manager-as-out-of-store-symlinks.md), and the vocabulary (dotfiles root, link set, write-back application, drift) in [GLOSSARY.md](GLOSSARY.md).

#### Bootstrapping a new machine

The flake declares Syncthing, so the dotfiles root arrives **after** the first rebuild, not before it. In order:

1. Make the host a recipient (below).
2. Generate its Syncthing identity: `nix run nixpkgs#syncthing -- generate --home="$(mktemp -d)"` prints the device ID and writes `cert.pem` and `key.pem`. Put the two files in `secrets/<host>.yaml` as `syncthing-cert` and `syncthing-key` (`SOPS_AGE_KEY_CMD="rbw get sops-age-key" sops secrets/<host>.yaml`), then delete the directory.
3. Add the host to `peers` in `homes/modules/syncthing/table.nix`, with that device ID and its Tailscale address, and to the folder rows it should take. Commit.
4. Rebuild an existing peer, so it knows the new device.
5. Rebuild the new host. Syncthing starts, connects and pulls its folders.

The links resolve once `~/dots` has synced. Nix cannot check this. The links point outside the store, so the build succeeds and activation places them whether or not their targets exist. Until `~/dots` arrives, every link dangles silently and the applications fail obscurely — starting with defaults or erroring on a config they can't read — rather than the rebuild failing loudly. If something looks unconfigured after a fresh install, check `ls -L ~/.config/<app>` first.

#### Making a new host a recipient

A new host must be able to read its secrets **before its first rebuild that needs one**, and Nix can't check this either: the build succeeds, then decryption fails at activation. From a machine that holds the user's age key:

1. Read the host's public key on the new host, which has no `ssh-to-age` yet: `nix run nixpkgs#ssh-to-age -- -i /etc/ssh/ssh_host_ed25519_key.pub`.
2. Add it to `.sops.yaml`, with a path rule for `secrets/<host>.yaml` and in the `secrets/shared.yaml` rule.
3. Create the host's own file: `echo '{}' > secrets/<host>.yaml && sops encrypt -i secrets/<host>.yaml`.
4. Re-encrypt the shared file for the new recipient list: `SOPS_AGE_KEY_CMD="rbw get sops-age-key" sops updatekeys secrets/shared.yaml`.
5. Commit, then run `nixos-rebuild` on the new host.

### Secrets

Secrets live in `secrets/` as ciphertext: `secrets/<host>.yaml` for one machine, `secrets/shared.yaml` for all of them. `modules/core/secrets.nix` imports sops-nix, which decrypts them at activation to `/run/secrets`, outside the Nix store. Each host decrypts with an age key derived from its SSH host key; the user is a recipient of everything through an age key kept in Bitwarden, so no machine's disk has to survive. Only secrets that can be rotated belong here, because git history keeps every encrypted version for good. The reasoning is in [ADR-0006](docs/adr/0006-secrets-are-sops-encrypted-in-the-public-repo.md).

Edit a file with `SOPS_AGE_KEY_CMD="rbw get sops-age-key" sops secrets/shared.yaml`, and declare `sops.secrets.<name>` next to the module that consumes it. `nix flake check` fails on any file in `secrets/` that isn't encrypted.

### Sync

Syncthing runs as a home-manager user service on every workstation, from `homes/modules/syncthing/`. `table.nix` holds the peers and one row per folder naming the peers it is shared with; a host builds only the rows that include it, and only the devices those rows name. Devices and folders added through the web UI are deleted on the next start (`overrideDevices`, `overrideFolders`), so a new share is a new row.

A **personal folder** syncs everything except what `ignores.nix` excludes; an **app-state folder** (a row with `only`) syncs nothing but the paths it names. Every `.stignore` is generated whole, key material first and never deletable, and written by activation before the service starts, so a new host's first scan already has its rules. The reasoning is in [ADR-0007](docs/adr/0007-flake-generates-every-stignore.md), and the vocabulary (peer, hub, personal and app-state folder) in [GLOSSARY.md](GLOSSARY.md). Changing a rule takes a rebuild on each host; editing a `.stignore` by hand is overwritten.

Each host's identity (`cert.pem`, `key.pem`) is a sops secret, so its device ID survives a reinstall. Old versions of changed and deleted files are kept per folder under `~/.local/state/syncthing/versions/`.
