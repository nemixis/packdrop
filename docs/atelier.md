# PackDrop — The Atelier (gameplay spec)

> Captured from the user's design doc 2026-10-30. This is the target for refining
> the current **Mint** tab into a commission-based crafting facility.

Working title: The Atelier. Category: collection management / light team-building / idle crafting.
Purpose: give collected cards a gameplay purpose — assemble teams, complete commissions,
permanently unlock unique cosmetic finishes.

---

## 1. Core concept
Facility where players send teams of FOUR cards on commissions.
Each commission: theme, requirements, preferred composition, a cosmetic finish reward,
difficulty + duration. Player picks ONE **Target Card** (gets the finish) + FOUR
**Specialists** (complete it). Roles/affinities/synergies decide quality.
Completion permanently unlocks the finish on the target. Specialists return, reusable.
**No card is ever consumed/destroyed/modified as a cost.**

## 2. Loop
Open Atelier → browse commissions → pick one → pick Target → assemble 4 Specialists →
review predicted performance → dispatch → wait → collect + reveal grade → apply finish →
re-team for the next. The interesting part is step 5 (finding the right combination).

## 3. Commission families (data-driven)
- **A. Elemental Resonance** — Fire/Water/Electric/Grass/Psychic/Dark finishes.
  Req: ≥2 Pokémon of the requested type preferred; Energy = stability; Supporter = technique.
- **B. Astral Restoration** — nebula / stars / cosmic holo / celestial borders.
  Req: Psychic/Dark/Dragon preferred; Supporter = technique; balance = stability.
- **C. Prismatic Calibration** — rainbow foil / iridescent / chromatic / refraction.
  Req: Items = precision; role variety = performance; Energy = stability.
- **D. Arcane Engraving** (post-MVP) — golden engraving / metallic / ornamental / geometric.
  Req: Items = precision; Supporters = technique; diversity bonus.

## 4. Target card
From collection; not also a Specialist; receives the finish; small affinity bonus if it
matches. Never consumed. Support every card category the render system can finish (not just
Pokémon). A card can accumulate MULTIPLE finishes and switch which is displayed.

## 5. Specialist roles (keep existing four)
| Role | Responsibility | Benefit |
|---|---|---|
| Pokémon | Affinity | elemental/thematic synergy |
| Supporter | Technique | execution, cuts time |
| Energy | Stability | raises floor, cuts penalties |
| Item | Precision | finish quality, commission-specific bonus |
A role is never useless outside its preferred commission; every card has a baseline.

## 6. Composition & synergy
4 free slots; any eligible card in any slot; role auto-detected.
- Individual contribution (base + requirement match bonus)
- Role diversity (1 of each = full bonus; not forced)
- Team synergy (compatible affinities, e.g. Fire Pokémon + Fire Energy)

## 7. Performance (0–100, transparent, deterministic)
| Component | Max |
|---|---:|
| Four Specialists base (10 each) | 40 |
| Commission requirement matches | 20 |
| Role diversity | 10 |
| Team synergy | 20 |
| Target affinity | 10 |

Rarity must NOT dominate — a common card must be able to reach Z. Every commission is
completable; weak team = lower grade, never blocked.

Grade thresholds (start, tune later): C 0–39 · B 40–54 · A 55–69 · S 70–79 · R 80–89 ·
X 90–96 · Z 97–100.

## 8. Duration (idle)
Tiers: Basic 2m · Advanced 5m · Expert 10m · Master 20m. Supporters cut time; Energy cuts
instability. Duration must NOT determine grade — grade is computed and LOCKED at dispatch.
Preserve the existing resumable-run architecture.

## 9. Cosmetic finish system
Two axes: **Finish Family** (visual identity) × **Grade** (intensity C→Z). Reuse the existing
CSS grade effects; build a MODULAR finish system (family = theme, grade = intensity), not 7
render systems per family.
Permanent unlock keyed by **Target Card ID + Finish Family ID**. Best grade kept (only replace
if better; never downgrade). Multiple families coexist; player switches the displayed one.

## 10. Progression
Start with a few basic commissions; completing unlocks harder tiers, more families,
requirements, advanced treatments. Difficulty raises composition challenge, not just rarity.

## 11. UI — four screens
A. Commission Board (cards: name, theme, requirements, roles, difficulty, duration, finish
preview, lock state). B. Team Builder (target + 4 slots + collection picker + role/affinity
indicators + synergy + score + predicted grade; live preview; explain bonus deltas; filters
role/type/rarity/expansion/owned; inspect before assign). C. Commission Running (target, 4
specialists, theme art, timer, expected grade, completion; locked at dispatch; leave & return).
D. Result & Reveal (notif → target appears → finish revealed → grade badge → added to card →
inspect; reuse Mint reveal animation).

## 12. Constraints (enforce)
No consumption/destruction; no random rolls; no downgrades; no rarity-exclusive ceilings; no
mandatory rare card; target ≠ specialist; a card in an active commission can't be reused until
done; every card contributes; every commission completable; deterministic + reproducible;
player can understand the grade. No hidden probabilities.

## 13. MVP scope
Atelier facility; 3 families (Elemental, Astral, Prismatic); 3 difficulties; 1 target; 4
specialists; 4 roles; composition/synergy calc; transparent score; 7 grades; permanent unlock;
timers + persistent state; result/reveal. Reuse Mint's picker/roles/grade ladder/CSS/state/
reveal. Refactor the math, don't replace everything. Data-driven (new family/affinity/finish =
config, not new engine).

## 14. Success criteria
Reason to inspect beyond rarity; commons stay useful; different commissions want different
teams; pursue specific finishes; team-building feels meaningful; satisfying reveal; scales to
more TCGs.

---

## Mapping to the current Mint (reuse plan)
- Mint tab → becomes **The Atelier** (same tab, richer content).
- `mintDraft` (target + 4 judge keys) → target + 4 specialist keys.
- `mintJudgeRole()` (type_line parsing) → specialist role detection (unchanged).
- `MINT_RARITY_BASE` / `mintParts()` / prestige cap → replaced by the transparent
  40/20/10/20/10 performance formula (deterministic; rarity = tiny prestige only).
- `MINT_GRADE_LO` → new thresholds C0/B40/A55/S70/R80/X90/Z97.
- `mint.grades[key]=g` → `mint.finishes[key] = { <familyId>: <bestGrade>, shown: <familyId> }`.
- `.mg-*` CSS + `.mg-ring` → finish rendering: family picks palette/motif, grade picks intensity.
- Reveal markup `mintRevealMarkup()` → commission reveal (family + grade).
- Resumable timer (`startedAt`, resume on load) → per-commission tier duration, grade locked at dispatch.


## Balance pass (measured 2026-10-31)

Scoring weights (max): Base 12 (3/card) · Requirements 28 · Diversity 12 · Synergy 30
(typeHits×4 + same-type pairs×6) · Target affinity 14 · Prestige 6 · Precision 8 (4/item) · Stability floor 6/energy.

Grade thresholds: `C <44 · B 44-59 · A 60-74 · S 75-85 · R 86-91 · X 92-96 · Z 97+`.

Tier grade caps (prestige gate): **Basic → S, Advanced → X, Expert → Z** — R/X/Z therefore
require the harder juries. Requirement unmet still caps at B (or A with ≥2 Energy).

Measured with the live engine (34-card synthetic collection, 3000 random teams per
commission, 12-restart hill-climb for the ceiling):

- Random play: **C 42% · B 32% · A 19% · S 6.6% · R 0.1% · X 0% · Z 0%**
- Ceiling: Elemental/Astral 95-98 (X/Z only with a near-perfect Expert team); Prismatic-Expert 89 (R).
- Prismatic affinity narrowed to Colorless/Dragon/Psychic/Water so the family can no longer
  score X/Z by accident off a random team.


## Rebalance v2 — grade pedigree (2026-10-31)

Card **grade now feeds the score**. New component **Pedigree** (0-12) = mean of the specialists'
best minted grade (C1 B2 A4 S6 R7 X8 Z9) x1.3. Ungraded cards contribute 0.

Weights: Base 8 (2/card) · Requirements 24 · Diversity 12 · Synergy 24 · Target affinity 12 ·
Prestige 3 · **Pedigree 12** · Precision 6 · Stability floor 6/energy.

Thresholds: `C <40 · B 40 · A 56 · S 72 · R 80 · X 86 · Z 92`.
Tier caps unchanged: Basic → S, Advanced → X, Expert → Z.

Measured (hill-climb ceiling per collection profile):
- **Ungraded cards**: perfect build tops out ~81 (R). S is reachable, X/Z are not.
- **All-B build**: ceiling 84. **All-S**: 89 (R). **All-Z**: 93 (Z reachable only with a near-perfect Expert team).
- Random play (ungraded): C 55 / B 34 / A 11 / S 0.1 — grades must be earned.
- Grade swing on an average team: median 46 (ungraded) → 58 (all-Z), i.e. ~12 points ≈ one full grade band.

UI: picker shows a per-card **score delta** (+/-) for the slot being filled, the card's **minted grade badge**,
and a ◆ **match** marker for the commission's affinity; filters are **multi-select** (types/roles + rarities,
both scroll rows) and the builder carries a **"How is the score calculated?"** legend plus a
**Next · grade at N pts** line.


### Balance pass v2.1 (final, 2026-10-31)

Thresholds: `C <40 · B 40 · A 56 · S 72 · R 82 · X 85 · Z 88` + **Z requires pedigree >= 10**
(average specialist grade around X tier). Tier caps: Basic → S, Advanced → X, Expert → Z.

Family fixes: Astral roles now `pokemon/supporter/item` (ceiling 74 → 90 with Z cards);
Prismatic synergy counts item/energy roles (theme payoff), ceiling 85 → 89; precision cap 8.

Measured ceilings (perfect Expert build):
- ungraded 77-81 → **S max**
- all-B 80-84 → **R**
- all-S 85-89 → **X**
- all-Z 89-93 → **Z** (gate satisfied)

Random play: ungraded C56/B33/A11 · all-B C50/B34/A16 · all-S C39/B38/A21/S2.5 · all-Z C29/B43/A22/S5.5.

Live scenario (same Expert build): B-graded team scores 78 → S; swapping the same team to S-graded
scores 83 → R (+5 pts, one full band). Grade choice is worth a grade.


## Design v3 — live score, success rolls, role economy (2026-11-01)

**Live score**: the panel renders as soon as a target is picked and re-renders on every placement
(target only → 4; +1 specialist → 40; +item → 48), so the score moves under your hands.

**Success roll**: every commission now has a success chance and can fail.
- `success = 92 - gradeIndex*6 + items*7 + energy*2 + supporters*2 - (unmet ? 25 : 0)`, clamped 5-99.
- On failure the attempt is **lost**: no finish is banked at all (nothing written to `mint.finishes`/`mint.grades`),
  only half the shard reward is paid. A failed attempt costs time, not resources, so the roll can be harsh.
- The roll is seeded per dispatch and stored on the active commission, so a resumed/offline commission
  resolves exactly the same way — but re-dispatching the same team re-rolls.
- This creates the intended tension: high grade = risky, items buy safety, so a player trades score
  for certainty.

**Role economy** (all four roles now matter for different reasons):
- Judge (Pokémon) → requirements, synergy, target affinity (score)
- Supporter → −30 s duration AND Support score (+4 each, max 10)
- Energy → score floor (stability) AND +2% success each
- Item → Precision score AND +7% success each

**Balance**: synergy cap cut 24→18 (same-element stacking is no longer king); requirement 26,
diversity 14, support 10, target 12, pedigree 12, precision 8.
Measured on Basic: mono-Fire team 69/A/82% vs Fire+Supporter+Item+Energy team 76/S/85%.
Ceilings: ungraded 76-80 (S), all-B 79-83 (R), all-S 84-88 (X), all-Z 88-92 (Z, pedigree gate).

**Tier value is now visible**: every board tile shows its grade cap and payout
(Basic max S +10 ◆ · Advanced max X +25 ◆ · Expert max Z +60 ◆), so Advanced/Expert have a
stated reason to be played. Reward is halved on a failed attempt.


## Magic side — same engine, different nouns (2026-11-03)

Magic cards store no colours, so the Atelier derives them: parse the mana cost for `W/U/B/R/G`
(falling back to basic land types), otherwise `Colorless`.

**Role mapping** (Magic types → the engine's four universal roles):

| Magic type line | Engine role | UI label |
|---|---|---|
| Creature / Planeswalker | `pokemon` | Creature |
| Instant / Sorcery / Enchantment | `supporter` | Spell |
| Land | `energy` | Land |
| Artifact | `item` | Artifact |

**Families:** Elemental Resonance → **Color Resonance** (first slot's colour sets the target colour);
Astral Restoration → **Arcane Weave** (Blue/Black affinity); Prismatic Calibration →
**Artifact Calibration** (Colorless affinity, artifact/land roles).

The elemental finish pipeline is reused unchanged: Magic colours get their own
`.fam-elemental-<white|blue|black|red|green|colorless>` wash/ring CSS, and finishes store as
`elemental-green` etc. Scoring, success rolls, pedigree, tier caps and rewards are identical —
only `atelierRole()`, `atelierTraits()`, `atelierFamilyLabel()` and `atelierSpec()` branch on game.

Switching the Pokémon/Magic tab resets the bench (commissions and family sets differ per game).


## Magic balance pass — 905 real cards (2026-11-03)

Sample: Scryfall, 3 sets (FDN/DSK/BLB), 905 cards — creatures 507, spells 298, lands 59, artifacts 41.

Findings and fixes:
1. **Rarity scale mismatch.** MTG tops out at `mythic` while Pokémon ranks run to `hyperRare`, so Magic
   prestige (and therefore its whole ceiling) capped at **87 — Z was unreachable**. Added
   `atelierRarityRank()` normalising common 0 / uncommon 2 / rare 5 / mythic 8.
   Ceilings after: ungraded 86-88, all-S 94-96, all-Z 98-100 (Z reachable).
2. **Artifact Calibration was a trap** — only 41 artifacts + 59 lands in 905 cards, so 71% of random
   teams ended at C. Colorless cards now also count as calibration stock, and Expert asks for 2
   (not 3). A deliberate artifact build now scores **80 / S** on Expert.
3. **Family identity confirmed on real cards**: Color Resonance → mono-colour 68; Arcane Weave →
   Blue/Black 70 vs off-colour 34; Artifact Calibration → artifact stack 80 vs mono 30.
4. Success by grade on Magic: C ~70%, B ~70-88%, A ~84-91%, S ~79-85% — items still the safety valve.

Pokémon scoring is unchanged by all of this (verified live: 67/A/89%).
