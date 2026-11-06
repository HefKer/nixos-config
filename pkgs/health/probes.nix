{
  lib,
  findutils,
  systemd,
  writeShellApplication,
  writeText,
  xmlstarlet,
}:
{
  # Takes home.file's targets; each must still be a link into a home-manager-files tree.
  linkDrift =
    targets:
    writeShellApplication {
      name = "health-probe-link-drift";
      text = ''
        while IFS= read -r t; do
          p=$HOME/$t
          if [ -L "$p" ]; then
            dest=$(readlink "$p")
            case $dest in /nix/store/*-home-manager-files/"$t") continue ;; esac
            echo "$p: symlink to $dest"
          elif [ -d "$p" ]; then
            echo "$p: directory"
          elif [ -e "$p" ]; then
            echo "$p: file"
          else
            echo "$p: missing"
          fi
        done <${writeText "home-file-targets" (lib.concatLines targets)}
      '';
    };

  # Reads folder paths from Syncthing's config.xml, never its API, so it works while Syncthing is stopped.
  syncConflict = writeShellApplication {
    name = "health-probe-sync-conflict";
    runtimeInputs = [
      findutils
      xmlstarlet
    ];
    text = ''
      config=
      for c in "''${XDG_STATE_HOME:-$HOME/.local/state}/syncthing/config.xml" \
        "''${XDG_CONFIG_HOME:-$HOME/.config}/syncthing/config.xml"; do
        if [ -f "$c" ]; then
          config=$c
          break
        fi
      done
      [ -n "$config" ] || exit 0

      # /configuration/folder skips <defaults><folder>, the template for new folders.
      xmlstarlet sel -t -m /configuration/folder -v @path -n "$config" | while IFS= read -r dir; do
        case $dir in
          "") continue ;;
          \~) dir=$HOME ;;
          \~/*) dir=$HOME/''${dir#\~/} ;;
        esac
        [ -d "$dir" ] || continue
        find "$dir" -name .stversions -prune -o -name '*.sync-conflict-*' -print || true
      done | sort -u
    '';
  };

  failedUnits =
    ignoreUnits:
    writeShellApplication {
      name = "health-probe-failed-units";
      runtimeInputs = [ systemd ];
      text = ''
        report() {
          local scope=$1 unit
          shift
          systemctl "$@" list-units --state=failed --plain --no-legend --no-pager |
            while read -r unit _; do
              if ! grep -qxF -- "$unit" ${writeText "health-ignore-units" (lib.concatLines ignoreUnits)}; then
                echo "$scope unit $unit failed"
              fi
            done
        }
        report user --user
        report system
      '';
    };
}
