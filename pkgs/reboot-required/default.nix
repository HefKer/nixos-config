{ coreutils, writeShellApplication }:
writeShellApplication {
  name = "reboot-required";
  runtimeInputs = [ coreutils ];
  text = ''
    # Prints the boot-time parts of system "$1" (default: the running one) that differ from the booted system.
    new=''${1:-/run/current-system}
    [ -e /run/booted-system ] || exit 0
    changed=()
    for p in kernel initrd kernel-modules; do
      if [ "$(readlink -f "/run/booted-system/$p")" != "$(readlink -f "$new/$p")" ]; then
        changed+=("$p")
      fi
    done
    if [ ''${#changed[@]} -gt 0 ]; then
      echo "''${changed[*]}"
    fi
  '';
}
