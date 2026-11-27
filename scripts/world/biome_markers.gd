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
## The sign's collider and footprint depth (z), in metres; its width is BOARD_SIZE.x.
const SIGN_DEPTH_M: float = 0.4
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
			var half := Vector2(BiomeData.PAD_HALF_M, BiomeData.PAD_HALF_M)
			_block(at - half, at + half)
			var sign_at := Vector2(at.x + SIGN_OFFSET_M, at.y)
			var sign_half := Vector2(BOARD_SIZE.x, SIGN_DEPTH_M) * 0.5
			_block(sign_at - sign_half, sign_at + sign_half)
		_blocked_ready = true
	return _blocked.has(cell)


## Marks every cell the box [low, high) overlaps.
static func _block(low: Vector2, high: Vector2) -> void:
	var first := Vector2i(floori(low.x / Terrain.CELL_M), floori(low.y / Terrain.CELL_M))
	var last := Vector2i(floori((high.x - 0.001) / Terrain.CELL_M), floori((high.y - 0.001) / Terrain.CELL_M))
	for x: int in range(first.x, last.x + 1):
		for z: int in range(first.y, last.y + 1):
			_blocked[Vector2i(x, z)] = true


## Forget the cached cells (for tests that reload the table).
static func reset() -> void:
	_blocked.clear()
	_blocked_ready = false


func _ready() -> void:
	name = "BiomeMarkers"
	build(GameState.dug)
	# The next-step line follows what a guest also has: lab XP, the audit log, the day.
	GameState.lab_xp_changed.connect(refresh_hints)
	GameState.audit_completed.connect(_on_audit_completed)
	GameState.farm_loaded.connect(refresh_hints)
	GameClock.day_started.connect(_on_day_started)


func _on_audit_completed(_report: Dictionary) -> void:
	refresh_hints()


func _on_day_started(_day: int) -> void:
	refresh_hints()


## The hover text of a biome's sign: its line, and while the biome is closed one more
## line naming the next step (step 9). A hint only.
static func hint_for(id: StringName, lab_level: int, audits_done: int, audit_day: int) -> String:
	var next: String = BiomeData.next_step_text(id, lab_level, audits_done, audit_day)
	var line: String = BiomeData.sign_text(id)
	return line if next.is_empty() else "%s
%s" % [line, next]


## Sets every sign's hover text from the lab level, the audits done and the day.
func refresh_hints() -> void:
	var level: int = GameState.lab_level()
	var audits: int = GameState.audit_log.size()
	var audit_day: int = GameState.next_audit_day(GameClock.get_day_index())
	for id: StringName in spoke_ids():
		var post: Clickable = get_node_or_null("Sign_%s" % id) as Clickable
		if post != null:
			post.hint = hint_for(id, level, audits, audit_day)


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
		for ix: int in range(-2, 3):
			for iz: int in range(-2, 3):
				var corner := Vector2(at.x + ix, at.y + iz)
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
		post.position = Vector3(sign_at.x, Terrain.height(sign_at, dug), sign_at.y)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(BOARD_SIZE.x, POST_HEIGHT_M, SIGN_DEPTH_M)
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
	refresh_hints()
