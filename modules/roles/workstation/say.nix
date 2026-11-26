{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.roles.workstation;
  say = pkgs.callPackage ../../../pkgs/say { };
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ say ];

    systemd.user.services.say = {
      description = "Local text-to-speech daemon behind say";
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
        ExecStart = lib.escapeShellArgs [
          (lib.getExe say)
          "--daemon"
          "--dms"
          (lib.getExe config.programs.dux-shell.package)
          # Written by game-focus-watcher while a game has focus; %t is $XDG_RUNTIME_DIR.
          "--game-file"
          "%t/game-focus"
        ];
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
