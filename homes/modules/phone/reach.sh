# Shared opening of each script here: $serial is empty when the phone is out of reach, and $unreached dates the first miss since it was last reached.
state=${XDG_STATE_HOME:-$HOME/.local/state}/phone
unreached=$state/unreached-since
mkdir -p "$state"
serial=$(timeout 60 phone-connect 2>/dev/null) || serial=
if [ -n "$serial" ]; then
  rm -f "$unreached"
elif [ ! -e "$unreached" ]; then
  touch "$unreached"
fi
