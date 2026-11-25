class_name HillDressing
extends Node3D
## Plants and rocks on the hills, the same on every PC. Only to look at, but a
## rock stops rovers and the uplink, as a boulder does [ASSUMPTION].

enum Plant { SHRUB, POPPY }
enum Rock { BUTTE, BASALT, ARCH, OUTCROP }

## The world's and the uplink's, as a boulder's.
const ROCK_LAYERS: int = 5
const ROCK_MODELS: Dictionary[Rock, String] = {
	Rock.BUTTE: "res://assets/voxels/mesa_butte_stack.glb",
	Rock.BASALT: "res://assets/voxels/basalt_column_cluster.glb",
	Rock.ARCH: "res://assets/voxels/mesa_arch_span.glb",
	Rock.OUTCROP: "res://assets/voxels/rim_inner_corner.glb",
}
const ROCK_VOXEL_M: float = 0.2
## The arch is drawn larger than its pack size, and its box with it [PLACEHOLDER].
const ROCK_SCALE: Dictionary[Rock, float] = {Rock.ARCH: 1.25}
## A whole box, so nobody drives into the arch, which is too small for a rover.
const ROCK_SIZE_M: Dictionary[Rock, Vector3] = {
	Rock.BUTTE: Vector3(2.4, 2.8, 2.4),
	Rock.BASALT: Vector3(2.0, 2.8, 2.0),
	Rock.ARCH: Vector3(3.5, 3.0, 2.5),
	Rock.OUTCROP: Vector3(2.0, 2.0, 2.0),
}
## The arch is wider than deep, and the outcrop's steps face the camera; the others
## can stand any way.
const ROCK_QUARTER_TURNS: Dictionary[Rock, int] = {Rock.ARCH: 0, Rock.OUTCROP: 1}
## Where the rocks stand, in meters, each at the middle of a cell: on high ground,
## far enough apart to drive between, and off every line from the farm or the road
## to the relay [PLACEHOLDER].
const ROCKS: Dictionary[Vector2i, Rock] = {
	Vector2i(49, 45): Rock.BUTTE, Vector2i(45, -47): Rock.BUTTE, Vector2i(-47, 49): Rock.BUTTE,
	Vector2i(41, 51): Rock.BASALT, Vector2i(53, 55): Rock.BASALT, Vector2i(53, -41): Rock.BASALT,
	Vector2i(-39, 43): Rock.BASALT, Vector2i(3, 65): Rock.BASALT,
	Vector2i(-65, 15): Rock.BASALT, Vector2i(15, -65): Rock.BASALT,
	Vector2i(63, 3): Rock.ARCH,
	Vector2i(57, 41): Rock.OUTCROP, Vector2i(39, -51): Rock.OUTCROP, Vector2i(-53, 55): Rock.OUTCROP,
}
## Cells this near a rock can't be dug [PLACEHOLDER].
const ROCK_MARGIN_M: float = 0.5
## A rover whose middle is this near a rock is inside it, and one this far
## from a rock's corner is clear however it faces.
const ROVER_INSIDE_M: float = 0.7
const ROVER_CLEAR_M: float = 1.5

const PLANT_MODELS: Dictionary[Plant, String] = {
	Plant.SHRUB: "res://assets/voxels/bitterberry_shrub.glb",
	Plant.POPPY: "res://assets/voxels/plateau_poppy.glb",
}
const PLANT_VOXEL_M: float = 0.1
## Half as wide as each plant at full size.
const PLANT_HALF_M: Dictionary[Plant, float] = {Plant.SHRUB: 0.5, Plant.POPPY: 0.4}
const PLANT_SEED: int = 24
## Plants keep this far from level ground, the land's edge and rocks [PLACEHOLDER].
const LEVEL_MARGIN_M: float = 3.0
const EDGE_MARGIN_M: float = 2.0
const ROCK_GAP_M: float = 1.0
## One chance of a shrub in each square this wide, likelier on a slope this steep
## or more than on flatter ground [PLACEHOLDER].
const SHRUB_EVERY_M: int = 5
const SLOPE: float = 0.08
const SHRUB_CHANCE_SLOPE: float = 0.45
const SHRUB_CHANCE_FLAT: float = 0.1
const SHRUB_SCALE := Vector2(0.75, 1.2)
## A second, looser shrub shape mixed in [ASSUMPTION], from Ryan's pack.
const LOOSE_SHRUB_MODEL: String = "res://assets/voxels/mesa_scrub_bush.glb"
const LOOSE_SHRUB_SHARE: float = 0.4
## Width and height factors per shrub; width stays under 1 so half_m holds [PLACEHOLDER].
const SHRUB_WIDTH := Vector2(0.8, 1.0)
const SHRUB_HEIGHT := Vector2(0.85, 1.25)
## Muted green and ochre tints, multiplied onto the model's colors [PLACEHOLDER].
const SHRUB_TINTS: Array[Color] = [
	Color("ffffff"), Color("d9ebc7"), Color("c9dba6"), Color("ecdcab"), Color("e0c48a"), Color("b8cf9a"),
]
## Poppies come in drifts: this many tries, how many each, how far out, and only
## where the ground is this high. At full size the model is 1.1 m tall [PLACEHOLDER].
const DRIFT_TRIES: int = 90
const DRIFT_COUNT := Vector2i(5, 11)
const DRIFT_M: float = 2.2
const DRIFT_ABOVE_M: float = 0.8
const POPPY_SCALE := Vector2(0.4, 0.6)
const POPPY_GAP_M: float = 0.5
## How far a base is below the lowest ground under it.
const SINK_M: float = 0.05
## Plants are drawn by squares this wide.
const CHUNK_M: int = 40

var _rocks: Dictionary[Vector2i, StaticBody3D] = {}
## The plants of each drawing.
var _drawn: Dictionary[MultiMesh, Array] = {}


## One plant: what, where its base is, how big and which way.
class Placed:
	var plant: Plant
	var at: Vector3
	var size: float
	var quarter_turns: int

	func half_m() -> float:
		return PLANT_HALF_M[plant] * size

	## Same spot, same look, from the position alone, so the random stream is not touched.
	func roll(salt: float) -> float:
		return fposmod(sin(at.x * 12.9898 + at.z * 78.233 + salt * 37.719) * 43758.5453, 1.0)

	## Only shrubs vary in shape.
	func is_loose() -> bool:
		return plant == Plant.SHRUB and roll(1.0) < LOOSE_SHRUB_SHARE

	func tint() -> Color:
		if plant != Plant.SHRUB:
			return Color.WHITE
		return SHRUB_TINTS[int(roll(2.0) * SHRUB_TINTS.size())]

	func stretch() -> Vector3:
		if plant != Plant.SHRUB:
			return Vector3.ONE
		var wide: float = lerpf(SHRUB_WIDTH.x, SHRUB_WIDTH.y, roll(3.0))
		return Vector3(wide, lerpf(SHRUB_HEIGHT.x, SHRUB_HEIGHT.y, roll(4.0)), wide)

	func place() -> Transform3D:
		var turned := Basis(Vector3.UP, PI / 2.0 * quarter_turns)
		return Transform3D(turned.scaled(stretch() * size * PLANT_VOXEL_M), at)


func _ready() -> void:
	for at: Vector2i in ROCKS:
		_add_rock(at)
	_add_plants()
	GameState.terrain_changed.connect(_refresh)
	_refresh()


## Half a rock's size along x and z.
static func rock_half_m(rock: Vector2i) -> Vector2:
	var size: Vector3 = ROCK_SIZE_M[ROCKS[rock]]
	return Vector2(size.x, size.z) / 2.0


## Whether a cell is under a rock or at its side, so it can't be dug [ASSUMPTION].
static func is_at_rock(cell: Vector2i) -> bool:
	var middle: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * Terrain.CELL_M
	return _is_near_rock(middle, ROCK_MARGIN_M + Terrain.CELL_M * 0.5)


## `at`, or just clear of a rock if a rover there would be inside it.
static func clear_of_rocks(at: Vector2) -> Vector2:
	for rock: Vector2i in ROCKS:
		if _rover_gap(at, rock) < ROVER_INSIDE_M:
			var away: Vector2 = at - Vector2(rock)
			var way: Vector2 = Vector2.RIGHT if away.is_zero_approx() else away.normalized()
			return Vector2(rock) + way * (rock_half_m(rock).length() + ROVER_CLEAR_M)
	return at


## The lowest ground under a footprint, so a base there has no corner in the air.
static func lowest_under(at: Vector2, half_m: Vector2, dug: Dictionary[Vector2i, int]) -> float:
	var lowest_m: float = INF
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			lowest_m = minf(lowest_m, Terrain.height(at + Vector2(x, z) * half_m, dug))
	return lowest_m


## Every plant of the natural land.
static func plants() -> Array[Placed]:
	var rng := RandomNumberGenerator.new()
	rng.seed = PLANT_SEED
	var found: Array[Placed] = []
	for x: int in range(-Terrain.HALF_M, Terrain.HALF_M, SHRUB_EVERY_M):
		for z: int in range(-Terrain.HALF_M, Terrain.HALF_M, SHRUB_EVERY_M):
			var at := Vector2(x + rng.randf() * SHRUB_EVERY_M, z + rng.randf() * SHRUB_EVERY_M)
			var chance: float = SHRUB_CHANCE_SLOPE if _slope(at) >= SLOPE else SHRUB_CHANCE_FLAT
			var wanted: bool = rng.randf() < chance
			var shrub: Placed = _placed(rng, Plant.SHRUB, at, SHRUB_SCALE)
			if wanted and _is_free(at):
				found.append(shrub)
	for i: int in DRIFT_TRIES:
		var middle := Vector2(rng.randf_range(-Terrain.HALF_M, Terrain.HALF_M), rng.randf_range(-Terrain.HALF_M, Terrain.HALF_M))
		var high: bool = Terrain.height(middle, {}) >= DRIFT_ABOVE_M
		var drift: Array[Vector2] = []
		for j: int in rng.randi_range(DRIFT_COUNT.x, DRIFT_COUNT.y):
			var out := Vector2(rng.randf_range(-DRIFT_M, DRIFT_M), rng.randf_range(-DRIFT_M, DRIFT_M))
			var poppy: Placed = _placed(rng, Plant.POPPY, middle + out, POPPY_SCALE)
			var crowded: bool = drift.any(func(other: Vector2) -> bool: return other.distance_to(middle + out) < POPPY_GAP_M)
			if high and not crowded and _is_free(middle + out):
				drift.append(middle + out)
				found.append(poppy)
	return found


## Whether a plant stands with this digging. It is gone while any cell under it is
## dug, and back when that is filled [ASSUMPTION].
static func stands(placed: Placed, dug: Dictionary[Vector2i, int]) -> bool:
	var at := Vector2(placed.at.x, placed.at.z)
	var half: Vector2 = Vector2.ONE * placed.half_m()
	var first: Vector2i = Terrain.cell_at(at - half)
	var last: Vector2i = Terrain.cell_at(at + half)
	for x: int in range(first.x, last.x + 1):
		for z: int in range(first.y, last.y + 1):
			if dug.has(Vector2i(x, z)):
				return false
	return true


static func _placed(rng: RandomNumberGenerator, plant: Plant, at: Vector2, sizes: Vector2) -> Placed:
	var placed := Placed.new()
	placed.plant = plant
	placed.size = rng.randf_range(sizes.x, sizes.y)
	placed.quarter_turns = rng.randi_range(0, 3)
	placed.at = Vector3(at.x, lowest_under(at, Vector2.ONE * placed.half_m(), {}) - SINK_M, at.y)
	return placed


## Off level ground, the land's edge and the rocks, with their margins.
static func _is_free(at: Vector2) -> bool:
	if maxf(absf(at.x), absf(at.y)) > Terrain.HALF_M - EDGE_MARGIN_M:
		return false
	# Nothing grows in the wash or its banks [ASSUMPTION].
	if Terrain.wash_out(at) < Terrain.WASH_REACH:
		return false
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			if Terrain.is_level(at + Vector2(x, z) * LEVEL_MARGIN_M):
				return false
	return not _is_near_rock(at, ROCK_GAP_M)


static func _slope(at: Vector2) -> float:
	var rise_x: float = Terrain.height(at + Vector2.RIGHT, {}) - Terrain.height(at + Vector2.LEFT, {})
	var rise_z: float = Terrain.height(at + Vector2.DOWN, {}) - Terrain.height(at + Vector2.UP, {})
	return Vector2(rise_x, rise_z).length() / 2.0


static func _is_near_rock(at: Vector2, within_m: float) -> bool:
	for rock: Vector2i in ROCKS:
		if _rock_gap(at, rock) < within_m:
			return true
	return false


## How far a point is from a rock's side along x or z, whichever is more.
static func _rock_gap(at: Vector2, rock: Vector2i) -> float:
	var gap: Vector2 = (at - Vector2(rock)).abs() - rock_half_m(rock)
	return maxf(gap.x, gap.y)


## As the crow flies, so a rover resting diagonally at a corner is outside.
static func _rover_gap(at: Vector2, rock: Vector2i) -> float:
	var gap: Vector2 = (at - Vector2(rock)).abs() - rock_half_m(rock)
	return gap.max(Vector2.ZERO).length()


func _add_rock(at: Vector2i) -> void:
	var kind: Rock = ROCKS[at]
	var box := BoxShape3D.new()
	box.size = ROCK_SIZE_M[kind]
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position.y = box.size.y / 2.0
	var model := ModelSlot.new()
	model.model_path = ROCK_MODELS[kind]
	model.model_scale = ROCK_VOXEL_M * ROCK_SCALE.get(kind, 1.0)
	model.rotation.y = PI / 2.0 * ROCK_QUARTER_TURNS.get(kind, _rocks.size())
	var body := StaticBody3D.new()
	body.collision_layer = ROCK_LAYERS
	body.collision_mask = 0
	body.add_child(shape)
	body.add_child(model)
	add_child(body)
	_rocks[at] = body


func _add_plants() -> void:
	var groups: Dictionary[Vector3i, Array] = {}
	for placed: Placed in plants():
		var chunk: Vector2i = Vector2i((Vector2(placed.at.x, placed.at.z) / CHUNK_M).floor())
		# y is the plant, plus 2 for the loose shrub.
		var kind: int = placed.plant + (2 if placed.is_loose() else 0)
		groups.get_or_add(Vector3i(chunk.x, kind, chunk.y), []).append(placed)
	for group: Vector3i in groups:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = _mesh_of(LOOSE_SHRUB_MODEL if group.y >= 2 else PLANT_MODELS[group.y])
		multi.instance_count = groups[group].size()
		var drawing := MultiMeshInstance3D.new()
		drawing.multimesh = multi
		add_child(drawing)
		_drawn[multi] = groups[group]


func _mesh_of(path: String) -> Mesh:
	var model: Node = (load(path) as PackedScene).instantiate()
	var mesh: Mesh = (model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh.duplicate()
	model.free()
	# Instance colors only show on materials that read vertex colors.
	for surface: int in mesh.get_surface_count():
		var own := mesh.surface_get_material(surface) as StandardMaterial3D
		if own == null:
			continue
		var material: StandardMaterial3D = own.duplicate()
		material.vertex_color_use_as_albedo = true
		mesh.surface_set_material(surface, material)
	return mesh


func _refresh() -> void:
	# An older save may have dug under a rock: it sits down with the ground.
	for at: Vector2i in _rocks:
		_rocks[at].position = Vector3(at.x, lowest_under(at, rock_half_m(at), GameState.dug) - SINK_M, at.y)
	for multi: MultiMesh in _drawn:
		var shown: int = 0
		for placed: Placed in _drawn[multi]:
			if stands(placed, GameState.dug):
				multi.set_instance_transform(shown, placed.place())
				multi.set_instance_color(shown, placed.tint())
				shown += 1
		multi.visible_instance_count = shown
