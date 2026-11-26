---
name: find-hardware
description: Find, price and shortlist hardware against the user's preferences, ending in a buy / wait / pass verdict in docs/research/. Use when the user wants a machine, part or peripheral bought, a deal judged, parts on hand priced for resale, or a shortlist's prices re-checked.
---

Buy hardware for the user the same way every time: **dealbreakers** first, then the **soft
ranking**, both in [`preferences.md`](preferences.md). Read it before anything else. A run
answers one **need**, in two stages: **what** (specs, which hold for months) and **where**
(listings, which rot in days).

The skill ends at links and a verdict. Messaging a seller, bidding, carting and checking
out are the user's.

1. **Frame the need.** Start from the issue (`docs/agents/issue-tracker.md` → Read) or the
   user's words. Done when you can state: the role the hardware plays, its hard
   requirements, what it plugs into or replaces, and the **ceiling** (the most the user
   will pay; ask once if they gave none).
   - Read the **private inputs** (see Private and public below). A blank one is asked for
     once and written back.
   - In the homelab effort, the standing preferences of its map (`HefKer/nixos-issues#88`)
     and its decided tickets override `preferences.md` where they conflict; the parts on
     hand are in `.scratch/notes/homelab.md`.
   - A **small buy** is a commodity under ~$50 (cable, charger, thermal paste). It skips
     stage 1 and the doc: verdict and links in chat, one line in the price log.
   - A **resale** need (what would the parts on hand fetch?) skips to step 3's baseline and
     reports a range per part, net of marketplace fees and shipping.
   - A **re-check** of an existing shortlist starts at step 3.
2. **Stage 1, what.** Hand `/research` this file's criteria, `preferences.md` and the need.
   Its brief:
   - The user's location (climate, local prices) comes from the private inputs or from
     asking; a time zone spans cities with different climates.
   - Search wide for the spec class: ServeTheHome and its forums, r/homelab, r/selfhosted,
     r/buildapc, manufacturer spec sheets, nixos-hardware, and Rui's config at
     `/home/hefker/nixos/reference/` (a tie-breaker).
   - Output **tiers with triggers**: the default spec class, then each step-up with the
     landed price at which it becomes the pick ("N150 mini-PC by default; an 8th-gen-or-newer
     SFF under $X; 32 GB if the delta is under $Y").
   - Per tier: idle and load watts from a measured source, noise at idle, upgrade room, and
     the Linux support of each core part (NIC, storage controller, display output).
   - **Compatibility** with everything the part plugs into (socket, cooler clearance, PSU
     connectors, RAM generation, case), each fit cited to manufacturer documentation. A fit
     that can't be cited is written down as an open risk.
   - Every tier is checked against every dealbreaker; one failure ends it.
   Done when every tier has every one of those cells filled from a cited source.
3. **Stage 2, where.** Runs in the main session, since it needs the browser rungs and the
   user's paste-backs. Follow [`sources.md`](sources.md) for which shops to read and how.
   - Search every tier, across new, open-box, refurbished and used.
   - Set the **baseline** per model and condition: eBay sold listings for used,
     PCPartPicker history for new, plus this need's price log. A listing with no baseline is
     marked `unverified`, and is never called a deal.
   - Price each listing at its **three-year total**: landed cost (price + shipping + tax)
     + three years of electricity for anything always-on (idle watts × rate) − resale of
     what it replaces.
   - A listing that trips a stage 1 trigger reopens the pick: say so and re-rank.
   - Append every listing read to `/home/hefker/nixos/main/docs/research/<need>.prices.csv`
     (`date,model,condition,source,landed`).
   - Cut to **3–5 finalists**; every other listing worth a mention goes on the rejected
     list with its reason.
   Done when every source in `sources.md` that fits the need was read or its failed rung
   recorded, and every finalist has a baseline or the `unverified` mark.
4. **Verdict** per finalist, with its reason:
   - **buy**: at or under baseline, inside the ceiling, no dealbreaker.
   - **wait**: above baseline with a sale window inside two weeks, or the price log shows
     it still falling.
   - **pass**: the wrong tier at this price.
5. **Write up** in `/home/hefker/nixos/main/docs/research/<need>.md`, in this order:
   - **Verdict** first: the pick, buy / wait / pass, and the one-line reason.
   - A table: finalists × condition, source type, landed cost, three-year total, baseline,
     warranty or return window, and each soft-ranking criterion.
   - The **tiers and triggers** from stage 1, with their compatibility citations.
   - **Rejected**: each with its reason, and `Revisit when: <event>` where a price or a
     restock would change it.
   - For every used finalist, a **pickup checklist**: what to test on the spot (boots to
     BIOS, RAM count, SMART from a live USB, every port, fan noise, BIOS password or
     Computrace lock on ex-corporate machines), and a drafted first message to the seller.
   - `Facts dated YYYY-MM-DD`, each listing with its seen-at date, and a cited source for
     every claim.
6. **Report back.**
   - GH issue: comment the verdict and finalists, linking the doc; set its label to
     `ready-for-human`.
   - In chat: the verdict, the finalists with their links, and what the user does next.
7. **Learn from the purchase.** When the user reports back (bought, walked away, how it
   arrived and tested), add the price paid to the log, and propose an edit to
   `preferences.md` for any preference it revealed, with the example that showed it; apply
   it once approved. A shop that surprised us gets its row in `sources.md` corrected.

## Private and public

The repo is public, and a local listing's link names the user's city.

- **Private inputs** live in `~/polaris/projects/homelab/find-hardware.md`: zip, pickup
  radius, sales tax rate, electricity rate, Micro Center store. Use them in searches and
  arithmetic.
- **Private listings**: links to local and used listings (Craigslist, OfferUp, Facebook
  Marketplace, eBay) go in `~/polaris/projects/homelab/listings-<need>.md`, with the
  pickup checklist's seller message.
- **Everything written under this repo or to an issue** carries model, condition, price,
  source type (`local pickup`, `eBay used`) and date, plus retail links (Newegg, Amazon,
  Micro Center product pages).

## Watch

During a sale window the user runs `/loop` on a re-check of the shortlist. Each pass
appends to the price log and reports only a finalist whose verdict changed to **buy**.
