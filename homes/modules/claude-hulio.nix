{
  config,
  consts,
  lib,
  dotfilesRoot,
  ...
}:
let
  # Only what Claude reads; claude-code refuses to write through a symlink, so anything it writes stays per-account.
  shared = {
    # skillshare manages ~/.claude/skills, so both accounts follow it there.
    skills = "${consts.home}/.claude/skills";
    agents = "${consts.home}/.claude/agents";
    # Straight to the dotfiles root, not via ~/.claude's own links, so there's no chain.
    commands = "${dotfilesRoot}/claude/.claude/commands";
    "keybindings.json" = "${dotfilesRoot}/claude/.claude/keybindings.json";
    "CLAUDE.md" = "${dotfilesRoot}/claude/.claude/CLAUDE.md";
  };
in
{
  home.file = lib.mapAttrs' (
    name: target:
    lib.nameValuePair ".claude-hulio/${name}" {
      source = config.lib.file.mkOutOfStoreSymlink target;
    }
  ) shared;
}
