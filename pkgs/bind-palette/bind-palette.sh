# One fuzzy search over every scope's binds: niri and DMS, the desktop leader,
# qutebrowser, nvim, fish and kanata. Each row shows the trigger beside its action, so
# searching teaches the bind. Window-manager, shell and leader rows run; app rows
# copy their trigger. Rows the ignore file names are hidden: Alt+H hides the selected
# row, Alt+Shift+H switches to the hidden rows, where Alt+H un-hides one.
#   bind-palette                 pick in fuzzel
#   bind-palette list            print the shown rows as TSV: scope, trigger, action, command
#   bind-palette list --all      every row, ignoring the ignore file
#   bind-palette list --hidden   the hidden rows, each with what hides it as a fifth field

# Every reader's rows go through this: tabs and newlines inside a field become spaces, and no escaping, which @tsv adds and the shell would keep.
tsv='map(. // "" | tostring | gsub("[\t\n]"; " ")) | join("\t")'
leader_config="${XDG_CONFIG_HOME:-$HOME/.config}/wlr-which-key/config.yaml"
# dots: bind-palette/. Blank lines and # comments aside, each line is a scope and a trigger
# joined by a tab, hiding that row, or ~ and an extended regex matched against the row's
# scope, trigger and action joined by tabs.
ignore_file="${XDG_CONFIG_HOME:-$HOME/.config}/bind-palette/ignore"

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
    | '"$tsv"
}

# Every leaf of the leader's menu, its keys joined after the trigger niri binds to wlr-which-key.
leader_rows() {
  [[ -r $leader_config ]] || return 0
  local trigger
  trigger=$(dms keybinds show niri | jq -r '[.binds[][] | select(.action | test("^spawn wlr-which-key"))][0].key // "Mod+Ctrl+Space"')
  yq -o=json '.menu' "$leader_config" | jq -r --arg t "$trigger" '
    def walk_menu($keys; $path):
      .[] | (.key | if type == "array" then .[0] else . end) as $k | .desc as $d
      | if .submenu then .submenu | walk_menu($keys + [$k]; $path + [$d | ltrimstr("+")])
        else ["leader", ([$t] + $keys + [$k] | join(" ")), (($path + [$d]) | join(" › ")), .cmd] end;
    walk_menu([]; []) | '"$tsv"
}

# qutebrowser's effective binds, which its config.py writes on every load (dots: bindsdump.py); asking the running browser over IPC would raise its window.
qutebrowser_rows() {
  local binds="${XDG_CACHE_HOME:-$HOME/.cache}/qutebrowser/binds.json"
  [[ -r $binds ]] || return 0
  jq -r 'to_entries[] | .key as $m | .value | to_entries[]
    | ["qutebrowser", (if $m == "normal" then .key else "\($m): \(.key)" end), .value, ""] | '"$tsv" "$binds"
}

# nvim's global maps with a description; buffer-local ones stay on <leader>sk.
nvim_rows() {
  nvim --headless -i NONE +'lua
    local rows = {}
    for _, m in ipairs({ "n", "x", "i", "o", "t", "c" }) do
      for _, k in ipairs(vim.api.nvim_get_keymap(m)) do
        if k.desc and k.desc ~= "" then
          local lhs = vim.fn.keytrans(k.lhs)
          rows[#rows + 1] = table.concat({ "nvim", m == "n" and lhs or (m .. ": " .. lhs), k.desc:gsub("[\t\n]", " "), "" }, "\t")
        end
      end
    end
    io.stdout:write(table.concat(rows, "\n") .. "\n")' +qa 2>/dev/null
}

# The fish scope: a hand-picked list (dots: fish/binds.tsv), not every preset. A row whose key fish no longer binds in vi insert mode is dropped; a trigger with a space describes a gesture (Tab after `cmd -`) and always stays.
fish_rows() {
  local list="${XDG_CONFIG_HOME:-$HOME/.config}/fish/binds.tsv" live
  [[ -r $list ]] || return 0
  # Binds load at the first prompt, which never comes: run its setup by hand, which also prints terminal codes, so the binds come out on fd 3. The key follows `-M insert` in each `bind` line.
  live=$(fish -ic '__fish_config_interactive; bind -M insert >&3' 3>&1 </dev/null >/dev/null 2>&1 |
    awk '$1 == "bind" { for (i = 2; i < NF; i++) if ($i == "-M") { print $(i + 2); break } }')
  # Through the environment, since -v would read the keys' backslashes as escapes.
  live=$live awk -F'\t' '
    BEGIN { n = split(ENVIRON["live"], keys, "\n"); for (i = 1; i <= n; i++) bound[keys[i]] }
    /^#/ || NF < 2 { next }
    { key = tolower($1); gsub(/\+/, "-", key) }
    $1 ~ / / || key in bound { printf "fish\t%s\t%s\t\n", $1, $2 }' "$list"
}

# kanata's home-row mods and held layers: Fn1 is Caps held, Fn2 is Tab inside Fn1. Aliases (@...) and keys mapped to themselves are skipped.
kanata_rows() {
  [[ -r $kanata_keymap ]] || return 0
  awk '
    BEGIN {
      split("bspc Backspace del Delete ret Enter esc Escape grv Grave ins Insert pgup PageUp pgdn PageDown " \
            "home Home end End lft Left left Left rght Right up Up down Down prnt PrintScreen caps CapsLock " \
            "pp Play/Pause prev PreviousTrack next NextTrack micmute MicMute mrgt MouseRight lrld ReloadKanata " \
            "menu Menu tab Tab spc Space ralt RightAlt rmet RightSuper rctl RightCtrl " \
            "lmet Super lalt Alt lctl Ctrl lsft Shift rsft Shift", pairs, " ")
      for (i = 1; i < length(pairs); i += 2) name[pairs[i]] = pairs[i + 1]
    }
    function key(k) { return (k in name) ? name[k] : toupper(k) }
    # A home-row mod alias: hra (t! hrm a lmet $left-mods), several per line.
    /\(t! hrm / {
      line = $0
      while (match(line, /\(t! hrm [^ ]+ [^ ]+/)) {
        split(substr(line, RSTART + 8, RLENGTH - 8), hr, " ")
        printf "kanata\tHold %s\t%s\t\n", key(hr[1]), key(hr[2])
        line = substr(line, RSTART + RLENGTH)
      }
      next
    }
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

all_rows() {
  # Each source fails alone, so one broken reader drops one scope, not the palette.
  niri_rows || true
  leader_rows || true
  qutebrowser_rows || true
  nvim_rows || true
  fish_rows || true
  kanata_rows || true
}

# The ignore file's lines that apply. A pattern that doesn't compile is reported on stderr and skipped, so it hides nothing rather than ending the filter.
ignore_lines() {
  [[ -r $ignore_file ]] || return 0
  local line
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    [[ -z $line || $line == '#'* ]] && continue
    # Through the environment, as the filter reads it, so the backslashes mean the same.
    if [[ $line == '~'* ]] && ! re=${line:1} gawk 'BEGIN { if ("" ~ ENVIRON["re"]) {} }' 2>/dev/null; then
      echo "bind-palette: invalid pattern skipped: $line" >&2
      continue
    fi
    printf '%s\n' "$line"
  done <"$ignore_file"
}

# Rows on stdin. shown prints those no line hides; hidden prints the others, with a fifth field: "row" for an exact-row line, or the ~pattern.
classify() {
  local rules
  rules=$(ignore_lines)
  rules=$rules gawk -F'\t' -v OFS='\t' -v view="$1" '
    BEGIN {
      n = split(ENVIRON["rules"], r, "\n")
      for (i = 1; i <= n; i++)
        if (substr(r[i], 1, 1) == "~") pat[++np] = substr(r[i], 2)
        else if (r[i] != "") exact[r[i]]
    }
    {
      by = ""
      if (($1 "\t" $2) in exact) by = "row"
      else for (i = 1; i <= np; i++) if (($1 "\t" $2 "\t" $3) ~ pat[i]) { by = "~" pat[i]; break }
    }
    view == "shown" && by == "" { print; next }
    view == "hidden" && by != "" { print $1, $2, $3, $4, by }'
}

list() {
  case "${1:-}" in
    "") all_rows | classify shown ;;
    --all) all_rows ;;
    --hidden) all_rows | classify hidden ;;
    *) usage ;;
  esac
}

hide() {
  mkdir -p "$(dirname "$ignore_file")"
  # A last line without its newline would swallow the new one.
  if [[ -s $ignore_file && -n $(tail -c1 "$ignore_file") ]]; then echo >>"$ignore_file"; fi
  # Appending, and the rewrite in unhide, write through the link into dots.
  printf '%s\t%s\n' "$1" "$2" >>"$ignore_file"
}

unhide() {
  local rest
  rest=$(line="$1"$'\t'"$2" gawk '{ l = $0; sub(/\r$/, "", l) } l != ENVIRON["line"]' "$ignore_file")
  if [[ -n $rest ]]; then printf '%s\n' "$rest" >"$ignore_file"; else : >"$ignore_file"; fi
}

pick() {
  local all rows view=shown sel=0 prompt hint idx rc row scope trigger action cmd by errs
  errs=$(ignore_lines 2>&1 >/dev/null)
  [[ -z $errs ]] || notify-send -a "Bind palette" "Ignore file: pattern skipped" "$errs"
  # Read once: the readers are the slow part, and a hide only reclassifies.
  all=$(all_rows)
  while true; do
    rows=$(classify "$view" <<<"$all")
    if [[ $view == shown ]]; then
      prompt="bind › " hint="Alt+H hide · Alt+Shift+H hidden"
    else
      prompt="hidden › " hint="Alt+H un-hide · Alt+Shift+H back"
    fi
    # custom-1 and custom-2 exit 10 and 11 with the row; set here, so fuzzel's other callers keep its defaults. The other custom-N keys stay on Alt+3.. and cancel.
    rc=0
    idx=$(awk -F'\t' '{ printf "%-12s %-28s %s%s\n", "[" $1 "]", $2, $3, ($5 ~ /^~/ ? "   ⟵ " $5 : "") }' <<<"$rows" |
      fuzzel --dmenu --index --prompt "$prompt" --placeholder "$hint" --width 90 --select-index "$sel" \
        --override=key-bindings.custom-1=Mod1+h --override=key-bindings.custom-2=Mod1+Shift+h) || rc=$?
    case $rc in
      0 | 10) ;;
      11)
        if [[ $view == shown ]]; then
          if [[ -z $(classify hidden <<<"$all") ]]; then
            notify-send -a "Bind palette" "Nothing hidden" "Alt+H on a row hides it"
          else
            view=hidden
          fi
        else
          view=shown
        fi
        sel=0
        continue
        ;;
      *) return 0 ;;
    esac
    # Typed text matching no row comes back as -1.
    [[ -n $idx ]] && ((idx >= 0)) || return 0
    row=$(sed -n "$((idx + 1))p" <<<"$rows")
    # cut, not read: read collapses runs of tabs, which shifts an empty field.
    scope=$(cut -f1 <<<"$row")
    trigger=$(cut -f2 <<<"$row")
    action=$(cut -f3 <<<"$row")
    cmd=$(cut -f4 <<<"$row")
    if ((rc == 10)); then
      # The palette reopens on the row after, so several can go one after another.
      sel=$idx
      if [[ $view == shown ]]; then
        hide "$scope" "$trigger"
      else
        by=$(cut -f5 <<<"$row")
        if [[ $by == row ]]; then
          unhide "$scope" "$trigger"
          # The last one un-hidden leaves nothing to show here.
          [[ -n $(classify hidden <<<"$all") ]] || view=shown sel=0
        else
          notify-send -a "Bind palette" "Hidden by a pattern" "$by"$'\n'"Edit $ignore_file to show it"
        fi
      fi
      continue
    fi
    if [[ -n $cmd ]]; then
      # Detached, as niri's own spawn runs it.
      setsid -f sh -c "$cmd" >/dev/null 2>&1
    else
      printf '%s' "$trigger" | wl-copy
      notify-send -a "Bind palette" "$scope: $trigger" "$action (trigger copied)"
    fi
    return 0
  done
}

usage() {
  echo "usage: bind-palette [pick | list [--all | --hidden]]" >&2
  exit 2
}

case "${1:-pick}" in
  pick) pick ;;
  list) list "${2:-}" ;;
  *) usage ;;
esac
