# The flake generates every .stignore

Status: accepted

Syncthing ignore rules were masters in the dotfiles root, spread by hand-run
scripts through symlinks and `#include` files. Syncthing never syncs `.stignore`,
refused the symlinked includes, and on a new host could scan a folder before any
rules existed, offering `~/.claude/.credentials.json` to its peers. Now the flake
composes each folder's whole `.stignore` from shared Nix lists, and activation
writes it as a real file before the service starts. Nothing is included, linked
or run by hand.

The native `ignorePatterns` option is left unused on purpose. Home-manager applies
it through `syncthing-init`, after the daemon has started, so it leaves the same
gap before the first scan. Don't "simplify" to it unless that ordering changes.

## Considered options

- **Masters in the dotfiles root.** An edit reaches the other host with no
  rebuild, but the rules depend on the folder they protect having already synced.
- **`ignorePatterns`, alone or alongside the file.** Less code, but alone it keeps
  the gap, and with the file it adds a second writer.

## Consequences

- Changing an ignore rule takes a rebuild on each host.
- `.stignore` edits by hand or through the web UI are overwritten.
