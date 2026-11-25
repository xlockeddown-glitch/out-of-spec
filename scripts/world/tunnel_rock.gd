class_name TunnelRock
extends Node3D
## Builds the tunnels from MAP: basalt floor, rock walls, rock arches, crystals
## and magma. Walls on the camera's side are drawn low so the rover is seen,
## but stop the rover and the signal all the same.

## North is up. # rock, . floor, A arch over a north-south passage, B arch over
## an east-west one, * crystals, ~ magma.
const MAP: PackedStringArray = [
	"########################",
	"###*......##############",
	"##.........######~~~~###",
	"##.........#####.~~~~.##",
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
	"######........##########",
	"#######.......##########",
	"##########...###########",
	"##########...###########",
	"########################",
]
const CELL_M: float = 3.0  # [PLACEHOLDER]
const LAYER_WORLD: int = 1
const LAYER_OCCLUDER: int = 4
## The rover drives under this; the signal is stopped from here up.
const ARCH_SIGNAL_M: float = 1.9  # [PLACEHOLDER]
const ARCH_LOW_M: float = 2.3  # [PLACEHOLDER]
const ARCH_HIGH_M: float = 4.0  # [PLACEHOLDER]
const ROCK_M: float = 6.0  # [PLACEHOLDER]
## An arch this near the rover is seen through.
const FADE_NEAR_M: float = 6.0  # [PLACEHOLDER]
const FADE_ALPHA: float = 0.2  # [PLACEHOLDER]

const BASALT := Color("#232832")
const BASALT_FLOOR := Color("#495261")
const TEAL := Color("#38e1c6")
const AMBER := Color("#f5a623")

@export var rover: Node3D

## Each arch's middle and the material of its lintel.
var _lintels: Dictionary[Vector3, StandardMaterial3D] = {}


static func tile(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= MAP.size() or cell.x < 0 or cell.x >= MAP[cell.y].length():
		return "#"
	return MAP[cell.y][cell.x]


## True where the rover can drive.
static func is_floor(cell: Vector2i) -> bool:
	return tile(cell) in ".AB"


## True if the rover can be at this place.
static func holds(place: Vector3) -> bool:
	return is_floor(cell_of(place)) and absf(place.y) < ROCK_M


## The middle of a cell.
static func at(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (MAP[0].length() - 1) * 0.5) * CELL_M, 0.0, (cell.y - (MAP.size() - 1) * 0.5) * CELL_M)


static func cell_of(place: Vector3) -> Vector2i:
	return Vector2i(roundi(place.x / CELL_M + (MAP[0].length() - 1) * 0.5), roundi(place.z / CELL_M + (MAP.size() - 1) * 0.5))


func _ready() -> void:
	_build_colliders()
	_build_blocks()
	for y: int in MAP.size():
		for x: int in MAP[y].length():
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


func _process(delta: float) -> void:
	if rover == null:
		return
	for middle: Vector3 in _lintels:
		var near: bool = middle.distance_to(rover.global_position) < FADE_NEAR_M
		var material: StandardMaterial3D = _lintels[middle]
		material.albedo_color.a = move_toward(material.albedo_color.a, FADE_ALPHA if near else 1.0, delta * 3.0)


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
	var size := Vector3(MAP[0].length() * CELL_M, 1.0, MAP.size() * CELL_M)
	_add_body("Floor", LAYER_WORLD | LAYER_OCCLUDER, Vector3(0.0, -0.5, 0.0), size)
	for y: int in MAP.size():
		var x: int = 0
		while x < MAP[y].length():
			var cell := Vector2i(x, y)
			var kind: String = tile(cell)
			var run: int = 1
			while x + run < MAP[y].length() and tile(cell + Vector2i(run, 0)) == kind:
				run += 1
			x += run
			var middle: Vector3 = at(cell) + Vector3((run - 1) * CELL_M * 0.5, 0.0, 0.0)
			if kind == "#":
				_add_body("Rock", LAYER_WORLD | LAYER_OCCLUDER, middle + Vector3.UP * ROCK_M * 0.5, Vector3(run * CELL_M, ROCK_M, CELL_M))
			elif kind in "*~":
				# Too low to stop the signal.
				_add_body("Low", LAYER_WORLD, middle + Vector3.UP * 0.5, Vector3(run * CELL_M, 1.0, CELL_M))


func _add_body(body_name: String, layer: int, middle: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = middle
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body, true)


func _build_blocks() -> void:
	var rock: Array[Transform3D] = []
	var rock_colors: Array[Color] = []
	var magma: Array[Transform3D] = []
	var magma_colors: Array[Color] = []
	var half: float = CELL_M * 0.5
	for y: int in range(-2, MAP.size() + 2):
		for x: int in range(-2, MAP[0].length() + 2):
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
					var top_m: float = 0.0
					var color: Color = BASALT_FLOOR.darkened(pick * 0.14)
					if kind == "#":
						top_m = 0.5 + 0.35 * pick if _hides_floor(cell) else 2.2 + 1.2 * pick
						color = BASALT.lightened(pick * 0.07)
					rock.append(_block(part + Vector3.UP * (top_m - 1.0) * 0.5, Vector3(half, top_m + 1.0, half)))
					rock_colors.append(color)
	var stone := StandardMaterial3D.new()
	stone.vertex_color_use_as_albedo = true
	stone.vertex_color_is_srgb = true
	stone.roughness = 1.0
	_add_blocks("Blocks", rock, rock_colors, stone)
	var molten := StandardMaterial3D.new()
	molten.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	molten.vertex_color_use_as_albedo = true
	molten.vertex_color_is_srgb = true
	_add_blocks("Magma", magma, magma_colors, molten)


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
	stone.albedo_color = BASALT.lightened(0.12)
	stone.roughness = 1.0
	for side: float in [-1.0, 1.0]:
		var size: Vector3 = step * 0.8 + across * 2.0 + Vector3.UP * ARCH_LOW_M
		var foot: Vector3 = middle + step * side * width_m * 0.5 + Vector3.UP * ARCH_LOW_M * 0.5
		_add_mesh(foot, size, stone)
		_add_body("Pillar", LAYER_WORLD, foot, size)
	var lintel: StandardMaterial3D = stone.duplicate()
	lintel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lintel.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	var height_m: float = ARCH_HIGH_M - ARCH_LOW_M
	_add_mesh(middle + Vector3.UP * (ARCH_LOW_M + height_m * 0.35),
		step * (width_m + 1.6) + across * 2.0 + Vector3.UP * height_m * 0.7, lintel)
	_add_mesh(middle + Vector3.UP * (ARCH_HIGH_M - height_m * 0.15),
		step * (width_m * 0.6) + across * 1.5 + Vector3.UP * height_m * 0.3, lintel)
	_lintels[middle] = lintel


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
