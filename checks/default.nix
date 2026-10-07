{
  pkgs,
  consts,
  src,
}:
let
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
}
