class_name FrostDressing
extends Node3D
## A small set of pale frosted rocks around the Frost Flats pad (docs/design/biomes.md
## section 6, step 11). Scene dressing only: low rocks with no collision (a rover
## drives over them), nothing to click, nothing saved or sent, no light. Every
## machine builds the same rocks from the same list. A rock keeps off roads, the
## pad's approach, the plot, pads and signs, built things, rocks, plants and the
## biome's lamps, and sits on the ground as dug leaves it. The ground is not
## levelled. Every number is a stand-in [PLACEHOLDER].

## Where the rocks are and how big: x, z, radius across, height above the ground
## (metres), all inside the Frost Flats, none on the road's line or in front of the pad.
const ROCKS: Array[Vector4] = [
	Vector4(-5.5, -81.0, 0.9, 0.55),
	Vector4(-9.0, -75.0, 0.6, 0.35),
	Vector4(-11.5, -83.5, 1.1, 0.6),
	Vector4(6.5, -83.0, 0.8, 0.5),
	Vector4(10.0, -77.0, 0.55, 0.3),
	Vector4(12.5, -85.5, 1.0, 0.55),
	Vector4(-2.5, -88.0, 0.7, 0.4),
]
## A rock's sphere is 2 high at scale 1; this share of its stretched upper half is
## under the ground on level ground (with the lower half, 67.5 % of it is buried).
const BURIED_SHARE: float = 0.35
## A rock keeps this far (plus its own radius) from a built thing, a rock or a
## fissure, and from a lamp. Plants only need their own size.
const SPOT_CLEAR_M: float = 1.0
const LAMP_CLEAR_M: float = 1.0
## The pad's approach: this far to each side of the road line, from the pad's far
## edge to this many metres south of the pad's middle, stays open.
const APPROACH_HALF_M: float = 3.5
const APPROACH_LENGTH_M: float = 12.0
const ROCK_COLOR := Color(0.82, 0.9, 0.96)

static var _spots: Array[Vector4] = []
static var _spots_ready: bool = false
static var _plants: Array[HillDressing.Placed] = []
static var _plants_ready: bool = false

var _rocks: Array[MeshInstance3D] = []


## The rocks that pass the rules, in list order. Worked out once.
static func spots() -> Array[Vector4]:
	if not _spots_ready:
		_spots.clear()
		for rock: Vector4 in ROCKS:
			if clear(rock):
				_spots.append(rock)
		_spots_ready = true
	return _spots


## Forget the worked-out spots (for tests that reload the table).
static func reset() -> void:
	_spots_ready = false
	_plants_ready = false


## The natural hill plants, cached.
static func plants() -> Array[HillDressing.Placed]:
	if not _plants_ready:
		_plants = HillDressing.plants()
		_plants_ready = true
	return _plants


## Whether a rock (x, z, radius, height) may stand: inside the Frost Flats, on the
## land, off the plot, roads, the pad's approach, pads and signs, built things,
## rocks, plants and lamps.
static func clear(rock: Vector4) -> bool:
	var at := Vector2(rock.x, rock.y)
	var half: float = rock.z
	if absf(at.x) > Terrain.HALF_M - 2.0 or absf(at.y) > Terrain.HALF_M - 2.0:
		return false
	if BiomeData.biome_at(at) != &"frost_flats":
		return false
	if absf(at.x) < BiomeData.PLOT_HALF_M + half and absf(at.y) < BiomeData.PLOT_HALF_M + half:
		return false
	if BiomeData.road_gap(at) <= BiomeData.ROAD_HALF_M + half:
		return false
	var first: Vector2i = Terrain.cell_at(at - Vector2.ONE * half)
	var last: Vector2i = Terrain.cell_at(at + Vector2.ONE * half)
	for x: int in range(first.x, last.x + 1):
		for z: int in range(first.y, last.y + 1):
			if BiomeData.is_road_cell(Vector2i(x, z)) or BiomeMarkers.is_blocked_cell(Vector2i(x, z)):
				return false
	var pad: Vector2 = BiomeData.marker(&"frost_flats")
	if absf(at.x - pad.x) < APPROACH_HALF_M + half and at.y + half > pad.y - BiomeData.PAD_HALF_M and at.y - half < pad.y + APPROACH_LENGTH_M:
		return false
	for box: Vector4 in BiomeData.spots():
		if absf(at.x - box.x) < box.z + half + SPOT_CLEAR_M and absf(at.y - box.y) < box.w + half + SPOT_CLEAR_M:
			return false
	for id: StringName in BiomeData.ids():
		for zone: StringName in BiomeData.zones(id):
			var way: Variant = BiomeData.entrance_at(id, zone)
			if way is Vector2 and at.distance_to(way as Vector2) < 4.0 + half:
				return false
	for plant: HillDressing.Placed in plants():
		if absf(at.x - plant.at.x) < plant.half_m() + half and absf(at.y - plant.at.z) < plant.half_m() + half:
			return false
	for lamp: Vector2 in RoadLamps.spots(&"frost_flats"):
		if at.distance_to(lamp) < half + LAMP_CLEAR_M:
			return false
	return true


func _ready() -> void:
	name = "FrostDressing"
	build(GameState.dug)
	cover(GameState.stone_pieces)
	GameState.terrain_changed.connect(_on_terrain_changed)
	GameState.stone_changed.connect(_on_stone_changed)


func _on_terrain_changed() -> void:
	settle(GameState.dug)


func _on_stone_changed() -> void:
	cover(GameState.stone_pieces)


## Puts the rocks in on the ground as `dug` leaves it.
func build(dug: Dictionary[Vector2i, int]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_rocks.clear()
	var material := StandardMaterial3D.new()
	material.albedo_color = ROCK_COLOR
	material.roughness = 0.85
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = material
	var index: int = 0
	for rock: Vector4 in spots():
		var node := MeshInstance3D.new()
		node.name = "Rock_%d" % index
		node.mesh = mesh
		# A different turn for each, so they do not look stamped.
		node.rotation.y = float(index) * 1.7
		node.position = Vector3(rock.x, 0.0, rock.y)
		add_child(node)
		_rocks.append(node)
		_seat(node, rock, dug)
		index += 1


## The lowest ground under a rock's footprint at `at`.
static func ground_y(rock: Vector4, dug: Dictionary[Vector2i, int]) -> float:
	return HillDressing.lowest_under(Vector2(rock.x, rock.y), Vector2.ONE * rock.z, dug)


## Whether stone covers any cell under a rock's footprint.
static func covered_by(rock: Vector4, pieces: Dictionary[Vector2i, int]) -> bool:
	var first: Vector2i = Terrain.cell_at(Vector2(rock.x, rock.y) - Vector2.ONE * rock.z)
	var last: Vector2i = Terrain.cell_at(Vector2(rock.x, rock.y) + Vector2.ONE * rock.z)
	for x: int in range(first.x, last.x + 1):
		for z: int in range(first.y, last.y + 1):
			if pieces.has(Vector2i(x, z)):
				return true
	return false


## How many rocks there are.
func rock_count() -> int:
	return _rocks.size()


## Re-seats every rock on the ground as `dug` leaves it.
func settle(dug: Dictionary[Vector2i, int]) -> void:
	for i: int in _rocks.size():
		_seat(_rocks[i], spots()[i], dug)


## Hides a rock while a stone piece covers its footprint.
func cover(pieces: Dictionary[Vector2i, int]) -> void:
	for i: int in _rocks.size():
		_rocks[i].visible = not covered_by(spots()[i], pieces)


## Whether a rock is showing (not under stone).
func is_shown(index: int) -> bool:
	return _rocks[index].visible


## The top of a rock: its height over the highest ground under its footprint, so a
## slope or a dug neighbour cannot bury it.
static func top_y(rock: Vector4, dug: Dictionary[Vector2i, int]) -> float:
	var at := Vector2(rock.x, rock.y)
	var high: float = Terrain.height(at, dug)
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			high = maxf(high, Terrain.height(at + Vector2(x, z) * rock.z, dug))
	return high + rock.w


## Stretches the sphere so its top stands at `top_y` and it still reaches below the
## lowest ground (BURIED_SHARE of the span is under the foot), so no edge hangs.
func _seat(node: Node3D, rock: Vector4, dug: Dictionary[Vector2i, int]) -> void:
	var foot: float = ground_y(rock, dug)
	var top: float = top_y(rock, dug)
	var span: float = maxf(top - foot, rock.w) / (1.0 - BURIED_SHARE)
	node.scale = Vector3(rock.z, span, rock.z * 0.85)
	node.position.y = top - span
