# Preview

The **preview** shows each finalist in use, so the user can judge its feel before a trial.
Shots go in `docs/research/<topic>/`, named `<finalist>-<n>-<view>.png`; the directory is
gitignored, so they stay local.

## Views

Three per finalist, the same three across finalists so they compare side by side:

1. **Core job**: the main view, mid-task (a track playing, a note open).
2. **Reach**: the help screen, bind hints or command palette.
3. **Settings**: the settings view, or its config file open beside it.

Read each image before keeping it: a blank window, a first-run wizard or an error only shows
there. Done when every finalist has its three views, or a line in the write-up saying which
view is missing and why.

## Trial config

Shoot each finalist on a **trial config**: a throwaway config directory at
`docs/research/<topic>/<finalist>-config/`, passed by `XDG_CONFIG_HOME` or the app's own
flag, holding a minimal config with the user's vim-style binds and the colours of the
matching app in `~/dots`. The user then sees the app as it would be adopted, their real
`~/.config` stays untouched, and the write-up's *Try it* line reuses the same directory.
Shoot on demo content from the scratchpad, since the user's own data would end up in the
image.

## Rungs

Take the first rung the finalist can reach.

1. **Terminal program**: `~/dots/scripts/claude-shot --keys <keys> OUT.png -- <cmd>`, in the
   user's own WezTerm, so the shot also shows how it sits in the theme.
2. **Program with its own window**: `claude-shot --gui`, a headless cage. Its header comment
   has the key syntax. `CMD exited before the shot` with a display error is evidence for the
   X11-only dealbreaker; `CMD never drew a frame` sends the finalist to rung 3.
3. **Needs setup first** (an account, a server, hardware): upstream's demo instance or its
   own screenshots, linked from the write-up with the version they show.
4. **Phone app**: [`phone.md`](phone.md) → Preview.

## Demo video

Beside the shots, one video per finalist from the YouTube research, linked at the second its
core job starts (`https://youtu.be/<id>?t=<seconds>`, found in the transcript). It qualifies
when it is unsponsored, shows the current major version, and shows the app being used
rather than installed. Write `no good demo` for a finalist with none.
