#!/data/data/com.termux/files/usr/bin/bash
# Runs one Termux script by name, after bringing this directory up to date with the delivered copy.
# Tasker's only way in: the name is the single argument, and data for the script arrives on stdin.
set -euo pipefail

export TERMUX_SCRIPTS_SOURCE=${TERMUX_SCRIPTS_SOURCE:-/sdcard/Sync/polaris/.polaris/termux}
here=$(dirname "$(realpath "$0")")

# A source without run.sh is a folder that is missing, unreadable or half synced: keep what is installed.
if [ -r "$TERMUX_SCRIPTS_SOURCE/run.sh" ]; then
  for delivered in "$TERMUX_SCRIPTS_SOURCE"/*.sh; do
    installed=$here/${delivered##*/}
    if ! cmp -s "$delivered" "$installed"; then
      # Renamed into place, so the copy of run.sh that bash is reading stays whole.
      cp "$delivered" "$installed.new"
      chmod 700 "$installed.new"
      mv -f "$installed.new" "$installed"
    fi
  done
  for installed in "$here"/*.sh; do
    [ -e "$TERMUX_SCRIPTS_SOURCE/${installed##*/}" ] || rm -f "$installed"
  done
fi

name=${1:-}
if [ $# != 1 ] || [[ ! $name =~ ^[a-z0-9][a-z0-9-]*$ ]] || [ "$name" = run ] || [ ! -f "$here/$name.sh" ]; then
  echo "run: no Termux script named '$name'" >&2
  exit 64
fi
exec bash "$here/$name.sh"
