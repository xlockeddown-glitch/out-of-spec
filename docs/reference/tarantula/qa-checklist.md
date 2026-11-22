# Tarantula Shop QA checklists

Combined from the retired shop skills `tarantula-shop-qa` and `tarantula-qa`. Paths in these checklists still point at The Tarantula Shop; they are reference only. The live Out-of-Spec playtest script is `docs/playtest.md`.

---

## Tarantula Shop QA

---
name: Tarantula Shop QA
description: >-
  Use when playtesting or smoke-checking The Tarantula Shop after a change — day
  loop, breed, trail, Elizabeth, binder, truck, saves.
---
# Tarantula Shop QA

Keep the game honest after every change. Prefer real play evidence over gut feel.

## Repo anchors
- Game: `xlockeddown-glitch/the-tarantula-shop`
- Core loop: `src/lib/game/` (especially `store.ts`)
- UI: `src/components/game/`
- Version: `package.json` and `src/lib/game/version.ts` must match
- Save key: `spinneret-save-v5` in `localStorage`

## Smoke checklist (run what the change can touch)
1. **Boot** — Title screen → Open shop (or Continue). Version string matches expected.
2. **Starter** — Pick a pack. Juveniles appear in the window; adult pair stays on the rack.
3. **Day loop** — List → Open → trade or Pass → Close → Tend all → Sleep. Rent and care behave.
4. **Breed** — Introduce adult F+M same species on rack. Sac collect path works when ready.
5. **Elizabeth** — After hire gates, till mode sells listed stock and unlocks Trail for that day.
6. **Trail** — Draw cards, hop, silk ends walk, pink print / landmarks behave.
7. **Binder / wall** — Unlock Window/Pair cards; Pin hangs; unpin works; guest interest if claimed.
8. **Truck** — Buy unlocked sling/juv; feeder pack; no crash on empty cash.
9. **Save** — Reload page; Continue restores day/cash/colony. New table wipes.

## Report format
- What you ran (steps)
- Broken (with repro)
- Still fine
- Suggested owner: Voice / Facts / Visual / Balance / implementer

## Anti-jobs
Do not implement features, rewrite art, change species facts, or publish. Hand ship decisions to the implementer.

---

## Tarantula QA

---
name: Tarantula QA
description: >-
  Use when playtesting or smoke-checking The Tarantula Shop after a change — day
  loops, breeding, trail, Elizabeth, binder/wall, truck, saves, version bumps.
---
# Tarantula QA

Playtest The Tarantula Shop the way a keeper would. Prefer evidence (what you clicked, what you saw) over gut feel. Hand product decisions and shipping to the product owner; do not rewrite art, species facts, or copy under this skill.

## Repo anchors

- GitHub: `xlockeddown-glitch/the-tarantula-shop`
- Version: `package.json` and `src/lib/game/version.ts` must match
- Save key: browser `localStorage` (see GameApp / store hydrate)
- Core UI: `src/components/game/*`, logic: `src/lib/game/*`

## Smoke checklist (every ship)

Run as much as the change touches; mark each pass/fail with a one-line note.

1. **Title → pack → table** — New table, pick a starter pack, juveniles land in the window, adults stay on the rack.
2. **Day loop** — List → Open → trade or Pass → Close → Tend all → Sleep. Rent deducts; molts / care advance overnight.
3. **Window vs rack** — List and unlist; pane caps match shop tier; guests only buy listed window stock.
4. **Breed** — Adult F+M same species on rack → Introduce → Collect sac when ready (Racks).
5. **Elizabeth** — Hire after extra glass + two hatches → fill window → Elizabeth has the till → Open locked for the day → Trail unlocks.
6. **Trail** — Draw cards, hop pawn, sticky silk ends walk, pink print / landmarks behave; pawn persists overnight.
7. **Binder / wall** — Unlock Window/Pair cards; Pin to wall; guest seeks pinned species on next Open.
8. **Truck** — Buy unlocked sling/juv; feeder pack available; do not soft-lock on chips.
9. **Save** — Reload continues; New table wipes.
10. **Version** — Title screen shows `GAME_VERSION`; matches `package.json`.

## Evidence

- Note day number, cash, shop tier, and any toast/journal lines that look wrong.
- Screenshot broken UI states when possible.
- Report: what you ran, what broke, what still looks fine.

## Out of scope

Implementing features, art direction, species taxonomy, economy retunes, publish without an explicit ask.
