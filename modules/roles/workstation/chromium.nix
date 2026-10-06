{ config, lib, ... }:
let
  cfg = config.custom.roles.workstation;
in
{
  config = lib.mkIf cfg.enable {
    # Writes to all chromium-based browsers
    programs.chromium = {
      enable = true;

      extensions = [
        "fcoeoabgfenejglbffodgkkbkcdhcgfn" # Claude for Chrome
      ];
    };
  };
}
