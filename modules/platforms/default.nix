{ lib, ... }:
{
  imports = [
    ./desktop
    ./laptop
  ];

  options.custom.platform = lib.mkOption {
    type = lib.types.enum [
      "desktop"
      "laptop"
    ];
    description = "The hardware class this host runs on; every host must pick exactly one.";
  };
}
