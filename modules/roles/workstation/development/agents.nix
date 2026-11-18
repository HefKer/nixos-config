{ config, lib, ... }:
let
  cfg = config.custom.roles.workstation.development;
in
{
  config = lib.mkIf cfg.enable {
    # claude.fish and lowpri start their scopes here, so agent load yields to the desktop's app.slice.
    systemd.user.slices.agents = {
      description = "Coding agents and low-priority jobs";
      sliceConfig = {
        CPUWeight = 20;
        MemoryHigh = "60%";
        # oomd kills the scope (one claude session) that is thrashing, not the whole slice.
        ManagedOOMMemoryPressure = "kill";
      };
    };
  };
}
