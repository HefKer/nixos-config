# Sources

Where `find-hardware` reads prices, and the **rung** of the fetch ladder each shop answers
on. Probed 2026-11-24. When a rung fails, try the next one, then correct the row and its
date.

## The fetch ladder

1. **curl**, with a desktop browser's `-A` user agent.
2. **Headless Chromium**, on a throwaway profile in the scratchpad:
   `timeout 40 chromium --headless=new --disable-gpu --user-data-dir=<scratchpad>/chr
   --user-agent='<desktop Chrome UA>' --virtual-time-budget=8000 --dump-dom '<url>'`.
   The default headless user agent is refused; a desktop one passes.
3. **Logged-in Chromium**, through the `claude-in-chrome` skill, on the user's dedicated
   profile. Read at a human's pace: one search, then the listings worth opening.
4. **Hand-off**: give the user the search link, and judge what they paste back.

A page counts as read when it yields prices. A 200 with a challenge title ("Just a
moment...", "Error Page") or a near-empty body is a failed rung.

## Shops

| Source | Good for | Rung |
|---|---|---|
| eBay, sold (`&LH_Sold=1&LH_Complete=1`) | the used **baseline**; resale ranges | 3 |
| eBay, active | used and seller-refurbished listings | 3 |
| PCPartPicker | new-part price history, compatibility filters | 2 |
| Micro Center | open box, in-store-only prices; add `&storeid=<store>` from the private inputs | 2 |
| Newegg | new, open box, refurbished | 2 |
| B&H | new, open box | 2 |
| ServerPartDeals | manufacturer-recertified drives | 2 |
| Amazon | new, Renewed, Warehouse | 1 |
| diskprices.com | Amazon drives ranked by $/TB | 1 |
| Dell Refurbished (dellrefurbished.com) | ex-lease OptiPlex and Latitude, with warranty | 1 |
| Slickdeals | whether a "deal" is one: read the thread's votes and comments | 1 |
| Reddit JSON (`old.reddit.com/r/<sub>/new.json`): buildapcsales, homelabsales, hardwareswap | deals as they post; used gear from vetted traders | 1 |
| ServeTheHome forums, Great Deals | server and homelab deals | 1 |
| labgopher.com | used servers ranked from eBay | 1 |
| Craigslist, OfferUp | local used; search on the private zip and radius | 1 |
| ShopGoodwill | untested lots | 1 |
| AliExpress | mini-PCs and adapters at source prices; weeks of shipping, weak returns | 1 |
| Facebook Marketplace | local used | 4, always: build the link (query, radius, price cap, newest first) and the user skims it |
| Best Buy | open box | 4: curl times out, headless returns nothing |
| camelcamelcamel | Amazon price history | 4: Cloudflare challenge; Amazon's own listing and the price log stand in |
| Walmart, Woot | new, refurbished | 2 untested; curl returns a shell page |
