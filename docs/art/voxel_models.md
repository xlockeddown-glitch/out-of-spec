# Voxel models (Week 4): merged spec

This spec merges two blind answers to the Week 4 concept-sheet prompt. The source answers, with their full orthographic grids, are in `sources/answer_a.md` and `sources/answer_b.md`; two more answers failed. Where this page and a source answer disagree, this page wins.

**What "pick" means below:** the starting grid to model from. The listed changes override it.

## Global rules

- **Voxel size by class.** Each class is fixed so models sit in the greybox's footprint. The engine applies the size through `model_scale` on each slot, assuming the export has 1 unit = 1 voxel. Verify this on the first export.

  | Class | Voxel size | Models |
  |---|---|---|
  | Small props and vehicles | 0.1 m | tractor, terrarium, Curlyhair |
  | Characters and set pieces | 0.2 m | Bram and his bay, ore fissure, drop-pod, AUD-1T |
  | Distant landmark | 0.5 m | relay mast |

  The 0.1 m size matches the existing rule in `assets/voxels/README.md`. Answer A proposed 0.25 m for everything; that would make the tractor 3.5 m × 6 m against a 1.6 m × 2.4 m collision box.
- **Axes in MagicaVoxel:** X = width, Y = depth, Z = up. Front faces −Y in MagicaVoxel and −Z in Godot. Put the origin at ground level, centred on the footprint.
- **Semantic colours** are the only glow colours. Never use them as plain paint.

  | Meaning | Hex |
  |---|---|
  | in tolerance, outdoor telemetry | `#38E1C6` |
  | guard band, warm indoor lamps | `#F5A623` |
  | out of tolerance | `#FF5A5F` |
  | shadow base | `#1D222B` |

  Answer B's extra glow colours (`#FFA53B`, `#FFA726`, `#8BFFF0`, `#6DFCE6`, `#FFD54F`) are dropped. Amber means guard band, so a lamp must use `#F5A623`, not a near-miss.
- **Red is earned.** No permanently lit red LEDs on the player's kit; red means out of tolerance. The only always-red voxel is Bram's broken torque wrench, which really is out of calibration.
- **State LEDs are not in the model.** The game draws and colours them by band. Leave those voxels empty, or paint them `#1D222B` as a socket:
  - the terrarium hygrometer LED (`Terrarium/StatusLED`)
  - the rover's cab readout
  - the relay's spool core
- **Emissive voxels:** put each glowing part in its own MagicaVoxel object named `emit_<part>`, for example `emit_headlights`. `ModelSlot` makes any mesh named `emit_*` glow in its own colours, because MagicaVoxel exports don't carry emission into Godot.
- **Readability at about 40 m:** keep silhouette features at least 2 voxels thick. Every lit voxel gets at least a 1-voxel `#1D222B` border (from answer A).

## 1. Tractor (`tractor.glb`, `tractor_wide.glb`)

- **Footprint:**
  - standard: 16 × 24 × 14 voxels = 1.6 m × 2.4 m × 1.4 m, matching the collision box
  - wide: 20 × 24 × 14 voxels (+2 voxels each side)
- **Pick: answer B.**
  - B's footprint matches the prompt and the collision box.
  - B's story is right: four chunky wheels as standard, and Bram's upgrade swaps the rear wheels for track units with sprockets and mud scrapers. Answer A put tracks on the standard tractor.
- **Palette** (B, with changes):
  - hull `#C85A2A`; I picked this one, see the open decisions
  - chassis `#1D222B`
  - grille and engine `#4D5663`
  - cab glass `#4A7A82`
  - sat-phone unit `#E2E8F0`
  - tyres `#101216`
- **Lit voxels:**
  - Antenna tip: `emit_antenna`, `#38E1C6`. It sits right under the uplink beam origin (`Rover/Antenna`, 2 m up), so keep it at the rear-right of the roof.
  - Headlamps: `emit_headlights`, `#F5A623`.
- **Changes:**
  - Removed B's red hitch plug and A's red bypass LED.
  - B's amber sat-phone "mode display" becomes a dark socket: the game will drive it from the steering band later.
- **Wide variant:** swapped in automatically when Bram fits the treads, if `tractor_wide.glb` exists.

## 2. Terrarium and Curlyhair (`terrarium.glb`, `curlyhair.glb`)

- **Footprint:**
  - tank: 14 × 10 × 12 voxels = 1.4 m × 1.0 m × 1.2 m, fits the 1.5 m × 1 m greybox
  - spider: about 6 × 6 × 3 voxels, as a separate file
- **Pick: answer A.** Its scale fits, and its palette stays on the semantic colours.
- **Palette:**
  - frame `#1D222B`
  - glass `#A3D5E0`, 25 % alpha
  - substrate `#3B2314`
  - cork bark `#4E6E48` (A) or `#634E3A` (B), your choice
  - lamp hood: `#9E7D3B` (B)
  - lamp bulb: `emit_heat_lamp`, `#F5A623`
- **From B:** the water dish and the bark slab tilted into the back corner.
- **Spider:** *Tliltocatl albopilosus*, a separate model so molting can hide it and show the exuvia.
  - carapace `#261710` (A)
  - gold curly tips `#D4A359` (A), on leg tips and joints and as abdomen speckle
  - B's shape: 3 × 4 abdomen, 2 × 2 prosoma
- **Changes:**
  - Hygrometer pod: body `#D4D9DE` (B). LED left out; the game drives it.
  - The pre-molt dimming currently tints only the greybox spider. The model keeps its colours unless that is extended.

## 3. Bram and his bay (`bram_bay.glb`)

- **Footprint:** 24 × 20 × 16 voxels = 4.8 m × 4.0 m × 3.2 m, against the 5.6 m × 4.6 m greybox roof. Bram is about 6 × 4 × 9 voxels, roughly 1.8 m tall.
- **Pick: answer A.**
  - Its jokes are on theme: a digital torque wrench on the pegboard, permanently red and out of calibration, and a cyan diagnostic scope on the bench.
  - Blue overalls `#2B4C65` stand out against the amber lamp.
- **From B:**
  - Bram's unkempt steel-grey beard, `#5E5855`
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
- **Changes:** the whole model hides while the fissure is mined, so no depleted variant is needed.

## 5. Drop-pod and AUD-1T (`drop_pod.glb`, `aud1t.glb`)

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
  - one scanner eye, 2 × 2: `emit_eye`, `#F5A623`
  - lift ring: `emit_lift_ring`, `#38E1C6`
- **Changes:**
  - A's red apex strobe becomes B's `#38E1C6` uplink beacon (`emit_beacon`), because red means out of tolerance.
  - The drone is its own file. The game bobs it beside the pod.

## 6. Relay mast (`relay_mast.glb`)

- **Footprint:** 18 × 18 × 32 voxels = 9 m × 9 m × 16 m, against the greybox's 16 m mast with the dish at 16 m.
- **Pick: B's silhouette and A's spool bay.**
  - B's tall lattice is the landmark the uplink beam points at.
  - A's side bay has gold-anodised flanges `#C48F2B` and silk `#D8F0F2`.
- **Palette:**
  - lattice `#526075`
  - footings `#30343D`
  - dish `#E1E8F0`
  - masthead beacon: `emit_beacon`, `#38E1C6`
- **Changes:**
  - B used amber as plain paint on the spool flanges; they are gold instead.
  - B's red diagnostic LED is removed.
  - The spool itself stays a game-driven node (`SatelliteRelay/SpoolBay`) because it appears only once a spool is installed. Model the bay empty.

## Verdict (blind)

| Answer | Score | Why |
|---|---|---|
| A | 8/10 | Stays on the semantic palette, has the best metrology jokes, and its grids line up with each other. But its 0.25 m scale breaks every in-game size, and it put tracks on the standard tractor. |
| B | 6/10 | Matches the requested tractor footprint and the wheels-to-tracks story, and has the right relay silhouette. But it invents 5 off-palette glow colours, has broken drop-pod grids, and its fissure would float above the ground. |

## Open decisions

- **Tractor hull colour.** The greybox's orange (`#E68C1F`) and answer A's gold (`#D99B26`) both sit too close to guard-band amber. I picked B's `#C85A2A`; say if you want something else.
- **Material values are unverified.** The Strength, Power and Flux numbers in the source answers aren't checked against MagicaVoxel's material panel. The game ignores them: glow comes from the `emit_*` naming.
