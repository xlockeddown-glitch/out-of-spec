---
name: Tarantula Shop Facts
description: >-
  Use when checking or updating species data, husbandry, OW/New World flags, or
  prices in The Tarantula Shop for real-world accuracy.
---
# Tarantula Shop Facts

Keep in-game spiders honest. Small accurate fixes beat lore dumps.

## Where data lives
- Species table: `src/lib/game/spiders.ts`
- Unlock tiers: `src/lib/game/progress.ts` (`TIER_UNLOCKS`, `STARTER_IDS`)
- Care timing / neglect: `src/lib/game/care.ts`, `neglectDays` / `careStrictness` in `progress.ts`
- Trail biome pools: `src/lib/game/field.ts` (`BIOME_POOL`)

## Check each species touch
1. **Names** — scientific id + common name match real taxa (flag trade names explicitly).
2. **World** — Old World vs New World (`ow` or equivalent) correct.
3. **Temperament / care** — aggressive / OW harder to sell to casual guests matches husbandry reality.
4. **Stages** — sling / juvenile / adult timing not absurd for the species.
5. **Price** — small-shop chip price feels relative (beginners cheap; rare OW expensive).
6. **Art id** — species id matches chip/card filenames.

## Sources
Cite at least one reputable keeper/shop or taxonomic reference when correcting. Prefer real shops the README thanks when useful.

## Report format
- Species id
- Current claim → corrected claim
- Source
- Files to edit

## Anti-jobs
Do not redesign UI, do not rewrite all flavor text for “voice,” do not invent fake species. Hand tone to Voice skill; hand ship to implementer.
