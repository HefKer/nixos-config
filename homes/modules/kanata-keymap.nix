{
  dotfilesRoot,
  lib,
  pkgs,
  ...
}:
let
  keymap = pkgs.callPackage ../../pkgs/kanata-keymap { };
  keymapDir = "${dotfilesRoot}/kanata";
in
{
  systemd.user.services.kanata-keymap-render = {
    Unit.Description = "Draw the kanata keymap for the keymap viewer";
    Service = {
      Type = "oneshot";
      ExecStart = lib.escapeShellArgs [
        (lib.getExe' keymap "kanata-keymap-render")
        keymapDir
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.paths.kanata-keymap-render = {
    Unit.Description = "Redraw the kanata keymap when it changes";
    Path.PathChanged = [
      "${keymapDir}/keymap.kbd"
      "${keymapDir}/keymap-drawer.yaml"
    ];
    Install.WantedBy = [ "default.target" ];
  };
}
