# Biomes: laying out the surface around the farm (design proposal)

Status: **design, 2026-11-26. Ryan answered §7 the same day (§7.1).** This PR changes no code and no data. Every number and name below is a [PLACEHOLDER] or an [ASSUMPTION] until Ryan sets it.

Ryan, after playtesting: "the map needs to be laid out better. We should make like 'biomes' with farm being center and different things in different areas extending from there." He also said the beginning needs a few tips and an idea of what you are doing (§4).

Markers, as in `zones.md`:

- **[ASSUMPTION]**: a design guess for Ryan to confirm or replace.
- **[PLACEHOLDER]**: a number or name with no source.
- **NEW**: something the game does not have today.
- **[RISK]**: technical risk (§3).

Rules this doc keeps:

- **Biomes are the surface. Zones are the places you go to** (`zones.md`). A biome is walked or driven over; a zone is a separate scene. A zone entrance sits in the biome it belongs to.
- **The farm stays first and complete.** A player who never leaves the middle still plays the loop.
- **Small PRs.** The first slice paints a map and moves a few props (§6).

## 1. The problem today

Read from `scenes/main_farm.tscn`, `scripts/world/terrain.gd` and `scripts/main_farm.gd` on main.

- **The land is one 160 m square** (`Terrain.SIZE_M`), centred on the farm, with seven hills of 3 to 6 m (`Terrain.HILLS`: three 6 m hills at the corners, four 3 m ones at the edges). Nothing says what any part of it is for.
- **The middle is crowded.** The 12 by 12 cell plot (`GameState.PLOT`, 2 m cells, so 24 m square) sits at the origin. Within about 20 m of it are the rover start (0, 2), the drop pod (-3, 14), the dome airlock (8, 14), the field calibration pad (13.5, 15), Bram's bay (16, -2), eight ore fissures (for example (-16, 3) and (11, 18)) and four rim rocks. The tunnel mouth and its pad are at (20.5, -19) and (20.5, -15.5). That is farming, metrology, shopping, mining and rover parking mixed in one ring.
- **The far land is empty.** Past the 33 m level circle (`Terrain.FARM_LEVEL_M`) there are hills, shrubs, rocks, the wash at (63, 8) and the relay at (-70, -70) with a level road to it. There is little reason to walk to most of it.
- **Things you do are in different scenes, not different places.** The dome, the tunnels and the farm are three scenes (`SceneSwitcher`). On the farm scene itself, digging, rover driving, ore and the tunnel entrance have no area of their own.
- **No sense of direction or progress.** The tunnel mouth is open from the first day. The wash, the arch and the hills are scenery. A new player has no road to follow and no sign of what comes next.
- **The new zones have nowhere to attach.** `zones.md` plans four more underground zones and a shuttle. Only the tunnel mouth exists as an entrance (and a lava hub scene, `scripts/world/lava_hub.gd`).

## 2. The ring idea

The farm is the centre. Around it, **five biomes**, each with one main job and, where it has one, one zone entrance. The land grows to about 240 m (Question 5, §7.1) and the biomes are painted onto it. The old 160 m middle keeps its ground.

| Biome | Job in play | Systems | Look [ASSUMPTION] | What you find | Level band [PLACEHOLDER] | Zone entrance |
|---|---|---|---|---|---|---|
| **Farm** (centre) | Grow, water, harvest, sleep | Plot, bed, bin, Lin buying crops, robots working | Warm terracotta flat, tidy | Crops, the day loop | Always | None |
| **Lab Quarter** | Metrology: dome, calibration pad, uplink | Dome airlock, field calibration pad, relay road, OIRM drop pod | Pale pads, antennas, cable runs | Instruments, standards, audits | Lab 1 to 20 | None (the dome is a scene) |
| **Badlands** | Hills, digging, stone, pit water, gauge blocks | `Terrain`, `PitWater`, `StonePieces`, `GaugeSet`, ore pockets, fissures | Rolling hills, mesas, the wash | Ore, blocks, stone, water | Earthworks 1 to 30 | Aquifer sinkhole (Flooded Aquifer, 8 to 24) |
| **Basalt Ridge** | Tunnel mouth, beacons, rover trips | Rover, Orin's beacons, the lava hub | Dark basalt, steam, cooler colour | Crystal ore, the Sentinel | Lab 5 to 20 | Lava Tubes mouth (built); Colony Mine gate on the ridge road (12 to 30) |
| **Frost Flats** (north) | Cold, long drives, ice | Rover range and uplink limits, heater supplies | Pale ice, frost, long shadows | Ice samples, minerals | Lab 18 to 35 | Polar Ice Caves ramp (18 to 35) |
| **Landing Field** | Shuttle, OIRM drop, off-world | Shuttle pad, Odalys's desk, fast-travel terminal | Concrete pad, lights, a gantry | Trips, parts, mail | Lab 20 and up (shuttle) | Phobos and Deimos (by shuttle) |

Where tarantulas live: in the dome, as now (`zones.md` §10). The biomes bring them in; they do not house them.

**Notes**

- **The Lab Quarter is mostly a re-labelling.** The dome is its own scene. The Lab Quarter is its surface side: the airlock, the calibration pad, the relay road and OIRM's drop pod. They already exist; today they sit among the fissures.
- **The Badlands is the home of digging.** The hills, the wash and the gauge blocks exist (`docs/decisions.md`, "Hills, digging, tunnels"). The biome gives them a name and a place.
- **The Basalt Ridge** holds what exists (tunnel mouth, pad) and gains a road.
- **The Frost Flats and the Landing Field are NEW.** Both start small, an empty flat and a pad, so the ring is visible before the content is built.

### 2.1 Layout A: wedges

The farm is the middle disc. Five wedges, painted on the existing 160 m square.

```
                 N
     +--------------------------------------+
     |  FROST FLATS          | BASALT RIDGE |
     |  (ice ramp)           | (tunnel mouth|
     |                       |  + mine gate)|
     |          .------------'              |
 W   |  LAB    /    FARM     \   LANDING    |  E
     | QUARTER |  plot, bed  |    FIELD     |
     | (dome,   \           /  (shuttle)    |
     |  pad)     '---------'                 |
     |  BADLANDS (hills, wash, digging)     |
     +--------------------------------------+
                 S
```

- **Good:** simple to paint from one function. Each wedge is one rule.
- **Bad:** wedges invite "walk straight over". A rover still needs a clear way, so roads come anyway.

### 2.2 Layout B: hub and spokes (roads)

The farm is the hub. Five roads leave it, each level and wide enough for a rover, each ending at the biome's marker. The land between the roads is Badlands.

```
                Frost Flats
                     |
                     | north road [PLACEHOLDER 60 m]
   Lab Quarter ------+------ Basalt Ridge
   (west road)       |       (east road)
                   FARM
                     |
                     | south road
                Landing Field

   Badlands: the open land between the roads
```

- **Good:** roads teach direction ("follow the road"). The game already has one level road, the one to the relay (`Terrain.ROAD_LEVEL_M`, `RELAY_WAY`). A road can light up when it opens (§4).
- **Bad:** more terrain rules and art (one road per biome). The Badlands has no edge of its own.
- **Recommended: B.** It copies the one road the game has and teaches the order of play. A is cheaper. Question 1.

### 2.3 What a biome marker is

Each biome has one marked place on its road: **a sign and a rover-sized pad**. The sign names the biome and the band ("Basalt Ridge: lab level 5 and up. Dark ground, cold nights."). The zone entrance, if any, is next to it. The warning is the soft gate of `zones.md` §7.1 (information, never a wall).

## 3. Size and travel

### 3.1 Distances

The land is 160 m square today. The times are measured (PR 211, `tools/measure_land.gd`): the rover tops out at 6 m/s after 0.75 s, and the walker goes 4 m/s. They are straight lines on flat ground, so hills and turns add some.

| Trip | Straight line | On foot | By rover |
|---|---|---|---|
| Farm centre to the dome airlock | about 16 m | 4 seconds | 3 seconds |
| Farm centre to the tunnel mouth | about 28 m | 7 seconds | 5 seconds |
| Farm centre to the relay | about 100 m | 25 seconds | 17 seconds |
| Farm centre to a new biome marker | 50 to 70 m [PLACEHOLDER] | 15 seconds at 60 m | 10 seconds at 60 m |

- Farther out: 100 m is 25 seconds on foot and 17 by rover; 115 m (the 240 m edge) is 29 seconds on foot and 20 by rover.
- **Walking is for the middle** (farm, Lab Quarter, Landing Field), where the walkers go (`scripts/walker/`).
- **The rover is for the ring**, as it already is for the dome and the tunnels (`docs/decisions.md`, co-op).
- **The land grows to about 240 m** (Question 5). The old 160 m middle keeps its heights, and the new outer ring gives the biomes room (§7.1). **The land is now 240 m** (step 2, done): `Terrain.HALF_M` is 120, the old edge is `Terrain.OLD_HALF_M` (80), and the ring is plain ground that eases out from the old edge over 40 m.

### 3.2 How the world is held

The biggest technical choice.

| Option | What it means | Co-op and save | Risk |
|---|---|---|---|
| **A. One big scene (recommended)** | Keep `main_farm.tscn`. Paint biomes into `Terrain`; add props from data. | Nothing changes: the host's farm, `GameState.dug`, the farm seed and the saves stay. | Low at 160 m; measured again at 240 m (§6 step 1). The ground is already built in 16 m chunks (`TerrainGround.CHUNK_M`). |
| **B. Streamed chunks** | Load and unload tiles as the rover drives. | Each PC would have a different loaded part, but the host must answer dig and till anywhere. | **High [RISK].** Nothing streams today. The land-hash tests need a rethink. |
| **C. A scene per biome** | Like the dome and the tunnels: a pad switches scene. | Matches `zones.md` (one scene per PC), but "the rover is in one place" (`rover_in_tunnels`) grows into one flag per biome. | **Medium to high [RISK].** Breaks the open land Ryan asked for. |

- **A is the plan.** One `Terrain`, one dig grid, one save.

**Measured (PR 211).** The middle 160 m keeps today's heights exactly; past it the ground eases from the old edge's height to the same height function with its rim at the new edge (`Terrain.natural_on`). Build is the ground's height grid plus all its meshes, median of 3, headless on one PC.

| | 160 m | 240 m |
|---|---|---|
| Ground build | 268 ms | 690 ms |
| Points / chunks / vertices | 25,921 / 100 / 153,600 | 58,081 / 225 / 345,600 |
| Uplink dead spots (every 4 m) | 7.8 % (131 of 1,681) | 6.7 % (250 of 3,721) |

At 240 m the new outer ring alone is 5.8 % dead (119 of 2,040). The ground does not depend on the farm seed, so one result stands for every seed. Hills and rocks both block the uplink and are counted; the four loose boulders are not.
- **The ground is computed from a point every meter.** 160 m is 161 by 161 points; 240 m is 2.2 times that. Measured: about 0.7 s to build, once, at the start.
- **[RISK] The uplink.** The ground blocks the relay (`docs/decisions.md`). More hills and a wider land mean more dead spots. A second relay for the far edge is a possible fix [ASSUMPTION]; the measured dead share is about 7 % at both sizes.
- **Zones stay scenes.** A zone entrance on the surface uses the pad-and-E pattern the tunnel mouth uses.

### 3.3 Co-op

- **Host-authoritative, anyone anywhere.** Players in the same biome share the one farm scene. Biomes add no new world to the host.
- **Shared rover.** The rover is one saved place. A friend who drives it to the Frost Flats leaves another on foot at the farm. That is already true, and is why `zones.md` §8.1 gives each zone its own field rover. A free **parking pad at each biome sign** would let a walker pick up a rover nearby [ASSUMPTION; Question 7].
- **No new message for a painted map.** The biome map is a function of the farm's seed, so every PC agrees, as the hills do now.

### 3.4 The terrain grid

- `Terrain` already has a seed and a salt, hills, a wash, a road and a rim. A biome is **one more input to the same function**: a tint (`TerrainGround` already tints by height) and a choice of rocks and plants (`HillDressing`).
- **Digging** (2 m cells, 0.5 m steps, at most 4 steps) works anywhere the rules allow. A biome can change the rules: no digging on a road or a pad; deep Badlands pits seep (`PitWater` already does) [ASSUMPTION].
- **[RISK] Any change to ground height moves the land hash**, so an old save's dug cells, found blocks and ore pockets could land in a different place. **Do not move the ground, only dress it,** in the early PRs (§5).

## 4. Gating and the first hour

The farm-first layout should teach the loop. The world opens outward in the order the game teaches things.

| Step | What the player does | What opens | Where |
|---|---|---|---|
| 0 | Start: a few tips ("Water the plot. Check the probe.") | The Farm: plot, bed, bin | Centre |
| 1 | First crops, first water | The Lab Quarter: a road sign points at the dome | West |
| 2 | First calibration, first audit (every 5th morning) | The relay road and the field calibration pad | Lab Quarter |
| 3 | Lab level about 5 | The Basalt Ridge road lights up; the tunnel mouth stays open | East |
| 4 | Earthworks skill, first gauge block | The Badlands get a sign and digging tips | Between roads |
| 5 | Lab level about 18 | The Frost Flats road lights up (a warning below) | North |
| 6 | Lab level 20, shuttle license | The Landing Field shuttle opens | South |

- **Roads are the tutorial.** A lit road is the hint. Nothing is walled; every biome is reachable on day one, and a sign says what to expect, as `zones.md` §7 chose. [ASSUMPTION] A lit road is a hint, not a lock.
- **Tips go on a quest board.** Add a board at the farm's edge (NEW; the lava hub already has one, `lava_hub.gd` `BOARD`) showing the first three jobs. The first story quest is "The Thirsty Probe" (`quests_levels_story.md` §6, S1). The hover label on props already gives short text.
- **Signs name the next step.** "Next: the auditor comes on morning 5" costs one label.
- **No hard gate on the surface.** Only zone depths and the shuttle license are hard gates (`zones.md` §7.2). Biomes only warn.

## 5. Migration

The rule is **move props, not ground.**

| Today | New layout | Move |
|---|---|---|
| Plot (24 m square at the origin) | Farm centre | Stays |
| Drop pod (-3, 14) | Lab Quarter | Stays or a short move [ASSUMPTION] |
| Dome airlock (8, 14) | Lab Quarter, west road | Stays or a short move |
| Field calibration pad (13.5, 15) | Lab Quarter | Stays or a short move |
| Bram's bay (16, -2) | Farm's edge | Question 6: at the farm's edge |
| Tunnel mouth (20.5, -19) and pad | Basalt Ridge | Stays; a road is added |
| Eight ore fissures near the plot | Badlands side, outside the plot ring | Move out; they are scene props, not in a save |
| Relay (-70, -70) and its road | West road to the Lab Quarter | Stays |
| Rim rocks, hill plants | Per biome | Redressed; they are "in no save" (`docs/decisions.md`) |
| Wash (63, 8) and the arch hill | Badlands | Stays |

- **Saves.** The seed, `GameState.dug`, `found_blocks`, `found_pockets`, `new_pockets`, `pocket_pending`, `pit_seep` and the rover's place are all in ground coordinates. If the ground does not move, **no save changes.** Props that are only scene nodes can move.
- **A prop that moves under something saved** (a tilled or dug cell at a fissure's old spot): the prop stays, or moves only to a free spot [ASSUMPTION]. Test with an old save.
- **Old rover places** all lie inside today's 160 m land, which does not shrink. [ASSUMPTION]
- **Co-op:** the PR that moves props should raise `CoopSession.PROTOCOL`, so a host and guest on different builds are refused, as other changes have done.
- **The biome map is data:** a table of biome id, centre, reach, tint and props, read the way the zone table is (`zone_data.gd`, `data/`). [ASSUMPTION]

## 6. Build order

Small PRs, one job each, smallest first.

1. **Measure.** A test or dev scene that prints rover top speed, ground build time and uplink dead spots at 160 m and 240 m, to put real numbers in §3.1. No change to play.
2. **Land size. DONE.** The land is 240 m. Every point inside the old 160 m keeps its height for an existing seed (§7.1); tests check it against a frozen hash of the old middle. The new ring has no props, blocks, ore pockets, tints or roads yet.
3. **Biome table.** `data/biomes.json` and a pure `BiomeData` class (ids, centres, reach, band, tint, zone entrance). Tests only.
   *Built 2026-11-26 (feat/biome-table):* `data/biomes.json` (the farm hub and the five biomes, every number a [PLACEHOLDER]), `scripts/world/biome_data.gd` (`BiomeData`: the check, `biome_at`, `marker`, `tint`, `band`, `sign_text`, zone `entrances` as a list) and `tests/test_biome_data.gd`. Marker pads are checked clear of props, rocks, the plot and the relay road, and near flat; the Lab Quarter covers the whole relay road. Nothing in play reads it yet.
4. **Paint the map.** A debug overlay (a key) that colours the ground by biome, so Ryan can see layout A against B before art is spent.
   *Built 2026-11-26 (feat/paint-map):* F8 (debug builds only, off every launch) calls `TerrainGround.show_biomes`, which rebuilds the chunks with each point coloured `BiomeData.tint(biome_at)` in place of the height tint [PLACEHOLDER], with a "Biome map (F8)" label while on. Colours are cached on the first use; heights, saves and the network are untouched. Four tints in `data/biomes.json` were changed so the biomes tell apart (the farm and the Badlands were both orange-brown); nothing else in the table moved. `tests/test_biome_paint.gd`.
5. **Tint the ground by biome.** `TerrainGround` takes the tint. Heights do not change, so the land hash and old saves are safe.
   *Built 2026-11-26 (feat/biome-tint):* each point's tint is its height tint times a biome multiplier: `Color.WHITE` leaned 50 % toward the biome's new `ground_tint` in `data/biomes.json` (the F8 overlay keeps the bright `tint`). The biome is looked up every 4 m, averaged over the 3 by 3 neighbours and smoothed between, so an edge fades over about 8 to 16 m; the farm is white, so its middle is as before. Worked out in `_ready` (about +45 ms), never saved or sent. Every number a [PLACEHOLDER]. `tests/test_biome_tint.gd`.
6. **Signs and parking pads.** One sign and one rover pad per biome, on the existing land. Hover text only.
   *Built 2026-11-27 (feat/biome-signs):* `BiomeMarkers` builds, in the farm scene, a post (hover hint = `BiomeData.sign_text`, click does nothing) and a pale 4 by 4 m slab at each spoke marker; the farm hub has none. Meshes are stand-ins [PLACEHOLDER]. `Terrain.dig_problem` refuses the pad and the sign's cells ("Keep the pad and its sign clear."); `can_dig` is untouched, so land hashes and old saves are safe, and an old save with digging there still loads. An ore pocket under a pad can still be dug (`pad_ok`). Stone can not be built there either. `CoopSession.PROTOCOL` is 28. Parking is just the free pad: no recall, nothing saved or sent. Extra cost in the farm `_ready` is under the noise (about 0 ms). `tests/test_biome_markers.gd`.
7. **Move the fissures out of the middle.** Scene props only. Old-save test.
   *Built 2026-11-27 (feat/move-fissures):* the eight fissures keep their names and ids and moved to the near (farm) side of the Badlands, x 44 to 58 and z 8 to 36, 6 to 12 m apart, clear of the wash, the Badlands pad and sign, and every prop [PLACEHOLDER]. `OreFissure` now sits on the ground (`Terrain.height` with `GameState.dug`, again whenever the terrain changes), since the scene's y is 0 and the spots are on hills; a cell dug at a fissure's new spot in an old save just lowers it. `BiomeData.SCENE_SPOTS` has the new rows. Nothing saved changes (`mined_fissures` is by id), but reach is only checked on a guest's own scene, so `CoopSession.PROTOCOL` is 29 and builds with different spots are refused. A fissure sits on the lowest ground under its 1.6 m footprint, with no lift. `tests/test_fissures.gd`.
8. **Roads.** Roads from the farm to each biome. Inside the old 160 m they are painted, not levelled, so old saves keep their ground (Question 11). On the new outer ring they can be levelled, as the relay road is.
9. **Gating hints.** Road lighting and signs tied to lab level and the first audit (§4).
10. **Basalt Ridge dressing.** Dark ground, steam, a lit road to the tunnel mouth.
11. **Frost Flats.** An empty flat, a sign and a small rock set. The ice-cave ramp comes with that zone.
12. **Landing Field.** The pad and terminal, when the shuttle is built.

## 7. Open questions for Ryan

Each has a recommended option first.

1. **Which layout?**
   - (a) Hub and spokes: roads out of the farm (recommended: teaches direction, matches the relay road).
   - (b) Wedges painted on the land.
   - (c) Wedges with a road to each hub.
2. **How many biomes?**
   - (a) Five around the farm: Lab Quarter, Badlands, Basalt Ridge, Frost Flats, Landing Field (recommended: each carries a zone).
   - (b) Four (leave out the Landing Field until the shuttle exists).
   - (c) Six or more (add a salt flat or a dune field for looks only).
3. **Is the Lab Quarter a biome of its own?**
   - (a) Yes, the surface around the dome and calibration pad (recommended: metrology is the game's core).
   - (b) No, the dome and pad stay part of the Farm.
4. **Do biomes block you until a level or a quest?**
   - (a) No: a sign warns and a road lights up as a hint (recommended: matches your soft-gate rule).
   - (b) A real gate on the Frost Flats and the Landing Field only.
   - (c) A gate on every biome except the Farm and the Lab Quarter.
5. **How big should the land be?**
   - (a) Keep 160 m for now and measure first (recommended: lowest risk to saves and hashes).
   - (b) Grow to about 240 m.
   - (c) Grow to about 320 m, with a second relay.
6. **Where does Bram's bay live?**
   - (a) At the farm's edge, the shop for the middle (recommended: the first stop for standards).
   - (b) In the Landing Field.
   - (c) In the Lab Quarter, beside the dome.
7. **What do you drive between biomes?**
   - (a) The shared rover, plus a free parking pad at each biome sign (recommended: no one is stranded).
   - (b) The shared rover only.
   - (c) A second small rover per biome.
8. **How do biomes look different?**
   - (a) Ground tint, rocks, plants and a few props per biome, with your packs as style reference (recommended: cheapest, saves untouched).
   - (b) Also a different ground shape per biome (taller hills in the Badlands, flat Frost Flats). This moves the land hash.
   - (c) Also different light or sky per biome.
9. **Where does the first-hour teaching live?**
   - (a) A quest board on the farm with three starter jobs, plus lit roads (recommended: reuses the quest system).
   - (b) A scripted tutorial with arrows and pop-ups.
   - (c) Only signs and the phone.
10. **Where does digging belong?**
    - (a) Allowed everywhere except roads and pads; the Badlands pays best (recommended).
    - (b) Only inside the Badlands.
    - (c) Everywhere, including roads (as today).
11. **Do old saves keep their ground?**
    - (a) Yes: biomes are painted over the same ground and only props move (recommended: no save breaks).
    - (b) Allow a new ground, with a "new world" prompt for old saves.
12. **Which zone entrance is built on the surface first?**
    - (a) The Aquifer sinkhole in the Badlands (recommended: digging and pit water are already there).
    - (b) The Colony Mine gate on the Basalt Ridge road.
    - (c) The Ice Caves ramp in the Frost Flats.

### 7.1 Ryan's answers (2026-11-26)

| # | Question | Ryan's answer |
|---|---|---|
| 1 | Layout | (a) Hub and spokes: roads out of the farm |
| 2 | How many biomes | (a) Five: Lab Quarter, Badlands, Basalt Ridge, Frost Flats, Landing Field |
| 3 | Lab Quarter its own biome | (a) Yes |
| 4 | Gates | (a) None: a sign warns and a road lights up |
| 5 | Land size | **(b) Grow to about 240 m** (not the recommended 160 m) |
| 6 | Bram's bay | (a) At the farm's edge |
| 7 | Travel | (a) The shared rover, plus a free parking pad at each biome sign |
| 8 | Look | (a) Ground tint, rocks, plants and a few props; Ryan's packs as style reference |
| 9 | First-hour teaching | (a) A farm quest board with three starter jobs, plus lit roads |
| 10 | Digging | (a) Everywhere except roads and pads; the Badlands pays best |
| 11 | Old saves | (a) Keep their ground |
| 12 | First surface zone entrance | (a) The Aquifer sinkhole in the Badlands |

What follows from the answers:

- **240 m and "keep the ground" together.** The land grows outward; today's 160 m middle keeps exactly the heights it has, so dug cells, found blocks and pockets stay where they are. The new ring outside it is new ground. The grow PR must test that every point inside the old 160 m is unchanged for an existing seed [ASSUMPTION: anything in `Terrain` that depends on `SIZE_M`, such as the rim, is kept for the inner square or moved out to the new edge; the seven hills keep their places, so the corner and edge hills end up inside the land, not at its edge].
- **Land size moves up the build order** (now §6 step 2, after measuring), so biome centres are placed on the 240 m land from the start. [RISK] stays as §3.2 says.
- **Roads and old saves.** Inside the old 160 m, roads are painted, not levelled, so Question 11 holds (§6 step 8). New ground outside it has no saved cells, so roads there can be levelled.
- **The farm quest board (Question 9) is the first-day tips work** Ryan asked for: three starter jobs that teach water, check the probe, and first calibration. It needs no biome work, so it is built first: right after the controller and controls guide PRs, before §6 step 1, on today's map. It is no longer a §6 step.
- Everything else in §2 to §6 stands as proposed.
