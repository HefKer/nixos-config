{
  lib,
  writeShellApplication,
  writeText,
  coreutils,
  diffutils,
  findutils,
  gitMinimal,
  gnugrep,
  gnused,
  # Absolute paths of every synced folder.
  folders,
  # The folders where Syncthing keeps no conflict copies (maxConflicts = 0), so any left are stale.
  appStateFolders ? [ ],
  # Short device ID (first 7 characters) -> peer name.
  peers ? { },
}:
let
  peerCases = lib.concatStrings (
    lib.mapAttrsToList (
      id: name: "      ${lib.escapeShellArg id}) echo ${lib.escapeShellArg name} ;;\n"
    ) peers
  );
in
writeShellApplication {
  name = "sync-resolve";
  runtimeInputs = [
    coreutils
    diffutils
    findutils
    gitMinimal
    gnugrep
    gnused
  ];
  text = ''
    usage() {
      cat >&2 <<'EOF'
    usage: sync-resolve [--dry-run]
      Settles Syncthing conflict copies. What is safe happens on its own: identical copies, stale
      app-state copies and git index/log copies are deleted, a diverged git ref is kept as a
      sync-conflict/<host>/<ref> branch, and a git-tracked text file whose sides merge cleanly
      against the last commit before the conflict is merged. The rest is asked about one by one on a terminal.
      --dry-run  print what would happen and change nothing
    EOF
      exit 2
    }
    dry=0
    case ''${1-} in
      "") ;;
      --dry-run | -n) dry=1 ;;
      *) usage ;;
    esac
    [ $# -le 1 ] || usage
    interactive=0
    if [ "$dry" = 0 ] && [ -t 0 ] && [ -t 1 ]; then interactive=1; fi

    peer() {
      case $1 in
    ${peerCases}      *) echo "$1" ;;
      esac
    }

    is_text() { [ ! -s "$1" ] || grep -qI "" "$1"; }

    # The git dir holding $1, if it lies inside one: an ancestor with HEAD and objects/.
    git_dir_of() {
      local d
      d=$(dirname "$1")
      while [ "$d" != / ] && [ "$d" != . ]; do
        if [ -f "$d/HEAD" ] && [ -d "$d/objects" ]; then
          echo "$d"
          return 0
        fi
        d=$(dirname "$d")
      done
      return 1
    }

    in_app_state() {
      local f
      while IFS= read -r f; do
        case $1 in "$f"/*) return 0 ;; esac
      done <${writeText "app-state-folders" (lib.concatLines appStateFolders)}
      return 1
    }

    act() {
      echo "$1: $c ($host, $when)"
      [ "$dry" = 1 ] && return 1
      return 0
    }
    remove() { if act "$1"; then rm -f -- "$c"; fi; }
    pending=0

    ask() {
      if [ "$interactive" = 0 ]; then
        echo "needs you: $c ($host, $when) — $1"
        pending=$((pending + 1))
        return
      fi
      local text=0 key
      if is_text "$orig" && is_text "$c"; then text=1; fi
      echo
      echo "── $orig"
      echo "   $host's copy from $when — $1"
      if [ "$text" = 1 ]; then diff -u --label live --label "$host" "$orig" "$c" | head -n 40 || true; fi
      while :; do
        if [ "$text" = 1 ]; then
          read -rp "[m]erge in ''${DIFFTOOL:-nvim -d}, keep [l]ive, take [t]heirs, [s]kip, [q]uit: " key </dev/tty
        else
          read -rp "keep [l]ive, take [t]heirs, [s]kip, [q]uit: " key </dev/tty
        fi
        case $key in
          m)
            [ "$text" = 1 ] || continue
            ''${DIFFTOOL:-nvim -d} "$orig" "$c" </dev/tty >/dev/tty
            read -rp "delete $host's copy now? [y/N] " key </dev/tty
            if [ "$key" = y ]; then rm -f -- "$c"; else pending=$((pending + 1)); fi
            return
            ;;
          l)
            rm -f -- "$c"
            return
            ;;
          t)
            mv -f -- "$c" "$orig"
            return
            ;;
          s)
            pending=$((pending + 1))
            return
            ;;
          q) exit 0 ;;
        esac
      done
    }

    # A ref copy: kept as a branch unless the live ref already contains it.
    resolve_ref() {
      local gd=$1 rel=$2 mine theirs name
      mine=$(cat "$orig")
      theirs=$(cat "$c")
      if [[ ! $theirs =~ ^[0-9a-f]{40}$ ]] || [[ ! $mine =~ ^[0-9a-f]{40}$ ]]; then
        ask "a symbolic or packed git ref"
        return
      fi
      if git --git-dir="$gd" merge-base --is-ancestor "$theirs" "$mine" 2>/dev/null; then
        remove "already in the live ref, deleted"
        return
      fi
      if ! git --git-dir="$gd" cat-file -e "$theirs^{commit}" 2>/dev/null; then
        ask "$host's ref points at commits not synced yet"
        return
      fi
      name=''${rel#refs/heads/}
      name=refs/heads/sync-conflict/$host/''${name//\//-}
      if act "kept as ''${name#refs/heads/}"; then
        git --git-dir="$gd" update-ref "$name" "$theirs"
        rm -f -- "$c"
      fi
    }

    resolve() {
      local base id stamp gd rel top tracked at merged
      base=$(basename "$c")
      id=$(sed -E 's/.*\.sync-conflict-[0-9]{8}-[0-9]{6}-([A-Z0-9]{7}).*/\1/' <<<"$base")
      stamp=$(sed -E 's/.*\.sync-conflict-([0-9]{8})-([0-9]{6})-.*/\1\2/' <<<"$base")
      when="''${stamp:0:4}-''${stamp:4:2}-''${stamp:6:2} ''${stamp:8:2}:''${stamp:10:2}"
      host=$(peer "$id")
      orig=$(dirname "$c")/$(sed -E 's/\.sync-conflict-[0-9]{8}-[0-9]{6}-[A-Z0-9]{7}//' <<<"$base")

      if in_app_state "$c"; then
        remove "app state Syncthing no longer keeps conflicts for, deleted"
      elif [ ! -e "$orig" ]; then
        ask "the live file is gone; taking theirs restores it"
      elif cmp -s "$orig" "$c"; then
        remove "identical, deleted"
      elif gd=$(git_dir_of "$c"); then
        rel=''${orig#"$gd"/}
        case $rel in
          index | */index | FETCH_HEAD | ORIG_HEAD | COMMIT_EDITMSG | logs/* | */logs/* | */FETCH_HEAD | */ORIG_HEAD)
            remove "git rebuilds it, deleted"
            ;;
          refs/* | HEAD | worktrees/*/HEAD) resolve_ref "$gd" "$rel" ;;
          *) ask "git internals" ;;
        esac
      elif top=$(git -C "$(dirname "$orig")" rev-parse --show-toplevel 2>/dev/null) &&
        tracked=$(git -C "$(dirname "$orig")" ls-files --full-name --error-unmatch -- "$(basename "$orig")" 2>/dev/null) &&
        is_text "$orig" && is_text "$c"; then
        # Base is the last commit before their copy was written: against HEAD, later commits would read as their reverts.
        at=$(git -C "$top" rev-list -1 --first-parent --before="@$(stat -c %Y "$c")" HEAD 2>/dev/null || true)
        merged=$(mktemp)
        if [ -z "$at" ] || ! git -C "$top" show "$at:$tracked" >"$merged.base" 2>/dev/null; then
          ask "no commit of it older than their copy"
        elif ! git merge-file -p "$orig" "$merged.base" "$c" >"$merged" 2>/dev/null; then
          ask "both sides changed the same lines since ''${at:0:8}"
        elif cmp -s "$merged" "$orig"; then
          remove "nothing beyond ''${at:0:8} the live file lacks, deleted"
        elif act "merged cleanly against ''${at:0:8}"; then
          cat "$merged" >"$orig"
          rm -f -- "$c"
        fi
        rm -f "$merged" "$merged.base"
      else
        ask "no common base to merge against"
      fi
    }

    while IFS= read -r -d "" c; do
      resolve
    done < <(
      while IFS= read -r dir; do
        [ -d "$dir" ] || continue
        find "$dir" -name .stversions -prune -o -name '*.sync-conflict-*' -type f -print0 || true
      done <${writeText "sync-folders" (lib.concatLines folders)}
    )

    if [ "$pending" -gt 0 ] && [ "$interactive" = 0 ] && [ "$dry" = 0 ]; then
      echo "$pending left; run sync-resolve on a terminal to settle them"
    fi
  '';
}
