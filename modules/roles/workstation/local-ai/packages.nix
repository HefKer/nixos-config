{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.roles.workstation.local-ai;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      lmstudio
    ];
  };
}
