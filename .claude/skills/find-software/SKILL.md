---
name: find-software
description: Find, compare and shortlist software against the user's preferences, ending in a cited verdict in docs/research/. Use when the user wants an app found, replaced, a lighter alternative to one, a self-hosted service picked, or an issue's candidate tools judged.
---

Choose software for the user the same way every time: **dealbreakers** first, then the
**soft ranking**, both in [`preferences.md`](preferences.md). Read it before anything else.

1. **Frame the need.** Start from the issue (`docs/agents/issue-tracker.md` → Read), the
   `.scratch/homelab/issues/NN` ticket, or the user's words. Done when you can state: the
   job the software does, the app it replaces (if any) and why that one falls short, the
   candidates already named, and whether it is **desktop** or **self-hosted**. In the homelab
   effort, `.scratch/homelab/map.md`'s standing preferences and its decided tickets override
   `preferences.md` where they conflict.
2. **Research** with `/research`, handing the background agent this file's criteria and
   `preferences.md` along with the question. Its brief:
   - Search wide: nixpkgs (mcp-nixos), upstream repos (commit activity, open issues),
     awesome-* lists, AlternativeTo, r/selfhosted, r/unixporn, HN threads, and Rui's config
     at `/home/hefker/nixos/reference/` (a tie-breaker, never wired into the flake).
   - YouTube is **corroboration**: `yt-dlp "ytsearch10:<query>" --flat-playlist --print
     "%(title)s|%(upload_date)s|%(view_count)s|%(url)s"`, then `youtube_transcript_api <id>`
     for the top reviews and demos. Use it for how the app feels and works day to day,
     weighted below written sources; skip sponsored videos.
   - Every candidate is checked against every dealbreaker; one failed dealbreaker ends it.
   - Cut to **3–5 finalists**; every other candidate goes on the rejected list with its reason.
   - `nix build --no-link nixpkgs#<pkg>` (or the flake's package) each finalist; record
     whether it builds.
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
   - Homelab ticket: add the verdict and doc link to the `.scratch/homelab/issues/NN` file.
   - In chat: the verdict, finalists and trial commands.
5. **Learn from the verdict.** When the user reports back on a trial, propose an edit to
   `preferences.md` for any preference their verdict revealed, with the example that showed
   it, and apply it once approved.
