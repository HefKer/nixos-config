{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.roles.workstation;
  windowVolume = pkgs.callPackage ../../../pkgs/window-volume {
    niri = config.programs.niri.package;
  };
in
{
  config = lib.mkIf cfg.enable {
    # For niri's per-window volume binds, on kanata's Fn2 a/s/d.
    environment.systemPackages = [ windowVolume ];

  };
}
