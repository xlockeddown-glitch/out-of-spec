class_name OreFissure
extends Node3D
## Shallow cyan quartz fissure on the Terracotta Plateau. The rover mines it
## with the drill/till action (Space) while parked on top. Regrows on a later
## morning (GameState). Greybox crystals are built in code; a MagicaVoxel model
## at res://assets/voxels/ore_fissure.glb replaces them automatically.

const MODEL_PATH: String = "res://assets/voxels/ore_fissure.glb"
const MINE_RADIUS_M: float = 2.0

@export var fissure_id: StringName = &""

var _visual: Node3D


func _ready() -> void:
	if fissure_id == &"":
		fissure_id = StringName(name)
	_visual = _build_visual()
	add_child(_visual)
	GameState.fissures_changed.connect(_refresh)
	_refresh()


func is_available() -> bool:
	return GameState.is_fissure_available(fissure_id)


## Horizontal distance check against the rover's position.
func is_in_reach(world_pos: Vector3) -> bool:
	var d := Vector2(world_pos.x - global_position.x, world_pos.z - global_position.z)
	return d.length() <= MINE_RADIUS_M


func _refresh() -> void:
	_visual.visible = is_available()


func _build_visual() -> Node3D:
	if ResourceLoader.exists(MODEL_PATH):
		var scene := load(MODEL_PATH) as PackedScene
		if scene != null:
			return scene.instantiate()
		push_warning("OreFissure: %s is not a scene; using greybox." % MODEL_PATH)
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#38E1C6")
	mat.emission_enabled = true
	mat.emission = Color("#38E1C6")
	mat.emission_energy_multiplier = 1.6
	# Three chunky crystals at fixed angles (deterministic per fissure).
	var specs: Array = [
		[Vector3(0, 0.45, 0), Vector3(0.35, 0.9, 0.35), Vector3(0, 0, 12)],
		[Vector3(0.35, 0.3, 0.15), Vector3(0.25, 0.6, 0.25), Vector3(10, 0, -25)],
		[Vector3(-0.3, 0.25, -0.2), Vector3(0.22, 0.5, 0.22), Vector3(-15, 0, 20)],
	]
	for spec: Array in specs:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = spec[1]
		mesh.material = mat
		box.mesh = mesh
		box.position = spec[0]
		box.rotation_degrees = spec[2]
		root.add_child(box)
	var glow := OmniLight3D.new()
	glow.light_color = Color("#38E1C6")
	glow.light_energy = 0.8
	glow.omni_range = 3.0
	glow.position = Vector3(0, 0.8, 0)
	root.add_child(glow)
	return root
