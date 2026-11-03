{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.roles.workstation;
  rebootRequired = pkgs.callPackage ../../../pkgs/reboot-required { };
  notify = pkgs.writeShellApplication {
    name = "reboot-required-notify";
    runtimeInputs = [
      pkgs.libnotify
      rebootRequired
    ];
    text = ''
      changed=$(reboot-required)
      if [ -n "$changed" ]; then
        notify-send -a NixOS -u critical "Reboot required" "$changed changed since boot"
      fi
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    systemd.user = {
      services.reboot-required-notify = {
        description = "Notify when the running system needs a reboot to take full effect";
        wantedBy = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe notify;
        };
      };
      paths.reboot-required-notify = {
        wantedBy = [ "graphical-session.target" ];
        pathConfig.PathChanged = "/run/current-system";
      };
    };
  };
}
