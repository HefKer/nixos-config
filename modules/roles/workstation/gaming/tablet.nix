{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.roles.workstation.gaming.tablet;
in
{
  options.custom.roles.workstation.gaming.tablet = with lib; {
    enable = mkEnableOption "Enable OpenTabletDriver (osu! tablet input)";
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "uinput" ]; # Required by OpenTabletDriver

    hardware = {
      opentabletdriver.enable = true;
      uinput.enable = true;
    };
  };
}
