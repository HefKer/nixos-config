{
  lib,
  coreutils,
  curl,
  findutils,
  gawk,
  gitMinimal,
  gnugrep,
  gnused,
  jq,
  callPackage,
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

  # Build output (target, node_modules, ...) over a size no file in it has changed for in `days`.
  staleBuild =
    {
      roots,
      days,
      minSizeMiB,
    }:
    writeShellApplication {
      name = "health-probe-stale-build";
      runtimeInputs = [
        coreutils
        findutils
        gawk
      ];
      text = ''
        cutoff=$(($(date +%s) - ${toString days} * 86400))
        while IFS= read -r root; do
          [ -d "$root" ] || continue
          find "$root" -name .git -prune -o -type d \( ${
            lib.concatMapStringsSep " -o " (n: "-name ${lib.escapeShellArg n}") [
              "target"
              "node_modules"
              ".venv"
              "venv"
              "build"
              "dist"
              ".direnv"
              ".next"
              ".gradle"
              ".turbo"
              "_build"
              "zig-out"
              ".zig-cache"
            ]
          } \) -prune -print0
        done <${writeText "stale-build-roots" (lib.concatLines roots)} |
          while IFS= read -r -d "" d; do
            newest=$(find "$d" -printf '%T@\n' | awk '$1 > m { m = $1 } END { printf "%d\n", m }')
            [ "$newest" -lt "$cutoff" ] || continue
            # du, not summed file sizes: cargo hardlinks its outputs.
            kib=$(du -sk "$d" | cut -f1)
            if [ "$kib" -ge ${toString (minSizeMiB * 1024)} ]; then
              echo "$d: $(numfmt --to=iec $((kib * 1024))), untouched since $(date -d "@$newest" +%F)"
            fi
          done | sort
      '';
    };

  # Repos with a remote holding uncommitted or unpushed work nobody has touched for `days`.
  unpushedWork =
    { roots, days }:
    writeShellApplication {
      name = "health-probe-unpushed-work";
      runtimeInputs = [
        coreutils
        findutils
        gitMinimal
        gnugrep
      ];
      text = ''
        # Never write the index: .git is synced, and a refresh here would be a change to sync.
        export GIT_OPTIONAL_LOCKS=0
        cutoff=$(($(date +%s) - ${toString days} * 86400))
        while IFS= read -r root; do
          [ -d "$root" ] || continue
          # Hidden directories (.archive, vendored clones) are parked on purpose.
          find "$root" -mindepth 1 \( -name node_modules -o -name target \) -prune -o \
            -name .git -printf '%h\0' -prune -o -name '.*' -prune
        done <${writeText "unpushed-work-roots" (lib.concatLines roots)} |
          while IFS= read -r -d "" r; do
            git -C "$r" rev-parse --git-dir >/dev/null 2>&1 || continue
            [ -n "$(git -C "$r" remote)" ] || continue
            what=()
            last=$(git -C "$r" log -1 --format=%ct 2>/dev/null || echo 0)
            dirty=$(git -C "$r" ls-files -z -m -o --exclude-standard | xargs -0 -r -I{} stat -c %Y "$r/{}" 2>/dev/null | sort -n | tail -n1 || true)
            if [ -n "$dirty" ] || [ -n "$(git -C "$r" ls-files -d)" ]; then
              what+=("uncommitted changes")
              if [ -n "$dirty" ] && [ "$dirty" -gt "$last" ]; then last=$dirty; fi
            fi
            ahead=$(git -C "$r" for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | grep -F '[ahead' | cut -d' ' -f1 | paste -sd, || true)
            if [ -n "$ahead" ]; then what+=("unpushed commits on $ahead"); fi
            if [ ''${#what[@]} -gt 0 ] && [ "$last" -lt "$cutoff" ]; then
              msg=$(printf '%s; ' "''${what[@]}")
              echo "$r: ''${msg%; }, idle since $(date -d "@$last" +%F)"
            fi
          done | sort
      '';
    };

  # Filesystems holding any of `paths` with less than `minPercent` free.
  diskFree =
    { paths, minPercent }:
    writeShellApplication {
      name = "health-probe-disk-free";
      runtimeInputs = [
        coreutils
        gawk
      ];
      text = ''
        df --output=pcent,target ${lib.escapeShellArgs paths} | tail -n +2 | sort -u -k2 |
          awk -v min=${toString minPercent} '{ used = $1 + 0; if (100 - used < min) print $2 ": under " min "% free" }'
      '';
    };

  # The running nixpkgs, dated at build time, against the age a flake update is due at.
  nixpkgsAge =
    { lastModified, maxAgeDays }:
    writeShellApplication {
      name = "health-probe-nixpkgs-age";
      runtimeInputs = [ coreutils ];
      text = ''
        if [ $(($(date +%s) - ${toString lastModified})) -gt $((${toString maxAgeDays} * 86400)) ]; then
          echo "nixpkgs is from $(date -d @${toString lastModified} +%F), over ${toString maxAgeDays} days old; update the flake"
        fi
      '';
    };

  rebootRequired = writeShellApplication {
    name = "health-probe-reboot-required";
    runtimeInputs = [ (callPackage ../reboot-required { }) ];
    text = ''
      changed=$(reboot-required)
      if [ -n "$changed" ]; then echo "$changed changed since boot; reboot to run it"; fi
    '';
  };

  # Reads what the system-level smart-status unit last wrote; drives need root to query.
  smart =
    file:
    writeShellApplication {
      name = "health-probe-smart";
      runtimeInputs = [ coreutils ];
      text = ''
        if [ -r ${file} ]; then cat ${file}; fi
      '';
    };

  # Peers unseen for `maxUnseenDays` and folder errors, through the REST API; silent when Syncthing is down.
  syncthingStatus =
    {
      guiAddress,
      peers,
      folders,
      maxUnseenDays,
    }:
    writeShellApplication {
      name = "health-probe-syncthing";
      runtimeInputs = [
        coreutils
        curl
        gnused
        jq
      ];
      text = ''
        key=
        for c in "''${XDG_STATE_HOME:-$HOME/.local/state}/syncthing/config.xml" \
          "''${XDG_CONFIG_HOME:-$HOME/.config}/syncthing/config.xml"; do
          if [ -r "$c" ]; then
            key=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' "$c")
            break
          fi
        done
        [ -n "$key" ] || exit 0
        api() { curl -fsS --max-time 5 -H "X-API-Key: $key" "http://${guiAddress}/rest/$1" 2>/dev/null; }
        conns=$(api system/connections) || exit 0
        stats=$(api stats/device) || exit 0

        cutoff=$(($(date +%s) - ${toString maxUnseenDays} * 86400))
        jq -r --argjson peers ${lib.escapeShellArg (builtins.toJSON peers)} --argjson conns "$conns" \
          'to_entries[] | select($peers[.key] and ($conns.connections[.key].connected | not))
            | "\($peers[.key])\t\(.value.lastSeen)"' <<<"$stats" |
          while IFS=$'\t' read -r name seen; do
            t=$(date -d "$seen" +%s)
            if [ "$t" -le 0 ]; then
              echo "peer $name never seen"
            elif [ "$t" -lt "$cutoff" ]; then
              echo "peer $name not seen since $(date -d "@$t" +%F)"
            fi
          done

        ${lib.concatStrings (
          lib.mapAttrsToList (id: name: ''
            api ${lib.escapeShellArg "db/status?folder=${id}"} |
              jq -r --arg n ${lib.escapeShellArg name} 'select(.state == "error") | "folder \($n): \(.error)"' || true
            api ${lib.escapeShellArg "folder/errors?folder=${id}"} |
              jq -r --arg n ${lib.escapeShellArg name} '.errors // [] | .[] | "folder \($n): \(.path): \(.error)"' || true
          '') folders
        )}
      '';
    };
}
