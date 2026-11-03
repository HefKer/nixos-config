{
  config,
  lib,
  pkgs,
  ...
}:
let
  sync = pkgs.callPackage ../../pkgs/herdr-plugins-sync {
    plugins = map (name: pkgs.callPackage ../../pkgs/${name} { }) [
      "herdr-hunk-diff"
      "smart-splits-backend-herdr"
    ];
  };
in
{
  # herdr rewrites plugins.json by rename and rereads it on every request, so it is merged into, never linked.
  home.activation.herdrPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe sync} ${lib.escapeShellArg "${config.xdg.configHome}/herdr/plugins.json"}
  '';
}
