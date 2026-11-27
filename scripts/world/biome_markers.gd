class_name BiomeMarkers
extends Node3D
## One sign and one rover pad at each spoke biome's marker (docs/design/biomes.md
## section 6, step 6), built from data/biomes.json when the farm scene loads. The
## sign's hover hint is the biome's sign line; clicking it does nothing. The pad
## is a pale 4 by 4 m slab on the ground, a place to leave a rover [PLACEHOLDER]:
## it has no recall, no teleport and nothing saved or sent. Land under a pad and
## its sign can not be dug (is_blocked_cell). The meshes are simple stand-ins
## [PLACEHOLDER], not art.

## The sign stands just off the pad's +x edge: its middle this far from the pad's.
const SIGN_OFFSET_M: float = BiomeData.PAD_HALF_M + 0.7
## The cells under the pad and the sign can not be dug: x from the pad's -x edge to
## this far past the middle, z the pad's width.
const BLOCK_X_MAX_M: float = BiomeData.PAD_HALF_M + 1.4
## The slab's thickness and how far its top rides above the highest ground under it.
const SLAB_THICKNESS_M: float = 0.3
const SLAB_LIFT_M: float = 0.03
const POST_HEIGHT_M: float = 1.8
const BOARD_SIZE := Vector3(1.5, 0.7, 0.08)
const BLOCKED_TEXT: String = "Keep the pad and its sign clear."

static var _blocked: Dictionary[Vector2i, bool] = {}
static var _blocked_ready: bool = false


## The biomes that get a sign and a pad: every one with a marker but the farm hub.
static func spoke_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in BiomeData.ids():
		if id != BiomeData.FARM:
			out.append(id)
	return out


## Whether a cell lies under a pad or its sign, so it can not be dug. Not part
## of Terrain.can_dig, which ore pockets and old-save hashes read.
static func is_blocked_cell(cell: Vector2i) -> bool:
	if not _blocked_ready:
		_blocked.clear()
		for id: StringName in spoke_ids():
			var at: Vector2 = BiomeData.marker(id)
			var low := Vector2i(floori((at.x - BiomeData.PAD_HALF_M) / Terrain.CELL_M), floori((at.y - BiomeData.PAD_HALF_M) / Terrain.CELL_M))
			var high := Vector2i(floori((at.x + BLOCK_X_MAX_M - 0.001) / Terrain.CELL_M), floori((at.y + BiomeData.PAD_HALF_M - 0.001) / Terrain.CELL_M))
			for x: int in range(low.x, high.x + 1):
				for z: int in range(low.y, high.y + 1):
					_blocked[Vector2i(x, z)] = true
		_blocked_ready = true
	return _blocked.has(cell)


## Forget the cached cells (for tests that reload the table).
static func reset() -> void:
	_blocked.clear()
	_blocked_ready = false


func _ready() -> void:
	name = "BiomeMarkers"
	build(GameState.dug)


## Puts a "Pad_<id>" slab and a "Sign_<id>" post in for each spoke biome, on the
## ground as `dug` leaves it. Clears any earlier ones first.
func build(dug: Dictionary[Vector2i, int]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var slab_material := StandardMaterial3D.new()
	slab_material.albedo_color = Color(0.82, 0.8, 0.74)
	slab_material.roughness = 0.9
	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = Color(0.35, 0.27, 0.2)
	var board_material := StandardMaterial3D.new()
	board_material.albedo_color = Color(0.9, 0.85, 0.6)
	for id: StringName in spoke_ids():
		var at: Vector2 = BiomeData.marker(id)
		var top: float = -INF
		for ix: int in 3:
			for iz: int in 3:
				var corner := Vector2(at.x + (ix - 1) * BiomeData.PAD_HALF_M, at.y + (iz - 1) * BiomeData.PAD_HALF_M)
				top = maxf(top, Terrain.height(corner, dug))
		top += SLAB_LIFT_M
		var slab := MeshInstance3D.new()
		slab.name = "Pad_%s" % id
		var slab_mesh := BoxMesh.new()
		slab_mesh.size = Vector3(BiomeData.PAD_HALF_M * 2.0, SLAB_THICKNESS_M, BiomeData.PAD_HALF_M * 2.0)
		slab_mesh.material = slab_material
		slab.mesh = slab_mesh
		slab.position = Vector3(at.x, top - SLAB_THICKNESS_M * 0.5, at.y)
		add_child(slab)
		var sign_at := Vector2(at.x + SIGN_OFFSET_M, at.y)
		var post := Clickable.new()
		post.name = "Sign_%s" % id
		post.collision_layer = 8
		post.collision_mask = 0
		post.hint = BiomeData.sign_text(id)
		post.position = Vector3(sign_at.x, Terrain.height(sign_at, dug), sign_at.y)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(BOARD_SIZE.x, POST_HEIGHT_M, 0.4)
		shape.shape = box
		shape.position = Vector3(0.0, POST_HEIGHT_M * 0.5, 0.0)
		post.add_child(shape)
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.06
		pole_mesh.bottom_radius = 0.06
		pole_mesh.height = POST_HEIGHT_M
		pole_mesh.material = post_material
		pole.mesh = pole_mesh
		pole.position = Vector3(0.0, POST_HEIGHT_M * 0.5, 0.0)
		post.add_child(pole)
		var board := MeshInstance3D.new()
		var board_mesh := BoxMesh.new()
		board_mesh.size = BOARD_SIZE
		board_mesh.material = board_material
		board.mesh = board_mesh
		board.position = Vector3(0.0, POST_HEIGHT_M - BOARD_SIZE.y * 0.5, 0.0)
		post.add_child(board)
		add_child(post)
