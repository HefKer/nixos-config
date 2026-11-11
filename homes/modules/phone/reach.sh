# Shared opening of every host-driven phone automation: $serial is empty when the phone is out of reach.
state=${XDG_STATE_HOME:-$HOME/.local/state}/phone
reached=$state/last-reached
mkdir -p "$state"
serial=$(timeout 180 phone-connect 2>/dev/null) || serial=
if [ -n "$serial" ]; then touch "$reached"; fi
