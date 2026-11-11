# A second Claude account is a separate config dir

Status: accepted

A second Claude account, hulio, lives in its own `CLAUDE_CONFIG_DIR`,
`~/.claude-hulio`, chosen per process. Each account keeps its own credentials,
project trust, permission state and session history. The configuration the two
share reaches hulio two ways. The pieces Claude only reads (skills, agents,
commands, `keybindings.json`, `CLAUDE.md`) are a link set of out-of-store
symlinks on development hosts (`homes/modules/claude-hulio.nix`). `settings.json`,
which Claude rewrites, is a real file that the `claude` fish wrapper
(`~/dots/fish/.config/fish/functions/claude.fish`) rebuilds at every hulio
launch: the main account's `settings.json` merged with hulio's own
`settings.override.json`.

## Considered options

- **Swapping `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY` in one config
  dir.** Shares everything for free, but the token only makes model requests:
  no Remote Control, no `/schedule`, no account info in `/status`. Both accounts'
  project trust and permission state would also mix in one `.claude.json`.
- **Symlinking `settings.json` between the dirs.** Claude rewrites its settings
  itself (`/config`, `/model`, "always allow"), and claude-code's atomic writer
  refuses outright: `Refusing to write through symlink` /
  `Refusing to write into symlinked directory` (2.1.263, when this was decided).
  This is the write-back application case from ADR-0001, at file granularity.
- **`--settings ~/.claude/settings.json`.** The CLI layer outranks project
  settings, so user-level keys would silently override a project's own
  `.claude/settings.json`.
- **home-manager's `programs.claude-code`.** Writes `settings.json` as a
  read-only store link: the same write-back problem, and no support for more
  than one account.

## Consequences

- A setting changed from a hulio session (`/config`, `/model`, "always allow")
  is lost at the next launch, unless it goes in `settings.override.json`.
- `jq`'s `*` merges objects deeply but replaces arrays wholesale, so an override
  that touches `permissions.allow` replaces the whole list.
- Only `settings.override.json` syncs between hosts, beside hulio's projects and
  sessions; each host builds its own merged `settings.json`
  (`homes/modules/syncthing/table.nix`).
- Sessions belong to one account's config dir, so `/resume` lists only that
  account's. `csend` moves a session's files to the other dir, and herdr's
  prefix+u runs it on the focused pane (`~/dots/scripts/herdr-claude-account`).
  A bare `claude --resume <id>` picks hulio when the session file lives under
  `~/.claude-hulio`, which is what herdr types when it restores a pane.
- Scripts that touch a config dir (the launch guard, the config backup hook,
  the statusline) read `CLAUDE_CONFIG_DIR` rather than assuming `~/.claude`; the
  statusline shows a hulio badge.
- The VS Code extension ignored `CLAUDE_CONFIG_DIR` when this was decided
  (anthropics/claude-code#30538), so hulio is a terminal-only account.
