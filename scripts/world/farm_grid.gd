class_name FarmGrid
extends GridMap
## Soil plot on a GridMap. Single layer at cell y = 0.
##
## Week 1 builds a greybox MeshLibrary in code. Week 4: export the MagicaVoxel
## tiles to a MeshLibrary with the SAME item IDs as `Tile` and assign it to
## `mesh_library_override` (or straight to `mesh_library`); no code changes.
##
## Tilled cells live in GameState.tilled_cells, changed only with
## GameState.till(), so they survive farm <-> dome scene swaps. The grid shows
## them, whoever tilled them.

signal tile_changed(cell: Vector3i, tile: int)

## CROP_* are tilled cells with a crop (GameState.plantings) growing or ready.
enum Tile { SOIL_UNTILLED = 0, SOIL_TILLED = 1 }
enum TillResult { TILLED, ALREADY_TILLED, NOT_SOIL }

@export var plot_origin_cell: Vector2i = Vector2i(-6, -6)
@export var plot_size_cells: Vector2i = Vector2i(12, 12)
@export var mesh_library_override: MeshLibrary

const CROP_STAGE_MODEL := "res://assets/voxels/crop_stage_%d.glb"
const CROP_WILTED_MODEL := "res://assets/voxels/crop_stage_wilted.glb"
## Crop models use 0.1 m voxels.
const CROP_VOXEL_M := 0.1

var _crop_models: Dictionary[Vector3i, Node3D] = {}


func _ready() -> void:
	if mesh_library_override:
		mesh_library = mesh_library_override
	elif mesh_library == null:
		mesh_library = _build_greybox_library()
	_fill_plot()
	GameState.crops_changed.connect(refresh_crops)
	GameState.soil_tilled.connect(_on_soil_tilled)


func world_to_cell(world_pos: Vector3) -> Vector3i:
	var cell: Vector3i = local_to_map(to_local(world_pos))
	cell.y = 0
	return cell


func till_cell(cell: Vector3i) -> TillResult:
	match get_cell_item(cell):
		Tile.SOIL_UNTILLED:
			if not GameState.till(cell):
				_on_soil_tilled(cell)  # already recorded, not shown yet
			return TillResult.TILLED
		Tile.SOIL_TILLED:
			return TillResult.ALREADY_TILLED
		_:
			return TillResult.NOT_SOIL


func _on_soil_tilled(cell: Vector3i) -> void:
	if get_cell_item(cell) == Tile.SOIL_UNTILLED:
		set_cell_item(cell, Tile.SOIL_TILLED)
		tile_changed.emit(cell, Tile.SOIL_TILLED)


func _fill_plot() -> void:
	for x: int in plot_size_cells.x:
		for z: int in plot_size_cells.y:
			var cell := Vector3i(plot_origin_cell.x + x, 0, plot_origin_cell.y + z)
			if get_cell_item(cell) == INVALID_CELL_ITEM:
				set_cell_item(cell, Tile.SOIL_UNTILLED)
	for tilled: Variant in GameState.tilled_cells:
		set_cell_item(tilled as Vector3i, Tile.SOIL_TILLED)
	refresh_crops()


## Places a crop model on each planted cell: growth stages 0 to 2 while it
## grows, stage 3 when ready, and the wilted model once its soil has left the
## moisture band (the harvest will be off spec).
func refresh_crops() -> void:
	for cell: Vector3i in _crop_models.keys():
		if not GameState.plantings.has(cell):
			_crop_models[cell].queue_free()
			_crop_models.erase(cell)
	for key: Variant in GameState.plantings:
		var cell: Vector3i = key
		var path: String = _crop_model_path(cell)
		var shown: Node3D = _crop_models.get(cell, null)
		if shown != null and shown.get_meta(&"model_path", "") == path:
			continue
		if shown != null:
			shown.queue_free()
		var model: Node3D = _make_crop_model(path)
		model.set_meta(&"model_path", path)
		model.position = map_to_local(cell) + Vector3(0.0, cell_size.y * 0.5, 0.0)
		add_child(model)
		_crop_models[cell] = model


func _crop_model_path(cell: Vector3i) -> String:
	var planting: Dictionary = GameState.plantings[cell]
	if int(planting["out_of_band_days"]) > 0 or planting.get("out_today", false):
		return CROP_WILTED_MODEL
	if GameState.is_crop_ready(cell):
		return CROP_STAGE_MODEL % 3
	var growth_days: int = maxi(1, int(GameState.crop(planting["crop_id"]).get("growth_days", 1)))
	return CROP_STAGE_MODEL % clampi(floori(float(int(planting["days_grown"]) * 3) / float(growth_days)), 0, 2)


## The voxel model at `path`, or a small green box if it can't load.
func _make_crop_model(path: String) -> Node3D:
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene != null:
		var instance: Node3D = scene.instantiate() as Node3D
		if instance != null:
			instance.scale = Vector3.ONE * CROP_VOXEL_M
			return instance
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(cell_size.x * 0.4, 0.4, cell_size.z * 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.55, 0.22)
	mesh.material = mat
	box.mesh = mesh
	box.position.y = 0.2
	var holder := Node3D.new()
	holder.add_child(box)
	return holder


func _build_greybox_library() -> MeshLibrary:
	var lib := MeshLibrary.new()
	_add_box_item(lib, Tile.SOIL_UNTILLED, "soil_untilled", Color(0.47, 0.35, 0.24))
	_add_box_item(lib, Tile.SOIL_TILLED, "soil_tilled", Color(0.24, 0.16, 0.10))
	return lib


func _add_box_item(lib: MeshLibrary, id: int, item_name: String, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(cell_size.x * 0.94, cell_size.y, cell_size.z * 0.94)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mesh.material = mat
	lib.create_item(id)
	lib.set_item_name(id, item_name)
	lib.set_item_mesh(id, mesh)
