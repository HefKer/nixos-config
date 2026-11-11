# Prints the adb serial of the phone, connecting over Tailscale first if needed.
# The phone is the tailnet's online Android peer, unless PHONE_HOST names one.
if [ -n "${PHONE_HOST:-}" ]; then
  host=$PHONE_HOST
  ip=$(tailscale ip -4 "$host") || { echo "phone-connect: $host not on the tailnet" >&2; exit 1; }
else
  host="the Android peer"
  ip=$(tailscale status --json | jq -r '[.Peer[] | select(.OS == "android" and .Online)][0].TailscaleIPs[0] // empty')
  [ -n "$ip" ] || { echo "phone-connect: no online Android peer on the tailnet" >&2; exit 1; }
fi

ready() { [ "$(timeout 5 adb -s "$1" get-state 2>/dev/null)" = device ]; }

# Drop dead entries left by a reboot or a port change, so `adb devices` stays unambiguous.
adb devices | awk -v ip="$ip" 'index($1, ip ":") == 1 && $2 != "device" {print $1}' |
  while read -r stale; do adb disconnect "$stale" >/dev/null; done

fixed="$ip:5555"
timeout 5 adb connect "$fixed" >/dev/null 2>&1
if ready "$fixed"; then echo "$fixed"; exit 0; fi

# Wireless debugging listens on a random port that changes whenever it restarts.
ports=$(nmap -Pn -sT -T4 --open -p 30000-65535 "$ip" -oG - | grep -o '[0-9]*/open' | cut -d/ -f1)
for port in $ports; do
  serial="$ip:$port"
  timeout 5 adb connect "$serial" >/dev/null 2>&1
  if ready "$serial"; then
    adb -s "$serial" tcpip 5555 >/dev/null
    for _ in 1 2 3 4 5; do
      sleep 1
      timeout 5 adb connect "$fixed" >/dev/null 2>&1
      if ready "$fixed"; then echo "$fixed"; exit 0; fi
    done
    echo "$serial"
    exit 0
  fi
  adb disconnect "$serial" >/dev/null 2>&1
done

echo "phone-connect: no adb on $host; Wireless debugging is off or the phone left Wi-Fi" >&2
exit 1
