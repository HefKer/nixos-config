{
  config,
  lib,
  pkgs,
  ...
}:
let
  plugins = lib.genAttrs [
    "herdr-auto-title"
    "herdr-floax"
    "herdr-hunk-diff"
    "herdr-lazygit"
    "herdr-yazi"
    "smart-splits-backend-herdr"
  ] (name: pkgs.callPackage ../../pkgs/${name} { });
  sync = pkgs.callPackage ../../pkgs/herdr-plugins-sync {
    plugins = lib.attrValues plugins;
  };
  # herdr-lazygit's AI commit picker, for lazygit outside herdr; it shares the plugin's ai-backend.conf.
  lazygitAiCommit = pkgs.writeShellScriptBin "lazygit-ai-commit" ''
    export HERDR_PLUGIN_CONFIG_DIR=${lib.escapeShellArg "${config.xdg.configHome}/herdr/plugins/config/herdr-lazygit"}
    exec ${lib.getExe pkgs.bash} ${plugins.herdr-lazygit}/scripts/ai-commit-pane.sh "$@"
  '';
in
{
  home.packages = [ lazygitAiCommit ];

  # herdr rewrites plugins.json by rename and rereads it on every request, so it is merged into, never linked.
  home.activation.herdrPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe sync} ${lib.escapeShellArg "${config.xdg.configHome}/herdr/plugins.json"}
  '';
}
