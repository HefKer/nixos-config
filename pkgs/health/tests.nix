{
  callPackage,
  gitMinimal,
  runCommandLocal,
  writeShellScript,
  writeShellScriptBin,
}:
let
  probes = callPackage ./probes.nix { };

  # Prints $PROBES/<name> as its findings and exits with $PROBES/<name>.exit, so a test sets both.
  fakeProbe =
    name:
    writeShellScript "probe-${name}" ''
      cat "$PROBES/${name}" 2>/dev/null || true
      exit "$(cat "$PROBES/${name}.exit" 2>/dev/null || echo 0)"
    '';

  # Logs each notification, or fails while $PROBES/notify-fails exists, as with no notification daemon up.
  fakeNotify = writeShellScriptBin "notify-send" ''
    if [ -e "$PROBES/notify-fails" ]; then exit 1; fi
    echo "$*" >>"$LOG"
  '';

  health = callPackage ./. {
    libnotify = fakeNotify;
    probes = {
      a = fakeProbe "a";
      b = fakeProbe "b";
    };
  };
in
runCommandLocal "health-tests"
  {
    nativeBuildInputs = [
      health
      (probes.linkDrift [
        ".config/app"
        ".config/f.toml"
      ])
      gitMinimal
      (probes.staleBuild {
        roots = [ "dev" ];
        days = 30;
        minSizeMiB = 1;
      })
      (probes.unpushedWork {
        roots = [ "dev" ];
        days = 30;
      })
      (probes.nixpkgsAge {
        lastModified = 0;
        maxAgeDays = 30;
      })
      # Relative, since the sandbox path is unknown at eval time; the test runs from $PWD.
      (probes.syncConflict [
        "home/s"
        "abs dir"
        "home/gone"
      ])
    ];
  }
  ''
    export HOME=$PWD/home PROBES=$PWD/probes LOG=$PWD/log
    mkdir -p "$HOME" "$PROBES"
    touch "$LOG"
    findings=$HOME/.local/state/health/findings
    fail=0
    expect() {
      if [ "$1" != "$2" ]; then
        printf 'FAIL %s:\n  got      %s\n  expected %s\n' "$3" "$1" "$2"
        fail=1
      fi
    }

    expect "$(health)" "no health findings" "clean run says so"
    expect "$(cat "$findings")" "" "clean run leaves the status file empty"
    expect "$(health --greeting)" "" "clean greeting prints nothing"

    echo x >"$PROBES/a"
    expect "$(health)" "a x" "a finding is prefixed with its probe"
    expect "$(health --greeting)" "⚠ 1 health finding — run 'health'" "greeting counts one"

    health --notify
    health --notify
    expect "$(wc -l <"$LOG")" 1 "the same finding on two runs notifies once, though a manual run saw it first"
    expect "$(cat "$LOG")" "-a health 1 new health finding a x" "the notification names the finding"

    : >"$PROBES/a"
    health --notify
    echo x >"$PROBES/a"
    health --notify
    expect "$(wc -l <"$LOG")" 2 "a finding that clears and returns notifies again"

    echo y >"$PROBES/a"
    touch "$PROBES/notify-fails"
    health --notify 2>/dev/null
    rm "$PROBES/notify-fails"
    health --notify
    expect "$(wc -l <"$LOG")" 3 "a failed notification is retried on the next run"
    echo x >"$PROBES/a"

    echo 3 >"$PROBES/b.exit"
    expect "$(health)" $'a x\nb probe exited 3' "a failing probe is a finding"
    expect "$(health --greeting)" "⚠ 2 health findings — run 'health'" "greeting counts two"
    rm "$PROBES/b.exit"

    mkdir -p "$HOME/.config"
    ln -s /nix/store/00000000000000000000000000000000-home-manager-files/.config/app "$HOME/.config/app"
    ln -s /nix/store/00000000000000000000000000000000-home-manager-files/.config/f.toml "$HOME/.config/f.toml"
    expect "$(health-probe-link-drift)" "" "placed links are clean"
    rm "$HOME/.config/f.toml"
    echo copy >"$HOME/.config/f.toml"
    expect "$(health-probe-link-drift)" "$HOME/.config/f.toml: file" "a regular copy is drift"
    rm "$HOME/.config/f.toml"
    ln -s /elsewhere "$HOME/.config/f.toml"
    expect "$(health-probe-link-drift)" "$HOME/.config/f.toml: symlink to /elsewhere" "a foreign link is drift"
    rm "$HOME/.config/f.toml" "$HOME/.config/app"
    mkdir "$HOME/.config/app"
    expect "$(health-probe-link-drift)" "$HOME/.config/app: directory"$'\n'"$HOME/.config/f.toml: missing" \
      "a directory and a missing target are drift"

    mkdir -p "$HOME/s/.stversions" "$PWD/abs dir"
    expect "$(health-probe-sync-conflict)" "" "no conflicts is clean"
    touch "$HOME/s/foo.sync-conflict-20260101-000000-ABCDEFG.txt" \
      "$HOME/s/.stversions/old.sync-conflict-20260101-000000-ABCDEFG.txt" \
      "$PWD/abs dir/.sync-conflict-20260101-000000-ABCDEFG.last"
    expect "$(health-probe-sync-conflict)" \
      "abs dir/.sync-conflict-20260101-000000-ABCDEFG.last"$'\n'"home/s/foo.sync-conflict-20260101-000000-ABCDEFG.txt" \
      "conflicts are found in every folder, outside .stversions, and a missing folder is skipped"

    mkdir -p dev/old/target dev/new/target dev/small/target dev/.hidden/target
    head -c 2M /dev/zero >dev/old/target/a
    head -c 2M /dev/zero >dev/new/target/a
    echo x >dev/small/target/a
    touch -d 2026-01-01 dev/old/target/a dev/old/target dev/small/target/a dev/small/target
    # du's figure depends on the sandbox filesystem's block size.
    expect "$(health-probe-stale-build | sed -E 's/: [0-9.]+[KMG]?,/: SIZE,/')" "dev/old/target: SIZE, untouched since 2026-01-01" \
      "only large build output untouched for a month is stale"

    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
    export GIT_AUTHOR_DATE=2026-01-01T00:00:00Z GIT_COMMITTER_DATE=2026-01-01T00:00:00Z
    git init -q --bare remote.git
    for r in pushed dirty ahead local .parked; do
      git init -q -b main dev/$r
      git -C dev/$r commit -q --allow-empty -m base
      if [ $r != local ]; then
        git -C dev/$r remote add origin "$PWD/remote.git"
        git -C dev/$r push -q origin "main:b''${r#.}"
        git -C dev/$r branch -q -u "origin/b''${r#.}"
      fi
    done
    echo x >dev/dirty/f
    touch -d 2026-01-02 dev/dirty/f
    git -C dev/ahead commit -q --allow-empty -m more
    echo x >dev/local/f
    echo x >dev/.parked/f
    expect "$(health-probe-unpushed-work)" "dev/ahead: unpushed commits on main, idle since 2026-01-01"$'\n'"dev/dirty: uncommitted changes, idle since 2026-01-02" \
      "idle repos with a remote report uncommitted and unpushed work; hidden and remote-less ones don't"
    echo y >dev/dirty/f
    expect "$(health-probe-unpushed-work)" "dev/ahead: unpushed commits on main, idle since 2026-01-01" "a fresh edit is not idle"

    expect "$(health-probe-nixpkgs-age)" "nixpkgs is from 1970-01-01, over 30 days old; update the flake" "an old nixpkgs is due an update"

    if [ "$fail" != 0 ]; then exit 1; fi
    touch $out
  ''
