{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.roles.workstation;
  real = config.system.build.nixos-rebuild;
  wrapper = pkgs.writeShellApplication {
    name = "nixos-rebuild";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.util-linux
    ];
    text = ''
      status=0
      ${lib.getExe real} "$@" || status=$?

      action=""
      for a in "$@"; do
        case $a in
          switch | boot | test | build | dry-build | dry-activate | build-vm | build-vm-with-bootloader | build-image)
            action=$a
            break
            ;;
        esac
      done
      [ -n "$action" ] || exit "$status"

      took="$((SECONDS / 60))m $((SECONDS % 60))s"
      if [ "$status" = 0 ]; then
        args=(-a NixOS "Rebuild finished" "$action · $took")
      else
        args=(-a NixOS -u critical "Rebuild failed" "$action · $took · exit $status")
      fi

      # Under sudo the session bus belongs to the invoking user, not root.
      if [ "$(id -u)" != 0 ]; then
        notify-send "''${args[@]}" || true
      elif [ -n "''${SUDO_UID:-}" ]; then
        runuser -u "$SUDO_USER" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$SUDO_UID/bus" \
          notify-send "''${args[@]}" || true
      fi
      exit "$status"
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ (lib.hiPrio wrapper) ];
  };
}
