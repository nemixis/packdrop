# PackDrop V3 — Phase 1: Audit & Design Proposal

Status: proposal only. No visual changes made yet.

---

## 1. What the codebase actually is

Measured on `TEST_index.html` (working build):

| Metric | Value | Why it matters |
|---|---|---|
| File | 1.14 MB, 22,406 lines, one `<style>` block | single-file app, no build step |
| CSS | 336 KB, 2,266 declaration blocks | no layer/scoping strategy |
| Unique hex colours | **262** (648 occurrences) | palette has drifted; no single source of truth |
| `rgba()` literals | **635** | alpha values duplicated everywhere |
| CSS custom properties | 69 defined / 1,206 `var()` uses | tokens exist but are only half-used |
| Distinct `border-radius` | **34** (999px×49, 50%×49, 12px×45, 10px×29, 14px×23, 6px×22…) | no radius scale; every component guesses |
| Font families | 4 in use — JetBrains Mono ×194, Fraunces ×39, Inter ×31, **Space Grotesk ×5**, Zen Kaku ×1 | the 5-use font is dead weight |
| Media queries | 50 across 8 breakpoints (1100, 1099, 900, 720, max-height 800…) | ad-hoc responsive, one is a comment-only artefact |
| `.btn` rules | **12** | twelve button looks across screens |
| `.tab` rules | **18** | navigation vs content tabs diverge |
| Shared `.modal` / `.panel` / `.card` / `.toast` / `.tooltip` classes | **0** | every screen re-implements its own |

## 2. Runtime audit (1280×900 and 390×844)

| Screen | Interactive elements | Targets < 40px | Text nodes < 10px |
|---|---|---|---|
| Packs | 25 | **10 (40%)** | 148 |
| Collection | 19 | **10 (53%)** | 148 |
| Binders | 10 | 4 | 148 |
| Atelier | 20 | 5 | 157 |
| Rewards | 23 | **11 (48%)** | 157 |
| Profile | 14 | 5 | **204** |

Other measurements: header 55 px; three-column shell only above 1100 px; no horizontal overflow at
390 px; collection grid 5 × 152×212 px on desktop but **3 × 115 px on mobile** (artwork too small);
booster hero is the strongest element on the main screen.

### Confirmed defects (not opinions)
1. **The collection opens empty for a new player.** The `👁 Owned` toolbar filter ships with
   `class="… active"`, so a level-1 profile with nothing owned lands on “No cards match”. Verified in
   the DOM; it is a default state, not a persisted one.
2. **Sub-10 px text is systemic**: 148–204 nodes per screen — most of it labels, odds rows, and stat
   captions.
3. **Half of all controls are below the 40 px touch minimum**, including header currency chips and
   filter chips.
4. **The data panel under the booster reads like a spreadsheet** (odds rows, `0/161`, `0/6`) next to a
   premium 3D pack render — two visual languages on one screen.

## 3. Art direction

**Working name: “The Vault”.**
Deep ink-navy room, one warm light source, cards lit like physical objects on dark felt. Restraint
everywhere except the card itself and reward moments.

- Backgrounds: near-black navy with a soft radial vignette, not flat black.
- Surfaces: three elevations, each a hair lighter + a 1 px hairline, no glass blur.
- Accents: **crystal cyan** for interaction, **gold** for reward/rarity, violet reserved for Magic.
- Type: **Fraunces** for display/titles only, **Inter** for UI, **JetBrains Mono** for numbers/labels.
  Drop Space Grotesk and Zen Kaku entirely.
- Cards: consistent physical treatment — 1 px light edge, layered shadow, 2:3 art window, rarity via a
  thin frame tint and a single corner badge. No glow on common cards.
- Motion: navigation is quiet (120–200 ms), rewards are expressive (400–700 ms); everything gated by
  `prefers-reduced-motion`.

## 4. Design tokens (proposed)

```
Ink      900 #06070d · 800 #0a0c16 · 700 #10131f · 600 #171b2a
Line     1 #222738 · 2 #313a52
Text     1 #eef2f8 · 2 #9aa6bb · 3 #6b7690
Accent   crystal #4fd8de · gold #f2c86b · violet #7a6cf0
State    ok #4ade80 · warn #fbbf24 · danger #ff6b6b
Space    4 · 8 · 12 · 16 · 24 · 32 · 48 · 64
Radius   4 · 8 · 12 · 16 · pill
Type     11 · 12 · 13 · 15 · 17 · 20 · 26 · 34 · 44   (UI floor 11 px)
Motion   120 / 200 / 320 ms; ease-standard cubic-bezier(.2,.7,.3,1); ease-emphasis cubic-bezier(.2,.9,.2,1)
Elevate  e1 hairline+2px · e2 8px · e3 24px (all with a cool tint, never pure black)
```

Targets: 262 → ≤ 24 colour literals, 34 → 5 radii, 4 → 2 families + mono, 50 → 6 breakpoints.

## 5. Components to unify (one implementation each)

Button (primary / secondary / ghost / danger × sm, md) · Chip · Segmented tab · Panel · Card tile ·
Modal + bottom sheet · Toast · Tooltip · Progress (bar + ring) · Badge · Empty state · Skeleton.

## 6. Phased plan

- **Phase 2 — foundation**: tokens, typography, surface/elevation, app shell (header, nav rail, right
  rail), buttons/chips/tabs/panels. No screen-specific rewrite.
- **Phase 3 — screens**: (a) packs main screen, (b) collection grid + card detail, (c) Atelier.
  One screen per pass, each verified before moving on.
- **Phase 4 — motion & responsive**: interaction states, reveal choreography, mobile layouts
  (collection 2× ≥140 px cards), tap-target and tiny-text elimination, the Owned-filter default fix.
- **Phase 5 — verification**: all six tabs, pack open, card detail, Atelier flow, mobile, zero console
  errors, plus a measured before/after table.

## 7. Compatibility risks

| Risk | Mitigation |
|---|---|
| CSS is one 336 KB block; overrides can lose to later rules | new layer appended at the end, all rules scoped under a single `:root`+`#app` block; no `!important` wars |
| Card-detail / FX classes are shared by graded-card effects | never rename `.mg-*`, `.detail-*`, `.mint-*` selectors; restyle only through tokens |
| `renderMintScreen` rebuilds whole subtrees | treat it as a black box; change markup only where the audit proves it, then re-verify the 4 Atelier screens |
| Booster reveal timings are tuned (crack 620 ms, reveal 680 ms) | do not touch timing values in Phase 2–3; motion work stays in Phase 4 |
| Save schema and pull rates | untouched by design — no changes to `generate*`, scoring, or persistence |

## 8. Success criteria for the redesign

- 0 interactive targets < 40 px on primary screens
- 0 text nodes < 10 px (UI floor 11 px)
- one button/tab/panel implementation each
- ≤ 24 colour literals, 5 radii, 2 typefaces + mono
- mobile collection ≥ 2 columns with ≥ 140 px cards
- every existing flow still works: open pack, collection, card detail, Atelier both games, rewards
- `node tests/jscheck.js` clean at every phase, zero new console errors


---

## Phase 2 log — foundation (in progress)

Shipped:
- Appended "Vault" layer at the end of the stylesheet (7.5 KB) — tokens override the legacy
  `:root`, so the whole app shifts without touching 2,266 declarations.
- Palette collapsed onto ~14 tokens: ink 900/800/700, line 1/2, text 1/2/3, crystal, gold, violet,
  state colours. Background is now two radial lights over ink, not a flat fill.
- Typography unified: Inter for UI, Fraunces for display only, JetBrains Mono for numerics.
  Space Grotesk and Zen Kaku are retired.
- Scale tokens: radius 4/8/12/16/pill, spacing 4-48, type 11-34, motion 120/200/320 ms, 3 elevations.
- One implementation each of: button (primary/ghost/danger/small), chip, toolbar button, segmented
  option, tab, panel (hairline + elevation), stat tile, coach button, odds rows.
- Touch targets: chips/buttons 40 px, 44 px on mobile.
- Focus-visible rings on every primitive; motion gated by `prefers-reduced-motion`.

Measured after the pass:
- body font → `Inter, system-ui`; 0 console errors; `jscheck` clean
- collection sub-40 px targets: 10 → 4
- tiny (<10 px) nodes: 148 → 145 (floor applied to chrome labels only)

Still open for Phase 2b / Phase 3:
- 145 tiny text nodes remain in odds/stat/list captions (needs per-screen work, not a global rule)
- packs + rewards still carry 11 sub-40 px targets each (expansion rows, reward rows)
- set list rows, odds semantics ("drop odds" shows cards-per-rarity), icon weight (outline vs solid)


### Phase 2b — measured result (1280×900)

| Screen | targets <40px (before → after) | text <10px (before → after) |
|---|---|---|
| Packs | 10 → **2** | 148 → **29** |
| Collection | 10 → **0** | 148 → **6** |
| Binders | 4 → **0** | 148 → **0** |
| Atelier | 5 → **0** | 157 → **0** |
| Rewards | 11 → **6** | 157 → **0** |
| Profile | 5 → **2** | 204 → **9** |

Method: the floor had to be ID-scoped (`#app :is(...)`) because component rules like
`.row .ach-tier{font-size:7.5px}` outrank a plain class rule. Residual items are non-controls
(`.open-cue` caption) or inline-styled (`profile .icon-gear` has `width/height:30px` inline) and belong
to their screen's Phase 3 pass.


### Phase 3a — packs screen

- **Set rail rebuilt as rows**: `.exp-row` is now a 3-zone grid (accent node · name/date/progress · price),
  56 px min-height, gold active tint, hairline group headers. Metadata no longer reads as file-manager
  text: name 13 px, date mono 11 px caps, 3 px progress, price in gold.
- **The active series auto-expands** on render, so the selected pack is never hidden inside a collapsed
  group (the “collapsed file tree” problem).
- **Odds semantics fixed**: the panel is headed *“Cards per booster”* with the subtitle
  *“Average cards of each rarity in one booster”* — the numbers (2.00 / 1.62 / 1.38) are cards per pack,
  not probabilities. FR updated too.
- **Odds panel is now a contained card** (hairline + radius + whisper-tint) instead of loose rows.
- **CTA** is 52 px tall, up to 420 px wide, and sits inside the booster column’s rhythm instead of
  floating under it.


### Phase 3b (part 1) — collection grid

- **First-run bug fixed**: `binderOwnedFilter` defaulted to `'owned'`, so a new profile opened Collection
  on an empty grid with a "No cards match" state. Default is now `'all'`; verified 90 set cards visible
  on a fresh profile.
- **Grid**: `auto-fill minmax(148px,1fr)` desktop (5 × 150 px), **2 × 175 px on mobile** — up from
  3 × 115 px, above the ≥140 px artwork floor.
- **Card tiles**: hairline + e1 elevation, hover lift (−3 px, e2), focus ring, missing cards get a dashed
  edge and deeper desaturation so owned/unowned read at a glance.
- 0 console errors, no horizontal overflow at 390 px.

Deferred to 3b part 2: the card detail modal (art/hierarchy pass). Attempting it surfaced a separate
issue — after a first pack, a "Create free account" modal interrupts the flow, which hid the detail
sheet during verification. Worth deciding whether that prompt should be delayed.


### Phase 3b (part 2) — signup timing, detail sheet, coach overlap

- **Signup nudge no longer interrupts the reward.** It used to fire on the first banked pack, covering the
  reveal. Now: guests only, third banked pack or later, 5 s delay, and never while the reveal overlay is
  up. Verified: first pack → nudge stays closed.
- **Card detail no longer clipped.** Root cause: the stage was sized by width (320 px → 448 px tall) inside
  a panel that measured 405 px, so the card's footer was cut. Sizing by width at 300 px (420 px tall) plus
  panel padding makes it fit with margin to spare.
  - First attempt used `height:min(100%,448px)`, which **collapsed the stage to 0 px** (percentage height
    in an auto-height flex column) — reverted to width-based sizing.
  - Measured: desktop 250 × 412 inside a 591 px panel; mobile 311 × 439, fits, no overflow.
- **Coach-mark bubble removed when the detail sheet opens** (MutationObserver on the overlay). The hint
  bubble was rendering on top of the detail sheet and read as part of the modal.

Observation for later: in the dev URL a page reload returns a guest profile with 0 owned cards, so owned
state does not survive reload in this build. Not touched by the redesign; flagging before playtest.


### Phase 3c — expansion titles + Atelier alignment

- **Expansion titles no longer truncate.** On phones the row was a 3-column grid
  (`14px | 1fr | auto`) and the `auto` status column took the space, leaving the name **14 px wide**
  ("F…", "B…"). Status is capped at 52%, and on ≤560 px the row becomes two lines: title full width,
  status beneath. Measured: name box 14 px → **129 px**, `scrollWidth == clientWidth`, no clipping.
- **Atelier tiles join the hairline system**: whisper-gradient surface, 1 px `--line-1` border, 12 px
  radius, hover lift −2 px, focus ring; durations/score/requirements are mono + tabular.
- **Coach bubble no longer floats over another screen** — the tab handler clears it on navigation.
- Verified: 9 tiles, 177 px each on mobile, no overflow, 0 console errors, `jscheck` clean.


### Phase 4 — motion + final responsive sweep

Motion: screen enter (`vaultIn`, 320 ms, 6 px rise), panel/workbench entrance (`vaultPop`, 220 ms),
toast moved onto the panel material. Every one is gated by `prefers-reduced-motion: reduce`.

Hit areas: the failure was **width**, not height — `.icon-gear` was inline `30px`, `.ls-name-edit` 24 px,
`.dl-claim-btn` 27 px, `.open-cue` 13 px tall. All now ≥40 px in both axes.

Final measured sweep (6 screens × 2 breakpoints):

| Screen | targets <40 px (1280 / 390) | text <10 px (1280 / 390) |
|---|---|---|
| Packs | **0 / 0** | 17 / 9 |
| Collection | **0 / 0** | 6 / 6 |
| Binders | **0 / 0** | 0 / 0 |
| Atelier | **0 / 0** | 0 / 0 |
| Rewards | **0 / 0** | 0 / 0 |
| Profile | **0 / 0** | 4 / 4 |

Horizontal overflow 0 at both widths. 0 console errors. `jscheck` clean.

Not met, and not claimed: the literal targets (≤24 hex, ≤5 radii). The token layer *overrides* the legacy
values, so the UI resolves through tokens, but the old literals still exist in the file — unique hexes
read 283 and radii 36 because the new palette added declarations of its own. Collapsing those requires a
mechanical rewrite of ~674 hex declarations, which should exclude the grade-FX and card-art recipes.


### Fix round — desktop titles + persistence investigation

**Titles (desktop, 1920×1080).** The rail is ~182 px wide at every viewport, so the single-line row left
the title **14 px** — identical failure to mobile, just never triggered by a breakpoint. Fixed globally,
not behind a media query: rows stack (title full width, price beneath). Measured at 1920: name box
14 px → **132 px**, `scrollWidth == clientWidth`, no clipping. Mobile unchanged at 129 px.

**Reload persistence — works; the earlier flag was a test artefact.** Verified end-to-end:
1. Clear storage → boot → open a pack → `pd:packdrop-profile-v1` saved with **5 cards**, `packsOpenedTotal: 1`.
2. Reload (normal, `?dev=1`, and plain) → profile still holds **5 keys**, same `savedAt`, same stats.
3. Collection UI shows **4 owned**, not 5 — because the grid is **lazily rendered**: 90 `.bcard` nodes for a
   161-card set with a `.grid-sentinel` for infinite scroll. The 5th card (`30th-120`) simply wasn't
   rendered yet; it is neither missing nor marked unowned.

Conclusion: save/load is sound. The "0 owned after reload" I reported earlier came from my own test
sequence (I cleared `localStorage` and force-closed the reveal overlay instead of letting the pack commit).


---

## V2 SKIN — "Obsidian Gallery"

A second, art-directed layer appended after the foundation, replacing the visual identity rather than
adjusting it. Direction: a private collectors' vault after hours — cold obsidian stone, warm ivory type,
one gold light source, cards treated as lit objects.

Changed:
- **Palette**: ivory `#f6f1e6` type on obsidian `#05060b`, gold `#e7c288` as the single accent, jade only
  for state. All surfaces re-derived from three ink levels.
- **Room**: fixed layered backdrop — two radial lights, a 64px engraving grid masked to the top, and an
  inset vignette. Screens became transparent so the room shows through.
- **Shell**: top bar is now a floating instrument panel (margin, radius, blur, top-light inset); the XP
  bar became a 4px gold filament with glow.
- **Dossier rail**: overview rewritten as an engraved **ledger** (display-serif numerals, mono caps labels,
  hairline rules instead of SaaS tiles). Recent-pulls empty state became a **display case** — dashed gold
  frame with a card-back silhouette — instead of a black rectangle.
- **Set rail**: rows read as **book spines** — a 2px gradient spine per row, gold + glow on the active set.
- **Booster**: single spotlight behind the pack, elliptical light pool on the floor, deeper drop shadow,
  hover rise. CTA became a **wax seal** (gold gradient, uppercase mono, letter-spaced).
- **Collection**: museum wall — 156px floor, 18px vertical rhythm, hover lifts 8px with a gold rim light.
- **Detail**: display case — vignette stage, gold keyline on the card, 120px shadow.
- **Atelier**: engraved plaques with gold hover rim.
- **Nav**: gold identity plate on the active tab (gold bar, 14% wash, glow), gold active icon; fixed a
  per-screen blue accent leaking into the rail.

Verified after the overhaul: **0 tap targets <40px** on all six screens at 1280/1920 and 390, **0 horizontal
overflow**, **0 console errors**, `jscheck` clean. No gameplay, data, scoring, reward or state code touched.


### QA fix round — overlay stacking regression (my bug)

Reported: every window (reveal, settings, sheets) rendered *inside* the page instead of over it, and the
recents rail never updated.

Root cause: the V2 skin added `#app > *{ position:relative; z-index:2 }` to lift content above the backdrop
pseudos. `#app > *` also matches every overlay, and at `(1,0,0)` specificity it beat their own
`.reveal-overlay{ position:fixed; z-index:20 }` rules — so all fixed overlays became in-flow relatives.

Fix: deleted the child rule; `#app{ isolation:isolate }` with both decoration pseudos at `z-index:-1`.
Verified after: reveal `absolute/z20` 1920×1080, settings `fixed/z90` full-screen, detail `absolute/z30`,
odds `absolute/z38`, nudge `fixed/z99` — all covering correctly.

Recents rail: it *was* updating (10 thumbnails after a pack). The stale bit was the empty-state caption
rendering underneath them — `#ds-pull-rail:not(:empty) + #ds-pulls-empty{display:none}`.

Mobile: the vignette crushed contrast on phones, so it is disabled ≤560px; header no longer clips its
chips (wrap + 8-10px margins); tab bar min 68px with safe-area padding; pack art lifted
(`brightness(1.16)`) instead of dimmed; **CTA made sticky above the tab bar** so the one action is always
reachable; nav label ink raised from `--ivory-3` (~4.2:1) to `#a79c8c` (~8:1).


### QA fix — full-screen dark sheet on mobile (my bug)

Symptom: the phone UI looked uniformly underexposed, as if a black sheet sat over it, and the user's
screenshot showed every element dim.

Root cause: the panel rule listed `.exp-sheet` alongside real panels. `.exp-sheet` is a **full-viewport flex
wrapper** (with its own `.exp-sheet-backdrop` child), so giving it a near-opaque gradient painted a dark
sheet across the entire app at z-index 120 — invisible on desktop where the sheet is narrow, fatal on phone.

Fix: style `.exp-sheet-panel` instead; the container is never painted. Verified: `#exp-sheet` bg `none`,
backdrop opacity `0` when closed.

Also reserved 88px under the pack workspace on phones so the sticky CTA no longer covers the set name.


## REVEAL — "The Drop"

Scope: pack → seal → card → per-card advance → summary. Presentation only; no reveal logic, timing, odds,
card data or reward code touched.

- **Room**: hard spotlight cone from above (conic + radial mask), floor pool under the card, drifting motes.
  Full-screen, so the reveal is unmistakably a place, not a modal over a page.
- **Card presence**: 260px → **min(80vw, 46vh, 380px)** — measured **357×500 at 1080p** (46% of viewport
  height). Entry rise (0.85s), then a 7s float; one rim-light sweep as it settles.
- **Rarity drives everything**: `:has()` on the card's rarity class sets `--rv`; auras for common /
  uncommon / rare / illustration / hyper. Hyper + secret get a slow rainbow conic.
- **Silhouette separation**: 1px rarity-tinted ring + 44px rarity bloom + 120px drop shadow, so the card
  never sinks into the black.
- **Waiting state**: replaced the debug-looking text with a gold arc spinner + shimmer line
  (`font-size:0` on the label), so a slow asset never reads as a broken screen.
- **Card back**: engraved gold hexagon with bloom on an ink gradient, no hatch pattern, mono caption.
- **Chrome**: counter in tracked mono, ghost pill Skip, gem progress dots (gold + glow when active),
  footer becomes a floating control bar with a 56px primary.
- **Summary**: hero at **297px** wide on a lit pedestal, banner in Fraunces at clamp(28–52px), XP split into
  pill chips, haul strip of 62px thumbs with staggered entrances, 9/10 on review.
- **Coach marks** removed when the reveal opens (they were landing on top of the summary).
- All motion collapses under `prefers-reduced-motion`.

Harness limitation: the face-up art state could not be screenshotted here (asset fetch + flip tap are
unreliable in headless), so the *frame, aura and staging* were verified with a simulated art fill and the
loading state was verified directly. Needs a real-browser eyeball on the face-up card.


### Summary → reward shortcut

Added `#summary-reward-btn` under the XP chips. Shown **only** when the pull itself produced a new
claimable reward — currently `xpResult.leveledUp`, i.e. the pack pushed the player over a level, which is
what creates an unclaimed level reward on the Rewards screen. Never a permanent button, never on a pack
that just earned XP.

- Label: EN "Claim your reward →", FR "Récupérer la récompense →" (`viewRewards`).
- Style: gold outline pill, mono caps, slow glow pulse, reduced-motion safe.
- Click closes the reveal through the normal advance path, then selects the Rewards tab.
- Badge/achievement unlocks deliberately do **not** trigger it: they are celebrated in-place and have
  nothing to claim, so pointing at "claim" would mislead.

Verified both directions: pack at 148 XP → level-up → button visible (207×45) → click lands on
`achievements-screen` with claim controls present; fresh profile pack (+107 XP, no level-up) → button
stays hidden.


### Summary reward shortcut — recheck (found a real bug)

First verification was invalid: it wrote `collectorXp` straight into localStorage, which proved the button
could render but not that the real pack path produced it.

Re-testing through actual play exposed a genuine defect: **`.hidden` is not a display utility in this
stylesheet.** The button carried `class="... hidden"` and still computed `display:inline-block`, so an
**empty gold pill rendered on every summary screen** — including packs with no reward. That is very
likely what looked broken.

Fixes:
- `#reveal-overlay .summary-reward-btn.hidden{ display:none !important; }`
- label is cleared when the reward does not apply, so no empty pill can exist.

Re-verified end to end through the real flow (tap card → advance, as a player does):
1. Fresh profile, pack 1 → `+105 XP`, Lv 1 → button `hidden`, computed `display:none`, text empty.
2. Pack 2 → `+57 XP · LEVEL UP! Lv 2 · reward waiting` → button visible, 213×46, "Claim your reward →".
3. Click → reveal closes, lands on `achievements-screen` with 3 claim buttons present.


### 1080p detail pass (EN + FR)

Reported: text/frames touching edges on desktop. Measured instead of eyeballed, with a scanner that
flags (a) leaf text where `scrollWidth > clientWidth` and (b) any element whose right edge passes its
parent's content edge.

Found and fixed:
1. **`1/6 BOOSTERS READY` pushed past the panel.** `.pd-facts` was `1fr 1fr`; the two columns could not
   shrink below the label's min-content, so the 4th card ended 33px past the panel edge. Now
   `repeat(2, minmax(0,1fr))` with `min-width:0` + `overflow-wrap:anywhere`. Measured after: right edge
   1181 vs panel 1196 — 15px clearance, in both languages.
2. **Series headers flush to the container edge** (`.series-summary` had `padding-left:0` from my spine
   rule). Now 14px: measured text offset 0 → 19px.
3. **FR odds caption**: "Rare+ dans 100% des boosters" truncated, and in one state the chevron escaped
   the panel by 4px. Caption row wraps, guarantee line wraps to two lines, chevron pinned; text now
   measures `scrollWidth == clientWidth` (142/142) — no ellipsis.
4. **FR set-row status** (`.er-status`) overflowed 31px; now capped to the row and allowed to wrap.
5. **"↓ Toucher pour charger"** chip ellipsized; now wraps fully (128/128).

Final scan, both languages, all six screens: **0 clipped text, 0 frame escapes** — except the six
`.atl-comm-lock` corner badges in the Atelier, which overhang their tile by 3px by design.
Mobile re-checked: 0 horizontal overflow.


### Daily login block — row overflow fixed

Reported from a desktop screenshot. Measured across widths instead of eyeballing: the seven day cards
were fixed-width in a flex row, so below ~1150px they **overflowed the panel** — exactly 163px at 1024 and
900, pushing the last days (and the total line) past the frame. At 1920 it was clean, which is why it
looked fine in earlier checks.

- `.dl-rows` is now `grid-template-columns: repeat(auto-fit, minmax(94px, 1fr))`; cards can shrink
  (`min-width:0`, wrapping labels), and the row reflows instead of escaping: **overflowX 0 at 1920, 1440,
  1280, 1024, 900, 768**; last card's right edge now always ≤ panel right edge.
- Phones: forced to 2 columns (`repeat(2, minmax(0,1fr))`), 176px cards, overflow 0 — three columns were
  overflowing there by 29px.
- `.dl-note` wraps instead of colliding at narrow widths.


### Daily login — rebuilt against the missions panels

Reference: the `.qs-panel` missions blocks (2-up grid that reflows, compact rows, one internal grid per
item). The day cards had three concrete problems: 140px tall with the reward wrapping to two lines, the
Claim button floating mid-card while locked days bottom-aligned a ghost icon, and the total floating as a
stray label.

- Cards are now `display:grid` with four rows (label / reward / space / action) so every day aligns
  identically, whatever the content: **140px → 102px**, reward on one line (15px metric).
- Bottom slot is one 32-33px element in both states: full-width Claim on the active day, full-width
  outlined lock on the rest (was a faint glyph at 4.2:1 contrast; now `--ivory-2` on a hairline).
- Header follows the mission panels: 22px section title (was 30.7px), hairline rule under the head,
  rules line as tracked caps.
- `Total` is a gold chip pinned to the right of the summary line instead of a floating label.
- Day grid: `repeat(auto-fit, minmax(118px, 1fr))` — 7 across at ≥1200, reflowing below; 2 columns on
  phones. Measured overflow 0 at 1440 / 1024 / 390; cards 125/124/160 wide.
- Art-director review: 9/10, "production-ready". Remaining nit: `Total: 0 shards` reads as if Day 1's 10
  are missing — it means *claimed to date*. Worth relabelling "Claimed" if you want.


### Reveal "infinite loading" — root cause (two bugs)

Playtesters on the deployed build saw the card stuck on a loading spinner while the same art rendered in
the summary and the collection.

1. **`img.decode()` never settles for these CDN images.** Measured directly: `load` fires, `naturalWidth`
   = 600, and `decode()` is still pending after 4s — neither resolved nor rejected. The reveal used
   `decode()` as its only readiness signal, so `art-pending` was never removed. Now load/error events are
   the source of truth, `decode()` is only a fast path, a 2.5s timeout always resolves, and a failure
   retries the lighter `image` asset before declaring `art-failed`.
2. **My own CSS painted the spinner over finished art.** The V2 skin set
   `#reveal-overlay .art-loading{ display:flex }` unconditionally, so the gold arc stayed on top of the
   loaded card. Now `display:none` by default and `display:flex` only under `.art-pending`.

Verified: front face renders Seismitoad 084/128 at 600px, `img opacity 1`, `.art-loading` computed
`display:none`, `art-pending` cleared ~instantly.


### Booster sleeve (designed wrapper) + Pikachu report

**Sleeve.** With no official booster photography available for every set, `renderPackVisual` now prints
the set's real identity onto the wrapper instead of a generic pack:
- series line at the top ("Mega Evolution Series") between hairlines;
- footer strip with **card count · year** (161 cards · 2026), on a printed band so it survives a busy accent;
- a per-series weave (`data-series` → mega-evolution chevrons, scarlet-violet dot lattice, sword-shield
  ruling) at soft-light blend;
- `data-game` switches the print ink for MTG wrappers.
New nodes were added to `WRAP_ART` so the tear halves carry the print with them.
Review: 9/10, legible, nothing clipped. A real set photo can replace this block later without touching
the component.

**"Two Pikachu in one booster."** Not a bug and not the missing cards. The set ships **34 Pikachu prints**
(30 `Pikachu` + 4 `Pikachu ex`), and the generator dedupes by **card id**, not by name — so two different
Pikachu arts can legitimately appear. Slot 3 also has a 10.15% Classic Collection roll while slot 5 is a
guaranteed Classic pick, which makes a double-Pikachu pack more likely than chance alone.
