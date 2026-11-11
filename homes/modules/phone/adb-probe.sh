[ -e "$unreached" ] || exit 0
# Counted from the first miss, not the last success, so a host that was off for a day doesn't report on its first try.
since=$(stat -c %Y "$unreached")
if [ $(($(date +%s) - since)) -gt 86400 ]; then
  echo "no adb connection since $(date -d "@$since" '+%F %R'); check Wireless debugging and Tailscale on the phone"
fi
