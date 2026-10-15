{
  config,
  consts,
  lib,
  ...
}:
let
  # Only what Claude reads; claude-code refuses to write through a symlink, so anything it writes stays per-account.
  shared = [
    "skills"
    "commands"
    "agents"
    "keybindings.json"
    "CLAUDE.md"
  ];
in
{
  home.file = lib.listToAttrs (
    map (
      name:
      lib.nameValuePair ".claude-hulio/${name}" {
        source = config.lib.file.mkOutOfStoreSymlink "${consts.home}/.claude/${name}";
      }
    ) shared
  );
}
