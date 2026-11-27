class_name BasaltDressing
extends Node3D
## Steam vents on the Basalt Ridge (docs/design/biomes.md section 6, step 10): a few
## low dark rings that breathe a slow, thin puff. Scene dressing only: no collision,
## nothing to click, nothing saved or sent, no light. Every machine builds the same
## vents from the same list. A vent keeps off roads, the plot, pads and signs, every
## way in (4 m), fissures, rocks, built things and the ridge's lamps, and sits on the
## ground as dug leaves it. Every number is a stand-in [PLACEHOLDER].

## Where the vents are (x, z), all inside the ridge [PLACEHOLDER].
const VENTS: Array[Vector2] = [
	Vector2(36.0, -38.0),
	Vector2(46.0, -41.0),
	Vector2(52.0, -29.0),
	Vector2(44.0, -16.0),
	Vector2(34.0, -26.0),
]
## A vent's ring, in metres: how wide at the foot and the lip, and how tall.
const FOOT_RADIUS_M: float = 0.65
const LIP_RADIUS_M: float = 0.38
const RING_HEIGHT_M: float = 0.28
## A vent's footprint half-width for the clearance checks.
const VENT_HALF_M: float = 0.7
## A vent keeps this far from a built thing, rock or fissure edge, from a lamp, and
## from a way in.
const SPOT_CLEAR_M: float = 1.0
const LAMP_CLEAR_M: float = 1.5
const ENTRANCE_CLEAR_M: float = 4.0
## The puff: few, small and slow (CPU particles, no light).
const PUFF_COUNT: int = 8
const PUFF_LIFETIME_S: float = 3.0
const PUFF_RISE_M_S: float = 0.9
const PUFF_SIZE_M: float = 0.5
## Steam colour: a neutral grey (Ryan, Nov 27 playtest: "maybe a bit greyer"; was 0.85/0.88/0.92) [PLACEHOLDER].
const PUFF_GREY := Color(0.66, 0.66, 0.66)

static var _spots: Array[Vector2] = []
static var _spots_ready: bool = false
## The hill's natural plants, worked out once: HillDressing.plants() rebuilds the
## whole list on every call, and `clear` runs once per vent.
static var _plants: Array[HillDressing.Placed] = []
static var _plants_ready: bool = false

var _vents: Array[Node3D] = []


## The vents that pass the clearance rules, in list order. Worked out once.
static func spots() -> Array[Vector2]:
	if not _spots_ready:
		_spots.clear()
		for at: Vector2 in VENTS:
			if clear(at):
				_spots.append(at)
		_spots_ready = true
	return _spots


## Forget the worked-out spots (for tests that reload the table).
static func reset() -> void:
	_spots_ready = false
	_plants_ready = false


## The natural hill plants (shrubs and poppies), cached.
static func plants() -> Array[HillDressing.Placed]:
	if not _plants_ready:
		_plants = HillDressing.plants()
		_plants_ready = true
	return _plants


## Whether a vent may stand at `at`: inside the Basalt Ridge, off the plot, roads,
## pads and signs, a way in, a built thing, rock or fissure, and a lamp.
static func clear(at: Vector2) -> bool:
	if absf(at.x) > Terrain.HALF_M - 2.0 or absf(at.y) > Terrain.HALF_M - 2.0:
		return false
	if BiomeData.biome_at(at) != &"basalt_ridge":
		return false
	if absf(at.x) < BiomeData.PLOT_HALF_M + VENT_HALF_M and absf(at.y) < BiomeData.PLOT_HALF_M + VENT_HALF_M:
		return false
	if BiomeData.on_road(at):
		return false
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1), Vector2.ZERO]:
		var point: Vector2 = at + corner * VENT_HALF_M
		var cell := Vector2i(floori(point.x / Terrain.CELL_M), floori(point.y / Terrain.CELL_M))
		if BiomeData.is_road_cell(cell) or BiomeMarkers.is_blocked_cell(cell):
			return false
	for box: Vector4 in BiomeData.spots():
		if absf(at.x - box.x) < box.z + VENT_HALF_M + SPOT_CLEAR_M and absf(at.y - box.y) < box.w + VENT_HALF_M + SPOT_CLEAR_M:
			return false
	for id: StringName in BiomeData.ids():
		for zone: StringName in BiomeData.zones(id):
			var way: Variant = BiomeData.entrance_at(id, zone)
			if way is Vector2 and at.distance_to(way as Vector2) < ENTRANCE_CLEAR_M:
				return false
	for plant: HillDressing.Placed in plants():
		if absf(at.x - plant.at.x) < plant.half_m() + VENT_HALF_M and absf(at.y - plant.at.z) < plant.half_m() + VENT_HALF_M:
			return false
	for lamp: Vector2 in RoadLamps.spots(&"basalt_ridge"):
		if at.distance_to(lamp) < LAMP_CLEAR_M:
			return false
	return true


func _ready() -> void:
	name = "BasaltDressing"
	build(GameState.dug)
	cover(GameState.stone_pieces)
	GameState.terrain_changed.connect(_on_terrain_changed)
	GameState.stone_changed.connect(_on_stone_changed)


func _on_terrain_changed() -> void:
	settle(GameState.dug)


func _on_stone_changed() -> void:
	cover(GameState.stone_pieces)


## Puts the vents in on the ground as `dug` leaves it.
func build(dug: Dictionary[Vector2i, int]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_vents.clear()
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.1, 0.1, 0.12)
	ring_material.roughness = 1.0
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = LIP_RADIUS_M
	ring_mesh.bottom_radius = FOOT_RADIUS_M
	ring_mesh.height = RING_HEIGHT_M
	ring_mesh.radial_segments = 8
	ring_mesh.rings = 1
	ring_mesh.material = ring_material
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	puff_material.billboard_keep_scale = true
	puff_material.vertex_color_use_as_albedo = true
	puff_material.albedo_color = PUFF_GREY
	var puff_mesh := QuadMesh.new()
	puff_mesh.size = Vector2.ONE * PUFF_SIZE_M
	puff_mesh.material = puff_material
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.2, Color(1, 1, 1, 0.35))
	var index: int = 0
	for at: Vector2 in spots():
		var vent := Node3D.new()
		vent.name = "Vent_%d" % index
		vent.position = Vector3(at.x, ground_y(at, dug), at.y)
		var ring := MeshInstance3D.new()
		ring.name = "Ring"
		ring.mesh = ring_mesh
		vent.add_child(ring)
		var puff := CPUParticles3D.new()
		puff.name = "Puff"
		puff.amount = PUFF_COUNT
		puff.lifetime = PUFF_LIFETIME_S
		puff.preprocess = PUFF_LIFETIME_S
		puff.mesh = puff_mesh
		puff.direction = Vector3.UP
		puff.spread = 12.0
		puff.gravity = Vector3.ZERO
		puff.initial_velocity_min = PUFF_RISE_M_S * 0.8
		puff.initial_velocity_max = PUFF_RISE_M_S * 1.2
		puff.scale_amount_min = 0.6
		puff.scale_amount_max = 1.8
		puff.color_ramp = fade
		puff.local_coords = false
		vent.add_child(puff)
		add_child(vent)
		_seat(vent, dug)
		_vents.append(vent)
		index += 1


## The lowest ground under a vent's ring at `at`, so no edge hangs in the air.
static func ground_y(at: Vector2, dug: Dictionary[Vector2i, int]) -> float:
	return HillDressing.lowest_under(at, Vector2.ONE * FOOT_RADIUS_M, dug)


## Where the lip of a vent at `at` is: RING_HEIGHT_M over the highest ground under the
## lip (and the middle), so a slope or a dug neighbour cannot bury the lip or the puff.
static func top_y(at: Vector2, dug: Dictionary[Vector2i, int]) -> float:
	var high: float = Terrain.height(at, dug)
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			high = maxf(high, Terrain.height(at + Vector2(x, z) * LIP_RADIUS_M, dug))
	return high + RING_HEIGHT_M


## Whether stone covers any cell under a vent's foot at `at`.
static func covered_by(at: Vector2, pieces: Dictionary[Vector2i, int]) -> bool:
	var first: Vector2i = Terrain.cell_at(at - Vector2.ONE * FOOT_RADIUS_M)
	var last: Vector2i = Terrain.cell_at(at + Vector2.ONE * FOOT_RADIUS_M)
	for x: int in range(first.x, last.x + 1):
		for z: int in range(first.y, last.y + 1):
			if pieces.has(Vector2i(x, z)):
				return true
	return false


## How many vents there are.
func vent_count() -> int:
	return _vents.size()


## Re-seats every vent on the ground as `dug` leaves it.
func settle(dug: Dictionary[Vector2i, int]) -> void:
	for vent: Node3D in _vents:
		_seat(vent, dug)


## Hides a vent, and stops its puff, while a stone piece covers its foot; shows it again
## when the stone is taken up.
func cover(pieces: Dictionary[Vector2i, int]) -> void:
	for vent: Node3D in _vents:
		var shown: bool = not covered_by(Vector2(vent.position.x, vent.position.z), pieces)
		vent.visible = shown
		(vent.get_node("Puff") as CPUParticles3D).emitting = shown


## Whether a vent is showing (not under stone).
func is_shown(index: int) -> bool:
	return _vents[index].visible


## Sets a vent's foot on the lowest ground, its ring up to the lip, and its puff at the lip.
func _seat(vent: Node3D, dug: Dictionary[Vector2i, int]) -> void:
	var at := Vector2(vent.position.x, vent.position.z)
	var foot: float = ground_y(at, dug)
	var height: float = maxf(top_y(at, dug) - foot, RING_HEIGHT_M)
	vent.position.y = foot
	var ring: Node3D = vent.get_node("Ring") as Node3D
	ring.scale = Vector3(1.0, height / RING_HEIGHT_M, 1.0)
	ring.position = Vector3(0.0, height * 0.5, 0.0)
	(vent.get_node("Puff") as Node3D).position = Vector3(0.0, height, 0.0)
