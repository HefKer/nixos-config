{ pkgs, ... }:
let
  rebootRequired = pkgs.callPackage ../../pkgs/reboot-required { };
in
{
  environment.systemPackages = [ rebootRequired ];

  system.activationScripts.rebootRequired = {
    supportsDryActivation = true;
    text = ''
      changed=$(${rebootRequired}/bin/reboot-required "$systemConfig" || true)
      if [ -n "$changed" ]; then
        echo "⚠  Reboot required: $changed changed since boot"
      fi
    '';
  };
}
