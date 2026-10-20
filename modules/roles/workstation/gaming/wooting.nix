{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.roles.workstation.gaming.wooting;
in
{
  options.custom.roles.workstation.gaming.wooting = with lib; {
    enable = mkEnableOption "Wootility and udev access for Wooting keyboards";
  };

  config = lib.mkIf cfg.enable {
    hardware.wooting.enable = true;
  };
}
