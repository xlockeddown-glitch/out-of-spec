# Layout and density: how full each place is (design proposal)

Status: **design, 2026-11-27. Waiting on Ryan's answers (§7).** This PR changes no code and no data. Every number below is a [PLACEHOLDER] or an [ASSUMPTION] until Ryan sets it.

Ryan, 2026-11-27: "Do we have map organization and filling out planned? Some parts should be cluttered, some more open, etc. Just depends on the biome/area."

Markers, as in `biomes.md` and `zones.md`: **[ASSUMPTION]** a design guess for Ryan to confirm, **[PLACEHOLDER]** a number with no source, **NEW** not in the game today, **[RISK]** a technical risk.

## 1. Where we are

`biomes.md` says what each surface area is *for* and roughly how it *looks*. `zones.md` says what each zone holds. Neither says **how full** a place is, where the open ground is, or where the eye should go. What is built today:

- **The surface is evenly sparse.** The farm's middle is busy (`biomes.md` §1), and the rest of the 240 m land has a handful of rocks and plants (`HillDressing`, fixed spots). Each biome dressing pass added a few props, all without collision: five steam vents on the Basalt Ridge (`BasaltDressing`), seven pale rocks round the Frost Flats pad (`FrostDressing`), and the Landing Field slab at (0, 106), lights, gantry and terminal (`LandingDressing`). Apart from the Landing Field, the outer ring (80 m to 120 m out) has almost nothing.
- **The zone hubs are one shape.** The Colony Mine and the Ice Caves hubs reuse the Lava Tubes hub grid (`TunnelRock.MAP`), "for now" in zones.md.
- **The depths are one shape.** Every zone's depth is a 24 by 22 cell grid (3 m cells) with three 7 by 5 rooms off a trunk (`ZoneDepth`, `MineDepth.ROOMS`). The Lava Tubes, the Aquifer, the Mine and the Ice Caves differ in colour, hazard and finds, not in layout.

So a player driving from the Badlands to the Frost Flats, or from the Mine down to the Ice Caves, sees a change of colour but not a change of *space*. This doc proposes that change.

## 2. Rules

1. **Density is a design choice per place, written down.** Each biome and zone gets a density grade (§3) for its core and for any named sub-area (a wash, a pad apron, a bank), and a short layout note.
2. **Contrast is the point.** A cluttered place reads as cluttered because there is open ground near it. Each biome's **core** is graded on its own; the band between two biomes blends over about 10 m [PLACEHOLDER] instead of stepping. Each cluttered biome has an open clearing and each open biome a cluttered pocket (§4).
3. **The rover always has a way.** Clutter never blocks a road, a pad, a way in, a find or a lift. Lanes are laid **before** scatter, as keep-clear strips at least 6 m wide [PLACEHOLDER] (rover about 2.5 m wide, room to turn), and every dead end has a turning space at least 8 m across [PLACEHOLDER]. Each layout is BFS-checked against **every** static obstacle (big clutter, hills too steep to drive, `HillDressing` rocks, fissures, signs, lamps), not just the new props, with each obstacle grown by half the rover's width; the check runs from the farm hub to every pad, way in, lift, clearing and turning space. Dug pits are save state, not layout, so the BFS does not see them; players dig their own way.
4. **Big new clutter collides, small does not.** NEW big scatter (boulders, mesa blocks, wreckage) blocks rovers and players. Small scatter (pebbles, scrub, ice chips, cable runs) is decoration only: no collision, no clicking. The existing dressings (`FrostDressing` rocks, `LandingDressing` gantry and slab, `BasaltDressing` vents) keep no collision; this doc does not change them.
5. **Move props, not ground. Everywhere.** As in `biomes.md` §5 and Ryan's answer to its Q8(a) (tint and props only): no ground height changes, inner land or outer ring. Mesas, canyon walls and lava flows on the surface are **props** standing on the ground, so old saves and every land hash stay as they are.
6. **From the seed, the same on every PC, cell by cell.** Each scatter cell decides its props from `(farm seed, cell x, cell z)` alone, with integer hashes (never Godot's random numbers), no running totals, no global cap that stops early, and no physics raycasts and no float comparisons to decide whether a prop exists (slopes are read from the integer height samples, as `Terrain` stores them). Things that change during play (digging, stone, buildings placed by players) never change which props exist; they only **hide** a prop (as the dressings do today). Host, guest and late joiner therefore build the same set, and nothing is saved or sent.
7. **Landmarks you can steer by.** Each biome has one big landmark seen from the farm (§4) and each zone hub has one seen from the way in. Open areas need them most.
8. **Cheap to draw.** Small scatter uses `MultiMeshInstance3D` **chunked** (about 32 m by 32 m per chunk [PLACEHOLDER]) with a visibility range, so off-screen chunks are culled. No new lights. Budgets per biome (§6).

## 3. The density scale

"Covered" counts each prop's footprint, so one big boulder or a small cluster covers 4 m² to 12 m² [PLACEHOLDER].

| Grade | Name | Feel | Share of ground covered [PLACEHOLDER] | Lanes |
|---|---|---|---|---|
| 1 | **Open** | Wide, long views, wind. You see the next landmark. | under 2 % | none needed |
| 2 | **Scattered** | A rock every so often; easy driving. | 2 to 6 % | none needed |
| 3 | **Broken** | Clumps with gaps; you pick a line. | 6 to 15 % | a 6 m lane every 30 m or so |
| 4 | **Cluttered** | Close, busy, things to look round. | 15 to 30 % | one 6 m lane through, plus turning spaces |
| 5 | **Packed** | Tight; on foot, or the rover on its lane only. | over 30 % | marked lanes only |

**How lanes are laid [ASSUMPTION].** A lane is a keep-clear strip along a short list of waypoints in the biome's data (like a road, but not painted unless it *is* a road). Grade 5 lanes are marked by small posts or light stakes along the edge (no collision). Lanes are laid first and scatter keeps off them, so nothing has to be carved out afterwards.

## 4. The surface

The ring of `biomes.md` §2.2 (hub and spokes). Proposed grade, layout and landmark per biome:

| Biome | Grade | Layout | Clutter | Open space | Landmark [ASSUMPTION] |
|---|---|---|---|---|---|
| **Farm** (centre) | 3 Broken, kept tidy | Plot in the middle, things you use in a ring round it | Crates, hoses, tool racks, robots; **hand-placed in rows**, not scatter | The plot, a clear yard in front of the dome | The dome |
| **Lab Quarter** (west, relay at (-70, -70)) | 2 Scattered | Pads and antennas along the west road; the OIRM drop pod (-3, 14) belongs here | Cable runs, survey stakes, small instrument cases, low fencing | Wide pale pads; the west road stays clean | The relay mast |
| **Badlands** (the open land between roads) | **4 Cluttered near the hills, 2 in the wash** | Mesa blocks and boulder fields round the hills, the flat open wash (63, 8) through the middle | Boulders, fallen slabs, scrub, broken ledges, old dig spoil | The wash and its fan; a broad flat for digging | The arch hill |
| **Basalt Ridge** (east; pad (20.5, -15.5) and tunnel mouth (20.5, -19) at the farm's edge, **no road**) | **3 Broken by the pad, 5 Packed further out** | A clear apron round the pad, the tunnel mouth and the three lamps between them; rough lava fields beyond, reached by one marked lane | Jagged basalt blocks, cooled flow ridges (props), vents, glassy shards | The pad apron and one smooth cooled-flow clearing out in the field | The tunnel mouth's cliff and the vents' steam |
| **Frost Flats** (north) | **1 Open** | Wide and pale; the ground is gently bumpy (not levelled, `biomes.md` step 11); the long drive is the point | A few frost-split boulders and slabs, ice chips | Almost everything | One tall ice pillar or a dead probe mast you can see from the farm, with a boulder pocket round it |
| **Landing Field** (south; pad and sign (0, 87), slab (0, 106)) | 2 Scattered, ordered | A grid: slab, taxi lines **painted** like roads, gantry | Cargo pods in neat **hand-placed** rows, fuel tanks, light posts | The slab and the approach | The gantry |
| **Outer ring** (80 to 120 m) | The biome's own grade, thinning by one step toward the edge, never below 1 | Each biome fades into the next; built pads out there (the Landing Field) are kept clear as usual | The biome's own clutter, thinning | Bands of open ground between biomes | Each biome's landmark lies near its outer edge |

**The farm stays tidy.** Its clutter is hand-placed in rows and on pads (the colonist's yard), so it reads as *made*, against the wild land round it. The Farm and the Landing Field rows are not scatter.

**One cluttered pocket in each open biome.** The Frost Flats gets one boulder field round the crashed probe; the Landing Field gets one scrapyard corner [ASSUMPTION].

**One open clearing in each cluttered biome.** The Basalt Ridge gets a smooth cooled flow where the rover can stop; the Badlands has the wash.

## 5. The zones

Today every depth is the same 24 by 22 grid with three rooms. Proposal: **each zone gets its own room pieces and its own trunk shape**, still from the integer hash, still BFS-checked, still 3 m cells, so the rules (finds, lifts, hatches, hazards) do not change.

| Zone | Grade | Shape of a depth [ASSUMPTION] | Clutter | Open space | Hub |
|---|---|---|---|---|---|
| **Lava Tubes** | 3 Broken | Long winding tubes with a few side chambers (as built) | Breakdown rubble, lava drips, glassy walls | A skylight chamber now and then | Orin's beacon cave (built) |
| **Flooded Aquifer** | 2 Scattered on water, 4 on the banks | **Big flooded chambers** joined by short wading channels; the water is the open space | Pipes, old pumps, mineral crusts at the edges | The water and the pumped-out pools | A pump house on a gallery over the water (NEW) |
| **Colony Mine** | **5 Packed** | **Tight straight shafts** on a grid, short side drifts, low ceilings, many small rooms | Props and beams, ore carts on rails, old crates, cable, collapsed timber; the most cluttered zone | Only the shaft junctions and the lift station | A head-frame yard: the shaft top, the winch house, Bram's crate (NEW, replaces the Lava grid) |
| **Polar Ice Caves** | **1 to 2 Open** | **Wide caverns** with tall ceilings, few walls, long sight lines; slick open floors (slice 14) | A few ice columns, fallen ice blocks, frozen probes | Most of it; the white-out (slice 14) hides it in its place | A broad ice hall at the ramp foot, with layered walls (NEW, replaces the Lava grid) |
| **Phobos** | 3 Broken | Built hub; low gravity (slice 17) | Service crates, cable, regolith piles | The landing apron | Odalys's desk (built) |
| **Deimos** | 2 Scattered | Built hub, quieter and older | Abandoned kit, a few pods | Wide dusty floor | Kestrel's camp (built) |
| **Valles Marineris** (built, slice 30; layout and look are [PLACEHOLDER]) | 1 Open floor, 4 at the walls | A canyon: open floor, cluttered talus at the foot of each wall | Talus, fallen layers | The canyon floor | The canyon wall itself |
| **Olympus Mons caves** (built, slice 31; layout and look are [PLACEHOLDER]) | 2 Scattered, at scale | Lava tubes at a larger scale: huge, mostly empty | Huge breakdown blocks, few and far | Big skylit halls | A skylight shaft |

**The Mine and the Ice Caves are the clearest pair.** Packed against open, and both reuse the Lava hub today, so they get their own hubs first (§8).

**Density change with depth [ASSUMPTION].** Deeper is a little more cluttered in the Mine (older, worse-kept workings) and a little more open in the Ice Caves (bigger caverns). In the Lava Tubes and the Aquifer, density does not change with depth (the Aquifer still gets its new chamber pieces, §8 step 7).

**Depth 1 stays as built.** Depth 1 of every zone is pinned by hash tests and its room ids key saved state (the Mine's `rooms_shored` and the colonist's case use plain ids at depth 1). New shapes go to the hubs and to depths 2 and down only, unless Ryan says otherwise (Question 4).

## 6. How it is built (the technical shape)

- **Density data.** `data/biomes.json` and `data/zones.json` each gain a `density` block: a core grade, a list of sub-areas, each with its own grade (on the surface a circle or waypoint strip: the Badlands wash, the Basalt pad apron; in a zone a tile kind or room role, since depths are generated per seed: the Aquifer banks beside water, a canyon wall), the lanes (waypoint lists), the pockets and clearings (centre, radius, grade), and a `clutter` list (prop kinds and weights). A pure reader class, as `BiomeData` is. Hand-placed rows (Farm, Landing Field) and landmarks stay in code, as the dressings are. [ASSUMPTION]
- **One surface scatter, not one script per biome.** `SurfaceScatter` (NEW) walks a grid of 4 m cells [PLACEHOLDER] over the five biomes round the Farm (Lab Quarter, Badlands, Basalt Ridge, Frost Flats, Landing Field) and the outer ring, not the Farm itself. The Landing Field's hand-placed rows and the Lab Quarter's buildings are keep-clear, so scatter only fills the ground between them (the scrapyard corner is a pocket). Each cell finds its grade from the density data (sub-area, pocket, core, outer-ring falloff, blend band) and rolls its props from `(seed, cell x, cell z)` only (rule 6). A cell places nothing if it touches a keep-clear thing.
- **Keep clear (static, decided once per seed).** Roads, lanes and turning spaces, pads and their aprons, signs, ways in, lifts, the plot, fissures, lamps, `HillDressing` rocks and plants, the existing dressings, the relay mast and a 10 m [PLACEHOLDER] radius round it, every ore pocket site and gauge block site the seed can produce (found or not), and ground too steep to drive.
- **Hide, never shift (dynamic).** Big or small, a prop over a dug cell, under stone or under a player's building is hidden, as the dressings do. A hidden big prop also loses its collider and its `dig_problem` refusal, so an old pit under it never becomes an invisible wall and can still be dug or built on. **Big props also refuse digging and stone** under them through `Terrain.dig_problem` ("A boulder is in the way." [PLACEHOLDER]), leaving `can_dig` untouched, so a player cannot dig under a boulder in the first place. Old dug cells from before the pass simply hide the boulder there.
- **Old saves.** Because big props never sit on a pocket, block or road and are hidden over old dug cells, the only clash left is a rover or player saved where a new boulder now stands. On load the host moves such a rover or player to the nearest clear cell (the same way a deep rover is moved when a gate shuts). Tested with an old save placed on a boulder cell.
- **The uplink stays seed-independent.** `biomes.md` §3.2 measures uplink dead spots once for every seed. To keep that true, scatter props **do not block the uplink** (only hills and `HillDressing` rocks do, as now). [ASSUMPTION; the other choice is a measured dead-spot cap across many seeds.]
- **Per-zone room pieces.** `ZoneDepth`, `AquiferDepth`, `MineDepth` and `IceDepth` each get their own room-piece list and trunk rule behind the same layout interface, for depths 2 and down and the hubs.
- **Budget [PLACEHOLDER].** Per biome, about 600 small instances and 40 big props at most; grade 4 and 5 ground covers a small share of the land, so the coverage of §3 is reached by footprint and small clusters, not by count. A zone depth: at most 300 small instances. A `terrain cell → instances` table, keyed by **every 2 m `Terrain` cell a prop's footprint overlaps** (not the 4 m scatter cell), so digging updates only those props and `dig_problem` looks up the same table. The 600 and 40 are data-tuning ceilings that the budget test checks, not runtime cutoffs in `SurfaceScatter` (rule 6). 40 big props of 4 to 12 m² cover at most about 480 m², so grade 5 is a few small patches per biome unless big props cluster; tune when measured. Measure startup with `tools/measure_land.gd` **and** a windowed run (draw calls and frame time, not only headless CPU). **[RISK]** The low-end PC: measure before and after each pass; ground plus tint already takes about 735 ms headless.
- **Co-op.** Nothing new is saved or sent. Any pass that adds, removes or moves a **colliding** prop anywhere (surface or zone) bumps `CoopSession.PROTOCOL` once, so mixed builds are refused.
- **Art.** Primitives and the existing voxel props first. Ryan's packs in `art_inbox/` are style reference; using any texture from them needs his OK, as always.

## 7. Questions for Ryan

1. **The grades in §4 and §5:** do they match what you picture? (Recommended: as written.)
2. **Frost Flats fully open (grade 1)**, with one boulder pocket round a crashed probe? Or a little more broken? (Recommended: open with one pocket.)
3. **Basalt Ridge packed (grade 5) beyond the pad apron**, reached by one marked rover lane? (Recommended: yes.)
4. **Zone depth 1:** keep every depth 1 exactly as built, or rework the Mine's and Ice Caves' depth 1 too so the pair feels different on the first visit? (Recommended: keep depth 1; its hashes and saved room ids stay safe. The new hubs already show the difference.)
5. **Clutter you can move?** Should some small clutter be pushable by the rover, or is all clutter fixed? (Recommended: fixed; physics clutter costs co-op sync.)
6. **Order:** start with the Mine and Ice Caves hubs (zones), or the surface scatter (biomes)? (Recommended: surface scatter first, since every session sees it.)

## 8. Build order (small PRs, one job each)

1. **Density data.** The `density` blocks in `data/biomes.json` and `data/zones.json`, a pure reader, tests. No change on screen.
2. **Surface scatter, small clutter only.** `SurfaceScatter` with no-collision clutter for the four outer biomes and the outer ring, chunked MultiMesh, keep-clear rules, lanes, budget test, same-on-every-PC test (two builds, same seed, same set), land-hash tests.
3. **Surface big clutter.** Colliding boulders and blocks for grades 3 to 5, the `dig_problem` refusal, the old-save move, full-obstacle lane BFS with turning spaces, PROTOCOL bump. Marked grade 5 lanes refuse digging and stone like roads [ASSUMPTION], so a lane is never cut.
4. **Landmarks and hand-placed rows.** The Frost Flats pillar or probe mast and its pocket, the Landing Field scrapyard corner and painted taxi lines, the Basalt clearing, the farm yard rows. PROTOCOL bump if any of them collide.
5. **Colony Mine hub and shafts.** Its own head-frame yard hub and packed shaft-grid room pieces for depths 2 to 6 (after slice 13 lands). PROTOCOL bump.
6. **Ice Caves hub and caverns.** Its own ice-hall hub and open cavern pieces for depths 2 and down (fits with slice 14, slick ice and white-out). PROTOCOL bump.
7. **Aquifer chambers.** Flooded-chamber pieces for depths 2 and down and a pump-house hub. PROTOCOL bump.
8. **Later areas** (Valles Marineris, Olympus Mons) are laid out to this doc when their slices come up (30, 31, both built). Olympus: one huge hall, four breakdown blocks in 66 m, a skylight shaft, and depths of two huge halls with two finds each.

Every number in these PRs is a [PLACEHOLDER], recorded in `docs/decisions.md`.
