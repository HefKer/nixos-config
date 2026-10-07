{ config, lib, ... }:
{
  config = lib.mkIf (config.custom.platform == "laptop") {
    services.libinput.enable = true;
  };
}
