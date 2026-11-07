{
  lib,
  coreutils,
  findutils,
  gnugrep,
  systemd,
  writeShellApplication,
  writeText,
}:
{
  # Takes home.file's targets; each must still be a link into a home-manager-files tree.
  linkDrift =
    targets:
    writeShellApplication {
      name = "health-probe-link-drift";
      runtimeInputs = [ coreutils ];
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

  # Takes the synced folders' absolute paths; they come from the flake's folder table, so Syncthing needn't be running.
  syncConflict =
    dirs:
    writeShellApplication {
      name = "health-probe-sync-conflict";
      runtimeInputs = [
        coreutils
        findutils
      ];
      text = ''
        while IFS= read -r dir; do
          [ -d "$dir" ] || continue
          find "$dir" -name .stversions -prune -o -name '*.sync-conflict-*' -print || true
        done <${writeText "sync-folders" (lib.concatLines dirs)} | sort -u
      '';
    };

  failedUnits =
    ignoreUnits:
    writeShellApplication {
      name = "health-probe-failed-units";
      runtimeInputs = [
        gnugrep
        systemd
      ];
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
