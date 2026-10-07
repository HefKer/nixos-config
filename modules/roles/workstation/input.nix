{
  config,
  lib,
  consts,
  ...
}:
let
  cfg = config.custom.roles.workstation;
in
{
  config = lib.mkIf cfg.enable {
    services.xserver.xkb = {
      layout = "us";
      variant = ""; # Selects a sub-variant of the layout. "" = default. Other options (for "us"): "dvorak", "colemak", "altgr-intl", "intl", "mac", "workman"
    };

    users.users.${consts.username}.extraGroups = [
      "dialout" # Required by CharaChorder
      # use "tty" if "dialout" stops working
    ];
  };
}
