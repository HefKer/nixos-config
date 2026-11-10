# One fuzzy search over every scope's binds: niri and DMS, the desktop leader,
# qutebrowser, nvim and kanata. Each row shows the trigger beside its action, so
# searching teaches the bind. Window-manager, shell and leader rows run; app rows
# copy their trigger.
#   bind-palette        pick in fuzzel
#   bind-palette list   print the rows as TSV: scope, trigger, action, command

leader_trigger="Mod+Ctrl+Space"
leader_config="${XDG_CONFIG_HOME:-$HOME/.config}/wlr-which-key/config.yaml"

# niri prints spawn arguments shell-quoted, and spawn-sh's script as one quoted string.
niri_rows() {
  dms keybinds show niri | jq -r '
    .binds[][]
    | (.action | if startswith("spawn-sh ") then .[9:] | ltrimstr("\"") | rtrimstr("\"") | gsub("\\\\+\""; "\"")
                 elif startswith("spawn ") then .[6:]
                 else "niri msg action " + . end) as $cmd
    | [ (if (.action | test("\\bdms ")) then "shell" else "wm" end),
        .key,
        (if (.desc // "") == "" then .action else .desc end),
        $cmd ]
    | @tsv'
}

# Every leaf of the leader's menu, its keys joined after the leader's own trigger.
leader_rows() {
  [[ -r $leader_config ]] || return 0
  yq -o=json '.menu' "$leader_config" | jq -r --arg t "$leader_trigger" '
    def walk_menu($keys; $path):
      .[] | (.key | if type == "array" then .[0] else . end) as $k | .desc as $d
      | if .submenu then .submenu | walk_menu($keys + [$k]; $path + [$d | ltrimstr("+")])
        else ["leader", ([$t] + $keys + [$k] | join(" ")), (($path + [$d]) | join(" › ")), .cmd] end;
    walk_menu([]; []) | @tsv'
}

# qutebrowser's effective binds, defaults merged with binds.py, asked of the running
# instance; a closed browser is left closed and drops out of the list.
qutebrowser_rows() {
  local out sockets
  sockets=("${XDG_RUNTIME_DIR:-/run/user/$UID}"/qutebrowser/ipc-*)
  [[ -S ${sockets[0]} ]] || return 0
  out=$(mktemp)
  # shellcheck disable=SC2016
  qutebrowser ":debug-pyeval -q open('$out.tmp', 'w').write(__import__('json').dumps({m: {str(k): v for k, v in __import__('qutebrowser.config.config', fromlist=['c']).key_instance.get_bindings_for(m).items()} for m in ['normal', 'insert', 'caret', 'passthrough']})) and __import__('os').rename('$out.tmp', '$out.json')" >/dev/null 2>&1
  for _ in $(seq 20); do
    [[ -s $out.json ]] && break
    sleep 0.1
  done
  [[ -s $out.json ]] && jq -r 'to_entries[] | .key as $m | .value | to_entries[]
    | ["qutebrowser", (if $m == "normal" then .key else "\($m): \(.key)" end), .value, ""] | @tsv' "$out.json"
  rm -f "$out" "$out.json" "$out.tmp"
}

# nvim's global maps with a description; buffer-local ones stay on <leader>sk.
nvim_rows() {
  nvim --headless -i NONE +'lua
    local rows = {}
    for _, m in ipairs({ "n", "x", "i", "o" }) do
      for _, k in ipairs(vim.api.nvim_get_keymap(m)) do
        if k.desc and k.desc ~= "" then
          local lhs = vim.fn.keytrans(k.lhs)
          rows[#rows + 1] = table.concat({ "nvim", m == "n" and lhs or (m .. ": " .. lhs), k.desc:gsub("[\t\n]", " "), "" }, "\t")
        end
      end
    end
    io.stdout:write(table.concat(rows, "\n") .. "\n")' +qa 2>/dev/null
}

# kanata's held layers: Fn1 is Caps held, Fn2 is Tab inside Fn1. Aliases (@...) and
# keys mapped to themselves are skipped.
kanata_rows() {
  [[ -r $kanata_keymap ]] || return 0
  awk '
    BEGIN {
      split("bspc Backspace del Delete ret Enter esc Escape grv Grave ins Insert pgup PageUp pgdn PageDown " \
            "home Home end End lft Left left Left rght Right up Up down Down prnt PrintScreen caps CapsLock " \
            "pp Play/Pause prev PreviousTrack next NextTrack micmute MicMute mrgt MouseRight lrld ReloadKanata " \
            "menu Menu tab Tab spc Space ralt RightAlt rmet RightSuper rctl RightCtrl", n, " ")
      for (i = 1; i < length(n); i += 2) name[n[i]] = n[i + 1]
    }
    function key(k) { return (k in name) ? name[k] : toupper(k) }
    /^\(deflayermap \(fn1\)/ { layer = "Fn1"; next }
    /^\(deflayermap \(fn2\)/ { layer = "Fn1+Tab"; next }
    /^\(deflayermap/ { layer = ""; next }
    layer == "" || /^[[:space:]]*;/ { next }
    {
      sub(/\)[[:space:]]*$/, "")
      for (i = 1; i < NF; i += 2) {
        src = $i; dst = $(i + 1)
        if (dst ~ /^@/ || src == dst) continue
        printf "kanata\t%s+%s\t%s\t\n", layer, key(src), key(dst)
      }
    }' "$kanata_keymap"
}

list() {
  # Each source fails alone, so one broken reader drops one scope, not the palette.
  niri_rows || true
  leader_rows || true
  qutebrowser_rows || true
  nvim_rows || true
  kanata_rows || true
}

pick() {
  local rows idx scope trigger action cmd
  rows=$(list)
  idx=$(awk -F'\t' '{ printf "%-12s %-28s %s\n", "[" $1 "]", $2, $3 }' <<<"$rows" |
    fuzzel --dmenu --index --prompt "bind › " --width 90) || return 0
  IFS=$'\t' read -r scope trigger action cmd < <(sed -n "$((idx + 1))p" <<<"$rows")
  if [[ -n $cmd ]]; then
    # Detached, as niri's own spawn runs it.
    setsid -f sh -c "$cmd" >/dev/null 2>&1
  else
    printf '%s' "$trigger" | wl-copy
    notify-send -a "Bind palette" "$scope: $trigger" "$action (trigger copied)"
  fi
}

case "${1:-pick}" in
  pick) pick ;;
  list) list ;;
  *)
    echo "usage: bind-palette [pick|list]" >&2
    exit 2
    ;;
esac
