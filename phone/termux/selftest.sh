#!/data/data/com.termux/files/usr/bin/bash
# Prints one line proving the chain from Tasker through Termux to Termux:API: battery, Wi-Fi, and whether the delivered scripts are readable.
set -euo pipefail

# Termux:API commands print one JSON key per line; without the Termux:API app they hang, hence the timeout.
field() { sed -n "s/^ *\"$1\": *\"\{0,1\}\([^\",]*\).*/\1/p" <<<"$2" | head -n1; }

if battery=$(timeout 5 termux-battery-status 2>/dev/null) && [ -n "$(field percentage "$battery")" ]; then
  status=$(field status "$battery")
  line="battery $(field percentage "$battery")% ${status,,}"
else
  line="battery unknown (Termux:API did not answer)"
fi

if wifi=$(timeout 5 termux-wifi-connectioninfo 2>/dev/null) && [ "$(field supplicant_state "$wifi")" = COMPLETED ]; then
  line+=", wifi $(field ssid "$wifi") $(field rssi "$wifi") dBm"
else
  line+=", wifi off"
fi

if [ -r "${TERMUX_SCRIPTS_SOURCE:-}/run.sh" ]; then
  line+=", scripts in sync"
else
  line+=", delivered scripts unreadable"
fi
echo "$line"
