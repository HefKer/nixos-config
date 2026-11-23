{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  steam-update = pkgs.callPackage ../../pkgs/steam-update {
    steam = osConfig.programs.steam.package;
    niri = osConfig.programs.niri.package;
  };
in
{
  systemd.user.services.steam-update = {
    Unit = {
      Description = "Install Steam's client update in the background, then quit it";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe steam-update;
      TimeoutStartSec = "15min";
    };
  };

  systemd.user.timers.steam-update = {
    Unit = {
      Description = "Update Steam 10 minutes into each session and every 12 hours after";
      PartOf = [ "graphical-session.target" ];
    };
    Timer = {
      OnActiveSec = "10min";
      OnUnitActiveSec = "12h";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
