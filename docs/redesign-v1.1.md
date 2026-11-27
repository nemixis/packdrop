# Redesign audit — main screen (V1.1)

Measured on `main` @ b34c138, desktop 1512×765, signed-in account with 0 packs opened.
Mobile widths not yet measured — the browser harness refuses to apply a viewport
override in this environment, so 360/390/430 validation needs a real device or a
manual DevTools pass.

## What the main screen is made of

`#packs-screen` → `.pack-stage`, in this order:

| region | element | notes |
|---|---|---|
| game switcher | `#game-switcher` | segmented pills: Magic / Pokémon |
| weekly banner | `#weekly-banner` | time-limited pack, countdown |
| series tabs | `.series-chip` row | Mega Evolution / Scarlet & Violet / POP |
| expansion grid | `#expansion-switcher` | ~9 bordered tiles, locked ones show a price |
| booster | `#pack-el` | **155×221 px** |
| pack detail | `#pack-detail` (.pdet) | 5-card spec, %, rarity bars, "OPEN BOOSTER" |
| odds hint | `#odds-hint` | "15 cards · real drop odds" |
| pull rail | `#pull-rail` | recent pulls |
| stats row | `.stats-row` | packs opened / cards owned / rare+ |

Sidebar (right): OVERVIEW (3 stats) + RECENT PULLS.

## Findings, worst first

1. **The booster is the smallest thing on the screen.** 155×221 on a 1512 px
   viewport, while the locked-expansion grid occupies ~460×470 and the sidebar
   ~370×700. The brief says the pack is the protagonist; today it is the smallest
   element and the least colourful.
2. **The coach tip covers the pack** it describes ("Tap the pack to tear it open"
   sits over the booster art). First-run guidance hides the product.
3. **A dead right column on a new account.** OVERVIEW reads 0 / 0 / 0 and RECENT
   PULLS is a dashed empty box — ~370 px of screen doing nothing, next to a pack
   that is 155 px wide.
4. **No typographic hierarchy.** Almost everything is 9–11 px mono, uppercase,
   letter-spaced. The wordmark is the same weight as the stat labels. Nothing on
   the screen reads at display scale, so nothing announces itself as the point.
5. **Nine identical bordered rectangles.** Expansion tiles, stat chips, spec rows
   and the sidebar blocks are all the same box with the same radius and border.
   This is the "endless grid of identical containers" the brief calls out.
6. **Six competing regions with no path through them.** Game switcher, weekly
   banner, series tabs, expansion grid, booster and detail panel all sit at
   similar visual weight. Nothing says "start here".
7. **Colour is absent.** Near-black + gold only. No cream field, no red identity,
   no warm page ground — the palette in the brief has no presence anywhere.
8. **The pack art is an image in a frame.** It is a `<img>` inside a bordered box,
   not a product: no shadow, no angled label, no packaging detail.
9. **Hover-only affordances.** Expansion tiles reveal price on hover; nothing
   indicates they are pressable on touch.

## Art direction for V1.1

Not a reskin. The main screen becomes three stacked bands, not three columns:

- **Band 1 — masthead.** PACKDROP as a drawn wordmark (heavy display face,
  slight rotation, red seal), centre nav as bold small-caps links with a red
  active underline, right cluster = shards, level chip, avatar.
- **Band 2 — the pack.** Cream paper field with halftone; booster rendered large
  (target 260×380 desktop, 200×290 mobile) with layered shadow + angled "NEW"
  sticker; oversized display heading with the set name; one red CTA. Spec strip
  under it as inline text, not a boxed panel.
- **Band 3 — shelf + activity.** Horizontal booster shelf (large thumbnails,
  selected = raised + red rule), then daily missions as an editorial strip, then
  a collection shortcut using real card art.

Palette (tokens): cream `#F3EBD9` ground, ink `#24252D` text, red `#E94B43`
identity/CTA, yellow `#F3C94F` reward, blue `#527EAA` secondary. Rarity colours
stay as-is — they are game data, not chrome.

Typography: one display face at three sizes (72/44/28) for set names and headings;
Inter for body; JetBrains Mono kept only for numbers and micro-labels.

Graphic assets (original SVG, in `assets/design/`): burst, sparkle, halftone
patch, sticker seal, arrow, divider, pack shadow. No CSS-gradient stand-ins for
these, per the brief.

## Risks

- `#packs-screen` carries the most logic of any screen (pack open, language,
  odds, rail, stats). The redesign must keep every id intact: the hooks are
  `#pack-el`, `#open-cue`, `#pack-detail`, `#expansion-switcher`, `#booster-toggle`,
  `#odds-hint`, `#pull-rail`, `#lang-pill`, `#exp-chipstrip`.
- Mobile is unvalidated in this environment. Nothing ships as "done" until it is
  checked on a real phone.
