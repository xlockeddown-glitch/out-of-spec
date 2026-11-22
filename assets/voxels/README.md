# assets/voxels

First-pass models are generated: run `python tools/voxgen/build_models.py`, which writes the `.glb` files here and editable MagicaVoxel sources in `source/`. Hand-refined exports (.glb preferred, or .gltf) replace them under the same names. Use these exact file names and they swap in automatically. Each greybox sits under a `ModelSlot` (or checks the path itself), so no scene or code edits are needed.

| File | Replaces | Notes |
|---|---|---|
| `tractor.glb` | Rover greybox (`Rover/VisualRoot`) | Origin at ground level, center of the wheelbase, front facing −Z. Collision stays on `Rover/CollisionShape3D`. |
| `bram_bay.glb` | Bram and his scrapyard bay (`BramBay/Visual`) | Open side faces +Z. The trade zone is the 5 m × 5 m `BramBay/Shape`. |
| `tractor_wide.glb` | Tractor after Bram's wide treads | Same origin as `tractor.glb`; swapped in when the treads are bought. |
| `ore_fissure.glb` | Crystal ore fissure greybox (`OreFissure`) | 1.6 m across; hidden while mined. |
| `terrarium.glb` | Tank, substrate, hygrometer pod, lamp hood (`Terrarium/TankModel`) | Leave the hygrometer LED out; the game drives it. |
| `curlyhair.glb` | Earlier spider model, replaced in the terrarium by `live_tarantula.glb` (not placed in the game; still in the dev model gallery) | Center origin. |
| `drop_pod.glb` | Pod hull, nose, hatch (`DropPod/PodModel`) | |
| `aud1t.glb` | AUD-1T drone (`DropPod/AUD1T/DroneModel`) | Center origin. The game bobs it. |
| `relay_mast.glb` | Mast and dish (`SatelliteRelay/MastModel`) | Model the spool bay empty; the spool is game-driven. |
| `boulder_a.glb` … `boulder_d.glb` | Farm boulders (`Rocks/Rock<A–D>/Model`) | 0.2 m voxels, origin at ground level. Each fills its rock's box collider, except that B's model is 3.6 m tall against a 3.5 m collider. Built from Gemini's layer grids (`tools/voxgen/sheets/boulder_a.txt` … `boulder_d.txt`). |
| `tarantula_exuvia.glb` | Molted skin left after a molt (shown in the terrarium while the spider is molted and until the morning after the spool is taken) | 0.1 m voxels like `curlyhair`, origin at ground level. Built from Gemini's layer grid (`tools/voxgen/sheets/tarantula_exuvia.txt`). |
| `soil_moisture_probe.glb` | Hand soil-moisture probe with a front dial (not placed in any scene yet) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid (`tools/voxgen/sheets/soil_moisture_probe.txt`). |
| `steering_encoder_jig.glb` | Steering-encoder calibration jig (not placed in any scene yet) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid, with Z = 2 corrected by Gemini Neon (`tools/voxgen/sheets/steering_encoder_jig.txt`). |
| `field_survey_tripod.glb` | Survey tripod with a target head (not placed in any scene yet) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid for Z = 0 and Gemini Neon's corrected grids for Z = 1 to 13 (`tools/voxgen/sheets/field_survey_tripod.txt`). |
| `crop_stage_0.glb` | Sun-pod crop, growth stage 0: seeded mound (not placed in any scene yet) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid (`tools/voxgen/sheets/crop_stage_0.txt`). |
| `crop_stage_1.glb` | Sun-pod crop, growth stage 1: twin-leaf sprout (not placed in any scene yet) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid (`tools/voxgen/sheets/crop_stage_1.txt`). |
| `crop_stage_2.glb` | Sun-pod crop, growth stage 2: leafy stalk and tight bud (not placed in any scene yet) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid (`tools/voxgen/sheets/crop_stage_2.txt`). |
| `crop_stage_3.glb` | Sun-pod crop, growth stage 3: mature sun-pod (not placed in any scene yet) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid (`tools/voxgen/sheets/crop_stage_3.txt`). |
| `crop_stage_wilted.glb` | Wilted, over-watered crop (not placed in any scene yet) | 0.1 m voxels, origin at ground level. Built from Ryan's Pack 3 grid (`tools/voxgen/sheets/crop_stage_wilted.txt`). |
| `live_tarantula.glb` | Live Curlyhair, matching the exuvia (`Terrarium/Tarantula/SpiderModel`; replaced `curlyhair.glb` on 2026-11-22) | 0.1 m voxels, origin at ground level, same footprint as `curlyhair`. Built from Ryan's Pack 3 grid (`tools/voxgen/sheets/live_tarantula.txt`). |
| `irrigation_junction.glb` | Drip-line valve and manifold junction (not placed in any scene yet) | 0.1 m voxels, origin at ground level. Built from Ryan's Pack 3 grid (`tools/voxgen/sheets/irrigation_junction.txt`). |

Each slot's `model_scale` sets the voxel size (0.1 m, 0.2 m or 0.5 m by class), assuming 1 export unit = 1 voxel. Full spec, palettes and the `emit_*` naming rule for glowing parts: `docs/art/voxel_models.md`.

Soil tiles: `soil_untilled.glb` and `soil_tilled.glb` (0.1 m voxels, centered on the cell; built from Gemini's layer grids in `tools/voxgen/sheets/soil_*.txt`) are packed into `soil_tiles.tres`, a MeshLibrary whose item IDs match `FarmGrid.Tile` (0 = soil_untilled, 1 = soil_tilled). It is assigned to `SoilGrid.mesh_library_override`. After changing either tile, rebuild it with `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/voxgen/build_soil_library.gd`.

Rocks: each rock is a `StaticBody3D` on `collision_layer = 5` (world + signal_occluder) with a box `Shape`, so LOS keeps working whatever the `Model` slot shows. Keep that layer if you replace them.


## Upgrade visuals

Wide treads widen the greybox `Wheel*` cylinders, or swap `tractor.glb` for
`tractor_wide.glb` once both exist.
