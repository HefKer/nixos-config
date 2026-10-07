{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.roles.workstation;
in
{
  config = lib.mkIf cfg.enable {
    fonts = {
      packages = with pkgs; [
        maple-mono.truetype
        liberation_ttf
        noto-fonts
        corefonts # Arial, Times New Roman, etc.
        vista-fonts # Calibri, Cambria, etc.
        google-fonts # Good general coverage
        noto-fonts-color-emoji
        nerd-fonts.jetbrains-mono
      ];

      fontconfig.defaultFonts = {
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
        monospace = [ "JetBrainsMono Nerd Font" ];
      };
    };
  };
}
