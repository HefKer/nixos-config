{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.custom.home.phone;
  vault = "${config.home.homeDirectory}/${(import ../syncthing/table.nix).folders.polaris.path}";
  automations = pkgs.callPackage ./automations.nix {
    phone = pkgs.callPackage ../../../pkgs/phone { tailscale = osConfig.services.tailscale.package; };
  };
in
{
  options.custom.home.phone.enable = lib.mkEnableOption "the phone automations this host runs";

  config = lib.mkIf cfg.enable {
    custom.health.probes.phone-adb.script = automations.adbProbe;

    # The phone's Termux can only read what lands under /sdcard, and the vault is the folder already synced there.
    home.activation.phoneTermuxScripts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe automations.termuxDeliver} ${../../../phone/termux} ${lib.escapeShellArg "${vault}/.polaris/termux"}
    '';

    systemd.user.services.phone-settings-changes = {
      Unit.Description = "Record the settings the phone's Settings app changed";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe automations.settingsChanges;
      };
    };

    systemd.user.timers.phone-settings-changes = {
      Unit.Description = "Record the phone's settings changes every 30 minutes";
      Timer.OnCalendar = "*:0/30";
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
