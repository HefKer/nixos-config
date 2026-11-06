{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.health;
  probes = pkgs.callPackage ../../pkgs/health/probes.nix { };

  # A writeShellApplication runs as its mainProgram; a plain script file runs as itself.
  exeOf = script: if script ? meta.mainProgram then lib.getExe script else "${script}";

  health = pkgs.callPackage ../../pkgs/health {
    probes = lib.mapAttrs (_: probe: exeOf probe.script) cfg.probes;
  };

  # A recursive target is a real directory of per-file links, so only the others are links themselves.
  linkTargets = map (f: f.target) (
    lib.filter (f: f.enable && !f.recursive) (builtins.attrValues config.home.file)
  );
in
{
  options.custom.health = with lib; {
    probes = mkOption {
      type = types.attrsOf (
        types.submodule {
          options.script = mkOption {
            type = types.package;
            description = "Executable that prints one line per finding to stdout, and nothing when all is well.";
          };
        }
      );
      default = { };
      description = "Probes `health` runs; any home module may add one next to the thing it checks.";
    };

    ignoreUnits = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "foo.service" ];
      description = "Full unit names, user or system, the failed-units probe skips.";
    };
  };

  config.assertions = lib.mapAttrsToList (name: _: {
    assertion = builtins.match "[A-Za-z0-9_-]+" name != null;
    message = "custom.health.probes.${name}: the name prefixes each finding line, so it takes no spaces or symbols";
  }) cfg.probes;

  # Probes are contributions, not switches, so any module sets them; the hosts-only rule is for switches.
  config.custom.health.probes = {
    link-drift.script = probes.linkDrift linkTargets;
    sync-conflict.script = probes.syncConflict;
    failed-units.script = probes.failedUnits cfg.ignoreUnits;
  };

  config.home.packages = [ health ];

  config.systemd.user.services.health = {
    Unit.Description = "Run the health probes and notify on new findings";
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe health} --notify";
    };
  };

  config.systemd.user.timers.health = {
    Unit.Description = "Run the health probes daily and soon after login";
    Timer = {
      OnCalendar = "daily";
      OnStartupSec = "5min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
