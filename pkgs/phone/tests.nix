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

  phone = callPackage ./. {
    android-tools = fakeAdb;
    tailscale = null;
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

  if [ "$fail" != 0 ]; then exit 1; fi
  touch $out
''
