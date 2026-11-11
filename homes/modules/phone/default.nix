{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.custom.home.phone;
  automations = pkgs.callPackage ./automations.nix {
    phone = pkgs.callPackage ../../../pkgs/phone { tailscale = osConfig.services.tailscale.package; };
  };
in
{
  options.custom.home.phone.enable = lib.mkEnableOption "the phone automations this host runs";

  config = lib.mkIf cfg.enable {
    custom.health.probes.phone-adb.script = automations.adbProbe 24;

    systemd.user.services.phone-settings-log = {
      Unit.Description = "Log the settings the phone's Settings app changed";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe automations.settingsLog;
      };
    };

    systemd.user.timers.phone-settings-log = {
      Unit.Description = "Log the phone's settings changes every 30 minutes";
      Timer.OnCalendar = "*:0/30";
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
