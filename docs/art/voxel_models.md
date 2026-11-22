# Voxel models (Week 4): merged spec

This spec merges two blind answers to the Week 4 concept-sheet prompt. The source answers, with their full orthographic grids, are in `sources/answer_a.md` and `sources/answer_b.md`; two more models were asked but returned nothing. Where this page and a source answer disagree, this page wins.

**What "pick" means below:** the starting grid to model from. The listed changes override it.

## Global rules

- **Voxel size by class.** Each class is fixed so models sit in the greybox's footprint. The engine applies the size through `model_scale` on each slot, assuming the export has 1 unit = 1 voxel. Verify this on the first export (see Export pipeline).

  | Class | Voxel size | Models |
  |---|---|---|
  | Small props and vehicles | 0.1 m | tractor, terrarium, Curlyhair, dome benches, cal station |
  | Characters and set pieces | 0.2 m | Bram and his bay, ore fissure, drop-pod, AUD-1T, dome room |
  | Distant landmark | 0.5 m | relay mast |

  The 0.1 m size matches the existing rule in `assets/voxels/README.md`. Answer A proposed 0.25 m for everything; that would make the tractor 3.5 m × 6 m against a 1.6 m × 2.4 m collision box.
- **Axes in MagicaVoxel:** X = width, Y = depth, Z = up. Front faces −Y in MagicaVoxel and −Z in Godot. Put the origin at ground level, centered on the footprint. Exceptions: AUD-1T and the Curlyhair spider use a center origin, because their slots sit at the greybox centers.
- **Semantic colors** are the only glow colors. Never use them as plain paint.

  | Meaning | Hex |
  |---|---|
  | in tolerance, outdoor telemetry | `#38E1C6` |
  | guard band, warm indoor lamps | `#F5A623` |
  | out of tolerance | `#FF5A5F` |
  | shadow base | `#1D222B` |

  Answer B's extra glow colors (`#FFA53B`, `#FFA726`, `#8BFFF0`, `#6DFCE6`, `#FFD54F`) are dropped. Amber means guard band, so a lamp must use `#F5A623`, not a near-miss.
- **Red is earned.** No permanently lit red LEDs on the player's kit; red means out of tolerance. The only always-red voxel is Bram's broken torque wrench, which really is out of calibration.
- **State LEDs are not in the model.** The game draws and colors them by band. Leave those voxels empty, or paint them `#1D222B` as a socket:
  - the terrarium hygrometer LED (`Terrarium/StatusLED`)
  - the rover's cab readout
  - the relay's spool core
- **Emissive voxels:** put each glowing part in its own MagicaVoxel object named `emit_<part>`, for example `emit_headlights`. `ModelSlot` makes any mesh named `emit_*` glow in its own colors, because MagicaVoxel exports don't carry emission into Godot. Glow parts are emission only (black albedo, no specular, so scene lights don't tint them) at `ModelSlot.EMIT_ENERGY` (1.2). Amber clips toward yellow under the Filmic tonemap long before teal does, so an amber lamp can get a per-part value through the slot's `emit_energy_overrides`. So far only the dome pendants and the terrarium heat lamp have one (0.5, tuned by eye); the farm's amber lamps (tractor headlights and roof lights, work lamp, drop-pod hatch, AUD-1T eye, relay bay lamp) still use 1.2 and haven't been tuned.
- **Readability at about 40 m:** keep silhouette features at least 2 voxels thick. Where space allows, give lit voxels a 1-voxel `#1D222B` border (from answer A). The generated first pass doesn't yet.

## 1. Tractor (`tractor.glb`, `tractor_wide.glb`)

Superseded in part by the Neon concept sheet section below: the whip and `emit_antenna` are replaced by the roof dish and `emit_beacon`.

- **Footprint:**
  - standard: 16 × 24 × 14 voxels = 1.6 m × 2.4 m × 1.4 m, matching the collision box
  - wide: 20 × 24 × 14 voxels (+2 voxels each side)
- **Pick: answer B.**
  - B's footprint matches the prompt and the collision box.
  - B's story is right: four chunky wheels as standard, and Bram's upgrade swaps the rear wheels for track units with sprockets and mud scrapers. Answer A put tracks on the standard tractor.
- **Palette** (B, with changes):
  - hull `#C85A2A`; I picked this one, see the open decisions
  - chassis `#1D222B` (B has `#1A1D24`; unified to the shadow base)
  - grille and engine `#4D5663`
  - cab glass `#4A7A82`
  - sat-phone unit `#E2E8F0`
  - tires `#101216`
- **Lit voxels:**
  - Antenna whip: 1 voxel thick, rising to Z = 22 (2.2 m), tip `emit_antenna`, `#38E1C6`. The uplink beam starts at `Rover/Antenna`, 2.2 m up. The cab roof tops out at 14 voxels and the sat-phone unit at 16.
  - Headlamps: `emit_headlights`, `#F5A623`.
- **Changes:**
  - Removed B's red hitch plug and A's red bypass LED.
  - B's amber sat-phone "mode display" becomes a dark socket. The Neon sheet dropped the sat-phone unit, so the game-driven steering readout (`Rover/CabReadout`, `scripts/rover/cab_readout.gd`) sits on the cab roof instead, at its front-right corner, clear of the uplink beam: 2 × 1 × 1 voxels centered at (0.3, 1.55, −0.2) m on the voxel roof (one voxel clear of the wide tractor's amber roof light), or (0.4, 1.7, 0.1) m on the greybox cab roof, colored by the steering band, at the same glow energy as the models' `emit_*` parts. These coordinates are a placement choice, not from a spec. The dash spot was hidden from the gameplay camera; the roof spot was checked visible from the iso camera at all 8 rover headings. Keep that roof spot clear in hand-refined models.
- **Wide variant:** swapped in automatically when Bram fits the treads, if `tractor_wide.glb` exists.

## 2. Terrarium and Curlyhair (`terrarium.glb`, `curlyhair.glb`)

- **Footprint:**
  - tank: 14 × 10 × 12 voxels = 1.4 m × 1.0 m × 1.2 m. The greybox glass is 1.4 m × 0.9 m × 0.9 m, so the model is 0.1 m deeper and 0.3 m taller (the lamp hood adds height).
  - spider: separate file; about 6 × 6 × 3 voxels is my estimate (neither source gives one)
- **Pick: answer A.** Its scale fits, and its palette stays on the semantic colors.
- **Palette:**
  - frame `#1D222B`
  - glass `#A3D5E0`, 25 % alpha
  - substrate `#3B2314`
  - cork bark `#4E6E48` (A) or `#634E3A` (B), your choice
  - lamp hood: `#9E7D3B` (B)
  - lamp bulb: `emit_heat_lamp`, `#F5A623`
- **From B:** the water dish and the bark slab tilted into the back corner.
- **Spider:** *Tliltocatl albopilosus*, a separate model. The pre-molt squash (scale) already applies to it, and it is hidden while molted (until the spool is taken). A voxel exuvia is not built yet.
  - carapace `#261710` (A)
  - gold curly tips `#D4A359` (A), on leg tips and joints and as abdomen speckle
  - B's shape: 3 × 4 abdomen, 2 × 2 prosoma, center origin
- **Changes:**
  - Hygrometer pod: body `#D4D9DE` (B). LED left out; the game drives it.
  - The pre-molt dimming currently tints only the greybox spider. The model keeps its colors unless that is extended.

## 3. Bram and his bay (`bram_bay.glb`)

- **Footprint:** 24 × 20 × 16 voxels = 4.8 m × 4.0 m × 3.2 m, against the 5.6 m × 4.6 m greybox roof. Bram is about 6 × 4 × 9 voxels, roughly 1.8 m tall.
- **Pick: answer A.**
  - Its jokes are on theme: a digital torque wrench on the pegboard, permanently red and out of calibration, and a cyan diagnostic scope on the bench.
  - Blue overalls `#2B3C65` stand out against the amber lamp.
- **From B:**
  - Bram's unkempt steel-gray beard, `#5E5855`
  - the sledgehammer raised over a bent suspension arm in a floor vise
- **Lit voxels:**
  - Overhead lamp: `emit_work_lamp`, `#F5A623`.
  - Torque wrench: `emit_torque_wrench`, `#FF5A5F`.
  - Bench scope: `emit_scope`, `#38E1C6`.
- **Changes:**
  - The open side faces +Z; the trade zone is the 5 m × 5 m `BramBay/Shape`.
  - The scene's work light (`BramBay/Visual/WorkLight`) stays on after the swap.

## 4. Crystal ore fissure (`ore_fissure.glb`)

- **Footprint:** 8 × 8 × 6 voxels = 1.6 m × 1.6 m × 1.2 m. The drill reach is 2 m.
- **Pick: answer A.**
  - It sits on ground level with spires rising, so it drops onto the plateau as is. B's version is a slab 4 voxels thick that would stand above the ground.
- **Palette:**
  - clay `#A8422B`
  - rust crust `#6E2617`
  - fissure shadow `#1D222B`
  - quartz base `#1F7A70`
  - crystal tips: `emit_crystals`, `#38E1C6`
- **Changes:**
  - A's grid has clay at Z01–Z02. Put the origin at the top of Z02 so those layers sink into the ground instead of standing 0.4 m proud.
  - The whole model hides while the fissure is mined, so no depleted variant is needed.

## 5. Drop-pod and AUD-1T (`drop_pod.glb`, `aud1t.glb`)

Superseded by the second batch of Neon sheets (see below): the stepped-nose pod with splayed legs and the cross-eyed AUD-1T.

- **Footprint:**
  - pod: 12 × 12 × 16 voxels = 2.4 m × 2.4 m × 3.2 m, against the greybox's 2 m diameter and 3.4 m height
  - AUD-1T: 4 × 4 × 5 voxels = 0.8 m × 0.8 m × 1.0 m, against the 0.8 m greybox sphere
- **Pick: answer A for both.** B's pod grids have row and width errors (two rows labelled 05, rows 14 cells wide). B's drone is too big.
- **Pod palette:**
  - hull `#E85D25`
  - struts `#4F5D73`
  - heat shield `#1D222B`
  - hatch seam: `emit_hatch`, `#F5A623`
- **AUD-1T palette:**
  - shell `#F0F4F8`
  - one scanner eye, 2 × 1 (A): `emit_eye`, `#F5A623`
  - lift ring: `emit_lift_ring`, `#38E1C6`
  - center origin (the slot sits at the greybox sphere's center)
- **Changes:**
  - A's red apex strobe becomes B's `#38E1C6` uplink beacon (`emit_beacon`), because red means out of tolerance.
  - The drone is its own file. The game bobs it beside the pod.

## 6. Relay mast (`relay_mast.glb`)

- **Source: Neon's concept sheet** (Gemini share, 2026-11-21), which replaces the earlier A/B merge for this model.
- **Shape:** square four-leg lattice tower, 3 m × 3 m, with one zigzag brace per 3 m panel (the top panel is 2 m), on a two-step concrete plinth. Side-mounted dish near the top faces the farm (+X +Z, tipped up). Dark cap at 15.5 m with the beacon on a 1 m stub above it, at 17 m.
- **Footprint:** 12 × 12 × 35 voxels at 0.5 m = 6 m × 6 m × 17.5 m.
- **Palette:**
  - lattice `#526075`
  - plinth `#5C6067`
  - cap and bay panels `#1D222B`
  - dish `#E1E8F0`
  - flange guides `#C48F2B`
- **Lit voxels:**
  - beacon: `emit_beacon`, `#38E1C6`
  - spool bay lamp: `emit_bay_lamp`, `#F5A623`
  - fiber run from the bay up to the dish: `emit_fiber`, `#38E1C6`. The game shows it only once a silk spool is installed (`SatelliteRelay.mast_model`).
- **Scene markers moved to match the model:**
  - `SpoolBay` to (2.0, 3.0, 0) m, inside the open pocket of the bay cage
  - `Dish` (the uplink target) to (2.0, 15.5, 2.0) m, at the dish center
  - `Beacon` light to 17.25 m on the tower axis, centered on the beacon voxels

## Neon concept sheets (2026-11-21)

Neon (Gemini) drew concept sheets for the tractor, terrarium, Bram's shed, the ore fissure and the relay mast. The generator follows them for those models; where a sheet and an earlier section of this page differ, the sheet wins, except for the changes below.

- **Tractor:**
  - big rear wheels (1.2 m), small front wheels (0.7 m)
  - mustard lower panels `#C9962E`, kept well off guard-band amber `#F5A623`
  - chrome-slatted grille, amber headlights
  - roof dish and a cyan roof beacon. The uplink dish replaces the whip, and `Rover/Antenna` (the LOS origin and beam start) moved to the dish center, (0.22, 1.88, 0.38) m, the tip of the feed horn.
  - wide variant: full-length tracks with sprocket, idler and fenders, plus amber roof lights
- **Terrarium:** glowing amber dome heat lamp on a slate bracket, hollow half-log hide, round water dish, pebbles. The sheet's two cyan LEDs stay one game-driven LED, colored by the hygrometer band.
- **Bram's shed:**
  - timber posts and a lean-to corrugated roof
  - pegboard tool wall, tire stacks, rusty barrels, a workbench with a cyan monitor, two hanging amber lamps
  - **Change:** the roof covers only the back half of the shed. Bram stands under it; the game camera's angle still shows him.
  - **Change:** the slab is sunk 0.2 m so it is flush with the ground and the rover drives onto it.
  - **Change:** tools are painted `#B0392B`, not alert red; the out-of-cal torque wrench is the only `#FF5A5F` red.
- **Bram:** chibi proportions, navy coveralls, messy brown hair, goggles pushed up, a big pipe wrench. No beard, per the sheet.
- **Ore fissure:** cracked terracotta flush with the ground, a dark jagged crack with a branch, and clusters of tall pointed crystals growing out of it.

### Second batch of sheets (2026-11-21, evening)

- **Drop-pod:** square hull with chamfered slate corner struts and a scorched lower band, a stepped pyramid nose under a teal beacon, a +Z hatch with an amber outline, and four splayed legs (orange upper, slate lower, orange pads). 18 × 18 × 21 voxels at 0.2 m (3.6 m across the legs, 4.2 m tall).
- **AUD-1T:** rounded white shell with a dark visor band and ONE cross-shaped amber eye, off-center like the sheet, plus a teal lift ring. 5 × 5 × 5 voxels at 0.2 m, center origin.
- **Dome interior**, in three new models with slots over the greybox. The clickable areas stay where they were.
  - `dome_room.glb`: arched ribbed vault (14 m wide, 5.6 m peak, 10 m deep, open toward the camera), a round airlock with a cyan ring (`emit_airlock_ring`), a door panel with teal LEDs, and three amber pendant lamps (`emit_lamps`). 0.2 m voxels.
  - `dome_bench.glb`: worn steel work table with slate legs and a shelf, used for both benches. 0.1 m voxels.
  - `cal_station.glb`: reference standard with a cyan screen, a clamp stand holding the hygrometer under test, an encoder test jig, a clipboard and a handheld meter. 0.1 m voxels.
  - **Change from the sheet:** it had a small red LED on the clamped hygrometer. The model has an empty socket instead, because red is only for something actually out of tolerance and the hygrometer's state is game-driven.
  - **Change from the sheet:** its green tablet readout is teal, so it stays on the palette.
  - **Change from the sheet:** the sheet puts the airlock on the left wall; it stays on the back wall to match the scene.

## Generated first pass

`python tools/voxgen/build_models.py` builds all twelve models from this spec. It writes `assets/voxels/*.glb`, which the game loads, and `assets/voxels/source/*.vox`, for refinement in MagicaVoxel. Checked in Godot 4.7.2: the tractor, fissure, bay, terrarium, spider, drop-pod and AUD-1T load at the right scale and facing, and their `emit_*` parts glow. The relay mast (off camera) and `tractor_wide` (needs the trade) were not seen in play.

Where the generated models differ from the footprints above:

| Model | Spec | Built | Why |
|---|---|---|---|
| tractor | 16 × 24 × 14 | 16 × 25 × 19 | Neon sheet: 12-voxel rear wheels; the roof dish tops out at 1.9 m; the hitch adds 1 voxel of depth |
| tractor_wide | 20 × 24 × 14 | 20 × 25 × 19 | same, with full-length tracks |
| terrarium | 14 × 10 × 12 | 14 × 10 × 15 | the dome lamp and bracket sit above the tank, whose frame tops out at 1.2 m |
| bram_bay | 24 × 20 × 16 | 25 × 20 × 18 | Neon sheet: lean-to roof peaks at 3.6 m; Bram's wrench pokes 1 voxel past the slab; the bay sits 0.5 m back to match the greybox |
| relay_mast | 12 × 12 × 35 (Neon sheet) | 12 × 12 × 35 | rebuilt from Neon's concept sheet; see section 6 |
| drop_pod (Neon sheet 2) | 12 × 12 × 16 | 18 × 18 × 21 | splayed legs widen it to 3.6 m; the nose and beacon reach 4.2 m |
| aud1t (Neon sheet 2) | 4 × 4 × 5 | 5 × 5 × 5 | the cross-shaped eye needs a 3-voxel visor |
| curlyhair | about 6 × 6 × 3 | 7 × 7 × 3 | legs reach 3 voxels out; abdomen and prosoma are 3 voxels wide (spec: 3 × 4 and 2 × 2) |
| ore_fissure | 8 × 8 × 6 | 8 × 8 × 7 | Neon sheet: the main crystal is 5 voxels tall above two sunk layers |


## Export pipeline (for hand-refined models)

- Each `.vox` is a single MagicaVoxel model, so part names (`emit_*`, glass) and the center offset are not in it. When refining by hand, split the glowing and glass parts back into named objects before export.
- The generated `.glb` files skip this step. After refining a `.vox` by hand: MagicaVoxel may not export glTF directly (not verified here). If not, export OBJ and convert to `.glb` (for example through Blender), or use a Godot `.vox` import plugin and save the result as a `.tscn`. `ModelSlot` accepts `.glb`, `.gltf` and `.tscn`.
- Whatever the route, check three things on the tractor first:
  - **Scale:** 1 unit = 1 voxel, or adjust that slot's `model_scale`.
  - **Facing:** front on −Z in Godot.
  - **Object names:** `emit_*` must arrive as mesh node names.
- Glow uses the palette texture. If the route bakes colors into vertex colors instead, `emit_*` parts glow white; tell me and I'll switch the glow to vertex colors.

## Verdict (blind)

| Answer | Score | Why |
|---|---|---|
| A | 8/10 | Stays on the semantic palette, has the best metrology jokes, and its grids line up with each other. But its 0.25 m scale breaks every in-game size, and it put tracks on the standard tractor. |
| B | 6/10 | Matches the requested tractor footprint and the wheels-to-tracks story, and has the right relay silhouette. But it invents 5 off-palette glow colors, has broken drop-pod grids, and its fissure would float above the ground. |

## Open decisions

- **Tractor hull color.** The greybox's orange (`#E68C1F`) and answer A's gold (`#D99B26`) both sit too close to guard-band amber. I picked B's `#C85A2A`; say if you want something else.
- **Material values are unverified.** The Strength, Power and Flux numbers in the source answers aren't checked against MagicaVoxel's material panel. The game ignores them: glow comes from the `emit_*` naming.

## Boulders and soil tiles

- **Boulders** (`boulder_a`–`boulder_d`, 0.2 m): canon puts surface boulders on the Terracotta Plateau, so they use the ore fissure's plateau palette (`#A8422B`, `#8E3522`, `#6E2617`, crack `#5E2214`) plus shadow `#1D222B` in the cracks. Each matches its greybox box (A 5 m × 4 m × 4 m, B 4 m × 3.5 m × 5 m, C 4 m cube, D 3 m cube) because the collider stays that box; B's model is 3.6 m tall (18 voxels). Layer 0 sits on the ground. No glow.
  - All four are built voxel for voxel by `boulder_sheet` from Gemini's layer grids, saved as `tools/voxgen/sheets/boulder_a.txt` … `boulder_d.txt` (MagicaVoxel axes; A 25 × 20 × 20, B 20 × 25 × 18, C 20 × 20 × 20, D 15 × 15 × 15). Where Gemini's rendered images disagree with its grids, the grids win.
  - B leans toward +x from layer 4 up (about 50 overhanging cells). C has a canyon split down the middle; one shadow voxel at X = 9, Y = 14, Z = 7 (the sheet's axes) is fully buried and never seen. Each grid is one connected solid with no sealed air.
- **Soil tiles** (`soil_untilled`, `soil_tilled`, 0.1 m): 19 × 2 × 19 voxels (1.9 m × 0.2 m × 1.9 m) in the 2 m cell. Both are built voxel for voxel by `soil_sheet` from Gemini's layer grids, saved as `tools/voxgen/sheets/soil_untilled.txt` and `soil_tilled.txt`. The grids name tokens but give no hex values, so the colors are sampled from Gemini's concept images.
  - Untilled: layer 0 all U1, layer 1 flat with speckles and six 2-voxel pebbles. U1 tan `#78563B`, U2 light `#A98463`, U3 dark `#563D26`. Which of U2 and U3 is light is an assumption; the grid does not say.
  - Tilled: layer 0 all T2 (`#2A1D15`, the wet trough floor). Layer 1 is ridges of T1 (`#442E21`) speckled with T3 (`#2D1E14`), with empty rows at Y = 2, 5, 8, 11, 14 and 17 as the furrows, running along X. No shadow-edge color.
  - Placement: `SoilGrid` sits at y = −0.05 m, so with 0.2 m cells centered on y = 0.05 m each tile's base layer spans −0.05 m to 0.05 m and its top layer 0.05 m to 0.15 m. That keeps the furrow floor 0.05 m above the Ground top (y = 0), so the furrows show `#2A1D15` and not the ground, with no z-fighting. The height is a tuning choice, not from a spec. The rover still drives on the Ground (y = 0), so its wheels sink up to 0.15 m into the tile tops; the tiles have no collision. Before this the base layer was buried (−0.15 m to −0.05 m) and the furrows showed the green ground.
