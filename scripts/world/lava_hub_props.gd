class_name LavaHubProps
extends Node3D
## The Lava Tubes hub's props, drawn from primitive meshes (LavaHub says where):
## Orin's beacon rack, the notice board, and a pad at each beacon spot that
## becomes a lit beacon once one is placed. Shows only; no rules.
## Palette and sizes are [PLACEHOLDER] via TunnelLook (ScopeTheme colours only).

const STEEL: Color = TunnelLook.STEEL
const DARK: Color = TunnelLook.BASALT_DARK
const CYAN: Color = TunnelLook.CRYSTAL
## A placed beacon's light [PLACEHOLDER].
const LIGHT_RANGE_M: float = 7.0
const LIGHT_ENERGY: float = 1.2
## Hub arch & rubble accent placement around the rack/board [PLACEHOLDER].
const ARCH_SPAN_M: float = 2.6
const ARCH_HEIGHT_M: float = 2.4
const RUBBLE_OFFSET := Vector3(-1.35, 0.0, -0.35)
const RUBBLE_SCALE: float = 0.65

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
			_add_unplaced_pad(spot)


func spot_node(spot_id: String) -> Node3D:
	return _spots.get(spot_id)


func _add_unplaced_pad(spot: Node3D) -> void:
	# Stepped basalt socket ring with brass anchor lugs and a teal core [PLACEHOLDER].
	spot.add_child(_part(_cylinder(0.82, 0.08), Vector3(0.0, 0.04, 0.0), _flat(TunnelLook.BASALT_DARK)))
	spot.add_child(_part(_cylinder(0.68, 0.06), Vector3(0.0, 0.06, 0.0), _flat(TunnelLook.BASALT_MID)))
	spot.add_child(_part(_cylinder(0.42, 0.04), Vector3(0.0, 0.08, 0.0), _glow(CYAN, 0.45)))
	for angle_deg: float in [45.0, 135.0, 225.0, 315.0]:
		var rad: float = deg_to_rad(angle_deg)
		spot.add_child(_part(_box(Vector3(0.14, 0.09, 0.14)), Vector3(cos(rad) * 0.68, 0.06, sin(rad) * 0.68), _flat(TunnelLook.BRASS)))


func _add_beacon(spot: Node3D) -> void:
	# Stepped basalt plinth, brass collar, steel mast, and glowing teal cap [PLACEHOLDER].
	spot.add_child(_part(_cylinder(0.42, 0.12), Vector3(0.0, 0.06, 0.0), _flat(DARK)))
	spot.add_child(_part(_cylinder(0.28, 0.10), Vector3(0.0, 0.16, 0.0), _flat(TunnelLook.BASALT_MID)))
	spot.add_child(_part(_cylinder(0.12, 0.12), Vector3(0.0, 0.26, 0.0), _flat(TunnelLook.BRASS)))
	spot.add_child(_part(_cylinder(0.06, 1.15), Vector3(0.0, 0.80, 0.0), _flat(STEEL)))
	spot.add_child(_part(_box(Vector3(0.22, 0.06, 0.22)), Vector3(0.0, 1.32, 0.0), _flat(TunnelLook.BRASS)))
	spot.add_child(_part(_sphere(0.16), Vector3(0.0, 1.44, 0.0), _glow(CYAN, 1.6)))
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.44, 0.0)
	light.light_color = CYAN
	light.omni_range = LIGHT_RANGE_M
	light.light_energy = LIGHT_ENERGY
	spot.add_child(light)


func _build_rack() -> void:
	var rack := Node3D.new()
	rack.name = "BeaconRack"
	rack.position = LavaHub.rack_position()
	add_child(rack)
	# Stepped basalt plinth, steel posts with brass gussets, timber top beam [PLACEHOLDER].
	rack.add_child(_part(_box(Vector3(2.0, 0.16, 0.84)), Vector3(0.0, 0.08, 0.0), _flat(DARK)))
	rack.add_child(_part(_box(Vector3(1.8, 0.10, 0.64)), Vector3(0.0, 0.20, 0.0), _flat(TunnelLook.BASALT_MID)))
	for x: float in [-0.85, 0.85]:
		rack.add_child(_part(_box(Vector3(0.14, 1.35, 0.14)), Vector3(x, 0.82, 0.0), _flat(STEEL)))
		rack.add_child(_part(_box(Vector3(0.20, 0.14, 0.20)), Vector3(x, 1.42, 0.0), _flat(TunnelLook.BRASS)))
	rack.add_child(_part(_box(Vector3(2.05, 0.14, 0.18)), Vector3(0.0, 1.52, 0.0), _flat(TunnelLook.TIMBER)))
	rack.add_child(_label("BEACON RACK", Vector3(0.0, 2.05, 0.0)))
	TunnelLook.add_rubble_pile(rack, RUBBLE_OFFSET, RUBBLE_SCALE)
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
		_rack_beacons.add_child(_part(_cylinder(0.10, 0.08), Vector3(x, 0.29, 0.0), _flat(TunnelLook.BRASS)))
		_rack_beacons.add_child(_part(_cylinder(0.05, 0.86), Vector3(x, 0.72, 0.0), _flat(STEEL)))
		_rack_beacons.add_child(_part(_sphere(0.12), Vector3(x, 1.22, 0.0), _glow(CYAN, 1.2)))


func _build_board() -> void:
	var board: Node3D = board_node("NOTICE BOARD")
	board.position = LavaHub.board_position()
	add_child(board)
	# Frame the hub board under a sturdy support-beam arch [PLACEHOLDER].
	TunnelLook.add_support_arch(board, Vector3(0.0, 0.0, -0.35), ARCH_SPAN_M, ARCH_HEIGHT_M)


## A notice board: stepped footplates, steel posts, timber backing & cap, brass
## corner brackets, two pinned cream notes, and `title` over it. The lava hub's
## and the farm's (NoticeBoard) are built the same way, at the origin of the node
## returned; the caller puts it down. Every size is a [PLACEHOLDER].
static func board_node(title: String) -> Node3D:
	var board := Node3D.new()
	board.name = "NoticeBoard"
	for x: float in [-0.82, 0.82]:
		board.add_child(_part(_box(Vector3(0.28, 0.12, 0.28)), Vector3(x, 0.06, 0.0), _flat(DARK)))
		board.add_child(_part(_box(Vector3(0.14, 1.56, 0.14)), Vector3(x, 0.82, 0.0), _flat(STEEL)))
		board.add_child(_part(_box(Vector3(0.18, 0.14, 0.18)), Vector3(x, 1.56, 0.0), _flat(TunnelLook.BRASS)))
	board.add_child(_part(_box(Vector3(1.94, 1.04, 0.12)), Vector3(0.0, 1.12, 0.0), _flat(TunnelLook.TIMBER)))
	board.add_child(_part(_box(Vector3(2.12, 0.12, 0.22)), Vector3(0.0, 1.66, 0.0), _flat(TunnelLook.TIMBER_LIGHT)))
	# Two pinned cream notices with brass tacks [PLACEHOLDER].
	board.add_child(_part(_box(Vector3(0.52, 0.36, 0.02)), Vector3(-0.4, 1.25, 0.075), _flat(TunnelLook.CREAM)))
	board.add_child(_part(_box(Vector3(0.06, 0.06, 0.03)), Vector3(-0.4, 1.39, 0.085), _flat(TunnelLook.BRASS)))
	board.add_child(_part(_box(Vector3(0.52, 0.36, 0.02)), Vector3(0.35, 0.95, 0.075), _flat(TunnelLook.CREAM)))
	board.add_child(_part(_box(Vector3(0.06, 0.06, 0.03)), Vector3(0.35, 1.09, 0.085), _flat(TunnelLook.BRASS)))
	board.add_child(_label(title, Vector3(0.0, 2.0, 0.0)))
	return board


static func _box(size: Vector3) -> Mesh:
	return TunnelLook.box(size)


static func _cylinder(radius: float, height: float) -> Mesh:
	return TunnelLook.cylinder(radius, height)


static func _sphere(radius: float) -> Mesh:
	return TunnelLook.sphere(radius)


## A fresh material each call: other scenes (e.g. FloodedAquifer's pools) change
## what they get back, so these two never hand out TunnelLook's shared cache.
static func _flat(color: Color) -> StandardMaterial3D:
	return TunnelLook.flat_mat(color).duplicate() as StandardMaterial3D


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	return TunnelLook.glow_mat(color, energy, false)


static func _part(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	return TunnelLook.part(mesh, at, material)


static func _label(text: String, at: Vector3) -> Label3D:
	return TunnelLook.label(text, at, CYAN)
