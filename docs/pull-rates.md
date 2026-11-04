# 30th Celebration (cel) — pull rates

Sources: pullrates.com (3,000+ packs, `#pull-rates`) and TCGplayer Authentication Center.

## Pack composition as published
> 2 Commons + 1 (Common / Illustration Rare / Classic Collection) + 1 (Rare / Double Rare /
> SIR / Futuristic Rare / RGB Mew) + 1 guaranteed Pikachu + 1 foil Basic Energy (YOSHIROTTEN art)

Published per-pack rates: **Double Rare 1 in 5 · Illustration Rare 1 in 5 · Classic Collection
1 in 10 · Special Illustration Rare 1 in 21 · Futuristic Rare 1 in 120.**

## Two different 30-card tiers — do not conflate them
| Tier | Cards | Art available | Role |
|---|---|---|---|
| **Pikachu Rare** | 30 prints, all named "Pikachu" (`30th-023`…`30th-052`) | yes | guaranteed last slot |
| **Classic Collection** | 30 gold-bordered reprints (Charizard, Misty, Shining Celebi, Lugia, Dark Tyranitar…) | **no** — absent from TCGdex and from pullrates' CDN | slot 3, 1 in 10 |

TCGdex labels the Pikachu tier "Pikachu Rare"; earlier notes here called it "Classic Collection",
which is what made a slot-3 roll look like a second Pikachu.

## Shipped model (5 cards)
| Slot | Contents | Rate |
|---|---|---|
| 1-2 | Common | 2 cards |
| 3 | Common | 70% |
| 3 | Illustration Rare | 20% |
| 3 | Classic Collection → **falls back to Rare** (no art yet) | 10% |
| 4 | Double Rare | 21.02% |
| 4 | Special Illustration Rare | 4.88% |
| 4 | Futuristic Rare | 0.83% |
| 4 | RGB Rare | 0.025% |
| 4 | else Rare | remainder |
| 5 | **Guaranteed Pikachu Rare** (only this slot draws that bucket) | 100% |

Consequence: **exactly one Pikachu print per pack.** Pikachu ex is a separate Double Rare / SIR and
can still appear in slot 4 — a different card, not a second Pikachu Rare.

## Open gap: the foil Basic Energy
The real pack has a 6th card, a foil Basic Energy with YOSHIROTTEN art. We ship 5 because that card
has no asset in either API. Adding it means a new synthetic card + pack size 5 → 6 in the UI.

## Verified (4 packs through the shipped generator)
size 5 every pack · **exactly 1 Pikachu per pack** · typical shape 3 Common + 1 Rare + 1 Pikachu Rare ·
duplicate ids 0.

## RGB Mew art
The three RGB Mews (`30th-R`, `30th-G`, `30th-B`) are the set's chase tier. TCGdex reports
image paths for them that 404, so their scans are vendored as `assets/30c/mew-r|g|b.webp`
and mapped by card id. With that, `artUnavailable` is **0** and the collection denominator is
**191**, matching the pool. (Before this, the denominator read 188 because those three were
excluded as unrenderable.)

### Upstream caveat: TCGdex edges disagree
The API is not consistent across its own CDN edges. Measured from the same machine, minutes apart:

- `curl` → **161** cards for `en/sets/30th`, and `/sets/30th/R` returns **200**
- the browser → **158** cards, and `/sets/30th/R` returns **404**

Because of that, the three RGB Mews are **baked into the app** (`CEL_RGB_3`) with vendored art
instead of being trusted to the set listing. Never assume a set listing is complete: inject the
cards that matter and assert the pool total (191) and the bucket counts, not just "it loaded".

### Cross-check: TCGdex vs pokecardex, full set
Verified against `pokecardex.com/en/series/30C` (the 191-card listing) and both TCGdex
endpoints, by normalised card name:

| Segment | TCGdex | pokecardex | Name diffs |
|---|---|---|---|
| Main set `30th-001…158` | 158 | 158 (indices 1–158) | **0** |
| Classic Collection `30th-c-001…030` | 30 | 30 (indices 159–188) | **0** |
| RGB Mews `30th R/G/B` | 3 | 3 (indices 189–191) | **0** |
| **Total** | **191** | **191** | — |

So the data itself is correct and complete; the earlier 158-card response was a **stale CDN
edge**, not a missing-data problem. Live pool after the fix: 191 cards, 191 unique ids,
0 duplicates, 0 `artUnavailable`.
