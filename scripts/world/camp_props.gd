class_name CampProps
extends Node3D
## A zone hub's camp, drawn from primitive meshes (Camp says where): a tent, a heater
## and a bedroll. Shown only once the farm has opened the camp; while it is shut the
## spot is bare floor and nothing changes for anyone. Shows only; no rules.

const CANVAS := Color(0.62, 0.55, 0.42)
const ROLL := Color(0.28, 0.34, 0.40)
const STEEL := Color(0.45, 0.48, 0.54)
const DARK := Color(0.12, 0.12, 0.13)
const EMBER := Color(0.95, 0.55, 0.2)
## The heater's glow [PLACEHOLDER].
const LIGHT_RANGE_M: float = 5.0
const LIGHT_ENERGY: float = 0.9

var _zone: String = ""
var _camp: Node3D


func _init(zone: String = "") -> void:
	_zone = zone


func _ready() -> void:
	name = "Camp"
	_camp = Node3D.new()
	_camp.name = "CampSpot"
	_camp.position = Camp.position(_zone)
	add_child(_camp)
	_camp.add_child(_part(_tent_mesh(), Vector3(0.0, 0.7, 0.0), _flat(CANVAS)))
	_camp.add_child(_part(_box(Vector3(2.0, 0.04, 2.4)), Vector3(0.0, 0.02, 0.0), _flat(DARK)))
	_camp.add_child(_part(_box(Vector3(0.7, 0.1, 1.6)), Vector3(1.8, 0.07, 0.0), _flat(ROLL)))
	_camp.add_child(_part(_cylinder(0.22, 0.5), Vector3(-1.6, 0.25, 0.9), _flat(STEEL)))
	_camp.add_child(_part(_cylinder(0.14, 0.05), Vector3(-1.6, 0.52, 0.9), _glow(EMBER, 1.4)))
	var light := OmniLight3D.new()
	light.position = Vector3(-1.6, 0.9, 0.9)
	light.light_color = EMBER
	light.omni_range = LIGHT_RANGE_M
	light.light_energy = LIGHT_ENERGY
	_camp.add_child(light)
	show_open(GameState.camps_open.has(_zone))
	GameState.camps_changed.connect(_on_camps_changed)


func _on_camps_changed() -> void:
	show_open(GameState.camps_open.has(_zone))


## Shown once the farm has opened this zone's camp.
func show_open(open: bool) -> void:
	if _camp != null:
		_camp.visible = open


func is_shown() -> bool:
	return _camp != null and _camp.visible


## The camp's tent: a triangular prism lying along the cell's z axis.
static func _tent_mesh() -> Mesh:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(2.0, 1.4, 2.2)
	return mesh


static func _box(size: Vector3) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cylinder(radius: float, height: float) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh


static func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.BLACK
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func _part(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.material_override = material
	return part
