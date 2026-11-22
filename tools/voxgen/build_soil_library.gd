extends SceneTree
## Builds assets/voxels/soil_tiles.tres, the MeshLibrary that SoilGrid uses, from
## soil_untilled.glb and soil_tilled.glb. Item IDs match FarmGrid.Tile.
##
## Run after `python tools/voxgen/build_models.py` (and after Godot has imported the
## .glb files, e.g. `--headless --import`):
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/voxgen/build_soil_library.gd

const VOXEL_M := 0.1
const OUT := "res://assets/voxels/soil_tiles.tres"
const TILES := {
	0: ["soil_untilled", "res://assets/voxels/soil_untilled.glb"],  # FarmGrid.Tile.SOIL_UNTILLED
	1: ["soil_tilled", "res://assets/voxels/soil_tilled.glb"],      # FarmGrid.Tile.SOIL_TILLED
}


func _init() -> void:
	var lib := MeshLibrary.new()
	for id: int in TILES:
		var item_name: String = TILES[id][0]
		var path: String = TILES[id][1]
		var scene := load(path) as PackedScene
		if scene == null:
			printerr("build_soil_library: can't load %s" % path)
			quit(1)
			return
		var root: Node = scene.instantiate()
		var mesh_instance := root.find_child("soil", true, false) as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			printerr("build_soil_library: %s has no 'soil' mesh" % path)
			root.free()
			quit(1)
			return
		# Copy so the library embeds the mesh instead of pointing into the import cache.
		var mesh := mesh_instance.mesh.duplicate(true) as Mesh
		root.free()
		lib.create_item(id)
		lib.set_item_name(id, item_name)
		lib.set_item_mesh(id, mesh)
		lib.set_item_mesh_transform(id, Transform3D(Basis.from_scale(Vector3.ONE * VOXEL_M), Vector3.ZERO))
	var err := ResourceSaver.save(lib, OUT)
	if err != OK:
		printerr("build_soil_library: save failed (%d)" % err)
		quit(1)
		return
	print("build_soil_library: wrote %s" % OUT)
	quit(0)
