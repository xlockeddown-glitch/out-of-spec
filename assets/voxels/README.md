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
| `soil_moisture_probe.glb` | Hand soil-moisture probe with a front dial (`SoilProbeModel` in the farm, beside the irrigation junction) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid (`tools/voxgen/sheets/soil_moisture_probe.txt`). |
| `steering_encoder_jig.glb` | Steering-encoder calibration jig (`EncoderJig` in the farm, beside the field calibration pad) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid, with Z = 2 corrected by Gemini Neon (`tools/voxgen/sheets/steering_encoder_jig.txt`). |
| `field_survey_tripod.glb` | Survey tripod with a target head (`FieldCalPad/Tripod` in the farm) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid for Z = 0 and Gemini Neon's corrected grids for Z = 1 to 13 (`tools/voxgen/sheets/field_survey_tripod.txt`). |
| `crop_stage_0.glb` | Sun-pod crop, growth stage 0: seeded mound (on planted farm cells) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid (`tools/voxgen/sheets/crop_stage_0.txt`). |
| `crop_stage_1.glb` | Sun-pod crop, growth stage 1: twin-leaf sprout (on planted farm cells) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid (`tools/voxgen/sheets/crop_stage_1.txt`). |
| `crop_stage_2.glb` | Sun-pod crop, growth stage 2: leafy stalk and tight bud (on planted farm cells) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid (`tools/voxgen/sheets/crop_stage_2.txt`). |
| `crop_stage_3.glb` | Sun-pod crop, growth stage 3: mature sun-pod (on planted farm cells) | 0.1 m voxels, origin at ground level. Built from Gemini's layer grid (`tools/voxgen/sheets/crop_stage_3.txt`). |
| `crop_stage_wilted.glb` | Wilted, over-watered crop (on planted farm cells whose soil has left its band) | 0.1 m voxels, origin at ground level. Built from Ryan's Pack 3 grid (`tools/voxgen/sheets/crop_stage_wilted.txt`). |
| `live_tarantula.glb` | Live Curlyhair, matching the exuvia (`Terrarium/Tarantula/SpiderModel`; replaced `curlyhair.glb` on 2026-11-22) | 0.1 m voxels, origin at ground level, same footprint as `curlyhair`. Built from Ryan's Pack 3 grid (`tools/voxgen/sheets/live_tarantula.txt`). |
| `irrigation_junction.glb` | Drip-line valve and manifold junction (in the farm, just outside the plot's front edge) | 0.1 m voxels, origin at ground level. Built from Ryan's Pack 3 grid (`tools/voxgen/sheets/irrigation_junction.txt`). |
| `mesa_scrub_bush.glb` | Wind-bent sage scrub, 2.0 m across and 1.6 m tall (two in the farm, scattered outside the plot) | 0.2 m voxels, origin at ground level. Built from Ryan's Plateau Clutter grid (`tools/voxgen/sheets/mesa_scrub_bush.txt`). |
| `scatter_pebbles_cluster.glb` | Three flat-topped plateau cobbles, 2.0 m × 1.6 m (two in the farm, scattered outside the plot) | 0.2 m voxels, origin at ground level. Built from Ryan's Plateau Clutter grid (`tools/voxgen/sheets/scatter_pebbles_cluster.txt`). |
| `mesa_dry_stump.glb` | Sun-bleached dry stump on red dust, 1.2 m tall (two in the farm, scattered outside the plot) | 0.2 m voxels, origin at ground level. Built from Ryan's Plateau Clutter grid (`tools/voxgen/sheets/mesa_dry_stump.txt`). |
| `water_cistern.glb` | Steel water cistern with pipe outlets and a brass handwheel, 1.6 m across and 1.8 m tall (in the farm, beside the irrigation junction) | 0.1 m voxels, origin at ground level. Built from Ryan's Farm Logistics grid (`tools/voxgen/sheets/water_cistern.txt`). |
| `harvest_crate.glb` | Safety-orange crate packed with sun-pods, 1.0 m × 0.8 m × 0.6 m (in the farm, at the plot's front edge) | 0.1 m voxels, origin at ground level. Built from Ryan's Farm Logistics grid (`tools/voxgen/sheets/harvest_crate.txt`). |
| `shipping_pallet.glb` | Slatted wood pallet with steel corner shoes, 1.4 m × 1.2 m × 0.3 m (in the farm, beside the harvest crate) | 0.1 m voxels, origin at ground level. Built from Ryan's Farm Logistics grid (`tools/voxgen/sheets/shipping_pallet.txt`). |
| `dry_gulch_straight.glb` | Dry wash channel along X between 1.2 m banks, a seamless 2.0 m terrain tile (six in a row in the farm, behind the plot) | 0.2 m voxels, origin at the center of the 2.0 m cell on the ground. Built from Ryan's Dry Gulch & Plateau Rim grid (`tools/voxgen/sheets/dry_gulch_straight.txt`). |
| `plateau_rim_straight.glb` | Stepped mesa cliff edge along X, 2.0 m tall, a seamless 2.0 m terrain tile (eight in the farm's plateau rim, behind the gulch) | 0.2 m voxels, origin at the center of the 2.0 m cell on the ground. Built from Ryan's Dry Gulch & Plateau Rim grid (`tools/voxgen/sheets/plateau_rim_straight.txt`). |
| `plateau_rim_corner.glb` | Outer 90° mesa headland corner, 2.0 m tall, a 2.0 m terrain tile (one at each end of the farm's plateau rim) | 0.2 m voxels, origin at the center of the 2.0 m cell on the ground. Built from Ryan's Dry Gulch & Plateau Rim grid (`tools/voxgen/sheets/plateau_rim_corner.txt`). |
| `lab_calibration_bench.glb` | ESD calibration workbench with a backsplash rail, a drawer, a brass ground lug and a brass terminal, 2.0 m × 1.4 m × 1.0 m tall (the dome's calibration bench, under the cal station) | 0.1 m voxels, origin at ground level. Built from Ryan's Metrology Lab grid (`tools/voxgen/sheets/lab_calibration_bench.txt`). |
| `ref_meter_ls85.glb` | Benchtop reference multimeter with a blank display bay, 0.4 m × 0.35 m × 0.15 m, on the chamber cart's lid in the dome | **0.025 m voxels**, origin at ground level. Built from Ryan's Metrology Lab grid (`tools/voxgen/sheets/ref_meter_ls85.txt`). |
| `field_meter_fm3.glb` | Yellow handheld digital multimeter lying face up, 0.15 m × 0.25 m × 0.1 m (not placed: the bench shows the FM-3 in its carry case, `fm3_field_meter_case`) | **0.025 m voxels**, origin at ground level. Built from Ryan's Metrology Lab grid (`tools/voxgen/sheets/field_meter_fm3.txt`). |
| `env_chamber_cart.glb` | Environmental chamber on a rolling cart, 1.4 m × 1.0 m × 1.6 m tall (in the dome, right of the calibration bench) | 0.1 m voxels, origin at ground level. Built from Ryan's Environmental Chamber grid (`tools/voxgen/sheets/env_chamber_cart.txt`). |
| `dry_well_calibrator.glb` | Dry-block temperature calibrator with a keypad, a blank screen bay, a vented tower and a probe well on top, 0.25 m × 0.25 m × 0.35 m tall (on the dome's calibration bench, back right) | **0.025 m voxels**, origin at ground level. Built from Ryan's Environmental Standards grid (`tools/voxgen/sheets/dry_well_calibrator.txt`). |
| `chilled_mirror_hygrometer.glb` | Chilled-mirror dew-point hygrometer with a blank screen bay, brass gas ports and a brass optical-head cap, 0.35 m × 0.3 m × 0.15 m tall (on the dome's calibration bench, front left) | **0.025 m voxels**, origin at ground level. Built from Ryan's Environmental Standards grid (`tools/voxgen/sheets/chilled_mirror_hygrometer.txt`). |
| `portable_core_drill.glb` | Tripod core drill, 1.2 m × 1.2 m × 1.6 m tall; not placed in any scene yet | 0.1 m voxels, origin at ground level. Built from Ryan's Mining & Crystal Extraction grid (`tools/voxgen/sheets/portable_core_drill.txt`). |
| `ore_sorting_skip.glb` | Hopper skip heaped with quartz and rock, 1.4 m × 1.2 m × 1.0 m tall; not placed in any scene yet | 0.1 m voxels, origin at ground level. Built from Ryan's Mining & Crystal Extraction grid (`tools/voxgen/sheets/ore_sorting_skip.txt`). |
| `seismic_thumper.glb` | Survey thumper with a yellow hammer weight, 0.8 m × 0.8 m × 1.0 m tall; not placed in any scene yet | 0.1 m voxels, origin at ground level. Built from Ryan's Mining & Crystal Extraction grid (`tools/voxgen/sheets/seismic_thumper.txt`). |
| `crystal_ore_fissure.glb` | Active crystal fissure, 2.0 m × 2.0 m × 1.6 m tall (does not replace `ore_fissure.glb`); not placed in any scene yet | 0.2 m voxels, origin at ground level; crystals are `emit_crystals`. Built from Ryan's Mining & Crystal Extraction grid (`tools/voxgen/sheets/crystal_ore_fissure.txt`). |
| `crystal_ore_fissure_depleted.glb` | The same fissure mined out, gray stubs, 1.0 m tall; not placed in any scene yet | 0.2 m voxels, origin at ground level. Built from Ryan's Mining & Crystal Extraction grid (`tools/voxgen/sheets/crystal_ore_fissure_depleted.txt`). |
| `plateau_weather_mast.glb` | Weather mast, 1.8 m tall; not placed in any scene yet | 0.1 m voxels, origin at ground level. Built from Ryan's Outdoor Infrastructure grid (`tools/voxgen/sheets/plateau_weather_mast.txt`). |
| `gulch_culvert_bridge.glb` | Culvert bridge for the straight gulch, 2.0 m × 2.0 m × 1.2 m tall; not placed in any scene yet | 0.2 m voxels, origin at the base. Built from Ryan's Outdoor Infrastructure grid (`tools/voxgen/sheets/gulch_culvert_bridge.txt`). |
| `solar_array_skid.glb` | Tilted solar panel on a skid, 1.2 m tall; not placed in any scene yet | 0.1 m voxels, origin at ground level. Built from Ryan's Outdoor Infrastructure grid (`tools/voxgen/sheets/solar_array_skid.txt`). |

Each slot's `model_scale` sets the voxel size (0.025 m, 0.1 m, 0.2 m or 0.5 m by class), assuming 1 export unit = 1 voxel. Full spec, palettes and the `emit_*` naming rule for glowing parts: `docs/art/voxel_models.md`.

Soil tiles: `soil_untilled.glb` and `soil_tilled.glb` (0.1 m voxels, centered on the cell; built from Gemini's layer grids in `tools/voxgen/sheets/soil_*.txt`) are packed into `soil_tiles.tres`, a MeshLibrary whose item IDs match `FarmGrid.Tile` (0 = soil_untilled, 1 = soil_tilled). It is assigned to `SoilGrid.mesh_library_override`. After changing either tile, rebuild it with `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/voxgen/build_soil_library.gd`.

Rocks: each rock is a `StaticBody3D` on `collision_layer = 5` (world + signal_occluder) with a box `Shape`, so LOS keeps working whatever the `Model` slot shows. Keep that layer if you replace them.


## Upgrade visuals

Wide treads widen the greybox `Wheel*` cylinders, or swap `tractor.glb` for
`tractor_wide.glb` once both exist.
