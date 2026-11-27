{
  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-uuid/BDED-32E0";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };

    "/" = {
      device = "/dev/disk/by-uuid/e1f9d61e-ed58-4b98-9aac-1ed166597a37";
      fsType = "ext4";
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/21b1029b-9139-4086-8d5a-1edbef14cb9a"; }
  ];
}
