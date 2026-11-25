class_name WalkerModel
extends Node3D
## The Remote Operator on foot, original voxels in code: a colored suit, dark
## boots and pack, teal visor [PLACEHOLDER]. Feet at the origin, facing -Z.

const VOXEL_M: float = 0.2
## The host's suit, and the solo one.
const SUIT := Color("#d9772b")
## Guests' suits, in order of preference [PLACEHOLDER]. They differ in lightness
## as well as hue, and none is teal, amber or red, which the HUD uses.
const GUEST_SUITS: Array[Color] = [Color("#2b4fb0"), Color("#d9b8f2"), Color("#2f7a3a"), Color("#e8e6df")]
const DARK := Color("#1d222b")
const VISOR := Color("#38e1c6")
const GEAR := Color("#3a4250")
const MAST := Color("#c8ccd2")
## The two legs swap this often, in meters walked [PLACEHOLDER].
const STEP_M: float = 0.7
const SWING_M: float = 0.2
## Arms swing against the legs, this many radians at most [PLACEHOLDER].
const ARM_SWING: float = 0.45

var speed_mps: float = 0.0

var _legs: Array[MeshInstance3D] = []
var _arms: Array[Node3D] = []
var _suit_materials: Array[StandardMaterial3D] = []
var _pads_materials: Array[StandardMaterial3D] = []
var _suit: Color = SUIT
var _walked_m: float = 0.0


func _init() -> void:
	# Place and size in voxels: 4 wide, 8 tall, 3 deep.
	for x: float in [-1.0, 1.0]:
		var leg: MeshInstance3D = _box(Vector3(x * 0.75, 1.5, 0.0), Vector3(1.0, 3.0, 1.0), SUIT)
		leg.add_child(_made(Vector3(0.0, -1.0, -0.1), Vector3(1.1, 1.0, 1.3), DARK))
		_legs.append(leg)
		# The arm hangs from the shoulder, so it swings about it.
		var arm := Node3D.new()
		arm.position = Vector3(x * 1.625, 5.0, 0.0) * VOXEL_M
		add_child(arm)
		arm.add_child(_made(Vector3(0.0, -1.0, 0.0), Vector3(0.75, 2.0, 1.0), SUIT))
		arm.add_child(_made(Vector3(0.0, -2.1, 0.0), Vector3(0.8, 0.5, 1.1), DARK))
		arm.add_child(_made(Vector3(0.0, 0.1, 0.0), Vector3(1.0, 0.6, 1.3), SUIT, true))
		_arms.append(arm)
	_box(Vector3(0.0, 4.25, 0.0), Vector3(2.5, 2.5, 1.5), SUIT)
	_box(Vector3(0.0, 4.5, 1.25), Vector3(2.0, 2.0, 1.0), DARK)
	# Pack: two side tanks and a short mast. The mast stays under the head's top.
	for x: float in [-0.8, 0.8]:
		_box(Vector3(x, 4.4, 1.95), Vector3(0.6, 1.5, 0.5), GEAR)
	_box(Vector3(0.6, 6.0, 1.4), Vector3(0.2, 2.0, 0.2), MAST)
	_box(Vector3(0.6, 7.1, 1.4), Vector3(0.4, 0.3, 0.4), DARK)
	_box(Vector3(0.0, 6.75, 0.0), Vector3(2.5, 2.5, 2.5), SUIT)
	_box(Vector3(0.0, 6.75, -1.15), Vector3(2.0, 1.2, 0.5), VISOR)


func _process(delta: float) -> void:
	_walked_m += speed_mps * delta
	step(0.0 if speed_mps < 0.1 else (1.0 if fmod(_walked_m, STEP_M * 2.0) < STEP_M else -1.0))


## 1 or -1 for which leg is in front, 0 to stand.
func step(front: float) -> void:
	_legs[0].position.z = -front * SWING_M
	_legs[1].position.z = front * SWING_M
	# Each arm goes forward with the opposite leg.
	_arms[0].rotation.x = -front * ARM_SWING
	_arms[1].rotation.x = front * ARM_SWING


## Dresses the model in `color`. Shoulder pads are a darker shade of it.
func set_suit(color: Color) -> void:
	_suit = color
	for material: StandardMaterial3D in _suit_materials:
		material.albedo_color = color
	for material: StandardMaterial3D in _pads_materials:
		material.albedo_color = color.darkened(0.25)


func suit() -> Color:
	return _suit


## The suit for a player, from the roster as every screen has it (the host first,
## the others in the order they joined). The host is orange. A guest has a
## preferred color from the number in its id, and when an earlier player already
## has that one it takes the next free one. So a leaver changes nobody's color
## unless two had shared a preference.
static func suit_for(player_id: String, roster: Array[String]) -> Color:
	if roster.is_empty() or roster[0] == player_id or not player_id in roster:
		return SUIT
	var taken: Array[int] = []
	for other: String in roster.slice(1):
		var at: int = _preferred(other)
		while at in taken:
			at = (at + 1) % GUEST_SUITS.size()
		if other == player_id:
			return GUEST_SUITS[at]
		taken.append(at)
	return SUIT


static func _preferred(player_id: String) -> int:
	var number: String = player_id.trim_prefix("player_")
	var n: int = number.to_int() if number.is_valid_int() else player_id.hash()
	# player_2, the first guest, gets the first suit.
	return posmod(n - 2, GUEST_SUITS.size())


func _box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var made: MeshInstance3D = _made(at, size, color)
	add_child(made)
	return made


func _made(at: Vector3, size: Vector3, color: Color, pad: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size * VOXEL_M
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material = material
	if color == SUIT:
		(_pads_materials if pad else _suit_materials).append(material)
	if pad:
		material.albedo_color = color.darkened(0.25)
	var made := MeshInstance3D.new()
	made.mesh = mesh
	made.position = at * VOXEL_M
	return made
