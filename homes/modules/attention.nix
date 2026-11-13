{ lib, pkgs, ... }:
let
  attention = pkgs.callPackage ../../pkgs/attention { };
in
{
  home.packages = [ attention ];

  systemd.user.services.attention-watch = {
    Unit = {
      Description = "Keep the attention queue's agent marks current";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe attention} watch";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
