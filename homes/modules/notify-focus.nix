{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  watcher = pkgs.callPackage ../../pkgs/notify-focus { };
in
{
  systemd.user.services.notify-focus = {
    Unit = {
      Description = "Focus an app's window when its notification is invoked";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.escapeShellArgs [
        (lib.getExe watcher)
        "--niri"
        (lib.getExe osConfig.programs.niri.package)
        "--busctl"
        "${pkgs.systemd}/bin/busctl"
      ];
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
