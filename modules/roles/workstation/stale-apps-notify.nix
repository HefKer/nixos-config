{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.roles.workstation;
  staleApps = pkgs.callPackage ../../../pkgs/stale-apps { nix = config.nix.package; };
  notify = pkgs.writeShellApplication {
    name = "stale-apps-notify";
    runtimeInputs = [
      pkgs.libnotify
      staleApps
    ];
    text = ''
      stale=$(stale-apps)
      if [ -n "$stale" ]; then
        notify-send -a NixOS "Restart to update" "''${stale//$'\n'/, }"
      fi
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ staleApps ];

    systemd.user = {
      services.stale-apps-notify = {
        description = "Notify when running apps are older builds than the current system ships";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe notify;
        };
      };
      paths.stale-apps-notify = {
        wantedBy = [ "graphical-session.target" ];
        pathConfig.PathChanged = "/run/current-system";
      };
    };
  };
}
