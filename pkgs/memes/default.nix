{
  callPackage,
  coreutils,
  curl,
  ffmpeg,
  findutils,
  fuzzel,
  gawk,
  glib,
  gnugrep,
  gnused,
  jq,
  lib,
  libnotify,
  pipewire,
  symlinkJoin,
  tesseract,
  wl-clipboard,
  wtype,
  writeShellApplication,
  yt-dlp,
  library,
  # The PipeWire sink whose loopback is the soundboard mic voice chat records from.
  sink,
  # A file holding a Klipy API key, for Klipy GIF pages.
  klipyKey,
}:
let
  repeat = callPackage ../repeat { };
  thumbSize = 64;
  sounds = "${library}/sounds";
  # sound-pick writes the PIDs of what it is playing here, and sound-stop kills them.
  pids = ''"''${XDG_RUNTIME_DIR:-/tmp}/sound-pick.pids"'';
  # sound-volume writes "<call %> <you %>" here and sound-pick reads it on every pick; per machine, as mics differ.
  volumeFile = ''"''${XDG_CONFIG_HOME:-$HOME/.config}/memes/sound-volume"'';
  defaultVolume = "20 20";

  # Shared by both commands: the picker makes any thumbnail or OCR text the other machine's meme-add made.
  thumb = ''
    library=${lib.escapeShellArg library}
    thumbs=''${XDG_CACHE_HOME:-$HOME/.cache}/memes/thumbs
    # Fuzzel draws only png and svg icons, so a gif or video shows its first frame.
    thumb() {
      local t
      t="$thumbs/$(basename "$1").png"
      if [ "$1" -nt "$t" ]; then
        mkdir -p "$thumbs"
        ffmpeg -loglevel error -y -i "$1" -frames:v 1 \
          -vf "scale=${toString thumbSize}:${toString thumbSize}:force_original_aspect_ratio=decrease" "$t" || true
      fi
      printf '%s' "$t"
    }
    # A 256-bit difference hash of the first frame, as 64 hex digits: one bit per neighbouring pair of a 17x16 grey thumbnail.
    dhash() {
      ffmpeg -loglevel error -i "$1" -frames:v 1 -vf scale=17:16:flags=area,format=gray -f rawvideo - 2>/dev/null |
        od -An -v -tu1 | awk '
          { for (i = 1; i <= NF; i++) v[n++] = $i }
          END {
            if (n < 272) exit 1
            for (r = 0; r < 16; r++) for (c = 0; c < 16; c += 4) {
              x = 0
              for (k = 0; k < 4; k++) x = x * 2 + (v[r * 17 + c + k] < v[r * 17 + c + k + 1])
              printf "%x", x
            }
            print ""
          }'
    }
    # Prints the library meme that looks like $1, if any: within 16 of 256 bits, so recompressed or resized copies match.
    find_dup() {
      local h f c hashes=''${XDG_CACHE_HOME:-$HOME/.cache}/memes/hashes
      h=$(dhash "$1") || return 1
      mkdir -p "$hashes"
      for f in "$library"/*; do
        [ -f "$f" ] || continue
        c="$hashes/$(basename "$f").hash"
        [ "$f" -ot "$c" ] || dhash "$f" >"$c" || true
        printf '%s\t%s\n' "$(cat "$c")" "$f"
      done | awk -F '\t' -v h="$h" '
        BEGIN { for (i = 0; i < 16; i++) { x = i; b = 0; while (x) { b += x % 2; x = int(x / 2) } bits[sprintf("%x", i)] = b } }
        length($1) == 64 {
          d = 0
          for (i = 1; i <= 64; i++) d += bits[sprintf("%x", xor(strtonum("0x" substr($1, i, 1)), strtonum("0x" substr(h, i, 1))))]
          if (d <= 16 && (best == "" || d < bestd)) { best = $2; bestd = d }
        }
        END { if (best == "") exit 1; print best }'
    }
    # Prints $1, or over 20 MB a copy in the cache shrunk until it fits a Discord upload; the library keeps the original.
    small() {
      local limit=$((20 * 1000 * 1000)) dir out w dur kbps ext
      if [ "$(stat -c %s "$1")" -le "$limit" ]; then
        printf '%s' "$1"
        return
      fi
      dir=''${XDG_CACHE_HOME:-$HOME/.cache}/memes/small
      mkdir -p "$dir"
      ext=$(tr '[:upper:]' '[:lower:]' <<<"''${1##*.}")
      case $ext in
        gif) out="$dir/$(basename "$1")" ;;
        mp4 | webm | mkv | mov) out="$dir/$(basename "''${1%.*}").mp4" ;;
        *) out="$dir/$(basename "''${1%.*}").jpg" ;;
      esac
      if [ "$1" -nt "$out" ]; then
        notify-send -a memes -t 3000 "Shrinking meme" "$(basename "$1") is over 20 MB" || true
        case $ext in
          gif)
            # Fewer frames, colours and pixels until it fits; a gif's size has no bitrate to aim at.
            for w in 480 360 270 200; do
              ffmpeg -loglevel error -y -i "$1" -vf "fps=15,scale='min(iw,$w)':-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer" \
                "$out" || return 1
              [ "$(stat -c %s "$out")" -gt "$limit" ] || break
            done
            ;;
          mp4 | webm | mkv | mov)
            # A video bitrate that lands at 90% of the limit over its length, after 96k of audio.
            dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$1")
            kbps=$(awk -v l="$limit" -v d="$dur" 'BEGIN { k = int(l * 8 * 0.9 / 1000 / d) - 96; print (k < 100 ? 100 : k) }')
            ffmpeg -loglevel error -y -i "$1" -vf "scale='min(iw,1280)':-2" -c:v libx264 -preset slow \
              -b:v "''${kbps}k" -maxrate "''${kbps}k" -bufsize "$((kbps * 2))k" -c:a aac -b:a 96k -movflags +faststart "$out" || return 1
            ;;
          *) ffmpeg -loglevel error -y -i "$1" -vf "scale='min(iw,2560)':-2" -q:v 3 "$out" || return 1 ;;
        esac
      fi
      printf '%s' "$out"
    }
    # The meme's text, read once and kept beside it for meme-pick to search: .<name>.<ext>.txt, one lowercase line.
    ocr() {
      local t f
      t="$(dirname "$1")/.$(basename "$1").txt"
      [ ! -e "$t" ] || return 0
      f=$(mktemp --suffix .png)
      # Through ffmpeg so a gif, webp or video is read from its first frame.
      if ffmpeg -loglevel error -y -i "$1" -frames:v 1 "$f"; then
        tesseract "$f" - 2>/dev/null | tr -s '[:space:][:cntrl:]' ' ' | tr '[:upper:]' '[:lower:]' >"$t" || true
      fi
      rm -f -- "$f"
    }
  '';

  # Shared by both pickers: puts $1 on the clipboard as a file reference, pasting it too when $2 is --paste after $3 seconds.
  clip = ''
    clip() {
      # A file reference, not the bytes: the one form Discord, Signal and WhatsApp all take for every format.
      printf 'file://%s\r\n' "$1" | wl-copy --type text/uri-list
      if [ "$2" = --paste ]; then
        # Focus returning from fuzzel, or the repeat key's Mod lifting, else the app sees Super+Ctrl+V.
        sleep "$3"
        wtype -M ctrl v -m ctrl
      fi
    }
  '';

  # Shared by both savers: the clipboard as the default source, and tags asked in fuzzel turned into a free path.
  saving = app: ''
    src=''${1:-$(wl-paste --no-newline 2>/dev/null || true)}
    fail() { notify-send -a memes "${app} not saved" "$1"; exit 1; }
    [ -n "$src" ] || fail "no URL or file given, and the clipboard is empty"

    tmp=$(mktemp -d)
    # A download can take seconds before the tags prompt, so a notification says it is underway until then.
    cue=""
    uncue() {
      [ -z "$cue" ] || gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.CloseNotification "$cue" >/dev/null 2>&1 || true
      cue=""
    }
    trap 'uncue; rm -rf "$tmp"' EXIT
    [ -f "$src" ] || cue=$(notify-send -p -t 0 -a memes "Fetching ${lib.toLower app}…" "$src" || true)

    # Prints a free path in $1 for tags asked in fuzzel, seeded from the title $2; fails when fuzzel is cancelled.
    tagged_path() {
      local suggest tags name n f
      # The suggestion is the page's title with repeated words dropped; Tenor slugs repeat a lot.
      suggest=$(tr -cs '[:alnum:]' '\n' <<<"$2" | tr '[:upper:]' '[:lower:]' | awk 'NF && !seen[$0]++' | paste -sd ' ')
      uncue
      tags=$(fuzzel --dmenu --prompt-only "tags: " --search "$suggest") || return 1
      # Names keep to [a-z0-9-] so the picker's file:// URIs need no escaping.
      name=$(tr '[:upper:]' '[:lower:]' <<<"$tags" | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-200)
      [ -n "$name" ] || name=meme
      mkdir -p "$1"
      # Repeated tags number all of their files, whatever the extension: name-1.jpg, name-2.png, ...
      n=$(find "$1" -maxdepth 1 -type f -regextype posix-extended -regex ".*/$name(-[0-9]+)?\.[^.]+" -printf '%f\n' |
        sed -E "s/^$name-?//; s/\.[^.]+$//; s/^$/0/" | sort -n | tail -1)
      if [ -z "$n" ]; then
        printf '%s' "$1/$name.$3"
        return
      fi
      # An unnumbered one, saved before there was a second, takes the next number along with its hidden .url and .txt.
      for f in "$1/$name".*; do
        [ -f "$f" ] || continue
        n=$((n + 1))
        mv -n -- "$f" "$1/$name-$n.''${f##*.}"
        for side in url txt; do
          [ ! -e "$1/.$(basename "$f").$side" ] || mv -n -- "$1/.$(basename "$f").$side" "$1/.$name-$n.''${f##*.}.$side"
        done
      done
      printf '%s' "$1/$name-$((n + 1)).$3"
    }
  '';
  savingInputs = [
    coreutils
    ffmpeg
    fuzzel
    gawk
    glib
    gnused
    libnotify
    repeat
    wl-clipboard
    yt-dlp
  ];

  add = writeShellApplication {
    name = "meme-add";
    runtimeInputs = savingInputs ++ [
      curl
      gnugrep
      jq
      tesseract
    ];
    text = ''
      ${thumb}
      ${saving "Meme"}
      ua="Mozilla/5.0 (X11; Linux x86_64)"

      if [ -f "$src" ]; then
        cp -- "$src" "$tmp/"
        title=$(basename -- "''${src%.*}")
      else
        case $src in
          # yt-dlp would take these pages' mp4, which Discord shows as a video player rather than a looping gif.
          https://tenor.com/*/view/* | https://tenor.com/view/* | https://giphy.com/gifs/*)
            url=$(curl -fsSL -A "$ua" "$src" | grep -oP '<meta[^>]+property="og:image" content="\K[^"]+' | head -1) ||
              fail "no gif found on $src"
            url=''${url%giphy.webp}
            [[ $url == */ ]] && url+=giphy.gif
            curl -fsSL -A "$ua" -o "$tmp/media.gif" "$url" || fail "download failed: $url"
            title=$(basename "$src" | sed -E 's/-gif-[0-9]+$//; t; s/-[A-Za-z0-9]+$//')
            ;;
          # Klipy's pages answer scripts with a Cloudflare challenge, so the GIF comes from its API by the page's slug.
          https://klipy.com/gifs/* | https://klipy.com/gif/* | https://www.klipy.com/gifs/*)
            slug=''${src%%[?#]*}
            slug=''${slug%/}
            slug=''${slug##*/}
            [ -r ${lib.escapeShellArg klipyKey} ] || fail "no Klipy API key; see klipy-api in secrets/shared.yaml"
            url=$(curl -fsS "https://api.klipy.com/api/v1/$(<${lib.escapeShellArg klipyKey})/gifs/$slug" |
              jq -r 'first(.. | objects | (.hd?, .md?) | objects | .gif?.url // empty)') ||
              fail "Klipy has no GIF $slug"
            [ -n "$url" ] || fail "Klipy has no GIF $slug"
            curl -fsSL -A "$ua" -o "$tmp/media.gif" "$url" || fail "download failed: $url"
            # Klipy slugs end in a number: dexter-42.
            title=$(sed -E 's/-[0-9]+$//' <<<"$slug")
            ;;
          # Reddit refuses logged-out reads of a post, and its API is closed to new apps.
          https://*reddit.com/*/comments/* | https://redd.it/*)
            fail "Reddit blocks post pages; in qutebrowser press eM on the image, or copy its image address"
            ;;
          *)
            # A direct image or video link (preview.redd.it, i.imgur.com) is no page yt-dlp has an extractor for.
            ct=$(curl -fsSLI -A "$ua" -o /dev/null -w '%{content_type}' "$src" 2>/dev/null || true)
            ct=''${ct%%;*}
            case $ct in
              image/* | video/*)
                ext=''${ct#*/}
                ext=''${ext%%+*}
                [ "$ext" = jpeg ] && ext=jpg
                curl -fsSL -A "$ua" -o "$tmp/media.$ext" "$src" || fail "download failed: $src"
                # The path's last part without its extension, and Reddit's -v0-<id> tail.
                title=$(basename "''${src%%\?*}" | sed -E 's/\.[^.]*$//; s/-v[0-9]+-[a-z0-9]+$//')
                ;;
              *)
                title=$(yt-dlp -q --no-warnings --no-playlist --no-simulate -t mp4 --print title \
                  -o "$tmp/media.%(ext)s" "$src") || fail "yt-dlp could not download $src"
                ;;
            esac
            ;;
        esac
      fi

      files=("$tmp"/*)
      [ -f "''${files[0]}" ] || fail "nothing was downloaded from $src"
      file=''${files[0]}
      ext=$(tr '[:upper:]' '[:lower:]' <<<"''${file##*.}")

      if dup=$(find_dup "$file"); then
        uncue
        # A near match can be a different caption on the same template, so saving anyway stays one pick away.
        choice=$(printf 'Skip: already saved as %s\nSave anyway\n' "$(basename "$dup")" |
          fuzzel --dmenu --index --prompt "duplicate> " --lines 2 --width 60) || exit 0
        [ "$choice" = 1 ] || exit 0
      fi

      dest=$(tagged_path "$library" "$title" "$ext") || exit 0
      mv -- "$file" "$dest"
      # The source beside the meme, hidden so meme-pick's listing skips it: .<name>.<ext>.url
      [ -f "$src" ] || printf '%s\n' "$src" >"$(dirname "$dest")/.$(basename "$dest").url"
      notify-send -a memes -i "$(thumb "$dest")" "Meme saved" "$(basename "$dest")"
      # Replayed bare, so a repeat reads the clipboard afresh: copy the next URL, repeat.
      [ "$#" -gt 0 ] || repeat record meme-add
      ocr "$dest"
    '';
  };

  pick = writeShellApplication {
    name = "meme-pick";
    runtimeInputs = [
      coreutils
      ffmpeg
      findutils
      fuzzel
      gawk
      libnotify
      repeat
      tesseract
      wl-clipboard
      wtype
    ];
    text = ''
      ${thumb}
      ${clip}
      # Copies $1, pasting it too when $2 is --paste, and makes that the repeat's replay; $3 is how long to wait before pasting.
      deliver() {
        local pick
        pick=$(small "$1") || pick=$1
        clip "$pick" "$2" "$3"
        repeat record meme-pick "$2" "$1"
      }

      # meme-pick --copy|--paste FILE: the repeat's replay, with no menu.
      if [ $# -gt 0 ]; then
        case "$# $1" in
          "2 --copy" | "2 --paste") ;;
          *) echo "usage: meme-pick [--copy|--paste FILE]" >&2 && exit 1 ;;
        esac
        if [ ! -f "$2" ]; then
          notify-send -a memes "Meme gone" "$(basename "$2") is no longer in the library"
          exit 0
        fi
        deliver "$2" "$1" 0.4
        exit 0
      fi

      # Newest first, so what was just added is on top before anything is typed.
      mapfile -t files < <(find "$library" -maxdepth 1 -type f ! -name '.*' -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2-)
      if [ ''${#files[@]} -eq 0 ]; then
        notify-send -a memes "No memes yet" "Copy a link and run meme-add"
        exit 0
      fi

      # Memes from before OCR, or copied in by hand, get their text in the background, searchable from the next pick.
      (for f in "''${files[@]}"; do ocr "$f"; done) >/dev/null 2>&1 &

      # Enter copies; Shift+Enter (fuzzel's custom-1, exit 10) copies and pastes into the focused window.
      rc=0
      i=$(
        for f in "''${files[@]}"; do
          base=$(basename "$f")
          label=''${base%.*}
          text=$(cat -- "$(dirname "$f")/.$base.txt" 2>/dev/null || true)
          # Shown: the tags. Searched: the tags and the OCR text, the hidden second column.
          printf '%s (%s)\t%s\0icon\x1f%s\n' "''${label//-/ }" "''${base##*.}" "$text" "$(thumb "$f")"
        done | fuzzel --dmenu --index --match-mode fzf --prompt "meme> " --placeholder "search tags or text" \
          --with-nth 1 --match-nth '{1} {2}' \
          --line-height ${toString (thumbSize + 8)} --lines 6 --width 60 \
          --override key-bindings.execute-input=none \
          --override "key-bindings.custom-1=Shift+Return Shift+KP_Enter"
      ) || rc=$?
      case $rc in
        0) deliver "''${files[i]}" --copy 0 ;;
        10) deliver "''${files[i]}" --paste 0.15 ;;
      esac
    '';
  };

  soundAdd = writeShellApplication {
    name = "sound-add";
    runtimeInputs = savingInputs;
    text = ''
      ${saving "Sound"}
      sounds=${lib.escapeShellArg sounds}

      if [ -f "$src" ]; then
        file=$src
        title=$(basename -- "''${src%.*}")
      else
        title=$(yt-dlp -q --no-warnings --no-playlist --no-simulate -f bestaudio/best --print title \
          -o "$tmp/media.%(ext)s" "$src") || fail "yt-dlp could not download $src"
        files=("$tmp"/media.*)
        [ -f "''${files[0]}" ] || fail "nothing was downloaded from $src"
        file=''${files[0]}
      fi

      uncue
      # Blank or Esc keeps the whole clip; otherwise start-end in anything ffmpeg reads as a time (5, 1:02.5).
      trim=$(fuzzel --dmenu --prompt-only "trim start-end (blank = all): " </dev/null) || trim=""
      cut=()
      if [ -n "$trim" ]; then
        [[ $trim == *-* ]] || fail "trim must be start-end, got $trim"
        start=''${trim%%-*} end=''${trim#*-}
        [ -z "$start" ] || cut+=(-ss "$start")
        [ -z "$end" ] || cut+=(-to "$end")
      fi

      dest=$(tagged_path "$sounds" "$title" opus) || exit 0
      # Opus because pw-play can't read m4a, YouTube's usual audio; loudnorm keeps clips from different sources at one level.
      ffmpeg -loglevel error -y "''${cut[@]}" -i "$file" -vn -af loudnorm -c:a libopus -b:a 96k "$dest" ||
        { rm -f -- "$dest"; fail "ffmpeg could not convert $src"; }
      notify-send -a memes "Sound saved" "$(basename "$dest")"
      [ "$#" -gt 0 ] || repeat record sound-add
    '';
  };

  soundStop = writeShellApplication {
    name = "sound-stop";
    runtimeInputs = [ coreutils ];
    text = ''
      pids=${pids}
      if [ -f "$pids" ]; then
        # shellcheck disable=SC2046
        kill $(cat "$pids") 2>/dev/null || true
        rm -f -- "$pids"
      fi
    '';
  };

  soundVolume = writeShellApplication {
    name = "sound-volume";
    runtimeInputs = [ coreutils ];
    text = ''
      # sound-volume prints the volumes; sound-volume CALL [YOU] sets them in percent, YOU defaulting to CALL.
      file=${volumeFile}
      if [ $# -eq 0 ]; then
        read -r vcall vyou _ 2>/dev/null <"$file" || read -r vcall vyou <<<"${defaultVolume}"
        echo "call ''${vcall}%, you ''${vyou:-$vcall}%"
        exit 0
      fi
      for v in "$@"; do
        [[ $v =~ ^[0-9]+$ ]] || { echo "usage: sound-volume [CALL% [YOU%]], whole numbers" >&2; exit 1; }
      done
      mkdir -p "$(dirname "$file")"
      echo "$1 ''${2:-$1}" >"$file"
      echo "call $1%, you ''${2:-$1}%"
    '';
  };

  soundPick = writeShellApplication {
    name = "sound-pick";
    runtimeInputs = [
      coreutils
      findutils
      fuzzel
      libnotify
      pipewire
      repeat
      soundStop
      gawk
      ffmpeg
      wl-clipboard
      wtype
    ];
    text = ''
      sounds=${lib.escapeShellArg sounds}
      ${clip}

      # Pastes $1 into the focused window after $2 seconds, as an .ogg so Discord shows its player; makes that the repeat's replay.
      paste() {
        local dir out
        dir=''${XDG_CACHE_HOME:-$HOME/.cache}/memes/ogg
        out="$dir/$(basename "''${1%.*}").ogg"
        if [ "$1" -nt "$out" ]; then
          mkdir -p "$dir"
          # The .opus is already Ogg, so a stream copy only renames the container.
          ffmpeg -loglevel error -y -i "$1" -map 0:a -c copy "$out" || { rm -f -- "$out"; out=$1; }
        fi
        clip "$out" --paste "$2"
        repeat record sound-pick --paste "$1"
      }

      # Plays $1 and makes that the repeat's replay.
      play() {
        local vcall vyou call
        # One clip at a time: a new pick cuts off the last.
        sound-stop
        read -r vcall vyou _ 2>/dev/null <${volumeFile} || read -r vcall vyou <<<"${defaultVolume}"
        vyou=''${vyou:-$vcall}
        # Once into the soundboard mic for the call and once to the default output for you, each at its sound-volume.
        pw-play --volume "$(awk -v p="$vcall" 'BEGIN { print p / 100 }')" --target ${lib.escapeShellArg sink} "$1" &
        call=$!
        pw-play --volume "$(awk -v p="$vyou" 'BEGIN { print p / 100 }')" "$1" &
        echo "$call $!" >${pids}
        repeat record sound-pick --play "$1"
      }

      # sound-pick --play|--paste FILE: the repeat's replay, with no menu.
      if [ $# -gt 0 ]; then
        case "$# $1" in
          "2 --play" | "2 --paste") ;;
          *) echo "usage: sound-pick [--play|--paste FILE]" >&2 && exit 1 ;;
        esac
        if [ ! -f "$2" ]; then
          notify-send -a memes "Sound gone" "$(basename "$2") is no longer in the library"
          exit 0
        fi
        if [ "$1" = --play ]; then play "$2"; else paste "$2" 0.4; fi
        exit 0
      fi
      # Newest first, so what was just added is on top before anything is typed.
      mapfile -t files < <(find "$sounds" -maxdepth 1 -type f ! -name '.*' -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2-)
      if [ ''${#files[@]} -eq 0 ]; then
        notify-send -a memes "No sounds yet" "Copy a link and run sound-add"
        exit 0
      fi

      # Enter plays; Shift+Enter (fuzzel's custom-1, exit 10) pastes the file into the focused window instead.
      rc=0
      i=$(
        for f in "''${files[@]}"; do
          base=$(basename "$f")
          label=''${base%.*}
          printf '%s\n' "''${label//-/ }"
        done | fuzzel --dmenu --index --match-mode fzf --prompt "sound> " --placeholder "search tags" \
          --override key-bindings.execute-input=none \
          --override "key-bindings.custom-1=Shift+Return Shift+KP_Enter"
      ) || rc=$?
      case $rc in
        0) play "''${files[i]}" ;;
        10) paste "''${files[i]}" 0.15 ;;
      esac
    '';
  };
in
symlinkJoin {
  name = "memes";
  paths = [
    add
    pick
    soundAdd
    soundPick
    soundStop
    soundVolume
  ];
  meta.mainProgram = "meme-pick";
}
