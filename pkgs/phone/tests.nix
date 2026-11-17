{
  callPackage,
  runCommandLocal,
  writeShellScriptBin,
}:
let
  # Holds each setting as the file $PHONE/<namespace>/<key>, and evaluates its arguments as the phone's shell would.
  fakeAdb = writeShellScriptBin "adb" ''
    [ "$1" = -s ] && shift 2
    [ "$1" = shell ] && shift
    eval "set -- $*"
    file=$PHONE/$3/$4
    case $2 in
      get)
        if [ -e "$PHONE/drops-after-put" ] && [ -e "$PHONE/put" ]; then exit 1; fi
        if [ -e "$file" ]; then cat "$file"; else echo null; fi
        ;;
      put)
        if [ -e "$PHONE/read-only" ]; then exit 0; fi
        touch "$PHONE/put"
        mkdir -p "$PHONE/$3"
        printf '%s\n' "$5" >"$file"
        ;;
      delete)
        rm -f "$file"
        echo "Deleted 1 rows"
        ;;
    esac
  '';

  # Knows a peer only as the file $PHONE/peers/<address>, which holds its OS.
  fakeTailscale = writeShellScriptBin "tailscale" ''
    [ "$1 $2" = "whois --json" ] && [ -e "$PHONE/peers/$3" ] || exit 1
    printf '{"Node":{"Hostinfo":{"OS":"%s"}}}\n' "$(cat "$PHONE/peers/$3")"
  '';

  phone = callPackage ./. {
    android-tools = fakeAdb;
    tailscale = fakeTailscale;
    nmap = null;
  };
in
runCommandLocal "phone-tests" { nativeBuildInputs = [ phone ]; } ''
  export HOME=$PWD/home PHONE=$PWD/phone ANDROID_SERIAL=fake:5555
  mkdir -p "$HOME" "$PHONE"
  journal=$HOME/.local/state/phone/journal.tsv
  fail=0
  expect() {
    if [ "$1" != "$2" ]; then
      printf 'FAIL %s:\n  got      %s\n  expected %s\n' "$3" "$1" "$2"
      fail=1
    fi
  }
  # The journal without its timestamp column.
  entries() { cut -f2- "$journal"; }

  expect "$(phone-set system font_scale 1.3)" "system font_scale: null -> 1.3" "a change prints old and new"
  expect "$(cat "$PHONE/system/font_scale")" "1.3" "the value reaches the phone"
  expect "$(entries)" $'system\tfont_scale\tnull\t1.3' "an unset key is journalled as null"
  expect "$(cut -f1 "$journal" | grep -cE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T')" 1 "an entry starts with its timestamp"

  phone-set system font_scale 1.0 >/dev/null
  expect "$(entries | tail -n1)" $'system\tfont_scale\t1.3\t1.0' "a second change journals the value it replaced"

  phone-set system font_scale --delete >/dev/null
  expect "$(entries | tail -n1)" $'system\tfont_scale\t1.0\tnull' "a delete journals the value it removed"
  [ ! -e "$PHONE/system/font_scale" ] || { echo "FAIL --delete left the key"; fail=1; }

  phone-set secure note "it's a; \$(touch pwned)"$'\t'"tab" >/dev/null
  expect "$(cat "$PHONE/secure/note")" "it's a; \$(touch pwned)"$'\t'"tab" "a value passes the phone's shell untouched"
  expect "$(entries | tail -n1)" $'secure\tnote\tnull\tit\'s a; $(touch pwned)\\ttab' "a tab in a value is escaped in the journal"

  before=$(wc -l <"$journal")
  touch "$PHONE/read-only"
  if phone-set global mode 2 >/dev/null 2>&1; then echo "FAIL a change the phone dropped exits 0"; fail=1; fi
  expect "$(entries | tail -n1)" $'global\tmode\tnull\tnull' "a dropped change is journalled as what the phone holds"
  rm "$PHONE/read-only"

  rm -f "$PHONE/put"
  touch "$PHONE/drops-after-put"
  if phone-set global mode 3 >/dev/null 2>&1; then echo "FAIL a change that couldn't be read back exits 0"; fail=1; fi
  expect "$(entries | tail -n1)" $'global\tmode\tnull\tunknown, asked for 3' "a change adb dropped after applying is still journalled with its old value"
  rm "$PHONE/drops-after-put"
  before=$((before + 1))

  for bad in "" "bogus key v" "system key" "system key v extra"; do
    # shellcheck disable=SC2086
    if phone-set $bad >/dev/null 2>&1; then echo "FAIL usage accepted: $bad"; fail=1; fi
  done
  expect "$(wc -l <"$journal")" "$((before + 1))" "a usage error journals nothing"

  context=$HOME/.local/state/phone/context.tsv
  mkdir -p "$PHONE/peers"
  echo android >"$PHONE/peers/100.64.0.2"
  echo linux >"$PHONE/peers/100.64.0.3"
  # Sends one request as the socket unit would and prints the status line: request METHOD PATH BODY [SENDER]
  request() {
    printf '%s %s HTTP/1.1\r\nHost: desktop\r\nContent-Length: %s\r\n\r\n%s' "$1" "$2" "''${#3}" "$3" |
      REMOTE_ADDR=''${4-100.64.0.2} phone-context receive 2>/dev/null | head -n1 | tr -d '\r'
  }
  post() { request POST /context "$@"; }
  # The state without its two timestamp columns.
  heard() { cut -f1,2 "$context" | tr '\t\n' '= '; }

  if phone-context >/dev/null 2>&1; then echo "FAIL no state yet exits 0"; fail=1; fi
  expect "$(phone-context place 2>/dev/null)" unknown "a key reads unknown before the phone's first post"

  expect "$(post 'power=plugged&place=home&interrupt=all')" "HTTP/1.1 200 OK" "the phone's post is accepted"
  expect "$(heard)" "power=plugged place=home dnd=off " "all three facts are recorded, interrupt mode as dnd"
  ts='[0-9-]{10}T[0-9:]{8}Z'
  expect "$(cut -f3,4 "$context" | grep -cE "^$ts"$'\t'"$ts\$")" 3 "each fact carries since and heard timestamps"
  expect "$(phone-context place)" home "a key prints its value"
  expect "$(phone-context dnd)" off "interrupt mode all is dnd off"
  expect "$(phone-context)" $'power\tplugged\tfor 0m\nplace\thome\tfor 0m\ndnd\toff\tfor 0m\nheard 0m ago' "no key prints every fact with its age"

  expect "$(post 'interrupt=none&place=away&power=unplugged')" "HTTP/1.1 200 OK" "pairs come in any order"
  expect "$(heard)" "power=unplugged place=away dnd=silence " "and the file keeps its own order"

  before=$(cat "$context")
  expect "$(post 'power=plugged&place=home&interrupt=all' 100.64.0.3)" "HTTP/1.1 403 Forbidden" "a tailnet peer that is not the phone is refused"
  expect "$(post 'power=plugged&place=home&interrupt=all' 100.64.0.9)" "HTTP/1.1 403 Forbidden" "an address Tailscale does not know is refused"
  for bad in 'power=%ContextPower&place=home&interrupt=all' 'power=plugged&place=home&interrupt=$(touch pwned)' \
    'power=plugged&place=home' 'power=plugged&power=unplugged&place=home&interrupt=all' \
    'power=plugged&place=home&interrupt=all&run=reboot' 'power=on&place=home&interrupt=all' ""; do
    expect "$(post "$bad")" "HTTP/1.1 400 Bad Request" "refused: $bad"
  done
  expect "$(request GET /context "")" "HTTP/1.1 405 Method Not Allowed" "only POST is answered"
  expect "$(request POST /run 'power=plugged&place=home&interrupt=all')" "HTTP/1.1 404 Not Found" "only /context is answered"
  expect "$(post "$(printf 'power=plugged&place=home&interrupt=all&%0100d' 0)")" "HTTP/1.1 413 Content Too Large" "a long body is refused unread"
  expect "$(cat "$context")" "$before" "a refused post changes nothing"
  [ ! -e pwned ] || { echo "FAIL a posted value was run"; fail=1; }

  stamp() { date -u -d "$1" +%FT%TZ; }
  old=$(stamp '2 hours ago')
  printf '%s\t%s\t%s\t%s\n' power plugged "$old" "$(stamp '10 minutes ago')" place home "$old" "$(stamp '10 minutes ago')" \
    dnd off "$old" "$(stamp '10 minutes ago')" >"$context"
  expect "$(phone-context)" $'power\tplugged\tfor 2h 0m\nplace\thome\tfor 2h 0m\ndnd\toff\tfor 2h 0m\nheard 10m ago' "ages count from since and heard"
  post 'power=unplugged&place=home&interrupt=all' >/dev/null
  expect "$(cut -f1,3 "$context" | grep -c "$old")" 2 "a repeated value keeps its since"
  expect "$(grep -c $'^power\tunplugged\t'"$old" "$context")" 0 "a changed value gets a new one"

  printf '%s\t%s\t%s\t%s\n' power plugged "$old" "$old" place home "$old" "$old" dnd off "$old" "$old" >"$context"
  expect "$(phone-context place || true)" unknown "a key reads unknown once the phone has been silent past the max age"
  if phone-context place >/dev/null; then echo "FAIL stale state exits 0"; fail=1; fi
  expect "$(phone-context | tail -n1)" "heard 2h 0m ago: stale, the phone may have changed since" "the full listing says it is stale"
  expect "$(phone-context --max-age 10000 place)" home "--max-age widens what counts as fresh"

  for bad in "bogus" "place dnd" "--max-age" "--max-age soon" "receive now"; do
    # shellcheck disable=SC2086
    if phone-context $bad >/dev/null 2>&1; then echo "FAIL usage accepted: $bad"; fail=1; fi
  done

  if [ "$fail" != 0 ]; then exit 1; fi
  touch $out
''
