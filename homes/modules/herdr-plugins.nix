{
  config,
  lib,
  pkgs,
  ...
}:
let
  sync = pkgs.callPackage ../../pkgs/herdr-plugins-sync {
    plugins = [ (pkgs.callPackage ../../pkgs/herdr-hunk-diff { }) ];
  };
in
{
  # herdr rewrites plugins.json by rename and rereads it on every request, so it is merged into, never linked.
  home.activation.herdrPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe sync} ${lib.escapeShellArg "${config.xdg.configHome}/herdr/plugins.json"}
  '';
}
