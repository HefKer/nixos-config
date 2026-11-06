{
  callPackage,
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

  fakeNotify = writeShellScriptBin "notify-send" ''echo "$*" >>"$LOG"'';

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
      probes.syncConflict
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

    : >"$findings"
    health --notify
    health --notify
    expect "$(wc -l <"$LOG")" 1 "the same finding on two runs notifies once"

    : >"$PROBES/a"
    health --notify
    echo x >"$PROBES/a"
    health --notify
    expect "$(wc -l <"$LOG")" 2 "a finding that clears and returns notifies again"

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

    mkdir -p "$HOME/.local/state/syncthing" "$HOME/s/.stversions" "$PWD/abs dir" "$HOME/default"
    cat >"$HOME/.local/state/syncthing/config.xml" <<'XML'
    <configuration>
      <folder id="a" path="~/s"></folder>
      <folder id="b" path="$PWD/abs dir"></folder>
      <folder id="c" path="~/gone"></folder>
      <defaults><folder id="" path="~/default"></folder></defaults>
    </configuration>
    XML
    sed -i "s|\$PWD|$PWD|" "$HOME/.local/state/syncthing/config.xml"
    expect "$(health-probe-sync-conflict)" "" "no conflicts is clean"
    touch "$HOME/s/foo.sync-conflict-20260101-000000-ABCDEFG.txt" \
      "$HOME/s/.stversions/old.sync-conflict-20260101-000000-ABCDEFG.txt" \
      "$PWD/abs dir/.sync-conflict-20260101-000000-ABCDEFG.last" \
      "$HOME/default/d.sync-conflict-20260101-000000-ABCDEFG.txt"
    expect "$(health-probe-sync-conflict)" \
      "$PWD/abs dir/.sync-conflict-20260101-000000-ABCDEFG.last"$'\n'"$HOME/s/foo.sync-conflict-20260101-000000-ABCDEFG.txt" \
      "conflicts are found in every folder, outside .stversions and the defaults template"

    if [ "$fail" != 0 ]; then exit 1; fi
    touch $out
  ''
