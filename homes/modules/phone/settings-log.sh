[ -n "$serial" ] || exit 0
log=$state/settings-changes.tsv
touch "$log"
history=$(adb -s "$serial" shell settings get system settings_change_history </dev/null) || exit 0

# Entries are `<epoch ms>|<key>|<package>` joined by `;`, newest first; the phone's own stamp makes each one unique.
tr ';' '\n' <<<"$history" | tac | while IFS='|' read -r ms key package; do
  case $ms in "" | *[!0-9]*) continue ;; esac
  line=$(printf '%s.%03dZ\t%s\t%s' "$(date -u -d "@$((ms / 1000))" +%FT%T)" "$((ms % 1000))" "$key" "$package")
  grep -qxF -- "$line" "$log" || printf '%s\n' "$line" >>"$log"
done
