{ consts, ... }:
let
  inherit (consts)
    timeZone
    defaultLocale
    username
    home
    ;
in
{
  time.timeZone = timeZone;
  i18n.defaultLocale = defaultLocale;

  i18n.extraLocaleSettings = {
    LC_ADDRESS = defaultLocale;
    LC_IDENTIFICATION = defaultLocale;
    LC_MEASUREMENT = defaultLocale;
    LC_MONETARY = defaultLocale;
    LC_NAME = defaultLocale;
    LC_NUMERIC = defaultLocale;
    LC_PAPER = defaultLocale;
    LC_TELEPHONE = defaultLocale;
    LC_TIME = defaultLocale;
  };

  users = {
    users.${username} = {
      isNormalUser = true;
      extraGroups = [ 
        "networkmanager" 
        "wheel"
        "dialout" # Rquired by CharaChorder
        # use "tty" if "dialout" stops working
    ];
    };
  };
}

