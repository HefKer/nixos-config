{ config, lib, ... }:
let
  cfg = config.custom.roles.workstation;
in
{
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./chromium.nix
    ./development
    ./display.nix
    ./fonts.nix
    ./input.nix
    ./networking.nix
    ./packages.nix
    ./printing.nix
    ./gaming
    ./local-ai
    ./virtualization
  ];

  options.custom.roles.workstation = with lib; {
    enable = mkEnableOption "the workstation role";
  };

  config.assertions =
    map
      (sub: {
        assertion = cfg.${sub}.enable -> cfg.enable;
        message = "custom.roles.workstation.${sub}.enable requires custom.roles.workstation.enable";
      })
      [
        "development"
        "gaming"
        "local-ai"
        "virtualization"
      ]
    ++ [
      {
        assertion = cfg.gaming.tablet.enable -> cfg.gaming.enable;
        message = "custom.roles.workstation.gaming.tablet.enable requires custom.roles.workstation.gaming.enable";
      }
    ];
}
