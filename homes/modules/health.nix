{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.custom.health;
  home = config.home.homeDirectory;
  # Options exist on every host so any module can add a probe; only workstations run them.
  enabled = osConfig.custom.roles.workstation.enable or false;
  builtinProbes = pkgs.callPackage ../../pkgs/health/probes.nix { };

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

    staleBuild = {
      roots = mkOption {
        type = types.listOf types.str;
        default = [ "${home}/dev" ];
        description = "Trees searched for build output (target, node_modules, .venv, ...).";
      };
      days = mkOption {
        type = types.ints.positive;
        default = 30;
        description = "Days with no file in the build output changed before it counts as stale.";
      };
      minSizeMiB = mkOption {
        type = types.ints.positive;
        default = 500;
        description = "Build output smaller than this is never reported.";
      };
    };

    unpushedWork = {
      roots = mkOption {
        type = types.listOf types.str;
        default = [ "${home}/dev" ];
        description = "Trees searched for repos; hidden directories and repos without a remote are skipped.";
      };
      days = mkOption {
        type = types.ints.positive;
        default = 30;
        description = "Days since the last commit or edit before uncommitted or unpushed work is reported.";
      };
    };

    diskFree = {
      paths = mkOption {
        type = types.listOf types.str;
        default = [
          "/"
          home
        ];
        description = "Paths whose filesystems are checked; one sharing a filesystem is reported once.";
      };
      minPercent = mkOption {
        type = types.ints.between 1 99;
        default = 10;
        description = "Free space below this percentage is a finding.";
      };
    };

    nixpkgsMaxAgeDays = mkOption {
      type = types.ints.positive;
      default = 30;
      description = "Age of the running nixpkgs, by its commit date, past which a flake update is due.";
    };

    ignoreUnits = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "foo.service" ];
      description = "Full unit names, user or system, the failed-units probe skips.";
    };
  };

  config.assertions = lib.optionals enabled (
    lib.mapAttrsToList (name: _: {
      assertion = builtins.match "[A-Za-z0-9_-]+" name != null;
      message = "custom.health.probes.${name}: the name prefixes each finding line, so it takes no spaces or symbols";
    }) cfg.probes
  );

  # Probes are contributions, not switches, so any module sets them; the hosts-only rule is for switches.
  config.custom.health.probes = lib.mkIf enabled {
    link-drift.script = builtinProbes.linkDrift linkTargets;
    failed-units.script = builtinProbes.failedUnits cfg.ignoreUnits;
    stale-build.script = builtinProbes.staleBuild cfg.staleBuild;
    unpushed-work.script = builtinProbes.unpushedWork cfg.unpushedWork;
    disk-free.script = builtinProbes.diskFree cfg.diskFree;
    nixpkgs-age.script = builtinProbes.nixpkgsAge {
      inherit (inputs.nixpkgs) lastModified;
      maxAgeDays = cfg.nixpkgsMaxAgeDays;
    };
    reboot-required.script = builtinProbes.rebootRequired;
    smart.script = builtinProbes.smart "/var/lib/smart-status/findings";
  };

  config.home.packages = lib.mkIf enabled [ health ];

  config.systemd.user.services.health = lib.mkIf enabled {
    Unit = {
      Description = "Run the health probes and notify on new findings";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe health} --notify";
    };
  };

  # current-home is the last thing a home-manager switch writes, after links and units are in place.
  config.systemd.user.paths.health = lib.mkIf enabled {
    Unit.Description = "Run the health probes after each switch";
    Path.PathChanged = "${config.xdg.stateHome}/home-manager/gcroots/current-home";
    Install.WantedBy = [ "default.target" ];
  };

  config.systemd.user.timers.health = lib.mkIf enabled {
    Unit.Description = "Run the health probes daily and soon after login";
    Timer = {
      OnCalendar = "daily";
      OnStartupSec = "5min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
