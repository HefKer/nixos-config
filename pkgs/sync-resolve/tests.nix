{
  callPackage,
  runCommandLocal,
  gitMinimal,
}:
let
  # Relative, since the sandbox path is unknown at eval time; the test runs from $PWD.
  sync-resolve = callPackage ./. {
    folders = [
      "sync"
      "app"
      "app/nested"
    ];
    appStateFolders = [ "app" ];
    peers.LENOVO1 = "lenovo";
  };
in
runCommandLocal "sync-resolve-tests"
  {
    nativeBuildInputs = [
      sync-resolve
      gitMinimal
    ];
  }
  ''
    export HOME=$PWD GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
    fail=0
    expect() {
      if [ "$1" != "$2" ]; then
        printf 'FAIL %s:\n  got      %s\n  expected %s\n' "$3" "$1" "$2"
        fail=1
      fi
    }
    sc=.sync-conflict-20260102-030405-LENOVO1
    m="(lenovo, 2026-01-02 03:04)"

    mkdir -p sync app
    echo same >sync/same.txt
    echo same >sync/same$sc.txt
    echo a >app/state.json
    echo b >app/state$sc.json
    mkdir -p app/nested
    echo a >app/nested/n.txt
    echo b >app/nested/n$sc.txt
    echo a >sync/plain.txt
    echo b >sync/plain$sc.txt
    echo b >sync/gone$sc.txt
    printf '%s\n' '{"uuid":"1"}' '{"uuid":"2"}' '{"type":"summary"}' >sync/t.jsonl
    printf '%s\n' '{"uuid":"1"}' '{"type":"summary","x":1}' >sync/t$sc.jsonl
    printf '%s\n' '{"uuid":"1"}' >sync/u.jsonl
    printf '%s\n' '{"uuid":"1"}' '{"uuid":"3"}' >sync/u$sc.jsonl

    git init -q -b master sync/repo
    r=sync/repo
    on() { GIT_AUTHOR_DATE="$1T00:00:00Z" GIT_COMMITTER_DATE="$1T00:00:00Z" "''${@:2}"; }
    printf '1\n2\n3\n4\n5\n' >$r/f.txt
    echo x >$r/g.txt
    echo h >$r/h.txt
    git -C $r add . && on 2026-01-01 git -C $r commit -qm base
    base=$(git -C $r rev-parse HEAD)
    side=$(on 2026-01-01 git -C $r commit-tree -p HEAD -m side "HEAD^{tree}")
    # Their copies are from Jan 2; HEAD moves on Jan 3, so a merge against HEAD would revert line 3.
    printf '1\n2\n3\n4\nfive\n' >$r/f$sc.txt
    echo theirs >$r/g$sc.txt
    echo h >$r/h$sc.txt
    touch -d 2026-01-02T00:00:00Z $r/f$sc.txt $r/g$sc.txt $r/h$sc.txt
    printf '1\n2\nthree\n4\n5\n' >$r/f.txt
    echo mine >$r/g.txt
    git -C $r add . && on 2026-01-03 git -C $r commit -qm next
    git -C $r branch old
    sed -i 1s/1/one/ $r/f.txt
    echo h2 >$r/h.txt
    cp $r/.git/index $r/.git/index$sc
    echo stale >>$r/.git/index$sc
    echo "$side" >$r/.git/refs/heads/master$sc
    echo "$base" >$r/.git/refs/heads/old$sc
    b8=''${base:0:8}

    expected=$(sort <<EOF
    identical, deleted: sync/same$sc.txt $m
    app state Syncthing no longer keeps conflicts for, deleted: app/state$sc.json $m
    needs you: sync/plain$sc.txt $m — no common base to merge against
    needs you: app/nested/n$sc.txt $m — no common base to merge against
    every message already in the live transcript, deleted: sync/t$sc.jsonl $m
    needs you: sync/u$sc.jsonl $m — holds 1 messages the live transcript lacks
    needs you: sync/gone$sc.txt $m — the live file is gone; taking theirs restores it
    merged cleanly against $b8: $r/f$sc.txt $m
    needs you: $r/g$sc.txt $m — both sides changed the same lines since $b8
    nothing beyond $b8 the live file lacks, deleted: $r/h$sc.txt $m
    git rebuilds it, deleted: $r/.git/index$sc $m
    kept as sync-conflict/lenovo/master: $r/.git/refs/heads/master$sc $m
    already in the live ref, deleted: $r/.git/refs/heads/old$sc $m
    EOF
    )

    before=$(find sync app -type f | sort)
    expect "$(sync-resolve --dry-run | sort)" "$expected" "a dry run plans each class"
    expect "$(find sync app -type f | sort)" "$before" "a dry run changes nothing"

    out_=$(sync-resolve </dev/null)
    expect "$(grep -v '^5 left' <<<"$out_" | sort)" "$expected" "a real run acts as planned"
    expect "$(tail -n1 <<<"$out_")" "5 left; run sync-resolve on a terminal to settle them" "off a terminal, the rest is counted"
    expect "$(cat $r/f.txt)" "$(printf 'one\n2\nthree\n4\nfive')" "a clean merge keeps both sides and later commits"
    expect "$(git -C $r rev-parse sync-conflict/lenovo/master)" "$side" "a diverged ref is kept as a branch"
    expect "$(find sync app -name '*.sync-conflict-*' | sort)" "$(printf '%s\n' app/nested/n$sc.txt sync/u$sc.jsonl sync/gone$sc.txt sync/plain$sc.txt $r/g$sc.txt | sort)" \
      "only the copies that need a person are left"

    if [ "$fail" != 0 ]; then exit 1; fi
    touch $out
  ''
