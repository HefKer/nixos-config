# Prints the phone context as this host last heard it; `phone-context receive` records one post from the phone.
export LC_ALL=C
file=${XDG_STATE_HOME:-$HOME/.local/state}/phone/context.tsv
max_age=2700

usage() {
  echo "usage: phone-context [--max-age SECONDS] [power|place|dnd]" >&2
  echo "       phone-context receive   (one HTTP request on stdin, from the socket unit)" >&2
  exit 2
}

# Answers the request and ends; a refusal is logged with what was sent, and still exits 0 so no failed unit is left behind.
reply() {
  printf 'HTTP/1.1 %s\r\nContent-Type: text/plain\r\nContent-Length: %s\r\nConnection: close\r\n\r\n%s\n' \
    "$1" "$((${#2} + 1))" "$2"
  if [ "$1" != "200 OK" ]; then
    printf 'phone-context: refused a post from %s: %s (%q)\n' "${REMOTE_ADDR:-?}" "$2" "${body-}" >&2
  fi
  exit 0
}

receive() {
  local line method path len="" os pair key value now next since
  local -a pairs
  local -A got=()

  IFS= read -r -t 10 line || exit 0
  read -r method path _ <<<"${line%$'\r'}"
  while IFS= read -r -t 10 line; do
    line=${line%$'\r'}
    [ -n "$line" ] || break
    case ${line,,} in
      content-length:*) len=${line#*:} len=${len// /} ;;
    esac
  done

  [ "$path" = /context ] || reply "404 Not Found" "no such path"
  [ "$method" = POST ] || reply "405 Method Not Allowed" "POST only"
  case $len in
    "" | *[!0-9]* | ????*) reply "400 Bad Request" "Content-Length missing or too long" ;;
  esac
  [ "$len" -le 128 ] || reply "413 Content Too Large" "body over 128 bytes"
  IFS= read -r -N "$len" -t 10 body || reply "400 Bad Request" "body shorter than its Content-Length"

  # Tailscale vouches for the sender's address, so the peer's OS identifies the phone as phone-connect does.
  os=$(tailscale whois --json "${REMOTE_ADDR:-}" 2>/dev/null | jq -r '.Node.Hostinfo.OS // empty') || os=
  [ "$os" = android ] || reply "403 Forbidden" "sender is not the phone"

  case $body in *[!a-z=\&]*) reply "400 Bad Request" "unknown key or value" ;; esac
  IFS='&' read -r -a pairs <<<"$body"
  for pair in "${pairs[@]}"; do
    case $pair in
      power=plugged | power=unplugged | place=home | place=away) key=${pair%%=*} value=${pair#*=} ;;
      interrupt=all) key=dnd value=off ;;
      interrupt=priority | interrupt=alarms) key=dnd value=${pair#*=} ;;
      interrupt=none) key=dnd value=silence ;;
      *) reply "400 Bad Request" "unknown key or value" ;;
    esac
    [ -z "${got[$key]-}" ] || reply "400 Bad Request" "repeated key"
    got[$key]=$value
  done
  [ "${#got[@]}" = 3 ] || reply "400 Bad Request" "power, place and interrupt are all required"

  now=$(date -u +%FT%TZ)
  mkdir -p "${file%/*}"
  next=$(mktemp "$file.XXXXXX")
  for key in power place dnd; do
    since=$(awk -F'\t' -v k="$key" -v v="${got[$key]}" '$1 == k && $2 == v { print $3 }' "$file" 2>/dev/null) || since=
    printf '%s\t%s\t%s\t%s\n' "$key" "${got[$key]}" "${since:-$now}" "$now"
  done >"$next"
  mv "$next" "$file"
  reply "200 OK" "recorded"
}

# 93784 -> "1d 2h", 7500 -> "2h 5m", 59 -> "0m"
span() {
  local s=$1
  if [ "$s" -ge 86400 ]; then
    echo "$((s / 86400))d $((s % 86400 / 3600))h"
  elif [ "$s" -ge 3600 ]; then
    echo "$((s / 3600))h $((s % 3600 / 60))m"
  else
    echo "$((s / 60))m"
  fi
}

show() {
  local want=$1 now key value since heard age found=""
  now=$(date +%s)
  if [ ! -s "$file" ]; then
    echo "phone-context: nothing heard from the phone yet" >&2
    [ -z "$want" ] || echo unknown
    exit 1
  fi
  while IFS=$'\t' read -r key value since heard; do
    age=$((now - $(date -d "$heard" +%s)))
    if [ -z "$want" ]; then
      printf '%s\t%s\tfor %s\n' "$key" "$value" "$(span $((now - $(date -d "$since" +%s))))"
    elif [ "$key" = "$want" ]; then
      found=$value
    fi
  done <"$file"
  if [ "$age" -gt "$max_age" ]; then
    if [ -z "$want" ]; then echo "heard $(span "$age") ago: stale, the phone may have changed since"; else echo unknown; fi
    exit 1
  fi
  if [ -z "$want" ]; then echo "heard $(span "$age") ago"; else echo "$found"; fi
}

want=""
while [ $# -gt 0 ]; do
  case $1 in
    receive)
      [ $# = 1 ] || usage
      receive
      ;;
    --max-age)
      case ${2-} in "" | *[!0-9]*) usage ;; esac
      max_age=$2
      shift
      ;;
    power | place | dnd)
      [ -z "$want" ] || usage
      want=$1
      ;;
    *) usage ;;
  esac
  shift
done
show "$want"
