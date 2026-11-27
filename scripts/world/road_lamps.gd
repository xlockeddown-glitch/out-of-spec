class_name RoadLamps
extends Node3D
## Low lamp posts along each spoke biome's road (docs/design/biomes.md section 6,
## step 9), dark while the biome is closed and warm once it is open (BiomeData.is_open
## from the lab level and the audits done). A hint only: nothing is blocked and no
## road changes. The Basalt Ridge has no road, so its pad's corners and the way to its tunnel mouth
## carry the lamps.
## Lamps sit just outside a road's strip, off pads, signs and built things, and ride
## the ground as dug leaves it. Meshes and numbers are stand-ins [PLACEHOLDER]; no
## OmniLight, only an emissive head. Nothing is saved or sent: it reads lab_xp and
## audit_log, which a guest already has.

## Metres along a road to the first lamp, then between lamps [PLACEHOLDER].
const FIRST_M: float = 3.0
const SPACING_M: float = 12.0
## How far beside the road line a lamp stands, so its cell is clear of the strip.
const SIDE_M: float = 4.0
## A lamp keeps this far from any built thing or rock in BiomeData.spots().
const SPOT_CLEAR_M: float = 0.5
## A padless biome's lamps stand this far off the pad's middle on each axis.
const PAD_LAMP_M: float = 2.8
## The Basalt Ridge's extra lamps (step 10), along the lit way from its pad to the
## tunnel mouth: one each side of the way and one near the pad [PLACEHOLDER].
const BASALT_WAY_SPOTS: Array[Vector2] = [Vector2(25.2, -21.6), Vector2(25.2, -14.2), Vector2(26.6, -23.0)]
const POST_HEIGHT_M: float = 1.1
const HEAD_SIZE_M: float = 0.28

static var _spots: Dictionary = {}

var _lit: Dictionary[StringName, bool] = {}
var _heads: Dictionary[StringName, Array] = {}
var _posts: Array[Node3D] = []
var _unlit_material: StandardMaterial3D
var _lit_material: StandardMaterial3D


## The biomes that carry lamps: the spokes.
static func lamp_ids() -> Array[StringName]:
	return BiomeMarkers.spoke_ids()


## Where a biome's lamps stand (x, z): along its road every SPACING_M, alternating
## sides, or at its pad's corners when it has no road (the Basalt Ridge adds three
## along its way to the tunnel mouth). Spots that would sit on a road
## cell, a pad or sign cell, or a built thing are dropped. Worked out once.
static func spots(id: StringName) -> Array[Vector2]:
	if not lamp_ids().has(id):
		return []
	if not _spots.has(id):
		var found: Array[Vector2] = []
		var line: Array[Vector2] = BiomeData.road(id)
		if line.size() >= 2:
			found = _along(line)
		else:
			var at: Vector2 = BiomeData.marker(id)
			for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
				var spot: Vector2 = at + corner * PAD_LAMP_M
				if _clear(spot):
					found.append(spot)
			if id == &"basalt_ridge":
				for spot: Vector2 in BASALT_WAY_SPOTS:
					if _clear(spot):
						found.append(spot)
		_spots[id] = found
	return _spots[id]


## Forget the worked-out spots (for tests that reload the table).
static func reset() -> void:
	_spots.clear()


static func _along(line: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var walked: float = 0.0
	var next: float = FIRST_M
	var side: float = 1.0
	for i: int in range(line.size() - 1):
		var run: Vector2 = line[i + 1] - line[i]
		var length: float = run.length()
		if length <= 0.0:
			continue
		var across: Vector2 = Vector2(-run.y, run.x) / length
		while next <= walked + length:
			var on_line: Vector2 = line[i] + run * ((next - walked) / length)
			var placed: bool = false
			for trial: float in [side, -side]:
				var spot: Vector2 = on_line + across * SIDE_M * trial
				if _clear(spot):
					out.append(spot)
					placed = true
					break
			if placed:
				side = -side
			next += SPACING_M
		walked += length
	return out


## Whether a lamp may stand at `at`: on land, off every road cell, pad and sign cell,
## and clear of the built things and rocks.
static func _clear(at: Vector2) -> bool:
	if absf(at.x) > Terrain.HALF_M - 1.0 or absf(at.y) > Terrain.HALF_M - 1.0:
		return false
	if absf(at.x) < BiomeData.PLOT_HALF_M and absf(at.y) < BiomeData.PLOT_HALF_M:
		return false
	var cell := Vector2i(floori(at.x / Terrain.CELL_M), floori(at.y / Terrain.CELL_M))
	if BiomeData.on_road(at) or BiomeData.is_road_cell(cell) or BiomeMarkers.is_blocked_cell(cell):
		return false
	for box: Vector4 in BiomeData.spots():
		if absf(at.x - box.x) < box.z + SPOT_CLEAR_M and absf(at.y - box.y) < box.w + SPOT_CLEAR_M:
			return false
	return true


func _ready() -> void:
	name = "RoadLamps"
	build(GameState.dug)
	GameState.lab_xp_changed.connect(refresh)
	GameState.audit_completed.connect(_on_audit_completed)
	GameState.farm_loaded.connect(refresh)
	GameState.terrain_changed.connect(_on_terrain_changed)


func _on_audit_completed(_report: Dictionary) -> void:
	refresh()


func _on_terrain_changed() -> void:
	settle(GameState.dug)


## Puts the posts in on the ground as `dug` leaves it, lit or dark as the game says.
func build(dug: Dictionary[Vector2i, int]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_posts.clear()
	_heads.clear()
	_lit.clear()
	if _unlit_material == null:
		_unlit_material = StandardMaterial3D.new()
		_unlit_material.albedo_color = Color(0.16, 0.16, 0.18)
		_lit_material = StandardMaterial3D.new()
		_lit_material.albedo_color = Color(1.0, 0.82, 0.5)
		_lit_material.emission_enabled = true
		_lit_material.emission = Color(1.0, 0.7, 0.3)
		_lit_material.emission_energy_multiplier = 2.5
	var pole_material := StandardMaterial3D.new()
	pole_material.albedo_color = Color(0.3, 0.3, 0.33)
	for id: StringName in lamp_ids():
		var heads: Array = []
		var index: int = 0
		for at: Vector2 in spots(id):
			var post := Node3D.new()
			post.name = "Lamp_%s_%d" % [id, index]
			post.position = Vector3(at.x, Terrain.height(at, dug), at.y)
			var pole := MeshInstance3D.new()
			var pole_mesh := CylinderMesh.new()
			pole_mesh.top_radius = 0.04
			pole_mesh.bottom_radius = 0.05
			pole_mesh.height = POST_HEIGHT_M
			pole_mesh.material = pole_material
			pole.mesh = pole_mesh
			pole.position = Vector3(0.0, POST_HEIGHT_M * 0.5, 0.0)
			post.add_child(pole)
			var head := MeshInstance3D.new()
			head.name = "Head"
			var head_mesh := BoxMesh.new()
			head_mesh.size = Vector3(HEAD_SIZE_M, HEAD_SIZE_M, HEAD_SIZE_M)
			head.mesh = head_mesh
			head.position = Vector3(0.0, POST_HEIGHT_M + HEAD_SIZE_M * 0.5, 0.0)
			post.add_child(head)
			add_child(post)
			_posts.append(post)
			heads.append(head)
			index += 1
		_heads[id] = heads
	refresh()


## Lights the lamps of every open biome and darkens the rest.
func refresh() -> void:
	var level: int = GameState.lab_level()
	var audits: int = GameState.audit_log.size()
	for id: StringName in lamp_ids():
		var open: bool = BiomeData.is_open(id, level, audits)
		_lit[id] = open
		for head: MeshInstance3D in _heads.get(id, []) as Array:
			head.material_override = _lit_material if open else _unlit_material


## Whether a biome's lamps are lit right now.
func is_lit(id: StringName) -> bool:
	return _lit.get(id, false)


## How many lamps a biome has.
func lamp_count(id: StringName) -> int:
	return (_heads.get(id, []) as Array).size()


## Re-seats every post on the ground as `dug` leaves it.
func settle(dug: Dictionary[Vector2i, int]) -> void:
	for post: Node3D in _posts:
		post.position.y = Terrain.height(Vector2(post.position.x, post.position.z), dug)
