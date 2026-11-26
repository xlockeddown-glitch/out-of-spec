class_name CisternGauge
extends Node3D
## A sight glass on the cistern: a dark slot with the water standing in it, as
## full as GameState.cistern_liters. It only reads the level, so a guest sees
## the host's. Water colors from VoxelWater, no glow.

## Slot size in meters [PLACEHOLDER]: up the tank's body, in a steel frame.
const SLOT_SIZE: Vector3 = Vector3(0.5, 1.2, 0.04)
const FRAME_SIZE: Vector3 = Vector3(0.62, 1.32, 0.03)
const FRAME_COLOR := Color("#6c7a89")
## The water rises in these steps [PLACEHOLDER].
const STEPS: int = 20
const SLOT_COLOR := Color("#1d222b")

var _water: MeshInstance3D
var _material := StandardMaterial3D.new()
var _shown: int = -1
var _color: Color = VoxelWater.SHALLOW


func _ready() -> void:
	var frame: MeshInstance3D = _box(FRAME_SIZE, FRAME_COLOR)
	frame.position.y = SLOT_SIZE.y * 0.5
	add_child(frame)
	var slot: MeshInstance3D = _box(SLOT_SIZE, SLOT_COLOR)
	slot.position.y = SLOT_SIZE.y * 0.5
	_water = _box(Vector3(SLOT_SIZE.x * 0.8, SLOT_SIZE.y - 0.04, SLOT_SIZE.z + 0.03), VoxelWater.SHALLOW)
	_water.material_override = _material
	_material.roughness = 1.0
	# It stands on the tank's shaded face, where lit water reads almost black.
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	add_child(slot)
	add_child(_water)
	_update()


func _process(_delta: float) -> void:
	_update()
	_dim()


## Steps of water for a level, 0 only when empty.
static func steps_for(liters: float, capacity: float) -> int:
	if liters <= 0.0:
		return 0
	return clampi(ceili(liters / capacity * STEPS), 1, STEPS)


func _update() -> void:
	var steps: int = steps_for(GameState.cistern_liters, GameState.CISTERN_CAPACITY_L)
	if steps == _shown:
		return
	_shown = steps
	_water.visible = steps > 0
	var height: float = (SLOT_SIZE.y - 0.04) * float(steps) / STEPS
	_water.scale.y = maxf(height, 0.001) / (SLOT_SIZE.y - 0.04)
	# The water's foot stays on the slot's bottom.
	_water.position.y = 0.02 + height * 0.5
	_color = VoxelWater.SHALLOW.lerp(VoxelWater.DEEP, 1.0 - float(steps) / STEPS)


## Unshaded water would glow at night, so it dims with the farm's ambient light.
func _dim() -> void:
	var environment: Environment = get_world_3d().environment
	var level: float = clampf(environment.ambient_light_energy, 0.0, 1.0) if environment else 1.0
	_material.albedo_color = _color * Color(level, level, level)


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	node.material_override = material
	return node
