{
  callPackage,
  coreutils,
  fuzzel,
  kanata,
  gawk,
  git,
  jq,
  lib,
  libnotify,
  symlinkJoin,
  ttyper,
  writers,
  writeShellApplication,
  keymapDir,
  ports,
  defcfg,
}:
let
  sim = callPackage ../kanata-sim { inherit kanata; };

  flag = writeShellApplication {
    name = "kanata-flag";
    runtimeInputs = [
      coreutils
      fuzzel
      gawk
      git
      jq
      libnotify
    ];
    text = ''
      keymap_dir=${lib.escapeShellArg keymapDir}
      log=$keymap_dir/misfires.md

      ask() { fuzzel --dmenu --prompt-only "$1: "; }
      meant=$(ask "meant to type") || exit 0
      got=$(ask "got") || exit 0

      # kanata greets each TCP connection with its current layer.
      layer() {
        (
          exec 3<>"/dev/tcp/127.0.0.1/$1"
          read -r -t 1 line <&3
          jq -r '.LayerChange.new' <<<"$line"
        ) 2>/dev/null || echo "?"
      }
      layers=""
      ${lib.concatMapAttrsStringSep "\n" (
        name: port: ''layers+=" ${name}=$(layer ${toString port})"''
      ) ports}

      if rev=$(git -C "$keymap_dir" rev-parse --short HEAD 2>/dev/null); then
        git -C "$keymap_dir" diff --quiet HEAD -- keymap.kbd || rev+="-dirty"
      else
        rev="?"
      fi

      entry="- $(date '+%F %H:%M') · meant \`$meant\` · got \`$got\` · layers$layers · keymap $rev"

      [ -e "$log" ] || printf '# Kanata misfires\n\n## Open\n\n## Resolved\n' >"$log"
      # New entries go at the end of Open, above the blank lines before Resolved.
      ENTRY=$entry awk '
        !NF { blanks++; next }
        /^## Resolved/ && !done {
          if (last ~ /^#/) print ""
          print ENVIRON["ENTRY"]
          done = 1
        }
        { while (blanks) { print ""; blanks-- } print; last = $0 }
        END { if (!done) print ENVIRON["ENTRY"] }
      ' "$log" >"$log.tmp"
      mv "$log.tmp" "$log"
      notify-send -a kanata "Misfire flagged" "$meant → $got"
    '';
  };

  test = writers.writePython3Bin "kanata-test" { } (
    lib.replaceStrings [ "@sim@" "@defcfg@" "@keymapDir@" "@wordLists@" ]
      # JSON strings and lists are Python literals.
      (map builtins.toJSON [
        (lib.getExe sim)
        defcfg
        keymapDir
        [ "${ttyper.src}/resources/runtime/language/english1000" ]
      ])
      (builtins.readFile ./kanata-test.py)
  );

  typetest = writeShellApplication {
    name = "kanata-typetest";
    runtimeInputs = [ ttyper ];
    text = ''
      exec ttyper --language-file ${lib.escapeShellArg "${keymapDir}/tests/hrm-words.txt"} --words 40 "$@"
    '';
  };
in
symlinkJoin {
  name = "kanata-misfires";
  paths = [
    flag
    test
    typetest
  ];
  meta.mainProgram = "kanata-flag";
}
