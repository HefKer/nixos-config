---
name: find-software
description: Find, compare and shortlist software against the user's preferences, ending in a cited verdict in docs/research/. Use when the user wants an app found, replaced, a lighter alternative to one, a self-hosted service or phone app picked, an issue's candidate tools judged, or adopt-vs-build weighed.
---

Choose software for the user the same way every time: **dealbreakers** first, then the
**soft ranking**, both in [`preferences.md`](preferences.md). Read it before anything else.

1. **Frame the need.** Start from the issue (`docs/agents/issue-tracker.md` → Read) or the
   user's words. Done when you can state: the job the software does, the app it replaces (if
   any) and why that one falls short, the candidates already named, and its **target**:
   **desktop**, **self-hosted**, **phone**, or a pair of them (a phone app and its desktop
   counterpart are judged together, on how they sync).
   - A phone target follows [`phone.md`](phone.md), which replaces the desktop-only parts of
     steps 2–3.
   - In the homelab effort, the standing preferences of its map (`HefKer/nixos-issues#88`)
     and its decided tickets override `preferences.md` where they conflict.
   - A **small pick** has no data to migrate and no config worth keeping (a one-job CLI
     utility). It ends in chat with the verdict, finalists and trial commands: skip the
     preview and the doc.
2. **Research** with `/research`, handing the background agent this file's criteria and
   `preferences.md` along with the question. Its brief:
   - Search wide: nixpkgs (mcp-nixos), upstream repos (commit activity, open issues),
     awesome-* lists, AlternativeTo, r/selfhosted, r/unixporn, HN threads, and Rui's config
     at `/home/hefker/nixos/reference/` (a tie-breaker, never wired into the flake).
   - On the desktop, also the DMS plugin registry (`dms plugins browse`) and the plugins
     already under `~/dots/DankMaterialShell/.config/DankMaterialShell/plugins/`; where the
     job could live inside an app already in use, its plugins too (neovim, qutebrowser
     userscripts, yazi).
   - One candidate is always **build our own**: a script or package glued from tools already
     installed, with a DMS widget where it needs a face. It runs the same dealbreakers, and
     its price is upkeep: the lines of code, and what breaks when a dependency changes.
   - YouTube is **corroboration**: `yt-dlp "ytsearch10:<query>" --flat-playlist --print
     "%(title)s|%(upload_date)s|%(view_count)s|%(url)s"`, then `youtube_transcript_api <id>`
     for the top reviews and demos. Use it for how the app feels and works day to day,
     weighted below written sources; skip sponsored videos. Keep each finalist's best demo
     and the second its core job starts, for the preview.
   - Every candidate is checked against every dealbreaker; one failed dealbreaker ends it.
   - Cut to **3–5 finalists**; every other candidate goes on the rejected list with its reason.
   - `nix build --no-link nixpkgs#<pkg>` (or the flake's package) each finalist; record
     whether it builds, and its closure size (`nix path-info -Sh`).
   - **Smoke-test** the top pick before the write-up: its core job (play a track, sync a
     file) on the user's own account and hardware. Run it headless with a debug log (`timeout
     45 script -qc "<cmd>" /dev/null`) and read the log, or hand the user the command and wait
     for the result. Record its idle memory (`ps -o rss= -p <pid>`). A failure moves it to
     Rejected and the next finalist gets tested. Delete the logs afterwards, since they can
     hold tokens. (spotatui built and logged in but couldn't play: the user's account hit
     librespot's audio-key block.)
3. **Preview** every finalist, following [`preview.md`](preview.md): what it looks like in
   use, shown to the user before they install anything.
4. **Write up** in `/home/hefker/nixos/main/docs/research/<topic>.md`, in this order:
   - **Verdict** first: the pick, and the one-line reason.
   - A table: finalists × dealbreakers and soft-ranking criteria. The Light row carries the
     measured closure size and idle memory.
   - A paragraph per finalist: price (yearly for subscriptions, best free option beside it),
     what breaks if its cloud disappears, how data gets exported, the privacy checklist, and
     the **switch**: what migrates from the app it replaces, what is lost, which binds change.
   - **Adoption** for the pick: the package or module that installs it, where its config
     lands in `dots`, and a ten-line sample of that config with the user's binds.
   - **Rejected**: each candidate with the reason it failed, and for a reason upstream could
     fix, `Revisit when: <event>` (ships a Wayland backend).
   - **Preview**: per finalist, its shots and its demo link.
   - **Try it**: per desktop finalist, a `nix run nixpkgs#<pkg>` line on the preview's trial
     config, then the two or three things to try, chosen where the finalists differ.
   - `Facts dated YYYY-MM-DD`, and a cited source for every claim.
   Done when every finalist has every table cell filled from a cited source.
5. **Report back.**
   - GH issue: comment the verdict, finalists and trial commands, linking the doc; set its
     label to `ready-for-human` (the user tries the finalists next).
   - In chat: the verdict, finalists, trial commands, and `imv /home/hefker/nixos/main/docs/research/<topic>/` to
     page through the preview.
6. **Learn from the verdict.** When the user reports back on a trial, propose an edit to
   `preferences.md` for any preference their verdict revealed, with the example that showed
   it, and apply it once approved.
