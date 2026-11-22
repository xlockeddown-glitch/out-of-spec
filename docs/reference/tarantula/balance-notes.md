---
name: Tarantula Shop Balance
description: >-
  Use when tuning Tarantula Shop chips, rent, unlocks, guest counts, truck
  prices, or early-game pacing.
---
# Tarantula Shop Balance

Keep early game fair and late game readable. Propose numbered tweaks with why.

## Knobs
- Cash / rent / feeders: `src/lib/game/spiders.ts` (`RENT_PER_NIGHT`, feeder packs, tank costs, `fairAsk`)
- Unlocks: `src/lib/game/progress.ts` (`TIER_UNLOCKS`, loft upgrades, window slots, daily guests, shop caps)
- Returns book: `src/lib/game/returns.ts`
- Trail forage chance: `src/lib/game/field.ts` (`forageRoll`)

## Checks
1. Day 1–4: can pay rent without perfect play; nothing dies the first four days (care rule).
2. Window panes vs guest count — more glass ≠ more buyers (by design).
3. Elizabeth hire gate and Trail unlock feel earned, not brick walls.
4. Truck pricing doesn’t strand a beginner who bought adults they can’t house.
5. Unlock tiers don’t dump OW stock before the player can care for it.

## Report
- Proposed numbers (before → after)
- Why
- How to smoke (which days / actions)

## Anti-jobs
Do not rewrite voice copy or art. Hand ship to implementer.
