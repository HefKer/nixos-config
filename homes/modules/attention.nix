{ lib, pkgs, ... }:
let
  attention = pkgs.callPackage ../../pkgs/attention { };
in
{
  home.packages = [ attention ];

  systemd.user.services.attention-watch = {
    Unit = {
      Description = "Keep the attention queue's agent marks current";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe attention} watch";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Each run also moves a marked tab's position along when a tab before it closes, so it runs often.
  systemd.user.services.attention-stale = {
    Unit.Description = "Mark stale herdr tabs, and close those marked a day";
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe attention} stale";
    };
  };
  systemd.user.timers.attention-stale = {
    Unit = {
      Description = "Sweep herdr for stale tabs every minute";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Timer.OnCalendar = "minutely";
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
