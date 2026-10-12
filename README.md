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

## Verified green

`python3 tests/run_all.py` → **8/8 suites PASS, 0 assertion failures, 0 harness
problems**: economy ✓ · check_fixes 15 · check_progress 13 · check_feedback 11 ·
check_reveal 0 · check_tear 9 · check_achievements 39 · sweep 0.

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
