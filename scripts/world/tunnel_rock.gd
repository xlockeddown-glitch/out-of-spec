class_name TunnelRock
extends Node3D
## Builds the tunnels from MAP: basalt floor, rock walls, rock arches, crystals
## and magma. Walls on the camera's side are drawn low so the rover is seen,
## but stop the rover and the signal all the same.

## North is up. # rock, . floor, A arch over a north-south passage, B arch over
## an east-west one, * crystals, ~ magma, w deep water. A letter in PIECES is that
## model.
const MAP: PackedStringArray = [
	"########################",
	"###*......##############",
	"##Sw.......######~~~~###",
	"##.........#####W~~~~V##",
	"##........*#####......##",
	"##...........B........##",
	"###..........B......*###",
	"#####..##########....###",
	"#####AA##########..#####",
	"#####..##########..#####",
	"#####..##########AA#####",
	"#####.........B....#####",
	"#####.........B....#####",
	"##########...###########",
	"##########AAA###########",
	"##########...###########",
	"#######......*##########",
	"######G.......##########",
	"#######.......##########",
	"##########...###########",
	"##########...###########",
	"########################",
]
const CELL_M: float = 3.0  # [PLACEHOLDER]
## Middle of the pool. The Cobalt Sentinel is found near it.
const SUMP := Vector3(-25.5, 0.0, -25.5)
## The pool's hollow is in here. From the deep cell's edge a shelf shallow enough
## to drive on goes this far out, and here the ground is level again [PLACEHOLDER].
const POOL := Rect2(-30.0, -30.0, 10.0, 10.0)
const SHELF_M: float = 2.4
const SHORE_M: float = 3.6
const DEEP_GROUND_M: float = -0.96
const SHELF_GROUND_M: float = -0.48
## The hollow's blocks are this wide and tall [PLACEHOLDER].
const POOL_BLOCK_M: float = 0.5
const POOL_STEP_M: float = 0.12
const WATER_M: float = -0.06  # [PLACEHOLDER]

## Ryan's underground models: each one's scene and its size in meters. Nothing is
## mined or collected from them.
const PIECES: Dictionary[String, Array] = {
	"G": ["cavern_crystal_grotto", Vector3(2.4, 2.0, 2.4)],
	"S": ["sub_sump_cistern", Vector3(2.0, 1.6, 2.0)],
	"W": ["sub_crystal_seam_wall", Vector3(2.0, 2.0, 2.0)],
	"V": ["sub_pillar_vault", Vector3(2.4, 2.0, 2.4)],
}
const PIECE_VOXEL_M: float = 0.2
## Which way each one's front faces [PLACEHOLDER].
const PIECE_YAW: Dictionary[String, float] = {"G": -PI / 2.0, "S": PI, "W": PI, "V": PI}
## Sunk so that the pool's water covers the model's own [PLACEHOLDER].
const SUMP_PIECE_M: float = -0.54
const LAYER_WORLD: int = 1
const LAYER_OCCLUDER: int = 4
## The rover drives under this; the signal is stopped from here up.
const ARCH_SIGNAL_M: float = 1.9  # [PLACEHOLDER]
const ARCH_LOW_M: float = 2.3  # [PLACEHOLDER]
const ARCH_HIGH_M: float = 4.0  # [PLACEHOLDER]
const ROCK_M: float = 6.0  # [PLACEHOLDER]
## A pillar's thickness along the arch. Above them the stone steps in this much
## more each course, for this many courses, under a capstone [PLACEHOLDER].
const PILLAR_M: float = 0.8
const ARCH_STEP_M: float = 0.7
const ARCH_COURSES: int = 2
## An arch this near the rover is seen through.
const FADE_NEAR_M: float = 6.0  # [PLACEHOLDER]
const FADE_ALPHA: float = 0.2  # [PLACEHOLDER]

const BASALT: Color = TunnelLook.WALL_BASALT  # lighter than the first dark basalt [PLACEHOLDER]
const BASALT_FLOOR: Color = TunnelLook.FLOOR_BASALT
## Tint ranges. Invariant (tested): arch stone < wall tints < floor tints in
## luminance, so pillars and the floor never blend and walls stay under the floor.
const FLOOR_DARKEN_MAX: float = 0.14
const WALL_LIGHTEN_MAX: float = 0.03
const ARCH_DARKEN: float = 0.15
const TEAL: Color = ScopeTheme.TEAL
const AMBER: Color = ScopeTheme.AMBER
## Deterministic wall strata, regolith scree, and seam thresholds [PLACEHOLDER].
const REGOLITH_BLEND_MAX: float = 0.24
const SCREE_THRESHOLD: float = 0.76
const SCREE_HEIGHT_M: float = 0.05
const SCREE_FOOTPRINT_M: float = 0.34
const SEAM_ICE_THRESHOLD: float = 0.90
const SEAM_ORE_THRESHOLD: float = 0.84
const SEAM_AQUIFER_ICE_THRESHOLD: float = 0.78
const SEAM_BAND_HEIGHT_M: float = 0.26
const ARCH_RIB_HEIGHT_M: float = 0.22
const ARCH_GUSSET_HEIGHT_M: float = 0.24
const ARCH_FADE_SPEED: float = 3.0

@export var rover: Node3D

## Each arch's middle and the material of its lintel.
var _lintels: Dictionary[Vector3, StandardMaterial3D] = {}
## Extra fading materials per arch middle (timber overhead ribs) [PLACEHOLDER].
var _lintel_trims: Dictionary[Vector3, StandardMaterial3D] = {}


## The map in use: the hub's MAP, or below it (ZoneDepth) the layout of the depth
## this screen's player is in. The same size, so a cell is in the same place.
static func grid() -> PackedStringArray:
	if ZoneDepth.local_depth > 0 and not ZoneDepth.local_layout.is_empty():
		return ZoneDepth.local_layout["grid"]
	if ZoneDepth.local_zone == AquiferDepth.ZONE:
		return AquiferDepth.hub_grid()
	return MAP


static func tile(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= grid().size() or cell.x < 0 or cell.x >= grid()[cell.y].length():
		return "#"
	return grid()[cell.y][cell.x]


## True where the rover can drive.
static func is_floor(cell: Vector2i) -> bool:
	return tile(cell) in ".AB"


## True if the rover can be at this place.
static func holds(place: Vector3) -> bool:
	return is_floor(cell_of(place)) and absf(place.y) < ROCK_M


## True if a rover here would stand in the deep water's edge, as one parked on the
## old floor could.
static func in_deep(place: Vector3) -> bool:
	return Rect2(SUMP.x - CELL_M * 0.5, SUMP.z - CELL_M * 0.5, CELL_M, CELL_M).grow(0.7).has_point(Vector2(place.x, place.z))


## True if the rover can be at this place on a given map (the host holds the rover
## to the map of the rover's own depth, whichever scene the host is in).
static func holds_in(map: PackedStringArray, place: Vector3) -> bool:
	var cell := Vector2i(roundi(place.x / CELL_M + (map[0].length() - 1) * 0.5), roundi(place.z / CELL_M + (map.size() - 1) * 0.5))
	if cell.y < 0 or cell.y >= map.size() or cell.x < 0 or cell.x >= map[cell.y].length():
		return false
	return map[cell.y][cell.x] in ".AB" and absf(place.y) < ROCK_M


## Half the rover's footprint, across and along [PLACEHOLDER].
const ROVER_HALF_M := Vector2(0.9, 1.5)


## True if the rover's body is on floor on a given map: every cell that the rotated
## footprint rectangle overlaps (not a few sample points, which can step over a corner
## of rock), judged as holds_in judges a cell's middle.
static func holds_body_in(map: PackedStringArray, at: Transform3D) -> bool:
	var centre := Vector2(at.origin.x, at.origin.z)
	# Off the map (or not a number): not on floor, before any cell arithmetic that
	# could wrap.
	var span: float = maxf(map[0].length(), map.size()) * CELL_M
	if not (is_finite(centre.x) and is_finite(centre.y)) or absf(centre.x) > span + ROVER_HALF_M.length() * 2.0 or absf(centre.y) > span + ROVER_HALF_M.length() * 2.0:
		return false
	var u := Vector2(at.basis.x.x, at.basis.x.z).normalized()
	var v := Vector2(at.basis.z.x, at.basis.z.z).normalized()
	if u == Vector2.ZERO or v == Vector2.ZERO:
		u = Vector2.RIGHT
		v = Vector2.DOWN
	var reach: float = ROVER_HALF_M.length() + CELL_M
	var half: float = CELL_M * 0.5
	var width: int = map[0].length()
	var depth: int = map.size()
	var first := Vector2i(roundi((centre.x - reach) / CELL_M + (width - 1) * 0.5), roundi((centre.y - reach) / CELL_M + (depth - 1) * 0.5))
	var last := Vector2i(roundi((centre.x + reach) / CELL_M + (width - 1) * 0.5), roundi((centre.y + reach) / CELL_M + (depth - 1) * 0.5))
	for cy: int in range(first.y, last.y + 1):
		for cx: int in range(first.x, last.x + 1):
			var middle := Vector2((cx - (width - 1) * 0.5) * CELL_M, (cy - (depth - 1) * 0.5) * CELL_M)
			if not _footprint_overlaps(centre, u, v, middle, half):
				continue
			if not holds_in(map, Vector3(middle.x, at.origin.y, middle.y)):
				return false
	return true


## Separating-axis test: the footprint (centre, axes u and v, ROVER_HALF_M) against a
## square cell (middle, half side). Touching by a hair is not overlap.
static func _footprint_overlaps(centre: Vector2, u: Vector2, v: Vector2, middle: Vector2, half: float) -> bool:
	var d: Vector2 = centre - middle
	for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN, u, v]:
		var rover_r: float = absf(u.dot(axis)) * ROVER_HALF_M.x + absf(v.dot(axis)) * ROVER_HALF_M.y
		var cell_r: float = (absf(axis.x) + absf(axis.y)) * half
		if absf(d.dot(axis)) >= rover_r + cell_r - 0.001:
			return false
	return true


## The middle of a cell.
static func at(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (grid()[0].length() - 1) * 0.5) * CELL_M, 0.0, (cell.y - (grid().size() - 1) * 0.5) * CELL_M)


## The middle of a cell of a given map, whichever map this screen is on.
static func at_in(map: PackedStringArray, cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (map[0].length() - 1) * 0.5) * CELL_M, 0.0, (cell.y - (map.size() - 1) * 0.5) * CELL_M)


static func cell_of(place: Vector3) -> Vector2i:
	return Vector2i(roundi(place.x / CELL_M + (grid()[0].length() - 1) * 0.5), roundi(place.z / CELL_M + (grid().size() - 1) * 0.5))


## The ground's height at x and z: level but for the pool's hollow.
static func ground_m(place: Vector2) -> float:
	if not POOL.has_point(place) or tile(cell_of(Vector3(place.x, 0.0, place.y))) in "#*":
		return 0.0
	var out: Vector2 = (place - Vector2(SUMP.x, SUMP.z)).abs() - Vector2.ONE * CELL_M * 0.5
	var out_m: float = out.max(Vector2.ZERO).length()
	if out_m == 0.0:
		return DEEP_GROUND_M
	return SHELF_GROUND_M * clampf(inverse_lerp(SHORE_M, SHELF_M, out_m), 0.0, 1.0)


## The same in the steps it is drawn in.
static func drawn_ground_m(place: Vector2) -> float:
	var block: Vector2 = ((place / POOL_BLOCK_M).floor() + Vector2.ONE * 0.5) * POOL_BLOCK_M
	return snappedf(ground_m(block), POOL_STEP_M)


func _enter_tree() -> void:
	# Before any child's _ready: the map is the one the rover is at.
	var zone: String = AquiferDepth.ZONE if GameState.rover_zone == AquiferDepth.ZONE else ZoneDepth.ZONE
	ZoneDepth.follow(GameState.rover_depth, GameState.world_seed, GameClock.get_day_index(), zone)


func _ready() -> void:
	_build_colliders()
	_build_blocks()
	# The Lava hub's sump is in the map's corner; the Aquifer's corner is rock.
	if ZoneDepth.local_zone == ZoneDepth.ZONE:
		var water := VoxelWater.new()
		water.name = "Water"
		water.fill(POOL, WATER_M, drawn_ground_m)
		add_child(water)
	for y: int in grid().size():
		for x: int in grid()[y].length():
			var cell := Vector2i(x, y)
			match tile(cell):
				"A":
					if tile(cell + Vector2i.LEFT) != "A":
						_build_arch(cell, Vector2i.RIGHT)
				"B":
					if tile(cell + Vector2i.UP) != "B":
						_build_arch(cell, Vector2i.DOWN)
				"*":
					_build_crystals(cell)
			if PIECES.has(tile(cell)):
				_build_piece(cell, tile(cell))


func _process(delta: float) -> void:
	if rover == null:
		return
	for middle: Vector3 in _lintels:
		var near: bool = middle.distance_to(rover.global_position) < FADE_NEAR_M
		var target_alpha: float = FADE_ALPHA if near else 1.0
		var material: StandardMaterial3D = _lintels[middle]
		material.albedo_color.a = move_toward(material.albedo_color.a, target_alpha, delta * ARCH_FADE_SPEED)
		if _lintel_trims.has(middle):
			var trim: StandardMaterial3D = _lintel_trims[middle]
			trim.albedo_color.a = move_toward(trim.albedo_color.a, target_alpha, delta * ARCH_FADE_SPEED)


## Rock this near the floor is drawn; past it is dark.
func _is_drawn(cell: Vector2i) -> bool:
	for y: int in range(-2, 3):
		for x: int in range(-2, 3):
			if tile(cell + Vector2i(x, y)) != "#":
				return true
	return false


## True if tall rock here would hide the floor behind it from the camera.
func _hides_floor(cell: Vector2i) -> bool:
	for y: int in range(-2, 1):
		for x: int in range(-2, 1):
			if tile(cell + Vector2i(x, y)) != "#":
				return true
	return false


func _build_colliders() -> void:
	var end: Vector2 = Vector2(grid()[0].length(), grid().size()) * CELL_M * 0.5
	# All but the pool's hollow.
	_add_floor(-end, Vector2(end.x, POOL.position.y))
	_add_floor(Vector2(-end.x, POOL.end.y), end)
	_add_floor(Vector2(-end.x, POOL.position.y), Vector2(POOL.position.x, POOL.end.y))
	_add_floor(Vector2(POOL.end.x, POOL.position.y), Vector2(end.x, POOL.end.y))
	_add_hollow()
	# Nothing falls out of the world, should it get through the hollow.
	_add_body("Net", LAYER_WORLD, Vector3(POOL.get_center().x, -2.5, POOL.get_center().y), Vector3(POOL.size.x, 1.0, POOL.size.y))
	for y: int in grid().size():
		var x: int = 0
		while x < grid()[y].length():
			var cell := Vector2i(x, y)
			var kind: String = tile(cell)
			var run: int = 1
			while x + run < grid()[y].length() and tile(cell + Vector2i(run, 0)) == kind:
				run += 1
			x += run
			var middle: Vector3 = at(cell) + Vector3((run - 1) * CELL_M * 0.5, 0.0, 0.0)
			if kind == "#":
				_add_body("Rock", LAYER_WORLD | LAYER_OCCLUDER, middle + Vector3.UP * ROCK_M * 0.5, Vector3(run * CELL_M, ROCK_M, CELL_M))
			elif kind in "*~w":
				# Too low to stop the signal.
				_add_body("Low", LAYER_WORLD, middle + Vector3.UP * 0.5, Vector3(run * CELL_M, 1.0, CELL_M))


func _add_floor(from: Vector2, to: Vector2) -> void:
	var middle: Vector2 = (from + to) * 0.5
	_add_body("Floor", LAYER_WORLD | LAYER_OCCLUDER, Vector3(middle.x, -0.5, middle.y), Vector3(to.x - from.x, 1.0, to.y - from.y))


## The pool's ground, which slopes where it is drawn in steps.
func _add_hollow() -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = int(POOL.size.x) + 1
	shape.map_depth = int(POOL.size.y) + 1
	var heights: PackedFloat32Array = []
	for z: int in shape.map_depth:
		for x: int in shape.map_width:
			heights.append(ground_m(POOL.position + Vector2(x, z)))
	shape.map_data = heights
	_add_shape("Hollow", LAYER_WORLD | LAYER_OCCLUDER, Vector3(POOL.get_center().x, 0.0, POOL.get_center().y), shape)


func _add_body(body_name: String, layer: int, middle: Vector3, size: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = size
	_add_shape(body_name, layer, middle, box)


func _add_shape(body_name: String, layer: int, middle: Vector3, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = middle
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	add_child(body, true)


func _build_blocks() -> void:
	var rock: Array[Transform3D] = []
	var rock_colors: Array[Color] = []
	var magma: Array[Transform3D] = []
	var magma_colors: Array[Color] = []
	var half: float = CELL_M * 0.5
	for y: int in range(-2, grid().size() + 2):
		for x: int in range(-2, grid()[0].length() + 2):
			var cell := Vector2i(x, y)
			var kind: String = tile(cell)
			if kind == "~":
				if (x + y) % 2 == 0:
					_add_light(at(cell) + Vector3.UP * 1.5, AMBER, 1.6, 8.0)
			if kind == "#" and not _is_drawn(cell):
				continue
			for east: int in 2:
				for south: int in 2:
					var part: Vector3 = at(cell) + Vector3((east - 0.5) * half, 0.0, (south - 0.5) * half)
					var pick: float = _hash(x * 2 + east, y * 2 + south)
					if kind == "~":
						magma.append(_block(part + Vector3.DOWN * 0.25, Vector3(half, 0.4, half)))
						magma_colors.append(AMBER.darkened(0.1 + pick * 0.4))
						continue
					if kind != "#" and POOL.has_point(Vector2(part.x, part.z)):
						_add_hollow_blocks(part, half, rock, rock_colors)
						continue
					var top_m: float = 0.0
					var aquifer: bool = ZoneDepth.local_zone == AquiferDepth.ZONE
					var pick2: float = _hash(x * 13 + east * 5 + 3, y * 17 + south * 7 + 11)
					var color: Color = BASALT_FLOOR.darkened(pick * FLOOR_DARKEN_MAX)
					if kind == "#":
						var low_wall: bool = _hides_floor(cell)
						top_m = 0.5 + 0.35 * pick if low_wall else 2.2 + 1.2 * pick
						color = BASALT.lightened(pick * WALL_LIGHTEN_MAX)
						if low_wall:
							rock.append(_block(part + Vector3.UP * (top_m - 1.0) * 0.5, Vector3(half, top_m + 1.0, half)))
							rock_colors.append(color)
						else:
							# Banded basalt strata: dark base course, mid banded course, optional seam/cap [PLACEHOLDER].
							var base_h: float = top_m * 0.42
							var mid_h: float = top_m * 0.36
							var cap_h: float = top_m - base_h - mid_h
							rock.append(_block(part + Vector3.UP * (base_h - 1.0) * 0.5, Vector3(half, base_h + 1.0, half)))
							rock_colors.append(color.darkened(0.10))
							rock.append(_block(part + Vector3.UP * (base_h + mid_h * 0.5), Vector3(half * 0.99, mid_h, half * 0.99)))
							var mid_col: Color = color if aquifer else color.lerp(TunnelLook.REGOLITH_DARK, pick2 * 0.18)
							rock_colors.append(mid_col)
							rock.append(_block(part + Vector3.UP * (base_h + mid_h + cap_h * 0.5), Vector3(half * 0.96, cap_h, half * 0.96)))
							rock_colors.append(color.lightened(0.02))
							# Occasional deterministic ice-seam or ore-vein wall stripe [PLACEHOLDER].
							var ice_cut: float = SEAM_AQUIFER_ICE_THRESHOLD if aquifer else SEAM_ICE_THRESHOLD
							if pick2 >= ice_cut:
								rock.append(_block(part + Vector3.UP * (base_h + mid_h * 0.5), Vector3(half + 0.04, SEAM_BAND_HEIGHT_M, half + 0.04)))
								rock_colors.append(TunnelLook.ICE)
							elif not aquifer and pick2 >= SEAM_ORE_THRESHOLD:
								rock.append(_block(part + Vector3.UP * (base_h + mid_h * 0.35), Vector3(half + 0.04, SEAM_BAND_HEIGHT_M, half + 0.04)))
								rock_colors.append(TunnelLook.quartz_base_color())
								rock.append(_block(part + Vector3.UP * (base_h + mid_h * 0.35), Vector3(half + 0.06, SEAM_BAND_HEIGHT_M * 0.45, half * 0.45)))
								rock_colors.append(TEAL)
					else:
						# Packed regolith floor tint (kept cool in Aquifer) + occasional scree [PLACEHOLDER].
						if not aquifer:
							color = color.lerp(TunnelLook.REGOLITH_DARK, pick2 * REGOLITH_BLEND_MAX)
						rock.append(_block(part + Vector3.UP * (top_m - 1.0) * 0.5, Vector3(half, top_m + 1.0, half)))
						rock_colors.append(color)
						if kind == "." and pick2 >= SCREE_THRESHOLD:
							var ox: float = (pick - 0.5) * half * 0.45
							var oz: float = (pick2 - 0.85) * half * 0.9
							var scree_col: Color = TunnelLook.BASALT_MID if aquifer else TunnelLook.REGOLITH
							rock.append(_block(part + Vector3(ox, SCREE_HEIGHT_M * 0.5, oz), Vector3(SCREE_FOOTPRINT_M, SCREE_HEIGHT_M, SCREE_FOOTPRINT_M * 0.85)))
							rock_colors.append(scree_col)
	var stone := StandardMaterial3D.new()
	stone.vertex_color_use_as_albedo = true
	stone.vertex_color_is_srgb = true
	stone.roughness = 1.0
	if ZoneDepth.local_zone == AquiferDepth.ZONE:
		stone.albedo_color = Color.WHITE.lerp(ScopeTheme.TEAL, 0.25)  # wet, ice-cemented rock [PLACEHOLDER]
		stone.roughness = 0.5
	_add_blocks("Blocks", rock, rock_colors, stone)
	var molten := ShaderMaterial.new()
	molten.shader = load("res://assets/shaders/magma.gdshader")
	_add_blocks("Magma", magma, magma_colors, molten)


## The small blocks of one floor block in the pool's hollow, darker the deeper.
func _add_hollow_blocks(middle: Vector3, width_m: float, blocks: Array[Transform3D], colors: Array[Color]) -> void:
	var count: int = roundi(width_m / POOL_BLOCK_M)
	for x: int in count:
		for z: int in count:
			var part: Vector3 = middle + Vector3(x - (count - 1) * 0.5, 0.0, z - (count - 1) * 0.5) * POOL_BLOCK_M
			var top_m: float = drawn_ground_m(Vector2(part.x, part.z))
			blocks.append(_block(part + Vector3.UP * (top_m - 1.2) * 0.5, Vector3(POOL_BLOCK_M, top_m + 1.2, POOL_BLOCK_M)))
			colors.append(BASALT_FLOOR.darkened(_hash(roundi(part.x * 4.0), roundi(part.z * 4.0)) * FLOOR_DARKEN_MAX - top_m * 0.5))


func _block(middle: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), middle)


func _add_blocks(blocks_name: String, blocks: Array[Transform3D], colors: Array[Color], material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = blocks.size()
	for i: int in blocks.size():
		multi.set_instance_transform(i, blocks[i])
		multi.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.name = blocks_name
	node.multimesh = multi
	add_child(node)


## How far a stepped course reaches in from its end, never past the middle of
## the span, so a short arch's two courses cannot overlap.
static func course_reach_m(course: int, width_m: float) -> float:
	return minf(PILLAR_M + ARCH_STEP_M * (course + 1), (width_m + PILLAR_M) * 0.5)


## An arch over a run of floor cells that starts at `cell`.
func _build_arch(cell: Vector2i, along: Vector2i) -> void:
	var run: int = 1
	while tile(cell + along * run) == tile(cell):
		run += 1
	var step := Vector3(along.x, 0.0, along.y)
	var across := Vector3(along.y, 0.0, along.x)
	var width_m: float = run * CELL_M
	var middle: Vector3 = at(cell) + step * (run - 1) * CELL_M * 0.5
	_add_body("Arch", LAYER_OCCLUDER, middle + Vector3.UP * (ARCH_SIGNAL_M + ROCK_M) * 0.5,
		step * width_m + across * 2.0 + Vector3.UP * (ROCK_M - ARCH_SIGNAL_M))
	var stone := StandardMaterial3D.new()
	stone.albedo_color = BASALT.darkened(ARCH_DARKEN)
	stone.roughness = 1.0
	for side: float in [-1.0, 1.0]:
		var size: Vector3 = step * PILLAR_M + across * 2.0 + Vector3.UP * ARCH_LOW_M
		var foot: Vector3 = middle + step * side * width_m * 0.5 + Vector3.UP * ARCH_LOW_M * 0.5
		_add_mesh(foot, size, stone)
		_add_body("Pillar", LAYER_WORLD, foot, size)
	var lintel: StandardMaterial3D = stone.duplicate()
	lintel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lintel.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	# Above the pillars the stone steps in course by course and a capstone spans
	# the top, so the opening is a stepped arch you can see through. Nothing here
	# is solid below ARCH_LOW_M, where the rover and walkers pass.
	var course_m: float = (ARCH_HIGH_M - ARCH_LOW_M) / (ARCH_COURSES + 1.0)
	for course: int in ARCH_COURSES:
		var reach_m: float = course_reach_m(course, width_m)
		var base_m: float = ARCH_LOW_M + course_m * course
		for side: float in [-1.0, 1.0]:
			var edge_m: float = width_m * 0.5 + PILLAR_M * 0.5
			_add_mesh(middle + step * side * (edge_m - reach_m * 0.5) + Vector3.UP * (base_m + course_m * 0.5),
				step * reach_m + across * 2.0 + Vector3.UP * course_m, lintel)
	_add_mesh(middle + Vector3.UP * (ARCH_HIGH_M - course_m * 0.5),
		step * (width_m + PILLAR_M) + across * 2.0 + Vector3.UP * course_m, lintel)
	# Overhead timber support rib & brass pillar brackets above ARCH_LOW_M [PLACEHOLDER].
	var trim := StandardMaterial3D.new()
	trim.albedo_color = TunnelLook.TIMBER
	trim.roughness = TunnelLook.MATTE_ROUGHNESS
	trim.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trim.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	var rib_root := Node3D.new()
	rib_root.name = &"ArchRib"
	rib_root.add_child(TunnelLook.part(TunnelLook.box(step * (width_m + PILLAR_M * 1.15) + across * 2.18 + Vector3.UP * ARCH_RIB_HEIGHT_M),
		middle + Vector3.UP * (ARCH_HIGH_M + ARCH_RIB_HEIGHT_M * 0.4), trim))
	var brass_mat: Material = TunnelLook.flat_mat(TunnelLook.BRASS)
	for side: float in [-1.0, 1.0]:
		var bracket_at: Vector3 = middle + step * side * width_m * 0.5 + Vector3.UP * (ARCH_LOW_M - ARCH_GUSSET_HEIGHT_M * 0.5)
		rib_root.add_child(TunnelLook.part(TunnelLook.box(step * (PILLAR_M + 0.08) + across * 2.12 + Vector3.UP * ARCH_GUSSET_HEIGHT_M),
			bracket_at, brass_mat))
	add_child(rib_root)
	_lintels[middle] = lintel
	_lintel_trims[middle] = trim


## A model that stops the rover and, but for the low sump, the signal as rock does.
## Not a ModelSlot, which would light its crystals.
func _build_piece(cell: Vector2i, kind: String) -> void:
	var size: Vector3 = PIECES[kind][1]
	var model: Node3D = (load("res://assets/voxels/%s.glb" % PIECES[kind][0]) as PackedScene).instantiate()
	model.name = "Piece%s" % kind
	model.scale = Vector3.ONE * PIECE_VOXEL_M
	model.rotation.y = PIECE_YAW[kind]
	model.position = at(cell) + Vector3.UP * (SUMP_PIECE_M if kind == "S" else 0.0)
	for part: Node in model.find_children(ModelSlot.EMIT_PREFIX + "*", "MeshInstance3D", true, false):
		var mesh := part as MeshInstance3D
		for i: int in mesh.mesh.get_surface_count():
			var unlit: BaseMaterial3D = mesh.get_active_material(i).duplicate()
			unlit.emission_enabled = false
			mesh.set_surface_override_material(i, unlit)
	add_child(model)
	_add_body("Piece", LAYER_WORLD if kind == "S" else LAYER_WORLD | LAYER_OCCLUDER, model.position + Vector3.UP * size.y * 0.5, size)


func _build_crystals(cell: Vector2i) -> void:
	var glow: StandardMaterial3D = _glow(TEAL, 0.9)
	for i: int in 5:
		var pick: float = _hash(cell.x * 7 + i, cell.y * 5 - i)
		var tall_m: float = 0.6 + 1.1 * pick
		var place: Vector3 = at(cell) + Vector3(cos(i * 1.3) * 0.8, tall_m * 0.5, sin(i * 1.3) * 0.8)
		var shard: MeshInstance3D = _add_mesh(place, Vector3(0.35, tall_m, 0.35), glow)
		shard.rotation = Vector3((pick - 0.5) * 0.5, i, (0.5 - pick) * 0.6)
	_add_light(at(cell) + Vector3.UP * 1.5, TEAL, 1.2, 7.0)


func _add_mesh(middle: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var node := MeshInstance3D.new()
	node.mesh = box
	node.position = middle
	add_child(node)
	return node


func _add_light(place: Vector3, color: Color, energy: float, range_m: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.position = place
	add_child(light)


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.4)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


## The same for a place every time, from 0 to 1.
func _hash(x: int, y: int) -> float:
	return absi((x * 73856093) ^ (y * 19349663)) % 997 / 997.0
