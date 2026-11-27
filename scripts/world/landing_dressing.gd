class_name LandingDressing
extends Node3D
## The shuttle pad and its terminal at the Landing Field (docs/design/biomes.md
## section 6, step 12): a flat concrete slab with edge lights, a small gantry at
## one side and a terminal post with a screen beside it. Scene dressing built the
## same on every machine from the constants below: nothing saved, nothing sent.
## The edge lights are emissive heads (no OmniLight), dark until the Landing
## Field is open (BiomeData.is_open, as RoadLamps) and warm after. There is no
## collision: a rover drives over the slab as over the biome pads, and the gantry
## and terminal are small and stand on ground that follows the digging. The
## terminal is clickable (a Clickable, layer 8, which blocks nothing); the panel
## is ShuttleUI. Every number is a stand-in [PLACEHOLDER].

const BIOME: StringName = &"landing_field"
## The slab's middle and its half-width (an 8 by 8 m slab), south of the biome's
## rover pad and its sign.
const SLAB_AT := Vector2(0.0, 106.0)
const SLAB_HALF_M: float = 4.0
const SLAB_THICKNESS_M: float = 0.6
const SLAB_LIFT_M: float = 0.03
## The terminal: its middle, and the box it fills (x, z half-widths).
const TERMINAL_AT := Vector2(7.5, 100.0)
const TERMINAL_HALF := Vector2(0.45, 0.35)
const TERMINAL_HEIGHT_M: float = 1.5
## The edge lights: one at each corner and one in the middle of each edge, a
## little in from the edge.
const LIGHT_INSET_M: float = 0.35
const LIGHT_SIZE_M: float = 0.3
## The gantry: two posts and a beam on the slab's south side, just off the slab.
const GANTRY_Z_M: float = 111.0
const GANTRY_X_M: float = 3.0
const GANTRY_POST_M: float = 0.4
const GANTRY_HEIGHT_M: float = 5.0
const GANTRY_BEAM_M: float = 0.35
## A built thing keeps this far (plus its own half-width) from a built thing, a
## rock or a fissure, and from a lamp.
const SPOT_CLEAR_M: float = 1.0
const LAMP_CLEAR_M: float = 1.0
## How near a player must stand to the terminal to use it, in metres [PLACEHOLDER].
## A guest's pose lags a little, so the host allows HOST_SLACK_M more.
const REACH_M: float = 5.0
const HOST_SLACK_M: float = 1.5
const HINT: String = "Shuttle terminal: launch windows and day trips"

static var _plants: Array[HillDressing.Placed] = []
static var _plants_ready: bool = false

var terminal_click: Clickable
var _lights: Array[MeshInstance3D] = []
var _heads: Array[Node3D] = []
var _slab: MeshInstance3D
var _gantry: Node3D
var _terminal: Node3D
var _lit: bool = false
var _unlit_material: StandardMaterial3D
var _lit_material: StandardMaterial3D


## Forget the worked-out plants (for tests that reload the table).
static func reset() -> void:
	_plants_ready = false


## The natural hill plants, cached.
static func plants() -> Array[HillDressing.Placed]:
	if not _plants_ready:
		_plants = HillDressing.plants()
		_plants_ready = true
	return _plants


## The slab's footprint as a Rect2 (x, z).
static func slab_rect() -> Rect2:
	return Rect2(SLAB_AT - Vector2.ONE * SLAB_HALF_M, Vector2.ONE * SLAB_HALF_M * 2.0)


## Every part's footprint as { name: Vector4(x, z, half x, half z) }: the slab, each
## gantry post and the terminal. The beam is above the slab's edge, over the posts.
static func parts() -> Dictionary[String, Vector4]:
	var out: Dictionary[String, Vector4] = {}
	out["slab"] = Vector4(SLAB_AT.x, SLAB_AT.y, SLAB_HALF_M, SLAB_HALF_M)
	out["gantry_west"] = Vector4(-GANTRY_X_M, GANTRY_Z_M, GANTRY_POST_M * 0.5, GANTRY_POST_M * 0.5)
	out["gantry_east"] = Vector4(GANTRY_X_M, GANTRY_Z_M, GANTRY_POST_M * 0.5, GANTRY_POST_M * 0.5)
	out["terminal"] = Vector4(TERMINAL_AT.x, TERMINAL_AT.y, TERMINAL_HALF.x, TERMINAL_HALF.y)
	return out


## Where the pad's edge lights stand (x, z).
static func light_spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var edge: float = SLAB_HALF_M - LIGHT_INSET_M
	for step: Vector2 in [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0)]:
		out.append(SLAB_AT + step * edge)
	return out


## Whether a part (x, z, half x, half z) may stand: inside the Landing Field and on
## the land, off the plot, roads, pads and signs, built things, rocks, plants, the
## biome's lamps and the ways in.
static func clear(part: Vector4) -> bool:
	var at := Vector2(part.x, part.y)
	var half := Vector2(part.z, part.w)
	for corner: Vector2 in [at - half, at + half, Vector2(at.x - half.x, at.y + half.y), Vector2(at.x + half.x, at.y - half.y)]:
		if absf(corner.x) > Terrain.HALF_M - 2.0 or absf(corner.y) > Terrain.HALF_M - 2.0:
			return false
		if BiomeData.biome_at(corner) != BIOME or corner.distance_to(BiomeData.centre(BIOME)) > BiomeData.reach(BIOME):
			return false
	var reach: float = maxf(half.x, half.y)
	if BiomeData.road_gap(at) <= BiomeData.ROAD_HALF_M + reach:
		return false
	var first: Vector2i = Terrain.cell_at(at - half)
	var last: Vector2i = Terrain.cell_at(at + half)
	for x: int in range(first.x, last.x + 1):
		for z: int in range(first.y, last.y + 1):
			if BiomeData.is_road_cell(Vector2i(x, z)) or BiomeMarkers.is_blocked_cell(Vector2i(x, z)):
				return false
	if absf(at.x) < BiomeData.PLOT_HALF_M + half.x and absf(at.y) < BiomeData.PLOT_HALF_M + half.y:
		return false
	for box: Vector4 in BiomeData.spots():
		if absf(at.x - box.x) < box.z + half.x + SPOT_CLEAR_M and absf(at.y - box.y) < box.w + half.y + SPOT_CLEAR_M:
			return false
	for id: StringName in BiomeData.ids():
		for zone: StringName in BiomeData.zones(id):
			var way: Variant = BiomeData.entrance_at(id, zone)
			if way is Vector2 and absf(at.x - (way as Vector2).x) < 4.0 + half.x and absf(at.y - (way as Vector2).y) < 4.0 + half.y:
				return false
	for plant: HillDressing.Placed in plants():
		if absf(at.x - plant.at.x) < plant.half_m() + half.x and absf(at.y - plant.at.z) < plant.half_m() + half.y:
			return false
	for lamp: Vector2 in RoadLamps.spots(BIOME):
		if absf(at.x - lamp.x) < half.x + LAMP_CLEAR_M and absf(at.y - lamp.y) < half.y + LAMP_CLEAR_M:
			return false
	return true


## Whether the parts keep off each other: no two footprints overlap.
static func parts_apart() -> bool:
	var found: Dictionary[String, Vector4] = parts()
	var names: Array = found.keys()
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var a: Vector4 = found[names[i]]
			var b: Vector4 = found[names[j]]
			if absf(a.x - b.x) < a.z + b.z and absf(a.y - b.y) < a.w + b.w:
				return false
	return true


## True if a player at `where` (the farm's x, y, z; null when unknown) is near enough
## to the terminal.
## `slack` is what the host allows beyond REACH_M for a late pose.
static func terminal_near(where: Variant, slack: float = 0.0) -> bool:
	if not where is Vector3:
		return false
	var at: Vector3 = where
	return Vector2(TERMINAL_AT.x - at.x, TERMINAL_AT.y - at.z).length() <= REACH_M + slack


func _ready() -> void:
	name = "LandingDressing"
	build(GameState.dug)
	cover(GameState.stone_pieces)
	GameState.lab_xp_changed.connect(refresh)
	GameState.audit_completed.connect(_on_audit_completed)
	GameState.farm_loaded.connect(refresh)
	GameState.terrain_changed.connect(_on_terrain_changed)
	GameState.stone_changed.connect(_on_stone_changed)


func _on_audit_completed(_report: Dictionary) -> void:
	refresh()


func _on_terrain_changed() -> void:
	settle(GameState.dug)


func _on_stone_changed() -> void:
	cover(GameState.stone_pieces)


## Whether stone covers any cell under a part's footprint.
static func covered_by(part: Vector4, pieces: Dictionary[Vector2i, int]) -> bool:
	var first: Vector2i = Terrain.cell_at(Vector2(part.x - part.z, part.y - part.w))
	var last: Vector2i = Terrain.cell_at(Vector2(part.x + part.z, part.y + part.w))
	for x: int in range(first.x, last.x + 1):
		for z: int in range(first.y, last.y + 1):
			if pieces.has(Vector2i(x, z)):
				return true
	return false


## Hides the slab (and its lights), a gantry or the terminal while a stone piece
## covers its footprint.
func cover(pieces: Dictionary[Vector2i, int]) -> void:
	var found: Dictionary[String, Vector4] = parts()
	var slab_hidden: bool = covered_by(found["slab"], pieces)
	_slab.visible = not slab_hidden
	for head: MeshInstance3D in _lights:
		head.visible = not slab_hidden
	_gantry.visible = not (covered_by(found["gantry_west"], pieces) or covered_by(found["gantry_east"], pieces))
	_terminal.visible = not covered_by(found["terminal"], pieces)


## Which of the slab, the gantry and the terminal are showing.
func shown() -> Dictionary[String, bool]:
	return {"slab": _slab.visible, "gantry": _gantry.visible, "terminal": _terminal.visible}


## The highest ground under a footprint (x, z, half x, half z), over its corners,
## edge middles and middle, so a slab on it has no corner buried.
static func highest_under(part: Vector4, dug: Dictionary[Vector2i, int]) -> float:
	var high: float = -INF
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			high = maxf(high, Terrain.height(Vector2(part.x + float(x) * part.z, part.y + float(z) * part.w), dug))
	return high


## The lowest ground under a footprint, so a post there has no foot in the air.
static func lowest_under(part: Vector4, dug: Dictionary[Vector2i, int]) -> float:
	return HillDressing.lowest_under(Vector2(part.x, part.y), Vector2(part.z, part.w), dug)


## Where the slab's top is: the highest ground under it, a little lifted.
static func slab_top(dug: Dictionary[Vector2i, int]) -> float:
	return highest_under(parts()["slab"], dug) + SLAB_LIFT_M


## Puts the pad, the gantry and the terminal in on the ground as `dug` leaves it.
func build(dug: Dictionary[Vector2i, int]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_lights.clear()
	_heads.clear()
	terminal_click = null
	if _unlit_material == null:
		_unlit_material = StandardMaterial3D.new()
		_unlit_material.albedo_color = Color(0.16, 0.16, 0.18)
		_lit_material = StandardMaterial3D.new()
		_lit_material.albedo_color = Color(1.0, 0.82, 0.5)
		_lit_material.emission_enabled = true
		_lit_material.emission = Color(1.0, 0.7, 0.3)
		_lit_material.emission_energy_multiplier = 2.5
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.62, 0.62, 0.6)
	concrete.roughness = 0.95
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.36, 0.38, 0.42)
	steel.roughness = 0.6
	var screen_material := StandardMaterial3D.new()
	screen_material.albedo_color = Color(0.1, 0.4, 0.38)
	screen_material.emission_enabled = true
	screen_material.emission = Color(0.22, 0.88, 0.78)
	screen_material.emission_energy_multiplier = 0.6
	var found: Dictionary[String, Vector4] = parts()
	# The slab: flat, its top over the highest ground under it.
	_slab = MeshInstance3D.new()
	_slab.name = "Slab"
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(SLAB_HALF_M * 2.0, SLAB_THICKNESS_M, SLAB_HALF_M * 2.0)
	slab_mesh.material = concrete
	_slab.mesh = slab_mesh
	add_child(_slab)
	# The edge lights: small posts' heads, riding on the slab's top.
	var index: int = 0
	for at: Vector2 in light_spots():
		var head := MeshInstance3D.new()
		head.name = "EdgeLight_%d" % index
		var head_mesh := BoxMesh.new()
		head_mesh.size = Vector3(LIGHT_SIZE_M, LIGHT_SIZE_M * 0.6, LIGHT_SIZE_M)
		head.mesh = head_mesh
		head.position = Vector3(at.x, 0.0, at.y)
		add_child(head)
		_lights.append(head)
		index += 1
	# The gantry: two posts and a beam across them.
	_gantry = Node3D.new()
	_gantry.name = "Gantry"
	for key: String in ["gantry_west", "gantry_east"]:
		var post := MeshInstance3D.new()
		post.name = "Post_" + key.trim_prefix("gantry_")
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(GANTRY_POST_M, GANTRY_HEIGHT_M, GANTRY_POST_M)
		post_mesh.material = steel
		post.mesh = post_mesh
		post.position = Vector3(found[key].x, GANTRY_HEIGHT_M * 0.5, found[key].y)
		_gantry.add_child(post)
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(GANTRY_X_M * 2.0 + GANTRY_POST_M, GANTRY_BEAM_M, GANTRY_POST_M)
	beam_mesh.material = steel
	beam.mesh = beam_mesh
	beam.position = Vector3(0.0, GANTRY_HEIGHT_M - GANTRY_BEAM_M * 0.5, GANTRY_Z_M)
	_gantry.add_child(beam)
	add_child(_gantry)
	# The terminal: a post, a screen on its north face and a clickable box.
	_terminal = Node3D.new()
	_terminal.name = "Terminal"
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(TERMINAL_HALF.x * 2.0, TERMINAL_HEIGHT_M, TERMINAL_HALF.y * 2.0)
	post_mesh.material = steel
	post.mesh = post_mesh
	post.position = Vector3(0.0, TERMINAL_HEIGHT_M * 0.5, 0.0)
	_terminal.add_child(post)
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(TERMINAL_HALF.x * 2.0 - 0.1, 0.55, 0.05)
	screen_mesh.material = screen_material
	screen.mesh = screen_mesh
	screen.position = Vector3(0.0, TERMINAL_HEIGHT_M - 0.4, -TERMINAL_HALF.y - 0.02)
	screen.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	_terminal.add_child(screen)
	terminal_click = Clickable.new()
	terminal_click.name = "TerminalClick"
	terminal_click.collision_layer = 8
	terminal_click.collision_mask = 0
	terminal_click.hint = HINT
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TERMINAL_HALF.x * 2.0 + 0.3, TERMINAL_HEIGHT_M, TERMINAL_HALF.y * 2.0 + 0.3)
	shape.shape = box
	shape.position = Vector3(0.0, TERMINAL_HEIGHT_M * 0.5, 0.0)
	terminal_click.add_child(shape)
	_terminal.add_child(terminal_click)
	_terminal.position = Vector3(TERMINAL_AT.x, 0.0, TERMINAL_AT.y)
	add_child(_terminal)
	settle(dug)
	refresh()


## Re-seats everything on the ground as `dug` leaves it.
func settle(dug: Dictionary[Vector2i, int]) -> void:
	var found: Dictionary[String, Vector4] = parts()
	var top: float = slab_top(dug)
	_slab.position = Vector3(SLAB_AT.x, top - SLAB_THICKNESS_M * 0.5, SLAB_AT.y)
	for head: MeshInstance3D in _lights:
		head.position.y = top + LIGHT_SIZE_M * 0.3
	# A post stands on the lowest ground under it and its top is the set height
	# above the highest, so a slope cannot bury it or hang it.
	var foot: float = minf(lowest_under(found["gantry_west"], dug), lowest_under(found["gantry_east"], dug))
	_gantry.position.y = foot
	_terminal.position.y = lowest_under(found["terminal"], dug)


## Lights the pad when the Landing Field is open, dark otherwise.
func refresh() -> void:
	_lit = BiomeData.is_open(BIOME, GameState.lab_level(), GameState.audit_log.size())
	for head: MeshInstance3D in _lights:
		head.material_override = _lit_material if _lit else _unlit_material


## Whether the pad's lights are lit right now.
func is_lit() -> bool:
	return _lit


## How many edge lights there are.
func light_count() -> int:
	return _lights.size()


## The slab's top as it stands now (the node's), for a test.
func slab_top_now() -> float:
	return _slab.position.y + SLAB_THICKNESS_M * 0.5
