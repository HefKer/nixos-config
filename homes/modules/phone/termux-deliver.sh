# Mirrors the Termux scripts in $1 into $2, the vault directory Syncthing carries to the phone, where run.sh installs them.
src=$1 dest=$2
# Creating the vault here would hand Syncthing an empty folder to sync out.
[ -d "$(dirname "$dest")" ] || { echo "phone-termux-deliver: $(dirname "$dest") is missing; nothing delivered" >&2; exit 0; }
mkdir -p "$dest"

for script in "$src"/*.sh; do
  delivered=$dest/${script##*/}
  if ! cmp -s "$script" "$delivered"; then
    # Syncthing ignores *.tmp, so the phone never sees a half-written script.
    install -m644 "$script" "$delivered.tmp"
    mv -f "$delivered.tmp" "$delivered"
  fi
done
for delivered in "$dest"/*.sh; do
  [ -e "$src/${delivered##*/}" ] || rm -f "$delivered"
done
