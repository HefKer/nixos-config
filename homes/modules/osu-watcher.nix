{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  watcher = pkgs.callPackage ../../pkgs/osu-focus-watcher { };

  # From `niri msg windows` with each running; umu gives osu!stable, like any game without a Steam ID, steam_app_0.
  appIds = [
    "osu!"
    "steam_app_0"
  ];

  ports = lib.mapAttrsToList (_: keyboard: keyboard.port) osConfig.services.kanata.keyboards;
in
{
  systemd.user.services.osu-focus-watcher = {
    Unit = {
      Description = "Switch kanata to passthrough while osu is focused";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.escapeShellArgs (
        [
          (lib.getExe watcher)
          "--niri"
          (lib.getExe osConfig.programs.niri.package)
        ]
        ++ lib.concatMap (id: [
          "--app-id"
          id
        ]) appIds
        ++ lib.concatMap (port: [
          "--port"
          (toString port)
        ]) ports
      );
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
