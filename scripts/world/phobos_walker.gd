class_name PhobosWalker
extends CharacterBody3D
## This screen's player on foot on a moon: a flat deck, so no terrain, no water and no
## rover. It is not sent to the farm's walkers: nobody on the farm sees it (the farm
## shows only those on the farm). On a moon it has the moon's low gravity (MoonGravity):
## each step is a small hop, a jump carries it past its mark and in the air it steers
## only a little. With the tether on it walks flat steps, cannot jump and steers fully. All of that is
## local to this screen; nothing here is saved or sent.

const SPEED_MPS: float = Walker.SPEED_MPS
## The deck's edge, from its middle [PLACEHOLDER].
const EDGE_M: float = 34.0
const FALL_MPS2: float = Walker.FALL_MPS2
## How fast the body settles when the hop stops, m/s [PLACEHOLDER].
const HOP_EASE_MPS: float = 0.5

## The tether is on: flat steps, no jump. Every player has one; it is a toggle that
## lasts while the game runs, and is neither bought nor saved [PLACEHOLDER].
static var tethered: bool = false

var camera: Camera3D
var model := WalkerModel.new()
## Which moon the walker stands on (the hubs set it); any other place has the farm's pull.
var moon: String = Shuttle.PHOBOS
var _walked_s: float = 0.0


func _init() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	shape.shape = Walker.capsule()
	shape.position.y = Walker.TALL_M / 2.0
	add_child(shape)
	add_child(model)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"moon_tether", false) and not RoverController.input_blocked \
			and not QuestsUI.other_panel_open(get_tree()):
		set_tether(not tethered)
		get_viewport().set_input_as_handled()


func set_tether(on: bool) -> void:
	tethered = on


## The line the moon screens show: what a jump and the tether do, with the keys.
static func hint_text() -> String:
	return Shuttle.text("hub_low_gravity") % [Controls.prompt(&"rover_till"), Controls.prompt(&"moon_tether"),
		Shuttle.text("hub_tether_on" if tethered else "hub_tether_off")]


func _physics_process(delta: float) -> void:
	var keys := Vector2.ZERO
	var blocked: bool = RoverController.input_blocked or RoverController.panel_has_stick(get_tree()) \
			or QuestsUI.other_panel_open(get_tree())
	if camera != null and not blocked:
		keys = Vector2(Input.get_axis(&"rover_steer_left", &"rover_steer_right"),
			Input.get_axis(&"rover_forward", &"rover_reverse"))
	var jump: bool = camera != null and not blocked and Input.is_action_just_pressed(&"rover_till")
	walk(Walker.heading(keys, camera.global_basis) if camera != null else Vector3.ZERO, delta, jump)


## One tick. `to` is the heading (up to 1 long); `jump` asks for a jump, which a walker
## on the deck, off the tether, on a moon takes.
func walk(to: Vector3, delta: float, jump: bool = false) -> void:
	var speed: float = MoonGravity.speed_mps(moon)
	var fall: float = MoonGravity.fall_mps2(moon)
	var sideways := Vector3.ZERO
	var rise: float = 0.0
	if is_on_floor():
		sideways = to * speed
		if jump and not tethered and MoonGravity.is_moon(moon):
			rise = MoonGravity.jump_mps(moon)
	else:
		# A tether switched on in the air steers fully only once the walker is down.
		sideways = MoonGravity.air_velocity(velocity, to, speed, delta, false)
		rise = velocity.y - fall * delta
	velocity = sideways + Vector3.UP * rise
	if to != Vector3.ZERO:
		rotation.y = atan2(-to.x, -to.z)
	move_and_slide()
	var raw := Vector2(global_position.x, global_position.z)
	var flat: Vector2 = raw.limit_length(EDGE_M)
	if flat != raw:
		# At the deck's edge only the outward part of the momentum stops, so a graze slides.
		var out := Vector3(flat.x - raw.x, 0.0, flat.y - raw.y).normalized() * -1.0
		var outward: float = maxf(velocity.dot(out), 0.0)
		velocity -= out * outward
	global_position = Vector3(flat.x, maxf(global_position.y, 0.0), flat.y)
	var real: Vector3 = get_real_velocity()
	model.speed_mps = Vector2(real.x, real.z).length()
	_hop(delta, model.speed_mps > 0.1 and is_on_floor())


## The body's small lift with each step: only the model rises, never the collider.
func _hop(delta: float, stepping: bool) -> void:
	if stepping:
		_walked_s = fmod(_walked_s + delta, MoonGravity.hop_s(moon))
	else:
		_walked_s = 0.0
	var lift: float = MoonGravity.hop_offset_m(moon, _walked_s, tethered)
	# Standing, the body eases down instead of snapping.
	model.position.y = lift if stepping else move_toward(model.position.y, 0.0, HOP_EASE_MPS * delta)
