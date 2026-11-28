# Layout and density: how full each place is (design proposal)

Status: **design, 2026-11-27. Waiting on Ryan's answers (§7).** This PR changes no code and no data. Every number below is a [PLACEHOLDER] or an [ASSUMPTION] until Ryan sets it.

Ryan, 2026-11-27: "Do we have map organization and filling out planned? Some parts should be cluttered, some more open, etc. Just depends on the biome/area."

Markers, as in `biomes.md` and `zones.md`: **[ASSUMPTION]** a design guess for Ryan to confirm, **[PLACEHOLDER]** a number with no source, **NEW** not in the game today, **[RISK]** a technical risk.

## 1. Where we are

`biomes.md` says what each surface area is *for* and roughly how it *looks*. `zones.md` says what each zone holds. Neither says **how full** a place is, where the open ground is, or where the eye should go. What is built today:

- **The surface is evenly sparse.** The farm's middle is busy, and the rest of the 240 m land has a handful of rocks and plants (`HillDressing`, fixed spots). Each biome dressing pass added a few props: five steam vents on the Basalt Ridge (`BasaltDressing`), seven pale rocks round the Frost Flats pad (`FrostDressing`), and the Landing Field slab, lights and gantry (`LandingDressing`). The new outer ring (80 m to 120 m out) has almost nothing.
- **The zone hubs are one shape.** The Colony Mine and the Ice Caves hubs reuse the Lava Tubes hub grid (`TunnelRock.MAP`), "for now" in zones.md.
- **The depths are one shape.** Every zone's depth is a 24 by 22 cell grid (3 m cells) with three 7 by 5 rooms off a trunk (`ZoneDepth`, `MineDepth.ROOMS`). The Lava Tubes, the Aquifer, the Mine and the Ice Caves differ in colour, hazard and finds, not in layout.

So a player driving from the Badlands to the Frost Flats, or from the Mine down to the Ice Caves, sees a change of colour but not a change of *space*. This doc proposes that change.

## 2. Rules

1. **Density is a design choice per place, written down.** Each biome and zone gets a density grade (§3) and a short layout note.
2. **Contrast is the point.** A cluttered place reads as cluttered because the place next to it is open. Neighbours should differ by at least two grades [ASSUMPTION].
3. **The rover always has a way.** Clutter never blocks a road, a pad, a way in, a find or a lift. Every dense area keeps a clear lane at least 4 m wide [PLACEHOLDER] (rover about 2.5 m), and every layout is BFS-checked the way the depths already are.
4. **Big things collide, small things do not.** Boulders, mesas, wreckage and walls block (and block the uplink, as hills do). Pebbles, scrub, ice chips and cable runs are decoration only: no collision, no clicking. This keeps clutter cheap and never traps a rover.
5. **Move props, not ground.** As in `biomes.md` §5: inside the old 160 m, no ground height changes, so old saves and the land hash stay. The outer ring may shape ground where a biome needs it (canyons, mesas) only if a frozen-hash test pins the old middle.
6. **From the seed, the same on every PC.** Clutter is placed from the farm seed with integer hashes (never Godot's random numbers), so the host and guests see the same thing and nothing is sent or saved. It follows digging and hides under stone, as the dressings already do.
7. **Landmarks you can steer by.** Each biome has one big landmark seen from the farm (§4) and each zone hub has one seen from the way in. Open areas need them most.
8. **Cheap to draw.** Repeated clutter uses `MultiMeshInstance3D`, primitives or the existing voxel props, no new lights, and a draw budget per biome (§6).

## 3. The density scale

| Grade | Name | Feel | Rough share of ground covered [PLACEHOLDER] | Clear lane |
|---|---|---|---|---|
| 1 | **Open** | Wide, long views, wind. You see the next landmark. | under 2 % | anywhere |
| 2 | **Scattered** | A rock every so often; easy driving. | 2 to 6 % | anywhere |
| 3 | **Broken** | Clumps with gaps; you pick a line. | 6 to 15 % | one 6 m lane per 30 m |
| 4 | **Cluttered** | Close, busy, things to look round. | 15 to 30 % | one 4 m lane |
| 5 | **Packed** | Tight; on foot or slow rover only. Small pockets. | over 30 % | marked lanes only |

## 4. The surface

The ring of `biomes.md` §2.2 (hub and spokes). Proposed grade, layout and landmark per biome:

| Biome | Grade | Layout | Clutter | Open space | Landmark [ASSUMPTION] |
|---|---|---|---|---|---|
| **Farm** (centre) | 3 Broken, kept tidy | Plot in the middle, things you use in a ring round it | Crates, hoses, tool racks, drop pod, robots; **tidy rows**, not random | The plot, the level circle, a clear yard in front of the dome | The dome |
| **Lab Quarter** (north-west) | 2 Scattered | Pads and antennas along the relay road | Cable runs, survey stakes, small instrument cases, low fencing | Wide pale pads; the relay road stays clean | The relay mast |
| **Badlands** (the open land between roads) | **4 Cluttered near hills, 2 in the wash** | Mesas and boulder fields round the hills, a flat open wash through the middle | Boulders, fallen slabs, scrub, broken ledges, old dig spoil | The wash (63, 8) and its fan; a broad flat for digging | The arch hill |
| **Basalt Ridge** (east) | **5 Packed in the flows, 3 on the road** | Rough lava fields either side of a lit road to the tunnel mouth and the Mine gate | Jagged basalt blocks, cooled flow ridges, vents, glassy shards | The road and a small turnout at each pad | The tunnel mouth's cliff and the vents' steam |
| **Frost Flats** (north) | **1 Open** | Huge, flat, pale; the long drive is the point | A few frost-split boulders, ice chips, low frost polygons painted on the ground | Almost everything | The ice ramp, and one tall ice pillar or a dead probe mast you can see from the farm |
| **Landing Field** (south) | 2 Scattered, ordered | A grid: slab, taxi lines, gantry | Cargo pods in neat rows, fuel tanks, light posts | The slab and the approach | The gantry |
| **Outer ring** (80 to 120 m) | Follows the biome, one grade less | Each biome fades into the next | The biome's own clutter, thinning | Bands of open ground between biomes | Each biome's landmark lies near its outer edge |

**The farm stays tidy.** Its clutter is laid out in rows and on pads (the colonist's yard), so it reads as *made*, against the wild land round it.

**One cluttered pocket in each open biome.** The Frost Flats gets one boulder field round a crashed probe; the Landing Field gets one scrapyard corner. A pocket gives the open land somewhere to go [ASSUMPTION].

**One open clearing in each cluttered biome.** The Basalt Ridge gets a smooth cooled flow where the rover can stop; the Badlands gets the wash. You come out of the clutter into light.

## 5. The zones

Today every depth is the same 24 by 22 grid with three rooms. Proposal: **each zone gets its own room pieces and its own trunk shape**, still from the integer hash, still BFS-checked, still 3 m cells, so the rules (finds, lifts, hatches, hazards) do not change.

| Zone | Grade | Shape of a depth [ASSUMPTION] | Clutter | Open space | Hub |
|---|---|---|---|---|---|
| **Lava Tubes** | 3 Broken | Long winding tubes with a few side chambers (as now) | Breakdown rubble, lava drips, glassy walls | A skylight chamber now and then | Orin's beacon cave (built) |
| **Flooded Aquifer** | 2 Scattered on water, 4 on the banks | **Big flooded chambers** joined by short wading channels; the water is the open space | Pipes, old pumps, mineral crusts at the edges | The water and the pumped-out pools | A pump house on a gallery over the water (NEW) |
| **Colony Mine** | **5 Packed** | **Tight straight shafts** on a grid, short side drifts, low ceilings, many small rooms | Props and beams, ore carts on rails, old crates, cable, collapsed timber; the most cluttered zone | Only the shaft junctions and the lift station | A head-frame yard: the shaft top, the winch house, Bram's crate (NEW, replaces the Lava grid) |
| **Polar Ice Caves** | **1 to 2 Open** | **Wide caverns** with tall ceilings, few walls, long sight lines; slick open floors (slice 14) | A few ice columns, fallen ice blocks, frozen probes | Most of it; the white-out (slice 14) hides it in its place | A broad ice hall at the ramp foot, with layered walls (NEW, replaces the Lava grid) |
| **Phobos** | 3 Broken | Built hub; low gravity (slice 17) | Service crates, cable, regolith piles | The landing apron | Odalys's desk (built) |
| **Deimos** | 2 Scattered | Built hub, quieter and older | Abandoned kit, a few pods | Wide dusty floor | Kestrel's camp (built) |
| **Valles Marineris** (later, slice 30) | 1 Open floor, 4 at the walls | A canyon: open floor, cluttered talus at the foot of each wall | Talus, fallen layers | The canyon floor | The canyon wall itself |
| **Olympus Mons caves** (later, slice 31) | 2 Scattered, at scale | Lava tubes at a larger scale: huge, mostly empty | Huge breakdown blocks, few and far | Big skylit halls | A skylight shaft |

**The Mine and the Ice Caves are the clearest pair.** Packed against open, and both reuse the Lava hub today, so they get their own hubs first (§8).

**Depth changes inside a zone [ASSUMPTION].** Deeper is a little more cluttered in the Mine (older, worse-kept workings) and a little more open in the Ice Caves (bigger caverns). The Lava Tubes and the Aquifer stay as built.

## 6. How it is built (the technical shape)

- **A density table.** `data/biomes.json` and `data/zones.json` each gain a `density` field (grade 1 to 5) and a `clutter` list (prop kinds and weights). Data only; a pure reader class, as `BiomeData` is. [ASSUMPTION]
- **One surface scatter, not one script per biome.** A `SurfaceScatter` (NEW) places clutter on a grid of cells (say 4 m [PLACEHOLDER]) from the farm seed: each cell rolls its biome's grade, then picks prop kinds from the biome's list. It keeps off roads, pads, signs, ways in, the plot, fissures, built things, lamps, rocks, plants and the uplink line where the relay needs it, and it leaves the clear lanes of §3. The existing dressings (`BasaltDressing`, `FrostDressing`, `LandingDressing`) stay as the hand-placed landmarks; the scatter is the fill.
- **Big and small.** Big clutter (grade 3 and up only) is a few colliding props per cell group and counts for the uplink dead-spot measure; small clutter is `MultiMeshInstance3D`, no collision.
- **Per-zone room pieces.** `ZoneDepth`, `AquiferDepth`, `MineDepth` and `IceDepth` each get their own room-piece list and trunk rule, behind the same layout interface. **Depth 1 of each zone stays byte for byte as it is** (pinned by hash tests, as the deep slices did), unless Ryan says depth 1 may change (Question 4).
- **Budget [PLACEHOLDER].** At most about 2,000 small clutter instances and 150 big props across the whole surface; measured with `tools/measure_land.gd` (ground build under 1 s at 240 m today). A zone depth: at most 300 small instances. **[RISK]** The low-end PC: measure before and after each pass.
- **Co-op and saves.** Nothing new is saved or sent; every PC builds the same clutter from the seed. If a pass moves a colliding prop where a guest's rover might stand, bump `CoopSession.PROTOCOL` so different builds are refused.
- **Art.** Primitives and the existing voxel props first. Ryan's packs in `art_inbox/` are style reference; using any texture from them needs his OK, as always.

## 7. Questions for Ryan

1. **The grades in §4 and §5:** do they match what you picture? (Recommended: as written.)
2. **Frost Flats fully open (grade 1)**, with one boulder field round a crashed probe? Or a little more broken? (Recommended: open with one pocket.)
3. **Basalt Ridge packed (grade 5)** off the road, so it is rover-on-the-road country? (Recommended: yes.)
4. **Zone depth 1:** keep every depth 1 exactly as built and give only the hubs and depths 2 and down the new shapes, or let depth 1 change too? (Recommended: let depth 1 change for the Mine and the Ice Caves only, so the pair feels different from the first visit; old saves are safe because depths reseed every day anyway.)
5. **Clutter you can move?** Should some small clutter be pushable by the rover, or is all clutter fixed? (Recommended: fixed for now; physics clutter costs co-op sync.)
6. **Order:** start with the Mine and Ice Caves hubs (zones), or the surface scatter (biomes)? (Recommended: surface scatter first, since every session sees it.)

## 8. Build order (small PRs, one job each)

1. **Density data.** `density` and `clutter` in `data/biomes.json` and `data/zones.json`, a pure reader, tests. No change on screen.
2. **Surface scatter, small clutter only.** `SurfaceScatter` with no-collision clutter for all five biomes and the outer ring, keep-clear rules, lanes, budget test, old-save and land-hash tests.
3. **Surface big clutter.** Colliding boulders and blocks for grades 3 to 5 (Badlands hills, Basalt flows), lane BFS, uplink dead-spot re-measure.
4. **Landmarks.** The Frost Flats pillar or probe mast and its boulder pocket, the Landing Field scrapyard corner, the Basalt clearing.
5. **Colony Mine hub and shafts.** Its own head-frame yard hub and packed shaft-grid room pieces (after slice 13 lands).
6. **Ice Caves hub and caverns.** Its own ice-hall hub and open cavern pieces (fits with slice 14, slick ice and white-out).
7. **Aquifer chambers.** Flooded-chamber pieces and a pump-house hub.
8. **Later areas** (Valles Marineris, Olympus Mons) are laid out to this doc when their slices come up (30, 31).

Every number in these PRs is a [PLACEHOLDER], recorded in `docs/decisions.md`.
