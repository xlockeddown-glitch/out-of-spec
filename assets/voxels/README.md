# assets/voxels

MagicaVoxel exports (.glb preferred, or .gltf) go here. Use these exact file names and they swap in automatically. Each greybox sits under a `ModelSlot` (or checks the path itself), so no scene or code edits are needed.

| File | Replaces | Notes |
|---|---|---|
| `tractor.glb` | Rover greybox (`Rover/VisualRoot`) | Origin at ground level, center of the wheelbase, front facing −Z. Collision stays on `Rover/CollisionShape3D`. |
| `bram_bay.glb` | Bram and his scrapyard bay (`BramBay/Visual`) | Open side faces +Z. The trade zone is the 5 m × 5 m `BramBay/Shape`. |
| `ore_fissure.glb` | Crystal ore fissure greybox (`OreFissure`) | About 1 m across; hidden while mined. |

Still greybox in scene files (slots to add when the models exist): terrarium tank, drop-pod and AUD-1T, relay mast. Wrap the greybox nodes in a `ModelSlot` (`scripts/world/model_slot.gd`) and set `model_path`.

Soil tiles: build a MeshLibrary whose item IDs match `FarmGrid.Tile` (0 = soil_untilled, 1 = soil_tilled) and assign it to `SoilGrid.mesh_library_override`.

Rocks: keep `collision_layer = 5` (world + signal_occluder) on whatever replaces the CSG boxes, or LOS stops working.

Scale: 1 voxel = 0.1 m reads well with the current camera (the greybox rover is 1.4 m × 2.4 m).

## Upgrade visuals

Wide treads currently widen the greybox `Wheel*` cylinders. Once `tractor.glb`
replaces the greybox, those cylinders are hidden, so the upgrade has no visual
until a `tractor_wide.glb` variant (or separate wheel meshes) is added.
