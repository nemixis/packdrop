# PackDrop

A browser-based trading-card collection game. Open boosters with real published pull
rates, build a collection across sets, and craft finishes in the Atelier.

**Status: playtest.** The build is feature-complete enough to hand to testers, not yet
released. Expect breaking changes between commits.

Live (playtest): <https://nemixis.github.io/packdrop/>

---

## What it is

PackDrop is a **single-file application**. `index.html` contains the markup, the
stylesheet and the game logic — roughly 1.2 MB, no build step, no bundler, no
framework. That is a deliberate constraint: the game can be served from any static
host, opened offline through the service worker, and forked by copying one file.

Everything the game knows about cards is fetched at runtime from public card APIs and
cached in `localStorage`; nothing is baked into the repository except the 30 local
scans described under [Assets](#assets).

## Run it locally

No dependencies. Any static server works:

```bash
python3 -m http.server 8899
# open http://127.0.0.1:8899/index.html
```

`file://` will not work — the service worker and the card fetches both need an origin.

## Repository layout

```
index.html            the entire application (markup + CSS + game logic)
assets/30c/           30 local card scans (see Assets)
sw.js                 service worker: app shell + offline
manifest.json         PWA manifest
docs/                 design + data documentation
  redesign.md         art direction and the redesign log
  pull-rates.md       booster composition and drop rates, with sources
  atelier.md          the crafting mode: scoring, requirements, balance
tests/
  jscheck.js          parses every inline script (the syntax gate)
  pdhelper.py         shared Playwright helpers for the browser suites
.github/workflows/    CI: syntax gate on every push and PR
```

## Testing

```bash
node tests/jscheck.js
```

That extracts every inline `<script>` from `index.html` and parses it. Because there is
no build step, nothing else catches a stray brace — the failure mode is a blank screen.
**This gate runs in CI on every push**; a commit that fails it should never reach `main`.

Browser suites live in `tests/pdhelper.py` (Playwright). They are run manually: they
drive a real browser, open packs and assert against rendered state, which needs a local
server and a fresh profile.

## Data and drop rates

Card data comes from [TCGdex](https://tcgdex.dev) (Pokémon) and
[Scryfall](https://scryfall.com) (Magic: The Gathering). Booster composition is modelled
per set from published pull-rate studies; the tables and their sources are in
`docs/pull-rates.md`. Rates are never invented — where a tier has no published art or
data, the gap is documented rather than filled with a guess.

## Assets

The 30 scans in `assets/30c/` are the **Classic Collection** reprints from the 30th
Celebration set. TCGdex publishes their metadata but no artwork, so the scans were
sourced from [pokecardex](https://www.pokecardex.com) and vendored here so the art
cannot disappear mid-session.

They are **official Pokémon card scans, © The Pokémon Company** — see `NOTICE.md`.
PackDrop is a free, non-commercial fan project and claims no affiliation.

## Licence

- **Code** (`index.html`, `sw.js`, `tests/`): MIT — see `LICENSE`.
- **Card artwork and card data**: property of their respective rights holders, used
  here under fan-project terms. Not covered by the MIT licence.

## Contributing

Changes land on `main` only through the CI gate. Keep gameplay logic and presentation
separate: the redesign work in `docs/redesign.md` touched styling and layout exclusively,
and the pull-rate model in `docs/pull-rates.md` is the reference for anything that
changes what a booster contains.
