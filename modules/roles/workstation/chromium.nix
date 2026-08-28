{ config, lib, ... }:
let
  cfg = config.custom.roles.workstation.chromium;
in
{
  options.custom.roles.workstation.chromium = with lib; {
    enable = mkEnableOption "Chromium-based browser policies (Chromium, Chrome, Brave)";
  };

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
