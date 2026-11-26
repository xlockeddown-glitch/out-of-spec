class_name LavaHubProps
extends Node3D
## The Lava Tubes hub's props, drawn from primitive meshes (LavaHub says where):
## Orin's beacon rack, the notice board, and a pad at each beacon spot that
## becomes a lit beacon once one is placed. Shows only; no rules.

const STEEL := Color(0.45, 0.48, 0.54)
const DARK := Color(0.12, 0.12, 0.13)
const CYAN := Color(0.2196, 0.8824, 0.7765)
## A placed beacon's light [PLACEHOLDER].
const LIGHT_RANGE_M: float = 7.0
const LIGHT_ENERGY: float = 1.2

## Spot id -> the node that shows it.
var _spots: Dictionary[String, Node3D] = {}
## The rack's beacons, one for each not yet placed.
var _rack_beacons: Node3D


func _ready() -> void:
	_build_rack()
	_build_board()
	_show_rack(GameState.beacons_placed.size())
	for spot_id: String in LavaHub.spot_ids():
		var spot := Node3D.new()
		spot.name = "Spot_" + spot_id
		spot.position = LavaHub.spot_position(spot_id)
		add_child(spot)
		_spots[spot_id] = spot
	show_placed(GameState.beacons_placed)


## One pad for each spot without a beacon, a lit one for each with.
func show_placed(placed: Array) -> void:
	_show_rack(placed.size())
	for spot_id: String in _spots:
		var spot: Node3D = _spots[spot_id]
		for child: Node in spot.get_children():
			child.queue_free()
		if spot_id in placed:
			_add_beacon(spot)
		else:
			spot.add_child(_part(_cylinder(0.7, 0.05), Vector3(0.0, 0.025, 0.0), _glow(CYAN, 0.4)))


func spot_node(spot_id: String) -> Node3D:
	return _spots.get(spot_id)


func _add_beacon(spot: Node3D) -> void:
	spot.add_child(_part(_cylinder(0.3, 0.1), Vector3(0.0, 0.05, 0.0), _flat(DARK)))
	spot.add_child(_part(_cylinder(0.06, 1.2), Vector3(0.0, 0.7, 0.0), _flat(STEEL)))
	spot.add_child(_part(_sphere(0.16), Vector3(0.0, 1.4, 0.0), _glow(CYAN, 1.6)))
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.4, 0.0)
	light.light_color = CYAN
	light.omni_range = LIGHT_RANGE_M
	light.light_energy = LIGHT_ENERGY
	spot.add_child(light)


func _build_rack() -> void:
	var rack := Node3D.new()
	rack.name = "BeaconRack"
	rack.position = LavaHub.rack_position()
	add_child(rack)
	rack.add_child(_part(_box(Vector3(1.8, 0.15, 0.7)), Vector3(0.0, 0.075, 0.0), _flat(DARK)))
	rack.add_child(_part(_box(Vector3(0.1, 1.3, 0.1)), Vector3(-0.85, 0.7, 0.0), _flat(STEEL)))
	rack.add_child(_part(_box(Vector3(0.1, 1.3, 0.1)), Vector3(0.85, 0.7, 0.0), _flat(STEEL)))
	rack.add_child(_part(_box(Vector3(1.8, 0.08, 0.08)), Vector3(0.0, 1.3, 0.0), _flat(STEEL)))
	rack.add_child(_label("BEACON RACK", Vector3(0.0, 1.9, 0.0)))
	_rack_beacons = Node3D.new()
	_rack_beacons.name = "Beacons"
	rack.add_child(_rack_beacons)


## One beacon on the rack for each not yet placed.
func _show_rack(placed: int) -> void:
	if _rack_beacons == null:
		return
	for child: Node in _rack_beacons.get_children():
		child.queue_free()
	for i: int in maxi(LavaHub.SPOTS.size() - placed, 0):
		var x: float = -0.5 + 0.5 * i
		_rack_beacons.add_child(_part(_cylinder(0.05, 0.9), Vector3(x, 0.6, 0.0), _flat(STEEL)))
		_rack_beacons.add_child(_part(_sphere(0.12), Vector3(x, 1.1, 0.0), _glow(CYAN, 1.2)))


func _build_board() -> void:
	var board := Node3D.new()
	board.name = "NoticeBoard"
	board.position = LavaHub.board_position()
	add_child(board)
	board.add_child(_part(_box(Vector3(0.12, 1.5, 0.12)), Vector3(-0.8, 0.75, 0.0), _flat(STEEL)))
	board.add_child(_part(_box(Vector3(0.12, 1.5, 0.12)), Vector3(0.8, 0.75, 0.0), _flat(STEEL)))
	board.add_child(_part(_box(Vector3(1.9, 1.0, 0.1)), Vector3(0.0, 1.1, 0.0), _flat(Color(0.30, 0.24, 0.17))))
	board.add_child(_part(_box(Vector3(0.5, 0.35, 0.02)), Vector3(-0.4, 1.25, 0.07), _flat(Color(0.9, 0.88, 0.8))))
	board.add_child(_part(_box(Vector3(0.5, 0.35, 0.02)), Vector3(0.35, 0.95, 0.07), _flat(Color(0.9, 0.88, 0.8))))
	board.add_child(_label("NOTICE BOARD", Vector3(0.0, 2.0, 0.0)))


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


static func _sphere(radius: float) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
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


static func _label(text: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.pixel_size = 0.01
	label.font_size = 32
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = CYAN
	return label
