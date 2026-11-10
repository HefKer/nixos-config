{
  config,
  lib,
  pkgs,
  ...
}:
let
  store = "${config.home.homeDirectory}/${(import ./syncthing/table.nix).folders.alarms.path}";
  alarm = pkgs.callPackage ../../pkgs/alarm { inherit store; };
in
{
  home.packages = [ alarm ];

  # Transient timers die with the user manager, so login rebuilds them from the files.
  systemd.user.services.alarm-sync = {
    Unit.Description = "Mirror the synced alarm files as systemd timers";
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe alarm} sync";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.paths.alarm-sync = {
    Unit.Description = "Re-sync the alarm timers when an alarm file changes, here or on another host";
    Path = {
      PathChanged = [ store ];
      MakeDirectory = true;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
