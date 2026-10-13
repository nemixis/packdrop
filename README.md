# Packdrop — feature import pack

Everything here is the change set on top of commit **c6c7092** (the state your
GitHub repo `nemixis/packdrop` is currently at). Replace the files below in your
repo, then apply the three commits in order — or push one combined commit.

## Files to import (replace existing paths in the repo)

```
Github/index.html                    → index.html                     (production bundle, features baked in)
Github/TEST_index.html               → TEST_index.html
Github/tests/check_achievements.py   → tests/check_achievements.py
Github/tests/check_arena.py          → tests/check_arena.py
Github/tests/check_desktop.py        → tests/check_desktop.py
Github/tests/check_progress.py       → tests/check_progress.py
Github/tests/engine/arena.css        → tests/engine/arena.css
Github/tests/engine/arena_dungeons.js→ tests/engine/arena_dungeons.js
Github/tests/engine/arena_ui.js      → tests/engine/arena_ui.js
Github/tests/engine/run_cp.js        → tests/engine/run_cp.js
Github/tests/engine/run_duel.js      → tests/engine/run_duel.js
Github/tests/review/*.png            → tests/review/                  (review screenshots)
Github/tests/sync_arena.js           → tests/sync_arena.js
```

## Commit messages (apply in order)

1. `feat(arena): infinite idle mode (∞), Rule chip, Badges set-ff:10 milestone, pull-rail persistence, 3-col sidebar`
   — files: tests/engine/arena_ui.js, arena.css, arena_dungeons.js, run_cp.js,
     run_duel.js, sync_arena.js, TEST_index.html
2. `test: assert infinite idle, Rule chip, set-ff:10 Badges milestone, desktop layout`
   — files: tests/check_achievements.py, check_arena.py, check_desktop.py,
     check_progress.py, tests/review/*.png
3. `build: merge arena features into production index.html bundle`
   — file: index.html
4. `fix(reveal): prefetch pack card art + loading state so flipped fronts aren't blank`
   — files: index.html, TEST_index.html
   (card art is streamed from a remote CDN per reveal, so a slow/rate-limited
   link left fronts blank for many seconds. Two layers: (1) prefetch every
   card's image_large the moment the pull is generated, warming the cache
   behind the tear/split animation; (2) `img.decode()` before showing the
   front — while it decodes the front shows a spinner + "Loading art…" and the
   back shows "Loading art… / Ready / Art unavailable". The flip and
   advance/skip are never blocked — it's feedback, not a gate.)
5. `feat(shop): buy a pack opening with shards when out of daily opens`
   — files: index.html, TEST_index.html
   (when the player has 0 opens left and taps the pack, a confirm modal offers
   to buy the opening with shards — 150 ◆ for a Play Booster, 300 ◆ for a
   Collector. Affording it deducts shards, grants a bonus pack, and opens
   normally; can't afford shows the shortfall and blocks the open. Shards now
   have a real sink alongside expansion unlocks. FR + EN.)
6. `feat(share): shareable pull cards (PNG) from the reveal`
   — files: index.html, TEST_index.html
   (a Share button sits beside the primary CTA once a card is revealed.
   Single card → a 1080×1350 hero card with the art, name, rarity and a NEW
   tag; the pack summary → a 4×2 grid of the best pulls with a stats line
   (cards · rare+ · foils) and the best-pull line. Uses the platform share
   sheet when available, otherwise downloads the PNG. Card art is fetched as
   a blob before drawing so the canvas isn't tainted and toBlob() succeeds;
   the pack-open prefetch means it's usually instant. FR + EN.)
7. `refactor(onboarding): replace the blocking gate + modal walkthrough with in-place coach marks`
   — files: index.html, TEST_index.html, tests/pdhelper.py
   (the first screen is now the game itself, immediately playable — no
   language wall, no modal. The UI language is auto-detected from the browser
   on first run (saved once), with an always-visible EN/FR toggle in the
   topbar as the one-tap override. Onboarding became three contextual hints
   that point at the real control and retire the moment the player uses it:
   the pack before the first open, the card during the first reveal, the Arena
   tab after the first pack is banked. Each hint is a spotlight + tooltip,
   never modal: the dim layer and the bubble are pointer-events:none so a hint
   can never swallow a tap meant for the game — only the quiet "Got it"
   dismiss is tappable. The `onboarded` flag lives in prefs. pdhelper's
   dismiss_overlays clears stray coach marks for fresh contexts.
   Fixes a real bug this exposed: the coach bubble previously had
   pointer-events:auto and silently ate a Collect tap on the Badges screen.)
8. `feat(pwa): service worker + manifest so PackDrop installs and works offline`
   — files: index.html, TEST_index.html, sw.js, manifest.json, icon.svg,
     icon-192.png, icon-512.png, icon-maskable-512.png, apple-touch-icon.png,
     favicon-32.png
   (new files this commit — see the note at the bottom about uploading all of
   them, not just index.html. `sw.js` caches the app shell (index.html,
   manifest, icons) and Google Fonts; navigations are network-first with the
   cached shell as the offline fallback, so a deployed update is always picked
   up when online but the game still opens with no connection. Same-origin
   statics are cache-first. Scryfall art and the Supabase/price feeds are
   deliberately passed through — large, dynamic, and already handled
   gracefully when unavailable. The manifest declares standalone display,
   portrait, dark theme, and a maskable icon. Registration is isolated in its
   own script and gated off in dev mode (?dev=1 / file://) so the test suites
   can never run against a cached build; if sw.js is missing it silently
   no-ops. Result: installable to home screen, instant repeat loads, and
   because the app already persists its card pools in localStorage the full
   UI renders offline after one online visit.)
9. `feat(data): export / import / reset the save from Settings`
   — files: index.html, TEST_index.html
   (a new "Your Data" section in Settings gives the player ownership of their
   save. Export downloads `packdrop-save-<date>.json` — the exact
   buildProfileSnapshot() object, so it round-trips with no lossy step in
   between. Import validates the file (must parse, and must carry
   schemaVersion + collection + stats) before anything is touched, then shows
   a summary of what is about to be restored — cards, packs opened, saved
   date — and warns that the current save is overwritten; cancelling changes
   nothing. Reset wipes the save (localStorage or Supabase, whichever is in
   play) and restarts the app fresh, behind a confirmation that states the
   loss is permanent. Reset is styled red so it never reads like a normal CTA.
   Import re-renders every collection-derived screen, not just the stats row,
   so an imported collection actually shows up in the Binder and Badges.
   Fixes a real bug this exposed: the file input kept its value after an
   import, so choosing the same backup twice silently did nothing.
   FR + EN, all 193 keys verified to resolve in both languages.)
10. `fix(storage): surface a full localStorage instead of silently dropping saves`
   — files: index.html, TEST_index.html
   (a guest save lives in localStorage under a ~5MB-per-origin ceiling, shared
   with the price-feed and card-pool caches. `sSet` caught and discarded EVERY
   error, so when the ceiling was reached the save simply stopped persisting
   and the player lost everything since the last successful write with no
   warning at all. `sSet` now re-throws quota errors (matched by name
   QuotaExceededError / NS_ERROR_DOM_QUOTA_REACHED and by code 22/1014, since
   the name varies by browser) while still swallowing genuinely non-fatal
   ones, and `saveProfile` turns that into a persistent warning banner naming
   the problem and offering an Export backup — export reads from memory and
   writes a file, so it still works when storage is full. The banner is
   deliberately not a toast: it has to persist until the player acts. It also
   sits clear of the fixed tab bar, because a warning the player cannot reach
   is no warning. `navigator.storage.estimate()` adds a proactive heads-up at
   90% of the origin budget, measured across the whole origin so the caches
   count toward the real ceiling; cloud (signed-in) saves skip the check since
   they have no local ceiling. FR + EN.)

11. `fix(i18n): translate the Arena screen, which was entirely English in French`
    — files: index.html, TEST_index.html, tests/engine/arena_ui.js,
      tests/engine/arena_dungeons.js, tests/engine/arena_elements.js,
      tests/engine/arena_cp.js
    (the Arena renders its whole screen from JS, so it was invisible to the
    `[data-i18n]` sweep that translates the static DOM — every dungeon name,
    twist rule, difficulty tier, element label, CP verdict and run-summary
    stat stayed English. Each arena data object now carries a parallel
    `labelFr`/`blurbFr`/`nameFr`, resolved through one `frPick()` helper that
    is duplicated per module (each file is an IIFE the node suites require()
    standalone) and guarded with `typeof uiLang` so the suites still get the
    English they assert on. The screen also now re-renders on a live language
    toggle — previously it kept showing the old language until the player
    navigated away and back. `gatedByTier()` was added so the lock hint can
    name the required tier in both languages without matching on display text.
    FR + EN.)

12. `feat(packs): replace the daily 4-pack allowance with hourly accrual`
    — files: index.html, TEST_index.html
    (free packs were `packsLeft: {date, left}` — a calendar-day reset. That
    punished anyone who missed a day (the allowance simply evaporated) and
    rewarded nobody who played twice (the second session got nothing extra).
    They now ACCRUE: one per hour up to a cap, and the cap grows +1 every 10
    Collector levels, so a long-term player ends each session with more waiting
    than a new one. Time the tab was closed counts, which is the point. The cap
    has a ceiling at 8 (reached level 40) on purpose — uncapped it reaches 14 at
    level 100, and the Arena's shard rates were tuned against roughly four
    packs a day, so unbounded growth would inflate the collection faster than
    the economy expects. The header chip shows a live countdown ("+1 in 45m")
    so the allowance is not a number that silently stalls; the out-of-opens
    dialog names the next pack time instead of saying "tomorrow". Saves from
    the old shape migrate by keeping the banked count and starting the clock at
    load time — no retroactive windfall. FR + EN.)

## Verified green

`python3 tests/run_all.py` → **8/8 suites PASS, 0 assertion failures, 0 harness
problems**: economy ✓ · check_fixes 15 · check_progress 13 · check_feedback 11 ·
check_reveal 0 · check_tear 9 · check_achievements 39 · sweep 0.

The three data actions were additionally driven end-to-end against a real
browser (34 checks): a valid backup downloads and round-trips; a bad file and a
non-JSON file are both rejected with a message and **no** wipe; import shows a
summary then replaces collection, shards and packs, and updates the shard chip
on screen; cancelling an import changes nothing; reset erases the old
collection/shards/packs and restarts the app at zero.

The storage fix was driven the same way (13 checks): a genuine
`QuotaExceededError` is thrown at the real save path (via a real `DOMException`
— headless Chrome's eviction policy will not exhaust the origin on demand, so
the browser condition is simulated rather than the app's error handling), the
warning appears with the correct message, export still succeeds while storage
is full, the banner dismisses, and the app stays on a tappable pack with no
page errors. The banner is measured to sit 8px clear of the fixed tab bar.

## Feature summary

- **Arena infinite idle mode** — "∞ Infinite" button label + endless-floors
  title + tier subtitle; idle runs skip beat-replay, pitch at the deepest
  cleared tier, auto-build a 5-card team if none chosen.
- **Rule chip** — leading "Rule" label in the twist band.
- **Badges set-ff:10 milestone** — 25-shard Collect that advances the tier
  (10% → 20% → 30% …); dot on the Badges icon (not Arena); one collapsed
  set-badge per family showing the live tier.
- **Pull-rail** — per-pull log persistence (`pd:pull-log`, capped) + a
  recent-pull rail populated by the reveal.
- **Sidebar** — three-column workspace above 1100px (nav rail left, pack
  centre, sidebar right); desktop CSS override scoped to one `#app` block at
  the end of the file (so it wins the cascade).
- **Data (export / import / reset)** — a "Your Data" section in Settings.
  Export writes `packdrop-save-<date>.json`; import validates the file before
  touching anything, previews what it will restore, and replaces the save
  behind a confirmation; reset wipes the save and restarts fresh. Import
  rebuilds every collection-derived screen, not just the stats row.
- **Free packs accrue hourly** — no longer a once-per-day allowance. One free
  pack per hour up to a cap that starts at 4 and grows +1 every 10 Collector
  levels, capped at 8 (level 40). A missed day rolls forward instead of
  evaporating, and a second session the same day has something waiting. The
  header chip shows a live countdown to the next one.
- **No queue on the free-pack clock** — one continuous countdown, not a queue.
  The clock starts only when a spend drops the bank off its ceiling, and later
  spends leave it running: opening a second pack at 2/4 does not buy back the
  hour the first one already spent waiting. At 0/4 the player therefore waits
  roughly an hour per missing pack, not an hour in total.
- **Deep stats on Profile** — three derived-only panels (rarity distribution
  bar + foil/duplicate/rare+ rates, per-set completion, and an XP sparkline
  over recent pulls). Every number is computed from data already in the save,
  so no migration is needed. Set progress reuses `expansionCompletion()`, the
  same function the badge ladder judges, so the percentage here can never
  disagree with a "10% reached, claim it" badge. Each section hides itself on
  an empty save rather than rendering a heading over nothing.
- **New set: 30th Celebration (Pokémon)** — the anniversary product, and the
  most generous Pokémon booster ever printed. Five-card packs (not the 11 every
  other Pokémon set here uses), and the 5th slot is a **guaranteed** Classic
  Collection rather than a reverse-holo — the biggest structural departure from
  any other generator in the app. Hit-slot odds are TCGplayer's Authentication
  Center figures from 3,000+ packs (Double Rare 21.02%, Illustration Rare
  19.72%, Classic Collection 10.15%, Special Illustration Rare 4.88%,
  Futuristic Rare 0.83%), validated by a 600-pack probe that lands every tier
  within ~1.6pp of published. Adds three new rarity tiers the classifier now
  knows — Classic Collection, Futuristic Rare, and RGB Rare. The RGB Mews drop
  at 1 in 4,063 (0.0246%), the only rate anyone has actually measured — a
  200,000-pack probe lands it at 0.02500%, within 0.1 sigma of target.
- **Storage self-heals instead of warning the player** — a single expansion's
  card pool caches at ~3.9MB against Chrome's ~5MB per-origin budget, so two
  expansions plus their price feeds left the player's 43KB save as the first
  write to fail. On a quota failure the save now evicts the disposable caches
  (`pools-`, `priceFeed-`, `langpack-`) and retries before surfacing anything;
  the banner only appears when the caches were already gone and the save truly
  has nowhere to go. The ten pool-cache writes and the price-feed write are
  also guarded, so a full quota can no longer abort an expansion load or
  silently downgrade a successful price fetch to stale data.
- **Arena** — an idle auto-battler. Six dungeons (five elemental plus one
  neutral, because 26% of a real Final Fantasy sample is colourless), each with
  a twist *rule* rather than a stat multiplier, and three gated difficulty
  tiers. Fully bilingual FR + EN: dungeon names, twist rules, difficulty tiers,
  element labels, the recommended-CP verdict and the run summary all follow the
  UI language, and the screen re-renders live when the language is toggled.
- **Storage-budget warning** — a full localStorage no longer drops saves in
  silence. A quota failure raises a persistent banner naming the problem and
  offering a one-tap Export backup (which still works when storage is full,
  since it reads from memory); `navigator.storage.estimate()` adds a
  proactive heads-up at 90% of the origin budget.

## Upload these files to the repo root

Commit 8 turns PackDrop into an installable PWA, which means **9 new files
alongside `index.html`**. A PWA is only as complete as the files that are
actually present — uploading `index.html` alone gives you no install prompt
and no offline (it degrades safely, but silently):

```
index.html              (the game, updated)
TEST_index.html         (dev copy — optional, keep if you track it)
sw.js                   (required — this is what makes it installable)
manifest.json           (required — install metadata + icons)
icon.svg                (vector favicon source)
icon-192.png            (required by the manifest)
icon-512.png            (required by the manifest)
icon-maskable-512.png   (Android adaptive/home-screen icon)
apple-touch-icon.png    (iOS home-screen icon)
favicon-32.png          (browser tab icon)
```

Everything is already staged in this `Github/` folder at the repo root, so it
is a straight drop-in — do not nest it in a subfolder, or `sw.js` will fail to
claim the right scope. After uploading, hard-refresh once
(Cmd/Ctrl+Shift+R) so the worker installs.

## Notes

- This `Github/` folder is a **staging folder only — do not commit it** to the
  repo. It is not tracked.
- `review/` and `work/` (untracked, scratch) are not needed for the repo.
- After import, confirm green locally: `.venv/bin/python tests/run_all.py`
  (or `python3 tests/run_all.py`).
