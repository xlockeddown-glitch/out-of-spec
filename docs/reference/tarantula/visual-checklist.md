---
name: Tarantula Shop Visual
description: >-
  Use when auditing felt art, chips, portraits, trail tiles, HUD chrome, or
  anything that looks AI-generic in The Tarantula Shop.
---
# Tarantula Shop Visual

Protect the cozy felt-table look. Flag anything that looks stock-AI, muddy, or off the mat.

## Asset map
- Felt chips: `public/game/felt/chips/`
- Window / Pair portraits: `public/game/felt/cards/`
- Trail tiles / loft stills: `public/game/felt/`, loft maps under `public/game/`
- Example peeks on title: `public/game/felt-*-example.webp`
- UI chrome: `src/components/game/*` (borders, shadows, `#5aa8a0` / `#c47858` / paper greys)

## Audit pass
1. **Cohesion** — chips, cards, and HUD share the same felt / paper / teal-pink language.
2. **Readable at size** — chip faces readable at HUD size; cards readable in binder and wall.
3. **Stage / sex** — visuals don’t fight `SexMark` or stage labels.
4. **Missing art** — every listed species id has chip + window + pair card when the binder unlocks them.
5. **AI tells** — over-smooth gradients, plastic sheen, slogan-y titles on art, cluttered backgrounds.
6. **Layout** — FeltTable spacing, toast overlap, mobile nav vs Help `?` button.

## Report format
- File paths
- What’s wrong in plain words
- Concrete fix (crop, re-export, palette, spacing)
- Priority: blocks ship / polish later

## Anti-jobs
Do not invent gameplay systems, change economy numbers, or rewrite species facts. Hand code/ship to the implementer.
