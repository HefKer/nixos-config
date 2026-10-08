{
  pkgs,
  consts,
  nixosConfigurations,
  src,
}:
let
  inherit (pkgs) lib;

  # Each host's link set, exactly: target in $HOME -> source under the dotfiles root.
  expectedLinks = {
    desktop.".config/mpv" = "mpv/.config/mpv";
    lenovo.".config/mpv" = "mpv/.config/mpv";
  };

  # Shell lines checking one host, built from the home.file set home-manager actually produces.
  linkChecks =
    host: expected:
    let
      inherit (nixosConfigurations.${host}) config;
      root = lib.escapeShellArg config.home-manager.extraSpecialArgs.dotfilesRoot;
      files = lib.filter (f: f.enable) (
        builtins.attrValues config.home-manager.users.${consts.username}.home.file
      );
      pairs = lib.mapAttrsToList (t: src: "${t}=${src}") expected;
    in
    ''
      produced=""
      root ${host} ${root}
    ''
    + lib.concatMapStrings (f: ''
      entry ${root} ${lib.escapeShellArg f.target} ${f.source}
    '') files
    + ''
      compare ${host} ${root} ${lib.escapeShellArg (lib.concatStringsSep " " (lib.sort lib.lessThan pairs))}
    '';

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
    root() {
      case "$2" in /nix/store/*) echo "$1: dotfiles root $2 is in the store"; fail=1 ;; esac
    }
    # Records target=source for every built source that is an out-of-store symlink into the root.
    entry() {
      if actual=$(readlink "$3") && [ "''${actual#"$1"/}" != "$actual" ]; then
        produced="$produced $2=''${actual#"$1"/}"
      fi
    }
    compare() {
      got=$(printf '%s\n' $produced | sort | xargs)
      if [ "$got" != "$3" ]; then
        echo "$1: out-of-store links into $2 are '$got', expected '$3'"
        fail=1
      fi
    }
    ${lib.concatStrings (lib.mapAttrsToList linkChecks expectedLinks)}
    if [ "$fail" != 0 ]; then exit 1; fi
    touch $out
  '';
}
