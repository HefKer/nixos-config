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

**Core**:
Configuration every host receives, including a headless server. Anything only a
machine with a person sitting at it needs does not belong here.
_Avoid_: base, common, default

**Platform**:
A class of hardware that one or more hosts run on, such as a laptop or a
Raspberry Pi. Facts unique to a single machine belong to its host, not its
platform.
_Avoid_: machine, hardware profile

**Role**:
A named kind of machine, such as a workstation, switched on by a host as a
whole. Roles are the unit of "what kind of machine is this".

**Sub-role**:
A narrower kind of use that only makes sense on top of a parent role, such as
gaming on a workstation.
_Avoid_: use case, profile, feature

**Subsystem**:
The part of the operating system a piece of configuration drives, such as
audio, input, display, or boot. Configuration is grouped by subsystem within a
layer; applications are not subsystems.
_Avoid_: concern, area, topic

**Host**:
A single named machine built from this flake: one platform plus the roles it
takes on. The only place capabilities are switched on.
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
configuration varies per host without being generated. It is linked file-level,
beside the application's directory link rather than inside it, since a link cannot
be placed inside a linked directory; niri's per-host file is the case.

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
granularity. An application that writes its config in place, through the link,
is not one: herdr does so, and is linked file-level. Nor is one that resolves the
link and renames over its destination, as git does. Either may then be linked file-level
where its directory holds runtime state.
_Avoid_: stateful app, self-modifying config

**Drift**:
Divergence between what is declared and what is actually there. Splits into
*content drift* (tracked files changed but uncommitted), *link drift* (a managed
target is no longer the link that was placed) and *baseline drift* (the phone no
longer holds its phone baseline).

### Sync

**Peer**:
A device that shares synced folders. Every host that syncs is a peer, but a peer
need not be a host: the phone is one and is not built from this flake.
_Avoid_: node, client

**Hub**:
A planned always-on peer that the others sync through, so two peers need not be
online together.
_Avoid_: sync server, central node

**Personal folder**:
A synced folder of files the user authors or keeps. Everything syncs except what
is excluded.
_Avoid_: data folder

**App-state folder**:
A synced folder an application writes. Nothing syncs except what is named.
_Avoid_: config folder

### Keyboards

**Digital feature**:
A keyboard behaviour expressible as a mapping from key events to key events,
such as a remap, a mod-tap, or a layer. Works the same on any keyboard, so it is
owned by the remapper rather than by any one keyboard's firmware.
_Avoid_: software feature, macro

**Onboard feature**:
A keyboard behaviour only the keyboard's own firmware can provide: anything
depending on how far a key is pressed, such as rapid trigger or a per-key
actuation point, and commands to the keyboard itself, such as switching between
its stored profiles. Stays in the firmware.
_Avoid_: analog feature, hardware feature, firmware feature

**Remapper**:
The single owner of every digital feature, applied to every keyboard on a
workstation except those whose output it would corrupt, such as a chording
keyboard.
_Avoid_: keyboard daemon, key mapper

**Passthrough layer**:
The remapper layer in which every key is stock, for a game that needs keys
unprocessed (osu). Switched on while such a game has focus.
_Avoid_: game mode, bypass

**Game layer**:
The remapper layer for every other game: stock keys plus arrows on the
right-hand modifier cluster. Switched on while a game has focus. Distinct from
the passthrough layer, which changes nothing.
_Avoid_: gaming layer, passthrough

### Secrets

**Secret**:
A value whose disclosure grants access, such as a password or an API key. Never
present in the Nix store in plaintext; configuration refers to it only by the
path where it appears at runtime.
_Avoid_: credential, env file

**Recipient**:
A key that can decrypt a given secret: the host that consumes it, plus the
user's own. Being a recipient is what authorises a host to read a secret.
_Avoid_: reader, owner

**Profile**:
What a configuration reveals about a setup without granting access to it, such
as which services run or which provider holds the backups. Publishing it is
accepted; publishing a secret in plaintext is not.
_Avoid_: metadata, fingerprint

### Phone

**Phone**:
The user's Android phone, named by its role rather than its model. A peer, not
a host: nothing builds it, so it is changed from outside, by hand, by agents,
or by scripts.
_Avoid_: device, mobile, handset

**Phone errand**:
A one-off job an agent does on the phone at the user's request, with the user
present to approve anything hard to undo.
_Avoid_: phone task, phone job

**Phone automation**:
A recurring job touching the phone that runs unattended on a trigger or
schedule. It runs on the phone when its trigger lives there or it must work
while the user is away, and on a host when it needs a host's files, compute or
agents. Unattended, it only reads and notifies, unless its changes are fixed and
were reviewed in advance.
_Avoid_: phone script, routine, macro

**Phone baseline**:
The settings and apps the user wants held on the phone, reapplied on demand.
The closest the phone gets to configuration, but nothing builds it, and drift
from it is only corrected when it is reapplied.
_Avoid_: phone config, phone profile

**Phone journal**:
The record of every change an agent makes to the phone, each with the value it
replaced, so any of them can be undone after the session that made it is gone.
_Avoid_: change log, history

### Health

**Probe**:
A periodic check for one class of silent breakage, such as link drift or a
sync-conflict file. Reports nothing when all is well.
_Avoid_: health check, monitor, test

**Finding**:
One instance of breakage a probe reports, open until a later run no longer
reports it.
_Avoid_: alert, warning, issue

### Claude

**Account**:
One Claude login and the config dir that holds it: credentials, project trust,
permission state and session history, none of it shared. Configuration Claude
only reads is shared into the second account's dir as a link set;
`settings.json`, which Claude rewrites (a write-back application at file
granularity), is a real file merged in at each launch. The main account is
`~/.claude`, the second, hulio, `~/.claude-hulio`.
_Avoid_: profile, login, user

### Desktop actions

**Repeatable action**:
A desktop action that records how to replay itself, so the repeat key can run it
again without its menu. The replay is the action's own choice, not necessarily
the command that started it.
_Avoid_: macro, last command

**Held volume**:
The level and mute state set for a window's audio, kept while the window plays
nothing and given to every stream it starts until the window closes.
_Avoid_: pending volume, window volume

### Backlog

**Draft**:
Text typed into a project's backlog box but not yet filed. Kept, one per
project, until it is filed or discarded.
_Avoid_: buffer, saved input

### Browser proxy

**Direct list**:
The sites the browser reaches without going through Proton VPN, kept by hand in
the dotfiles. Every other site goes through the tunnel.
_Avoid_: exceptions, bypass list, whitelist

**Blocked on the exit**:
A site that fails through the Proton VPN server but loads when reached directly,
because the server's address is refused, geo-fenced or misrouted there. The
remedy is the direct list. A site that fails both ways is down, not blocked.
_Avoid_: proxy break, VPN-blocked
