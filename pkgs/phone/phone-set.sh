# Changes one Android setting and appends the value it replaced to the phone journal.
usage() {
  echo "usage: phone-set {global|secure|system} <key> <value|--delete>" >&2
  exit 2
}
[ $# = 3 ] || usage
ns=$1 key=$2 value=$3
case $ns in global | secure | system) ;; *) usage ;; esac
[ -n "$key" ] || usage

journal=${XDG_STATE_HOME:-$HOME/.local/state}/phone/journal.tsv
serial=${ANDROID_SERIAL:-$(phone-connect)}

# adb joins its arguments into one line for the phone's shell, so each is quoted for that shell.
quote() { printf "'%s'" "${1//\'/\'\\\'\'}"; }
settings() { adb -s "$serial" shell settings "$1" "$ns" "$(quote "$key")" "${@:2}" </dev/null; }
# Keeps one journal entry on one line whatever the value holds.
field() {
  local s=${1//\\/\\\\}
  s=${s//$'\t'/\\t}
  printf %s "${s//$'\n'/\\n}"
}

old=$(settings get)
if [ "$value" = --delete ]; then
  settings delete >/dev/null
else
  settings put "$(quote "$value")"
fi
# Read back, so the journal holds what the phone took rather than what was asked.
new=$(settings get)

mkdir -p "$(dirname "$journal")"
printf '%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "$ns" "$(field "$key")" "$(field "$old")" "$(field "$new")" >>"$journal"
echo "$ns $key: $old -> $new"

if [ "$value" != --delete ] && [ "$new" != "$value" ]; then
  echo "phone-set: the phone holds '$new', not '$value'" >&2
  exit 1
fi
