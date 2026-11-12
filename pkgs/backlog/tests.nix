{
  callPackage,
  jq,
  runCommandLocal,
  writeShellScriptBin,
}:
let
  # Fake GitHub: $FAKE/offline drops the network, $FAKE/broken fails a label, $FAKE/{public,missing}/<owner>_<repo>.
  fakeGh = writeShellScriptBin "gh" ''
    net() { echo "error connecting to api.github.com" >&2; exit 1; }
    case "$1 $2" in
      "api repos/"*/contents/*)
        [ -e "$FAKE/offline" ] && net
        p=''${2#repos/}
        f=$FAKE/uploads/''${p/\/contents\//\/}
        url="https://github.com/''${p%%/contents/*}/blob/main/''${p#*/contents/}"
        if [ "$3 $4" = "-X PUT" ]; then
          [ -e "$f" ] && { cat >/dev/null; echo "gh: sha wasn't supplied (HTTP 422)" >&2; exit 1; }
          mkdir -p "$(dirname "$f")"
          jq -r .content | base64 -d >"$f"
          echo "upload $p" >>"$LOG"
        else
          [ -e "$f" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
        fi
        echo "$url"
        ;;
      "api "*)
        [ -e "$FAKE/offline" ] && net
        r=''${2#repos/}
        [ -e "$FAKE/missing/''${r//\//_}" ] && { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
        if [ -e "$FAKE/public/''${r//\//_}" ]; then echo false; else echo true; fi
        echo "api $r" >>"$FAKE/api-calls"
        ;;
      "issue create")
        [ -e "$FAKE/offline" ] && net
        [ -e "$FAKE/broken" ] && { echo "could not add label: 'capture' not found" >&2; exit 1; }
        shift 2
        echo "create $*" >>"$LOG"
        n=$(($(cat "$FAKE/n" 2>/dev/null || echo 0) + 1))
        echo "$n" >"$FAKE/n"
        while [ "$1" != --repo ]; do shift; done
        echo "Creating issue in $2"
        echo "https://github.com/$2/issues/$n"
        ;;
      "label list") cat "$FAKE/labels" 2>/dev/null || true ;;
      "label create") echo "label $3 $5" >>"$LOG" ;;
      "repo create") echo "repo create $3 $4" >>"$LOG" ;;
      *) echo "fake gh: unexpected $*" >&2; exit 1 ;;
    esac
  '';

  fakeNotify = writeShellScriptBin "notify-send" ''
    echo "notify $*" >>"$FAKE/notes"
  '';

  # Answers with the next line of $FAKE/answers (ESC prints the box's text, ESC:TEXT or the refill, CTRLG cancels), logging args, prompt, refill and list.
  fakeFuzzel = writeShellScriptBin "fuzzel" ''
    prev="" search="" box=0
    echo "$*" >>"$FAKE/fuzzel-args"
    for a; do
      case $a in *"> ") echo "$a" >>"$FAKE/fuzzel-prompts" ;; --prompt-only) box=1 ;; esac
      if [ "$prev" = --search ]; then echo "$a" >>"$FAKE/fuzzel-search" && search=$a; fi
      prev=$a
    done
    [ "$box" = 1 ] || cat >"$FAKE/fuzzel-list"
    n=$(($(cat "$FAKE/fuzzel-n" 2>/dev/null || echo 0) + 1))
    echo "$n" >"$FAKE/fuzzel-n"
    a=$(sed -n "''${n}p" "$FAKE/answers")
    case $a in
      CTRLG) exit 2 ;;
      ESC) [ "$box" = 1 ] || exit 2; echo "$search" && exit 11 ;;
      ESC:*) echo "''${a#ESC:}" && exit 11 ;;
      SHIFT:*) echo "''${a#SHIFT:}" && exit 10 ;;
      *) echo "$a" ;;
    esac
  '';

  # The clipboard: $FAKE/clip-types lists its types, $FAKE/clip holds the bytes.
  fakeWlPaste = writeShellScriptBin "wl-paste" ''
    case $1 in
      --list-types) cat "$FAKE/clip-types" 2>/dev/null || true ;;
      *) echo "$*" >>"$FAKE/wl-paste-args" && cat "$FAKE/clip" ;;
    esac
  '';

  backlog = callPackage ./. {
    gh = fakeGh;
    libnotify = fakeNotify;
    fuzzel = fakeFuzzel;
    wl-clipboard = fakeWlPaste;
  };
in
runCommandLocal "backlog-tests"
  {
    nativeBuildInputs = [
      backlog
      jq
    ];
  }
  ''
    export HOME=$PWD/home FAKE=$PWD/fake LOG=$PWD/log
    export BACKLOG_CONFIG=$PWD/projects.yaml
    mkdir -p "$HOME" "$FAKE/public"
    touch "$LOG"
    queue=$HOME/.local/state/backlog/queue.jsonl
    cat >"$BACKLOG_CONFIG" <<'EOF'
    projects:
      - name: nixos
        repo: o/nixos-issues
        match: [homelab]
      - name: dots
        repo: o/dots-issues
      - name: open
        repo: o/open
      - name: openok
        repo: o/openok
        public_ok: true
        labels: [idea]
    EOF
    touch "$FAKE/public/o_open" "$FAKE/public/o_openok"
    fail=0
    expect() {
      if [ "$1" != "$2" ]; then
        printf 'FAIL %s:\n  got      %s\n  expected %s\n' "$3" "$1" "$2"
        fail=1
      fi
    }

    expect "$(backlog add nixos 'img viewer // see https://x.y/z' </dev/null)" \
      "https://github.com/o/nixos-issues/issues/1" "add prints the issue URL"
    expect "$(tail -n 1 "$LOG")" \
      "create --repo o/nixos-issues --title img viewer --body see https://x.y/z --label needs-triage --label capture" \
      "text after // is the body, and both default labels are set"

    backlog add dots 'see https://a.b/c' </dev/null >/dev/null
    expect "$(tail -n 1 "$LOG")" \
      "create --repo o/dots-issues --title see https://a.b/c --body  --label needs-triage --label capture" \
      "a URL's :// stays in the title"

    echo "from stdin" | backlog add dots 'one // two' >/dev/null
    expect "$(tail -n 3 "$LOG")" \
      "create --repo o/dots-issues --title one --body two"$'\n\n'"from stdin --label needs-triage --label capture" \
      "stdin is appended to the body"

    mkdir -p "$PWD/dev/homelab-thing"
    (cd "$PWD/dev/homelab-thing" && backlog add 'guessed' </dev/null >/dev/null)
    expect "$(tail -n 1 "$LOG" | cut -d' ' -f3)" "o/nixos-issues" "the cwd picks the project by its match words"
    expect "$(cd "$PWD/dev/homelab-thing" && backlog projects | head -n 2 | tr '\n' ' ')" "nixos dots " \
      "projects lists the guess, then the most recent"

    before=$(wc -l <"$LOG")
    expect "$(backlog add open 'leak' </dev/null 2>&1 || echo "rc=$?")" \
      "backlog: refused: o/open is public; set public_ok: true in $BACKLOG_CONFIG to allow it"$'\n'"rc=1" \
      "a public repo without public_ok is refused"
    expect "$(wc -l <"$LOG")" "$before" "a refused idea files nothing"
    expect "$([ -e "$queue" ] && echo queued || echo none)" none "a refused idea is not queued"

    backlog add openok 'fine' </dev/null >/dev/null
    expect "$(tail -n 1 "$LOG")" "create --repo o/openok --title fine --body  --label idea" \
      "public_ok allows a public repo, and labels override the default"

    printf 'projects:\n  - name: x\n    repo: xo/dots-issues\n' >"$PWD/x.yaml"
    touch "$FAKE/public/xo_dots-issues"
    expect "$(BACKLOG_CONFIG=$PWD/x.yaml backlog add x 'leak' </dev/null 2>&1 | cut -d' ' -f1-3 || true)" \
      "backlog: refused: xo/dots-issues" "a cached private repo doesn't vouch for one whose name ends the same"

    mkdir -p "$PWD/elsewhere"
    expect "$(cd "$PWD/elsewhere" && backlog add 'fallback' </dev/null 2>&1 >/dev/null)" \
      "backlog: nothing matches $PWD/elsewhere; using the most recent project, openok" \
      "with no match the CLI falls back to the most recent project and says so"

    calls=$(wc -l <"$FAKE/api-calls")
    backlog add nixos 'again' </dev/null >/dev/null
    expect "$(wc -l <"$FAKE/api-calls")" "$calls" "a repo's visibility is cached"

    touch "$FAKE/offline"
    expect "$(backlog add --notify nixos 'offline idea // b' </dev/null 2>/dev/null; echo "rc=$?")" "rc=0" \
      "an offline add succeeds by queueing"
    expect "$(jq -r '"\(.repo) \(.title) \(.body)"' "$queue")" "o/nixos-issues offline idea b" "the idea is queued"
    expect "$(tail -n 1 "$FAKE/notes")" "notify -a backlog -u normal backlog: queued (offline) offline idea" \
      "offline is a normal-urgency notification"
    backlog flush
    expect "$(wc -l <"$queue")" 1 "a flush while offline keeps the line"
    rm "$FAKE/offline"
    expect "$(backlog flush)" "https://github.com/o/nixos-issues/issues/8" "a flush back online files it"
    expect "$([ -e "$queue" ] && echo queued || echo none)" none "and empties the queue"

    touch "$FAKE/broken"
    backlog add --notify dots 'broken' </dev/null >/dev/null 2>&1 || true
    expect "$(tail -n 1 "$FAKE/notes" | cut -d' ' -f1-6)" "notify -a backlog -u critical backlog:" \
      "any other failure is critical"
    backlog flush 2>/dev/null
    backlog flush 2>/dev/null
    expect "$(jq -r .fails "$queue")" 3 "each failed flush counts against the line"
    expect "$(grep -c 'failed' "$FAKE/notes" || true)" 0 "a quiet flush can't raise the notification"
    backlog flush --notify 2>/dev/null
    expect "$(grep -c 'failed 4 times' "$FAKE/notes")" 1 "the next notifying run past the limit raises it"
    backlog flush --notify 2>/dev/null
    expect "$(grep -c 'failed' "$FAKE/notes")" 1 "and only once"
    expect "$(backlog queue | cut -d' ' -f3-)" "o/dots-issues  broken  (failed 5x)" "queue lists the line"
    rm "$FAKE/broken"
    backlog add dots 'next' </dev/null >/dev/null
    expect "$(tail -n 2 "$LOG" | cut -d' ' -f5 | tr '\n' ' ')" "broken next " "a capture flushes the queue first"

    printf 'needs-triage\n' >"$FAKE/labels"
    : >"$LOG"
    backlog setup >/dev/null
    expect "$(sort "$LOG" | tr '\n' ' ')" \
      "label capture o/dots-issues label capture o/nixos-issues label capture o/open label idea o/openok " \
      "setup creates only the missing labels in each repo"

    printf 'PNG1' >"$PWD/shot.png"
    : >"$LOG"
    expect "$(backlog add --image "$PWD/shot.png" nixos 'x' </dev/null 2>&1 || echo "rc=$?")" \
      "backlog: --image needs attachments_repo: OWNER/NAME in $BACKLOG_CONFIG"$'\n'"rc=1" \
      "--image without attachments_repo is refused"
    expect "$(cat "$LOG")" "" "and nothing is uploaded or filed"

    echo 'attachments_repo: o/attach' >>"$BACKLOG_CONFIG"
    day=$(date -u +%Y-%m-%d)
    raw() { echo "https://github.com/o/attach/blob/main/$day/$(sha256sum "$1" | cut -c1-16).png?raw=true"; }
    url1=$(raw "$PWD/shot.png")
    backlog add --image "$PWD/shot.png" nixos 'shot // look' </dev/null >/dev/null
    expect "$(cat "$FAKE/uploads/o/attach/$day/"*.png)" PNG1 "the image is committed to the attachments repo"
    expect "$(tail -n 3 "$LOG")" \
      "create --repo o/nixos-issues --title shot --body look"$'\n\n'"![image]($url1) --label needs-triage --label capture" \
      "and embedded at the end of the body by its raw URL"

    backlog add --image "$PWD/shot.png" dots 'again' </dev/null >/dev/null
    expect "$(tail -n 1 "$LOG")" "create --repo o/dots-issues --title again --body ![image]($url1) --label needs-triage --label capture" \
      "an image already uploaded is reused"

    printf 'PNG2' >"$PWD/two.png"
    url2=$(raw "$PWD/two.png")
    touch "$FAKE/offline"
    backlog add --image "$PWD/two.png" nixos 'later' </dev/null 2>/dev/null
    expect "$(cat "$(jq -r .image "$queue")")" PNG2 "offline, the image is copied into the state dir beside the queued line"
    rm "$PWD/two.png" "$FAKE/offline"
    backlog flush >/dev/null
    expect "$(tail -n 1 "$LOG")" "create --repo o/nixos-issues --title later --body ![image]($url2) --label needs-triage --label capture" \
      "a flush uploads the copy and files the line with it, after the original is gone"
    expect "$(ls -A "$HOME/.local/state/backlog/images")" "" "and removes the copy"

    touch "$FAKE/public/o_attach"
    rm "$HOME/.local/state/backlog/visibility"
    expect "$(backlog add --image "$PWD/shot.png" dots 'leak' </dev/null 2>&1 >/dev/null || true)" \
      "backlog: queued after an error: o/attach is public; attachments_repo must be private" \
      "a public attachments repo is never uploaded to"
    expect "$(tail -n 1 "$LOG")" "create --repo o/nixos-issues --title later --body ![image]($url2) --label needs-triage --label capture" \
      "nor is the issue filed without its image"
    rm "$FAKE/public/o_attach" "$queue" "$HOME/.local/state/backlog/visibility"
    rm -r "$HOME/.local/state/backlog/images"

    mkdir -p "$FAKE/missing"
    touch "$FAKE/missing/o_attach"
    : >"$LOG"
    expect "$(backlog setup | grep o/attach)" "o/attach: created (private)" "setup creates a missing attachments repo"
    expect "$(grep '^repo' "$LOG")" "repo create o/attach --private" "as private"
    rm "$FAKE/missing/o_attach"
    expect "$(backlog setup | grep o/attach)" "o/attach: exists" "and leaves an existing one"

    # The prompt runs last: the add it starts is backgrounded, so its log lines land late.
    record=$HOME/.local/state/repeat/last
    printf 'ESC\n' >"$FAKE/answers"
    backlog prompt dots
    expect "$([ -e "$record" ] && echo recorded || echo none)" none "Esc in the text box records nothing"

    printf '0\nfrom the picker\nESC\nagain\n' >"$FAKE/answers"
    rm -f "$FAKE/fuzzel-n" "$FAKE/fuzzel-prompts"
    backlog prompt
    expect "$(tr '\0' ' ' <"$record")" "backlog prompt dots " "a filed line records the box for its project"
    backlog prompt dots
    expect "$(tr '\n' '|' <"$FAKE/fuzzel-prompts")" "backlog> |dots> |dots> |" \
      "the replay opens the project's box without the picker"
    expect "$(tr '\0' ' ' <"$record")" "backlog prompt dots " "Esc in the replayed box leaves the record"
    backlog prompt nixos
    expect "$(tr '\0' ' ' <"$record")" "backlog prompt nixos " "the next filed line overwrites it"

    : >"$FAKE/notes"
    backlog prompt removed
    expect "$(cat "$FAKE/notes")" "notify -a backlog backlog: no project removed it is no longer in $BACKLOG_CONFIG" \
      "a replay for a project gone from the config notifies and does nothing else"
    expect "$(cat "$FAKE/fuzzel-n")" 4 "and opens no box"

    # Shift+Enter: with no attachments_repo, then no image, the box reopens with the text; then the image is filed.
    filed() {
      for _ in $(seq 100); do grep -q "title $1 " "$LOG" && return 0; sleep 0.1; done
    }
    : >"$FAKE/notes"
    rm -f "$FAKE/fuzzel-n" "$FAKE/fuzzel-search"
    printf 'SHIFT:pic // see\nESC\n' >"$FAKE/answers"
    BACKLOG_CONFIG=$PWD/x.yaml backlog prompt x
    expect "$(grep "can't attach" "$FAKE/notes")" "notify -a backlog backlog: can't attach an image set attachments_repo: OWNER/NAME in $PWD/x.yaml" \
      "Shift+Enter without attachments_repo says so"
    expect "$(cat "$FAKE/fuzzel-search")" "pic // see" "and reopens the box with the text kept"

    : >"$FAKE/notes"
    rm -f "$FAKE/fuzzel-n" "$FAKE/fuzzel-search"
    printf 'text/plain\n' >"$FAKE/clip-types"
    printf 'SHIFT:nopic // see\nESC\n' >"$FAKE/answers"
    backlog prompt nixos
    expect "$(grep "can't attach" "$FAKE/notes")" "notify -a backlog backlog: can't attach an image no image on the clipboard" \
      "Shift+Enter with no image on the clipboard says so"
    expect "$(cat "$FAKE/fuzzel-search")" "nopic // see" "and reopens the box with the text kept"

    rm -f "$FAKE/fuzzel-n"
    printf 'image/jpeg\nimage/png\n' >"$FAKE/clip-types"
    printf 'PNG3' >"$FAKE/clip"
    printf 'SHIFT:pic // see\n' >"$FAKE/answers"
    backlog prompt nixos
    filed pic
    expect "$(cat "$FAKE/wl-paste-args")" "--no-newline --type image/png" "PNG is preferred among the offered types"
    expect "$(grep -A2 'title pic ' "$LOG")" \
      "create --repo o/nixos-issues --title pic --body see"$'\n\n'"![image]($(raw "$FAKE/clip")) --label needs-triage --label capture" \
      "the second Shift+Enter files the line with the clipboard's image"
    for _ in $(seq 100); do compgen -G "$HOME/.local/state/backlog/clip.*" >/dev/null || break; sleep 0.1; done
    expect "$(compgen -G "$HOME/.local/state/backlog/clip.*" || true)" "" "and removes the clipboard's copy"
    expect "$(tr '\0' ' ' <"$record")" "backlog prompt nixos " "an image filing records the box like a plain one"

    # Drafts: Esc keeps the box's text per project, reopened in the box and marked in the picker.
    drafts=$HOME/.local/state/backlog/drafts
    box() {
      rm -f "$FAKE/fuzzel-n" "$FAKE/fuzzel-search" "$FAKE/fuzzel-list" "$FAKE/fuzzel-args"
      printf '%s\n' "''${@:2}" >"$FAKE/answers"
      backlog prompt ''${1:+"$1"}
    }
    draft() { if [ -e "$drafts/$1" ]; then cat "$drafts/$1"; else echo none; fi; }
    text='foo // bar "q" ✓  '
    box openok "ESC:$text"
    expect "$(draft openok)" "$text" "Esc keeps the text, byte for byte, as the project's draft"
    expect "$(grep -c -- --no-exit-on-keyboard-focus-loss "$FAKE/fuzzel-args")" 1 "the box stays open on focus loss"

    box "" 0 ESC
    expect "$(tr '\n' '|' <"$FAKE/fuzzel-list")" "openok ✎|$(backlog projects | grep -vx openok | tr '\n' '|')" \
      "a project with a draft leads the picker, marked"
    expect "$(cat "$FAKE/fuzzel-prompts" | tail -n 1)" "openok> " "picking it opens its box by its bare name"
    expect "$(cat "$FAKE/fuzzel-search")" "$text" "with the draft in it"
    expect "$(draft openok)" "$text" "Esc on the untouched box keeps the draft"

    box "" 0 'drafted // filed'
    filed drafted
    expect "$(draft openok)" none "Enter files it and clears the draft"
    box "" 0 ESC
    expect "$(grep -c '✎' "$FAKE/fuzzel-list" || true)" 0 "the next picker marks nothing"
    expect "$([ -e "$FAKE/fuzzel-search" ] && echo refilled || echo empty)" empty "and the next box is empty"

    box dots "ESC:keep"
    box nixos "ESC:mine"
    box dots CTRLG
    expect "$(cat "$FAKE/fuzzel-search")" keep "the box reopens with its own project's draft"
    expect "$(draft dots)" none "Ctrl+G discards the draft"
    expect "$(draft nixos)" mine "and leaves another project's"
    box nixos "ESC:   "
    expect "$(draft nixos)" none "Esc on an emptied box clears the draft"

    box dots "ESC:cli"
    backlog add dots 'from the cli' </dev/null >/dev/null
    expect "$(draft dots)" cli "the CLI's add leaves drafts alone"
    rm "$drafts/dots"

    box open 'secret // s'
    for _ in $(seq 100); do [ -e "$drafts/open" ] && break; sleep 0.1; done
    expect "$(draft open)" "secret // s" "a line the repo refuses becomes the draft again"

    touch "$FAKE/offline"
    box nixos "ESC:later"
    box nixos 'queued draft'
    for _ in $(seq 100); do grep -q 'queued draft' "$queue" 2>/dev/null && break; sleep 0.1; done
    expect "$(jq -r .title "$queue")" "queued draft" "an offline line is queued"
    expect "$(draft nixos)" none "and clears the draft, as filing does"
    rm "$FAKE/offline"

    if [ "$fail" != 0 ]; then exit 1; fi
    touch $out
  ''
