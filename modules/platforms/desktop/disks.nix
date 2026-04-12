{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.platforms.desktop.disks;
in
{
  options.custom.platforms.desktop.disks = with lib; {
    enable = mkEnableOption "Enable Desktop disk layout";
  };

  config = lib.mkIf cfg.enable {
    fileSystems = {
      "/boot" = {
        device = "/dev/disk/by-uuid/6BD9-EC59";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      "/" = {
        device = "/dev/disk/by-uuid/735b1e45-23f8-4f92-8cb7-f8f1b32d65f8";
        fsType = "ext4";
      };
    };

    swapDevices = [
      { device = "/dev/disk/by-uuid/dfdb6027-c9b0-43c9-aa2a-063274b49864"; }
    ];

  };
}
