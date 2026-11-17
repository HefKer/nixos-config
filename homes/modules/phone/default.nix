{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.custom.home.phone;
  phone = pkgs.callPackage ../../../pkgs/phone { tailscale = osConfig.services.tailscale.package; };
  automations = pkgs.callPackage ./automations.nix { inherit phone; };
  # This host's tailnet address, kept where Syncthing's peers already dial it.
  tailnetAddress = (import ../syncthing/table.nix).peers.${osConfig.networking.hostName}.address;
in
{
  options.custom.home.phone = {
    enable = lib.mkEnableOption "the phone automations this host runs";
    contextPort = lib.mkOption {
      type = lib.types.port;
      default = 8377;
      description = "TCP port, on this host's tailnet address, where the phone posts its context.";
    };
  };

  config = lib.mkIf cfg.enable {
    custom.health.probes.phone-adb.script = automations.adbProbe;

    systemd.user.services.phone-settings-changes = {
      Unit.Description = "Record the settings the phone's Settings app changed";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe automations.settingsChanges;
      };
    };

    systemd.user.sockets.phone-context = {
      Unit.Description = "Hear the phone's context on the tailnet address";
      Socket = {
        ListenStream = "${tailnetAddress}:${toString cfg.contextPort}";
        # The address appears only once tailscaled is up, which can be after this socket starts.
        FreeBind = true;
        Accept = true;
        MaxConnections = 4;
      };
      Install.WantedBy = [ "sockets.target" ];
    };

    systemd.user.services."phone-context@" = {
      Unit.Description = "Record one context post from the phone";
      Service = {
        ExecStart = "${phone}/bin/phone-context receive";
        StandardInput = "socket";
        StandardOutput = "socket";
        StandardError = "journal";
        RuntimeMaxSec = 30;
      };
    };

    systemd.user.timers.phone-settings-changes = {
      Unit.Description = "Record the phone's settings changes every 30 minutes";
      Timer.OnCalendar = "*:0/30";
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
