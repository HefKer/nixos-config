{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.roles.workstation;
  micMuteWarn = pkgs.callPackage ../../../pkgs/mic-mute-warn {
    dms = config.programs.dux-shell.package;
  };
in
{
  config = lib.mkIf cfg.enable {
    systemd.user.services.mic-mute-warn = {
      description = "Toast when an app starts recording from a muted mic";
      wantedBy = [ "graphical-session.target" ];
      partOf = [
        "graphical-session.target"
        "pipewire.service"
      ];
      after = [
        "graphical-session.target"
        "pipewire.service"
      ];
      serviceConfig = {
        ExecStart = lib.getExe micMuteWarn;
        Restart = "always";
        RestartSec = 2;
      };
    };
  };
}
