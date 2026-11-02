{
  pkgs,
  consts,
  nixosConfigurations,
  src,
}:
let
  inherit (pkgs) lib;

  # Each host's exact link set, target in $HOME -> source under the root; a swapped host variant fails here.
  expectedLinks = {
    desktop = {
      ".config/niri-host.kdl" = "niri/host/desktop.kdl";
      ".config/DankMaterialShell" = "DankMaterialShell/.config/DankMaterialShell";
      ".config/fastfetch" = "fastfetch/.config/fastfetch";
      ".config/fish" = "fish/.config/fish";
      ".config/fuzzel" = "fuzzel/.config/fuzzel";
      ".config/git/config" = "git/.config/git/config";
      ".config/git/ignore" = "git/.config/git/ignore";
      ".config/herdr/config.toml" = "herdr/.config/herdr/config.toml";
      ".config/hunk/config.toml" = "hunk/.config/hunk/config.toml";
      ".config/mimeapps.list" = "xdg/.config/mimeapps.list";
      ".config/mpv" = "mpv/.config/mpv";
      ".config/niri" = "niri/.config/niri";
      ".config/nvim" = "nvim/.config/nvim";
      ".config/qutebrowser" = "qutebrowser/.config/qutebrowser";
      ".config/starship.toml" = "starship/.config/starship.toml";
      ".config/wezterm" = "wezterm/.config/wezterm";
      ".config/xdg-desktop-portal-termfilechooser" =
        "xdg-desktop-portal-termfilechooser/.config/xdg-desktop-portal-termfilechooser";
      ".local/bin/qute-sandbox" = "scripts/qute-sandbox";
      ".local/bin/session-find" = "scripts/session-find";
      ".local/share/qutebrowser/userscripts" = "qutebrowser/.local/share/qutebrowser/userscripts";
    };
    lenovo = {
      ".config/niri-host.kdl" = "niri/host/lenovo.kdl";
      ".config/DankMaterialShell" = "DankMaterialShell/.config/DankMaterialShell";
      ".config/fastfetch" = "fastfetch/.config/fastfetch";
      ".config/fish" = "fish/.config/fish";
      ".config/fuzzel" = "fuzzel/.config/fuzzel";
      ".config/git/config" = "git/.config/git/config";
      ".config/git/ignore" = "git/.config/git/ignore";
      ".config/herdr/config.toml" = "herdr/.config/herdr/config.toml";
      ".config/hunk/config.toml" = "hunk/.config/hunk/config.toml";
      ".config/mimeapps.list" = "xdg/.config/mimeapps.list";
      ".config/mpv" = "mpv/.config/mpv";
      ".config/niri" = "niri/.config/niri";
      ".config/nvim" = "nvim/.config/nvim";
      ".config/qutebrowser" = "qutebrowser/.config/qutebrowser";
      ".config/starship.toml" = "starship/.config/starship.toml";
      ".config/wezterm" = "wezterm/.config/wezterm";
      ".config/xdg-desktop-portal-termfilechooser" =
        "xdg-desktop-portal-termfilechooser/.config/xdg-desktop-portal-termfilechooser";
      ".local/bin/qute-sandbox" = "scripts/qute-sandbox";
      ".local/bin/session-find" = "scripts/session-find";
      ".local/share/qutebrowser/userscripts" = "qutebrowser/.local/share/qutebrowser/userscripts";
    };
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

  no-hardcoded-consts =
    noMatches "no-hardcoded-consts" "use consts (lib/consts.nix) instead of these literals:"
      "grep -rnF -e '\"${consts.username}\"' -e '${consts.home}' -e '${consts.timeZone}' -e '${consts.defaultLocale}' --include='*.nix' . | grep -v '^\\./lib/consts\\.nix:'";

  one-line-comments =
    noMatches "one-line-comments"
      "code comments are one line (CODING_STANDARDS.md); these continue one:"
      "find . -name '*.nix' -exec awk 'FNR==1{p=0} /^[[:space:]]*#/{if(p)print FILENAME\":\"FNR\": \"$0; p=1; next} {p=0}' {} +";

  # filestatus trusts the sops metadata, so values are inspected too; only key paths are printed, never values.
  secrets-encrypted =
    pkgs.runCommandLocal "check-secrets-encrypted"
      {
        nativeBuildInputs = [
          pkgs.sops
          pkgs.yq-go
        ];
      }
      ''
        cd ${src}
        fail=0
        while IFS= read -r f; do
          if ! sops filestatus "$f" 2>/dev/null | grep -q '"encrypted":true'; then
            echo "$f: not sops-encrypted"
            fail=1
            continue
          fi
          if ! plain=$(yq 'del(.sops) | .. | select(tag != "!!map" and tag != "!!seq") | select(tag != "!!str" or (test("^ENC\\[AES256_GCM,") | not)) | path | join(".")' "$f" 2>/dev/null); then
            echo "$f: not readable as yaml"
            fail=1
          elif [ -n "$plain" ]; then
            echo "$f: plaintext values under:"
            echo "$plain"
            fail=1
          fi
        done < <(find secrets ! -type d)
        if [ "$fail" != 0 ]; then exit 1; fi
        touch $out
      '';

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
