{ lib, pkgs, ... }:
let
  backlog = pkgs.callPackage ../../pkgs/backlog { };
in
{
  home.packages = [ backlog ];

  systemd.user.services.backlog-flush = {
    Unit = {
      Description = "File the ideas backlog queued while offline";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe backlog} flush --notify";
      # A filed notification waits for its Open action; the oneshot exits without it, so leave it running.
      KillMode = "process";
    };
  };

  systemd.user.timers.backlog-flush = {
    Unit.Description = "Retry the backlog queue every 15 minutes";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "15min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
