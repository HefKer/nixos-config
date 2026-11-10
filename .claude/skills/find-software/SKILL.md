---
name: find-software
description: Find, compare and shortlist software against the user's preferences, ending in a cited verdict in docs/research/. Use when the user wants an app found, replaced, a lighter alternative to one, a self-hosted service picked, an issue's candidate tools judged, or adopt-vs-build weighed.
---

Choose software for the user the same way every time: **dealbreakers** first, then the
**soft ranking**, both in [`preferences.md`](preferences.md). Read it before anything else.

1. **Frame the need.** Start from the issue (`docs/agents/issue-tracker.md` → Read) or the
   user's words. Done when you can state: the job the software does, the app it replaces (if
   any) and why that one falls short, the candidates already named, and whether it is
   **desktop** or **self-hosted**. In the homelab effort, the standing preferences of its map
   (`HefKer/nixos-issues#88`) and its decided tickets override `preferences.md` where they
   conflict.
2. **Research** with `/research`, handing the background agent this file's criteria and
   `preferences.md` along with the question. Its brief:
   - Search wide: nixpkgs (mcp-nixos), upstream repos (commit activity, open issues),
     awesome-* lists, AlternativeTo, r/selfhosted, r/unixporn, HN threads, and Rui's config
     at `/home/hefker/nixos/reference/` (a tie-breaker, never wired into the flake).
   - On the desktop, also the DMS plugin registry (`dms plugins browse`) and the plugins
     already under `~/dots/DankMaterialShell/.config/DankMaterialShell/plugins/`.
   - One candidate is always **build our own**: a script or package glued from tools already
     installed, with a DMS widget where it needs a face. It runs the same dealbreakers, and
     its price is upkeep: the lines of code, and what breaks when a dependency changes.
   - YouTube is **corroboration**: `yt-dlp "ytsearch10:<query>" --flat-playlist --print
     "%(title)s|%(upload_date)s|%(view_count)s|%(url)s"`, then `youtube_transcript_api <id>`
     for the top reviews and demos. Use it for how the app feels and works day to day,
     weighted below written sources; skip sponsored videos.
   - Every candidate is checked against every dealbreaker; one failed dealbreaker ends it.
   - Cut to **3–5 finalists**; every other candidate goes on the rejected list with its reason.
   - `nix build --no-link nixpkgs#<pkg>` (or the flake's package) each finalist; record
     whether it builds.
   - **Smoke-test** the top pick before the write-up: its core job (play a track, sync a
     file) on the user's own account and hardware. Run it headless with a debug log (`timeout
     45 script -qc "<cmd>" /dev/null`) and read the log, or hand the user the command and wait
     for the result. A failure moves it to Rejected and the next finalist gets tested. Delete
     the logs afterwards, since they can hold tokens. (spotatui built and logged in but
     couldn't play: the user's account hit librespot's audio-key block.)
3. **Write up** in `docs/research/<topic>.md`, in this order:
   - **Verdict** first: the pick, and the one-line reason.
   - A table: finalists × dealbreakers and soft-ranking criteria.
   - A paragraph per finalist: price (yearly for subscriptions, best free option beside it),
     what breaks if its cloud disappears, how data gets exported, the privacy checklist.
   - **Rejected**: each candidate with the reason it failed.
   - **Try it**: a `nix run nixpkgs#<pkg>` line per desktop finalist.
   - `Facts dated YYYY-MM-DD`, and a cited source for every claim.
   Done when every finalist has every table cell filled from a cited source.
4. **Report back.**
   - GH issue: comment the verdict, finalists and trial commands, linking the doc; set its
     label to `ready-for-human` (the user tries the finalists next).
   - In chat: the verdict, finalists and trial commands.
5. **Learn from the verdict.** When the user reports back on a trial, propose an edit to
   `preferences.md` for any preference their verdict revealed, with the example that showed
   it, and apply it once approved.
