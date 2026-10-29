{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.roles.workstation.gaming.wooting;
in
{
  options.custom.roles.workstation.gaming.wooting = with lib; {
    enable = mkEnableOption "Wootility and udev access for Wooting keyboards";
  };

  config = lib.mkIf cfg.enable {
    hardware.wooting.enable = true;

    nixpkgs.overlays = [
      # On native Wayland the hidden window never fires ready-to-show, so it only appears on a second launch
      (final: prev: {
        wootility = final.symlinkJoin {
          inherit (prev.wootility) name meta;
          paths = [ prev.wootility ];
          nativeBuildInputs = [ final.makeWrapper ];
          postBuild = ''
            wrapProgram "$out/bin/wootility" --add-flags --ozone-platform=x11
          '';
        };
      })
    ];
  };
}
