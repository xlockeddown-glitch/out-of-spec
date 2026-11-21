class_name FarmGrid
extends GridMap
## Soil plot on a GridMap. Single layer at cell y = 0.
##
## Week 1 builds a greybox MeshLibrary in code. Week 4: export the MagicaVoxel
## tiles to a MeshLibrary with the SAME item IDs as `Tile` and assign it to
## `mesh_library_override` (or straight to `mesh_library`); no code changes.

signal tile_changed(cell: Vector3i, tile: int)

enum Tile { SOIL_UNTILLED = 0, SOIL_TILLED = 1 }
enum TillResult { TILLED, ALREADY_TILLED, NOT_SOIL }

@export var plot_origin_cell: Vector2i = Vector2i(-6, -6)
@export var plot_size_cells: Vector2i = Vector2i(12, 12)
@export var mesh_library_override: MeshLibrary


func _ready() -> void:
	if mesh_library_override:
		mesh_library = mesh_library_override
	elif mesh_library == null:
		mesh_library = _build_greybox_library()
	_fill_plot()


func world_to_cell(world_pos: Vector3) -> Vector3i:
	var cell: Vector3i = local_to_map(to_local(world_pos))
	cell.y = 0
	return cell


func till_cell(cell: Vector3i) -> TillResult:
	match get_cell_item(cell):
		Tile.SOIL_UNTILLED:
			set_cell_item(cell, Tile.SOIL_TILLED)
			tile_changed.emit(cell, Tile.SOIL_TILLED)
			return TillResult.TILLED
		Tile.SOIL_TILLED:
			return TillResult.ALREADY_TILLED
		_:
			return TillResult.NOT_SOIL


func _fill_plot() -> void:
	for x: int in plot_size_cells.x:
		for z: int in plot_size_cells.y:
			var cell := Vector3i(plot_origin_cell.x + x, 0, plot_origin_cell.y + z)
			if get_cell_item(cell) == INVALID_CELL_ITEM:
				set_cell_item(cell, Tile.SOIL_UNTILLED)


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
