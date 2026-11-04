# Changelog

Notable changes to PackDrop. Dates are commit dates, not release dates.

## Unreleased — playtest build

### Added
- **Atelier**: commission-based crafting for both Pokémon and Magic, with requirement
  gating, elemental/colour resonance, deterministic scoring with a grade pedigree,
  seeded success rolls, downgrade-on-failure and tier rewards. Spec: `docs/atelier.md`.
- **30th Celebration — Classic Collection**: the 30 gold-bordered reprints added to the
  set (metadata from TCGdex, scans vendored under `assets/30c/`). Set is now 191 cards.
- **Reveal sequence**: spotlight stage, rarity-driven auras, hero-scale card, designed
  load state, summary pedestal.
- **Reward shortcut** on the pack summary when a pull creates a claimable level reward.
- **Booster sleeve**: series line, card count and year printed on the wrapper, with a
  per-series weave.

### Changed
- **Art direction** reworked end to end ("Obsidian Gallery"): tokens, shell, packs,
  collection, detail sheet, Atelier and nav share one visual language. Log: `docs/redesign.md`.
- **30th Celebration slot 3** now matches published rates — Common 70% · Illustration
  Rare 20% · Classic Collection 10%. Guaranteed Pikachu Rare stays in the last slot only,
  so a pack holds exactly one Pikachu print.
- Collection opens on **All** instead of an empty "Owned" filter.

### Fixed
- **Reveal stuck on "Loading art…"** — `img.decode()` never settles for CDN images; load
  events are now the source of truth, with a timeout and a low-res retry.
- **Spinner painted over loaded art** (styles set `display:flex` unconditionally).
- **Overlays stacking inside the page** — `#app > *` was overriding fixed positioning.
- **Daily login overflow** below ~1150px (163px past the panel); now reflows, 2 columns on phones.
- **Expansion titles truncated** to 14px in the rail at every width.
- **Signup nudge** no longer covers the first pack's reward.
- **Index files consolidated**: `TEST_index*.html` removed; `index.html` is the single
  shipped build.

## Notes
- Pull-rate sources and per-slot tables: `docs/pull-rates.md`.
- Supporter/Energy/Item role effects and Atelier scoring weights: `docs/atelier.md`.
