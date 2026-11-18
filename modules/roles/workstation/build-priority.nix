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

    # oomd only kills descendants of the cgroup it watches; builds share the daemon's cgroup, so a kill takes all of them (the socket restarts it).
    systemd.slices.nix-daemon.sliceConfig.ManagedOOMMemoryPressure = "kill";
    systemd.services.nix-daemon.serviceConfig = {
      Slice = "nix-daemon.slice";
      MemoryHigh = "60%";
    };
  };
}
