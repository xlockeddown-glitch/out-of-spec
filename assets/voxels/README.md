# assets/voxels

MagicaVoxel exports (.gltf/.glb) land here in Week 4.

- Rover: instance the mesh under `Rover/VisualRoot`, then delete the CSG greybox children. Collision stays on `Rover/CollisionShape3D`.
- Soil tiles: build a MeshLibrary whose item IDs match `FarmGrid.Tile` (0 = soil_untilled, 1 = soil_tilled) and assign it to `SoilGrid.mesh_library_override`.
- Rocks: keep collision_layer = 5 (world + signal_occluder) on whatever replaces the CSG boxes, or LOS stops working.
