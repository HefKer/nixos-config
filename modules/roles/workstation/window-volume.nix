{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.roles.workstation;
  windowVolume = pkgs.callPackage ../../../pkgs/window-volume {
    niri = config.programs.niri.package;
  };
in
{
  config = lib.mkIf cfg.enable {
    # For niri's per-window volume binds, on kanata's Fn2 a/s/d.
    environment.systemPackages = [ windowVolume ];

    systemd.user.services.window-volume-watch = {
      description = "Give new audio streams their window's held volume";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [
        "graphical-session.target"
        "pipewire.service"
      ];
      serviceConfig = {
        ExecStart = "${lib.getExe windowVolume} watch";
        Restart = "always";
        RestartSec = 2;
      };
    };
  };
}
