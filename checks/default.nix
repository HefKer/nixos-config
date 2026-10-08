{
  pkgs,
  consts,
  nixosConfigurations,
  src,
}:
let
  inherit (pkgs) lib;

  # The link set's targets per host, exactly; extend this as packages move off stow.
  expectedLinks = {
    desktop = [ ".config/mpv" ];
    lenovo = [ ".config/mpv" ];
  };

  # Shell lines checking one host: its targets, then where every built source links to.
  linkChecks =
    host: targets:
    let
      inherit (nixosConfigurations.${host}) config;
      root = config.home-manager.extraSpecialArgs.dotfilesRoot;
      hm = config.home-manager.users.${consts.username};
      inherit (hm.custom.home.dotfiles) links;
      words = xs: lib.escapeShellArg (lib.concatStringsSep " " (lib.sort lib.lessThan xs));
    in
    ''
      targets ${host} ${words targets} ${words (builtins.attrNames links)}
      root ${host} ${lib.escapeShellArg root}
    ''
    + lib.concatMapStrings (t: ''
      link ${host} ${lib.escapeShellArg t} ${hm.home.file.${t}.source} ${lib.escapeShellArg "${root}/${links.${t}}"}
    '') (builtins.attrNames links);

  # Fails, printing the matches, when `search` (run from the repo root) prints anything.
  noMatches =
    name: message: search:
    pkgs.runCommandLocal "check-${name}" { } ''
      cd ${src}
      hits=$(${search} || true)
      if [ -n "$hits" ]; then
        echo "${message}"
        echo "$hits"
        exit 1
      fi
      touch $out
    '';
in
{
  format = pkgs.runCommandLocal "check-format" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
    cd ${src}
    find . -name '*.nix' -exec nixfmt --check {} +
    touch $out
  '';

  custom-set-only-in-hosts =
    noMatches "custom-set-only-in-hosts" "custom.* is switched on only in hosts/*/default.nix:"
      "grep -rnE '^\\s*custom(\\.[A-Za-z.-]+)?\\s*=' --include='*.nix' . | grep -vE '^\\./hosts/[^/]+/default\\.nix:'";

  hosts-are-plain =
    noMatches "hosts-are-plain"
      "host files other than default.nix are plain config, with no options or mkIf:"
      "grep -rnE 'mkIf|mkOption|mkEnableOption' --include='*.nix' hosts | grep -v '/default\\.nix:'";

  # The cli.nix exemption goes away once git config leaves home-manager.
  no-hardcoded-consts =
    noMatches "no-hardcoded-consts" "use consts (lib/consts.nix) instead of these literals:"
      "grep -rnF -e '\"${consts.username}\"' -e '${consts.home}' -e '${consts.timeZone}' -e '${consts.defaultLocale}' --include='*.nix' . | grep -vE '^\\./lib/consts\\.nix:|^\\./homes/modules/cli\\.nix:[0-9]+: *name = \"${consts.username}\";'";

  # The flake-trap guard (ADR-0001); readlink never follows a link, so the root needn't exist.
  dotfiles = pkgs.runCommandLocal "check-dotfiles" { } ''
    fail=0
    targets() {
      [ "$2" = "$3" ] || { echo "$1: link targets are '$3', expected '$2'"; fail=1; }
    }
    root() {
      case "$2" in /nix/store/*) echo "$1: dotfiles root $2 is in the store"; fail=1 ;; esac
    }
    link() {
      if ! actual=$(readlink "$3"); then
        echo "$1: ~/$2 is not an out-of-store symlink: $3"
        fail=1
      elif [ "$actual" != "$4" ]; then
        echo "$1: ~/$2 links to $actual, expected $4"
        fail=1
      fi
    }
    ${lib.concatStrings (lib.mapAttrsToList linkChecks expectedLinks)}
    if [ "$fail" != 0 ]; then exit 1; fi
    touch $out
  '';
}
