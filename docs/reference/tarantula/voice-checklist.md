---
name: Tarantula Shop Voice
description: >-
  Use when rewriting player-facing Tarantula Shop copy so it sounds like a human
  shopkeeper, not polished LLM prose.
---
# Tarantula Shop Voice

Make every player-facing string sound like a real keeper wrote it on a sticky note.

## Voice anchors
- README tone (plain, concrete, short)
- Best Elizabeth toasts in `src/lib/game/store.ts` (till / racks current)
- Avoid: slogans, “delightful journey,” thesaurus adjectives, fake clever compounds, checklist-speak in coach cards

## Copy hotspots
- `src/components/game/HelpGuide.tsx` (fix stale lines — e.g. wall already ships)
- CoachCard / onboarding in `src/components/game/FeltTable.tsx`
- Toasts and journal in `src/lib/game/store.ts`
- Trail blurbs: `src/lib/game/field.ts` (`cardBlurb`, labels)
- Loft upgrade blurbs: `src/lib/game/progress.ts` (`LOFT_UPGRADES`)
- Title / pack / evicted screens: `src/components/game/GameApp.tsx`
- Retire leftover loft-controller phrasing (“E on the jar,” bay talk) if still present

## Rewrite rules
1. One concrete action per sentence.
2. Keeper vocabulary: jars, panes, rack, till, chips, sac — not “inventory units.”
3. Numbers only when the player needs them; don’t read like a spec sheet.
4. Species claims → hand to Facts skill before shipping.
5. Keep Help useful; don’t pad.

## Deliverable
- Table: file → old line → new line
- Call out stale/wrong help
- Hand implementation to the ship skill / implementer

## Anti-jobs
Do not change rules or economy numbers. Do not turn the README into marketing.
