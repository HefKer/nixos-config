{ config, lib, ... }:
{
  config = lib.mkIf (config.custom.platform == "laptop") {
    # DMS's bar battery widget and its low/critical alerts read the battery through UPower.
    services.upower.enable = true;
  };
}
