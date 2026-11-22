# assets/voxels

First-pass models are generated: run `python tools/voxgen/build_models.py`, which writes the `.glb` files here and editable MagicaVoxel sources in `source/`. Hand-refined exports (.glb preferred, or .gltf) replace them under the same names. Use these exact file names and they swap in automatically. Each greybox sits under a `ModelSlot` (or checks the path itself), so no scene or code edits are needed.

| File | Replaces | Notes |
|---|---|---|
| `tractor.glb` | Rover greybox (`Rover/VisualRoot`) | Origin at ground level, center of the wheelbase, front facing −Z. Collision stays on `Rover/CollisionShape3D`. |
| `bram_bay.glb` | Bram and his scrapyard bay (`BramBay/Visual`) | Open side faces +Z. The trade zone is the 5 m × 5 m `BramBay/Shape`. |
| `tractor_wide.glb` | Tractor after Bram's wide treads | Same origin as `tractor.glb`; swapped in when the treads are bought. |
| `ore_fissure.glb` | Crystal ore fissure greybox (`OreFissure`) | 1.6 m across; hidden while mined. |
| `terrarium.glb` | Tank, substrate, hygrometer pod, lamp hood (`Terrarium/TankModel`) | Leave the hygrometer LED out; the game drives it. |
| `curlyhair.glb` | Spider greybox (`Terrarium/Tarantula/SpiderModel`) | Center origin. Separate so molt visuals can be added. |
| `drop_pod.glb` | Pod hull, nose, hatch (`DropPod/PodModel`) | |
| `aud1t.glb` | AUD-1T drone (`DropPod/AUD1T/DroneModel`) | Center origin. The game bobs it. |
| `relay_mast.glb` | Mast and dish (`SatelliteRelay/MastModel`) | Model the spool bay empty; the spool is game-driven. |
| `boulder_a.glb` … `boulder_d.glb` | Farm boulders (`Rocks/Rock<A–D>/Model`) | 0.2 m voxels, origin at ground level. Each fills its rock's box collider. Built from Gemini's layer grids (`tools/voxgen/sheets/boulder_a.txt` … `boulder_d.txt`). |

Each slot's `model_scale` sets the voxel size (0.1 m, 0.2 m or 0.5 m by class), assuming 1 export unit = 1 voxel. Full spec, palettes and the `emit_*` naming rule for glowing parts: `docs/art/voxel_models.md`.

Soil tiles: `soil_untilled.glb` and `soil_tilled.glb` (0.1 m voxels, centered on the cell; sampled from Gemini's concepts into `tools/voxgen/sheets/soil_*.txt`) are packed into `soil_tiles.tres`, a MeshLibrary whose item IDs match `FarmGrid.Tile` (0 = soil_untilled, 1 = soil_tilled). It is assigned to `SoilGrid.mesh_library_override`. After changing either tile, rebuild it with `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/voxgen/build_soil_library.gd`.

Rocks: each rock is a `StaticBody3D` on `collision_layer = 5` (world + signal_occluder) with a box `Shape`, so LOS keeps working whatever the `Model` slot shows. Keep that layer if you replace them.


## Upgrade visuals

Wide treads widen the greybox `Wheel*` cylinders, or swap `tractor.glb` for
`tractor_wide.glb` once both exist.
