{
  coreutils,
  curl,
  ffmpeg,
  findutils,
  fuzzel,
  gawk,
  gnugrep,
  gnused,
  lib,
  libnotify,
  symlinkJoin,
  wl-clipboard,
  writeShellApplication,
  yt-dlp,
  library,
}:
let
  thumbSize = 64;

  # Shared by both commands: the picker makes any thumbnail the other machine's meme-add made.
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
  '';

  add = writeShellApplication {
    name = "meme-add";
    runtimeInputs = [
      coreutils
      curl
      ffmpeg
      fuzzel
      gawk
      gnugrep
      gnused
      libnotify
      wl-clipboard
      yt-dlp
    ];
    text = ''
      ${thumb}
      src=''${1:-$(wl-paste --no-newline 2>/dev/null || true)}
      fail() { notify-send -a memes "Meme not saved" "$1"; exit 1; }
      [ -n "$src" ] || fail "no URL or file given, and the clipboard is empty"

      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT
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
          *)
            title=$(yt-dlp -q --no-warnings --no-playlist --no-simulate -t mp4 --print title \
              -o "$tmp/media.%(ext)s" "$src") || fail "yt-dlp could not download $src"
            ;;
        esac
      fi

      files=("$tmp"/*)
      [ -f "''${files[0]}" ] || fail "nothing was downloaded from $src"
      file=''${files[0]}
      ext=$(tr '[:upper:]' '[:lower:]' <<<"''${file##*.}")

      # The suggestion is the page's title with repeated words dropped; Tenor slugs repeat a lot.
      suggest=$(tr -cs '[:alnum:]' '\n' <<<"$title" | tr '[:upper:]' '[:lower:]' | awk 'NF && !seen[$0]++' | paste -sd ' ')
      tags=$(fuzzel --dmenu --prompt-only "tags: " --search "$suggest") || exit 0
      # Names keep to [a-z0-9-] so the picker's file:// URIs need no escaping.
      name=$(tr '[:upper:]' '[:lower:]' <<<"$tags" | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-200)
      [ -n "$name" ] || name=meme

      mkdir -p "$library"
      dest=$library/$name.$ext
      n=2
      while [ -e "$dest" ]; do
        dest=$library/$name-$n.$ext
        n=$((n + 1))
      done
      mv -- "$file" "$dest"
      notify-send -a memes -i "$(thumb "$dest")" "Meme saved" "$(basename "$dest")"
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
      wl-clipboard
    ];
    text = ''
      ${thumb}
      # Newest first, so what was just added is on top before anything is typed.
      mapfile -t files < <(find "$library" -maxdepth 1 -type f ! -name '.*' -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2-)
      if [ ''${#files[@]} -eq 0 ]; then
        notify-send -a memes "No memes yet" "Copy a link and run meme-add"
        exit 0
      fi

      i=$(
        for f in "''${files[@]}"; do
          base=$(basename "$f")
          label=''${base%.*}
          printf '%s (%s)\0icon\x1f%s\n' "''${label//-/ }" "''${base##*.}" "$(thumb "$f")"
        done | fuzzel --dmenu --index --match-mode fzf --prompt "meme> " --placeholder "search tags" \
          --line-height ${toString (thumbSize + 8)} --lines 6 --width 60
      ) || exit 0
      # A file reference, not the bytes: the one form Discord, Signal and WhatsApp all take for every format.
      printf 'file://%s\r\n' "''${files[i]}" | wl-copy --type text/uri-list
    '';
  };
in
symlinkJoin {
  name = "memes";
  paths = [
    add
    pick
  ];
  meta.mainProgram = "meme-pick";
}
