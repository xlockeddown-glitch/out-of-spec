# Wild animals: proposal (draft for Ryan, v2)

Status: **DRAFT, not approved.** Numbers marked [PLACEHOLDER] are first guesses to tune after a playtest.

Ryan, Nov 28: "Lets make animals mostly wild that you can still tend to but dont keep."

## 1. The idea in one line
Feral hens, goats and rabbits roam the plateau around the farm. They're the descendants of colony stock that got out years ago. You don't buy, pen or own them. You **tend** them: leave food at feeding spots, check on them, and over time they trust the farm enough to leave you useful things.

## 2. Where they live
- **Small groups** wander the farm's outskirts, outside the plot and away from the roads:
  - 3 to 5 hens [PLACEHOLDER];
  - 2 or 3 goats [PLACEHOLDER];
  - 2 to 4 rabbits [PLACEHOLDER].
- Each species keeps to its own kind of ground: hens near the scrub bushes, goats on the plateau rim, and rabbits along the dry gulch.
- They wander slowly, back away if you run at them, and bed down at night.
- Later slices could add other groups in the zones (for example, cave rabbits in the Aquifer), but not in this slice.

## 3. Tending
- **Feeding spots:** one per group, a flat stone or an old trough. Use it to leave food there. The food is your crop leftovers (chaff, coir, pith and so on), which the game lists now but doesn't use. Harvesting now also puts the crop's leftover in a shared feed bin.
- **Trust:** each group has a farm-wide trust level from 0 to 5 [PLACEHOLDER].
  - A day with food left at their spot raises trust by 1.
  - Three days in a row with no food lowers it by 1 [PLACEHOLDER].
  - Trust never goes below 0, and **animals never die or leave**. An unfed group just stays shy.
- **What trust gives you:**
  - **Trust 1 or more:** they let you walk close instead of backing off.
  - **Trust 2 or more:** they leave things at their feeding spot each dawn:
    - hens: 1 or 2 eggs;
    - goats: a tuft of shed cashmere;
    - rabbits: a tuft of fur.
    These go into the harvest bin and sell to Lin (12, 30 and 40 CR [PLACEHOLDER]).
  - **Trust 4 or more:** now and then (1 day in 5 [PLACEHOLDER]) a group leads you to a find, such as a lost gauge block or a bit of crystal ore. Their wandering ends at it and a marker shows on it.
- Nothing is kept: no pen, no names and no buying. If you stop tending, they drift back to wild.

## 4. The metrology twist (optional, your call)
- **The colony wildlife survey:** Lin, or OIRM, wants yearly numbers on the feral stock. Once a day you can weigh one trusting animal with a hanging field scale.
- The scale drifts like every other gauge. A weighing logged with a calibrated scale counts toward a small survey bounty (lab XP and credits [PLACEHOLDER]). A weighing with a drifted scale is rejected.
- This gives the animals a reason to exist in a game about measuring, without making them pets.

## 5. Co-op (host-authoritative)
- Trust, the feed bin and each dawn's leftovers belong to the **farm**.
- Any player can feed or collect. The host decides each dawn and syncs it, so two players can't take the same egg.
- Animal positions are cosmetic on each machine. Only the host's dawn outcomes and finds matter.
- Collecting gives XP to the collecting player's **farming skill** (5 XP [PLACEHOLDER]).

## 6. Out of scope for the first slice
- Animals in the zones, breeding, robots tending them, quests built on them, and the survey if you'd rather skip it.

## 7. Build plan (one small PR)
1. **Data:** a new `data/animals.json` with the three species, their foods, gifts, group sizes, trust rules and [PLACEHOLDER] numbers.
2. **Logic:** GameState gains group trust, fed-today flags, the feed bin, the dawn step, feeding and collecting, plus save/load and FarmSync.
3. **World:** animal nodes with Gemini's three models (converted to .glb by the voxgen tool). They use a simple wander inside their home area, back away from players, and have one feeding spot per group.
4. **Tests:** trust up and down, dawn gifts, no double collect in co-op, and save round-trip.
5. **Lane:** Neon builds and Opus reviews on your Console credits. If you say yes, the survey is a second small PR.

## Questions for Ryan
1. Should they live around the farm only for now, or in the zones too?
2. Is the wildlife survey with the drifting scale in or out?
3. Are the gifts right: eggs, cashmere, fur, and the odd find at high trust?
