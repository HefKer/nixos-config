# Hardware preferences

The criteria `find-hardware` judges every candidate by. An entry gains the example that
showed it once a purchase has; add new ones the same way.

## Dealbreakers

One failure rules the candidate out.

- **A core part without mainline Linux support**: NIC, storage controller or display
  output. Every host runs NixOS.
- **A drive that is used or seller-refurbished.** Drives are bought new or
  manufacturer-recertified with a warranty.
- **Shipped used gear with no return window or buyer protection.**
- **An unproven seller**: under ~98% feedback or ~50 sales on eBay; an account opened this
  month on a local market.
- **Idle draw over the need's ceiling**, for an always-on role.
- **Audible at idle**, for a role sited in living space.
- **A proprietary part that blocks the planned upgrade**: a non-standard PSU connector,
  RAM soldered below what the need calls for.
- **A price that needs a new store card.**

## Soft ranking

Highest first.

1. **Lowest three-year total**: landed cost + power − resale.
2. **Warranty and return length.**
3. **Condition**: new on sale ≈ manufacturer-refurbished > open box > seller-refurbished >
   used local > used shipped.
4. **Upgrade room**: a free RAM slot, NVMe plus SATA, a PCIe slot.
5. **Quiet and low idle watts**, beyond the dealbreaker bar.
6. **Well-trodden**: common in homelab circles (ServeTheHome, r/homelab) and on NixOS (a
   nixos-hardware entry). The homelab map's "boring, well-trodden option" applied to
   hardware.
7. **Local pickup** over shipped, at equal price.

## Memberships and bundles

Priced in, case by case.

- A membership's fee is added to the landed cost, unless the user already holds it or
  would use it anyway.
- A bundle is priced as the parts the need calls for, minus a realistic resale of the rest.

## Used and local

- Local markets (Facebook Marketplace, Craigslist, OfferUp) suit gear that can be tested
  on the spot: SFF desktops, cases, coolers, GPUs.
- A Micro Center is inside the pickup radius, so its open-box shelf and in-store-only
  prices are checked on every run.
