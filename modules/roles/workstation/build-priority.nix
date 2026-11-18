{ config, lib, ... }:
let
  cfg = config.custom.roles.workstation;
in
{
  config = lib.mkIf cfg.enable {
    nix = {
      daemonCPUSchedPolicy = "idle";
      daemonIOSchedClass = "idle";
    };

    # oomd only kills a descendant of the cgroup it watches, so the daemon needs a slice of its own.
    systemd.slices.nix-daemon.sliceConfig.ManagedOOMMemoryPressure = "kill";
    systemd.services.nix-daemon.serviceConfig = {
      Slice = "nix-daemon.slice";
      MemoryHigh = "60%";
    };
  };
}
