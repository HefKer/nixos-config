{
  coreutils,
  curl,
  ffmpeg,
  findutils,
  fuzzel,
  gawk,
  glib,
  gnugrep,
  gnused,
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
}:
let
  thumbSize = 64;
  sounds = "${library}/sounds";
  # sound-pick writes the PIDs of what it is playing here, and sound-stop kills them.
  pids = ''"''${XDG_RUNTIME_DIR:-/tmp}/sound-pick.pids"'';

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
    wl-clipboard
    yt-dlp
  ];

  add = writeShellApplication {
    name = "meme-add";
    runtimeInputs = savingInputs ++ [
      curl
      gnugrep
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

      dest=$(tagged_path "$library" "$title" "$ext") || exit 0
      mv -- "$file" "$dest"
      # The source beside the meme, hidden so meme-pick's listing skips it: .<name>.<ext>.url
      [ -f "$src" ] || printf '%s\n' "$src" >"$(dirname "$dest")/.$(basename "$dest").url"
      notify-send -a memes -i "$(thumb "$dest")" "Meme saved" "$(basename "$dest")"
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
      libnotify
      tesseract
      wl-clipboard
      wtype
    ];
    text = ''
      ${thumb}
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
      [ "$rc" -eq 0 ] || [ "$rc" -eq 10 ] || exit 0
      # A file reference, not the bytes: the one form Discord, Signal and WhatsApp all take for every format.
      printf 'file://%s\r\n' "''${files[i]}" | wl-copy --type text/uri-list
      if [ "$rc" -eq 10 ]; then
        # Give focus a moment to return from fuzzel to the window it was over.
        sleep 0.15
        wtype -M ctrl v -m ctrl
      fi
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

  soundPick = writeShellApplication {
    name = "sound-pick";
    runtimeInputs = [
      coreutils
      findutils
      fuzzel
      libnotify
      pipewire
      soundStop
    ];
    text = ''
      sounds=${lib.escapeShellArg sounds}
      # Newest first, so what was just added is on top before anything is typed.
      mapfile -t files < <(find "$sounds" -maxdepth 1 -type f ! -name '.*' -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2-)
      if [ ''${#files[@]} -eq 0 ]; then
        notify-send -a memes "No sounds yet" "Copy a link and run sound-add"
        exit 0
      fi

      i=$(
        for f in "''${files[@]}"; do
          base=$(basename "$f")
          label=''${base%.*}
          printf '%s\n' "''${label//-/ }"
        done | fuzzel --dmenu --index --match-mode fzf --prompt "sound> " --placeholder "search tags"
      ) || exit 0

      # One clip at a time: a new pick cuts off the last.
      sound-stop
      # Once into the soundboard mic for the call and once to the default output for you, both at 20%, under the boosted mic.
      pw-play --volume 0.2 --target ${lib.escapeShellArg sink} "''${files[i]}" &
      call=$!
      pw-play --volume 0.2 "''${files[i]}" &
      echo "$call $!" >${pids}
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
  ];
  meta.mainProgram = "meme-pick";
}
