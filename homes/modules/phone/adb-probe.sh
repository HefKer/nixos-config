if [ -n "$serial" ]; then exit 0; fi
# A phone never reached starts its day at the first run, so a new host isn't a finding at once.
[ -e "$reached" ] || touch "$reached"
since=$(stat -c %Y "$reached")
if [ $(($(date +%s) - since)) -gt $((MAX_HOURS * 3600)) ]; then
  echo "no adb connection since $(date -d "@$since" '+%F %R'); turn Wireless debugging back on"
fi
