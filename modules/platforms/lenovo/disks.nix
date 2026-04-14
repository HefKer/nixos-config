{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.platforms.lenovo.disks;
in
{
  options.custom.platforms.lenovo.disks = with lib; {
    enable = mkEnableOption "Enable lenovo disk layout";
  };

  config = lib.mkIf cfg.enable {
    fileSystems = {
      "/boot" = {
        device = "/dev/disk/by-uuid/D033-3864";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      "/" = {
        device = "/dev/disk/by-uuid/d3746905-9ecd-4b67-a16c-c90c131b9921";
        fsType = "ext4";
      };
    };

    swapDevices = [
      { device = "/dev/disk/by-uuid/3e02a0c7-4df4-4dec-8954-351fcfc0b5a1"; }
    ];

  };
}
