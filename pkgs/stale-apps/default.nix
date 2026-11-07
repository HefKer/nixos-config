{
  coreutils,
  gnugrep,
  nix,
  writeShellApplication,
}:
writeShellApplication {
  name = "stale-apps";
  runtimeInputs = [
    coreutils
    gnugrep
    nix
  ];
  text = ''
    # Prints, one per line, the packages your running processes use an older build of than system "$1" (default: the running one) ships.
    system=''${1:-/run/current-system}
    store='/nix/store/[a-z0-9]\{32\}-[^/[:space:]]*'

    declare -A live=() shipped=() stale=()
    while read -r p; do
      live[$p]=1
      name=''${p#/nix/store/*-}
      shipped[''${name%%-[0-9]*}]=1
    done < <(nix-store -qR "$system")

    for proc in /proc/[0-9]*; do
      [ -O "$proc" ] || continue
      exe=$(readlink "$proc/exe" 2>/dev/null) || continue
      while read -r p; do
        [ -n "$p" ] && [ -z "''${live[$p]:-}" ] || continue
        name=''${p#/nix/store/*-}
        pname=''${name%%-[0-9]*}
        # Only a package the system still ships under that name counts, so `nix shell` tools aren't flagged.
        [ -n "''${shipped[$pname]:-}" ] && stale[$pname]=1
      done < <({ echo "$exe"; tr '\0' '\n' <"$proc/cmdline" 2>/dev/null; } | grep -o "$store" || true)
    done

    if [ ''${#stale[@]} -gt 0 ]; then
      printf '%s\n' "''${!stale[@]}" | sort
    fi
  '';
}
