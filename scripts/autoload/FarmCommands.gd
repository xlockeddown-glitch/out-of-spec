extends Node
## The one way a screen changes the farm: a named action with plain arguments.
## Alone, or as the host, it happens at once. In co-op a guest's goes to the host,
## which says who acts; the arguments never do.

## What a screen may ask for. Each is a GameState function; its own types are
## the argument types, and its player argument is filled in here.
const ACTIONS: Array[StringName] = [
	&"accept_job", &"add_robot_calibrate_card", &"add_robot_card", &"add_robot_collect_card",
	&"adjust_setpoint", &"build_robot", &"buy_from_kestrel", &"buy_standard", &"buy_wide_treads",
	&"calibrate_at_bench", &"check_with_block", &"clear_lab_area", &"collect_spool", &"complete_job", &"dig", &"fill", &"fit_lab_area", &"get_up", &"go_to_bed",
	&"harvest_crop", &"hit_boulder", &"mine_fissure", &"plant_crop", &"release_robot", &"remove_robot_card",
	&"sell_harvest_to_lin", &"send_to_oirm", &"set_interlock_override", &"slot_spool_into_relay",
	&"start_lab_grow", &"till", &"zero_steering",
]
const PLAYER_ARGUMENTS: Array[String] = ["player_id", "performed_by"]

## True while a guest: nothing is done here, only asked for.
var guest: bool = false
## A guest's way to the host: called with (action, arguments), it returns the
## host's answer, maybe later.
var remote: Callable
## The farm acted on. Only tests set another.
var state: Node

var _waiting: bool = false


## Does `action` for the player at this screen and returns GameState's own answer,
## or a refusal of the same type. Await it: the host's answer takes time.
func request(action: StringName, arguments: Array = []) -> Variant:
	if not guest:
		return execute(_farm().local_player_id, action, arguments)
	if problem(action, arguments) != "":
		return refusal(action, problem(action, arguments))
	if not remote.is_valid():
		return refusal(action, "Not connected to the host.")
	# A second press before the answer must not act twice.
	if _waiting:
		return refusal(action, "Still waiting for the host.")
	_waiting = true
	var answer: Variant = await remote.call(action, arguments)
	_waiting = false
	if typeof(answer) != _method(action)["return"]["type"]:
		return refusal(action, "The host gave no answer.")
	return answer


## On the host: does `action` as `player_id`, who must come from the connection.
func execute(player_id: String, action: StringName, arguments: Array) -> Variant:
	# GameState would take no name as the host's own.
	var reason: String = "No player is named." if player_id == "" else problem(action, arguments)
	if reason != "":
		return refusal(action, reason)
	# Whoever does something is up.
	if action != &"go_to_bed":
		CoopBeds.get_up(player_id)
	var passed: Array = arguments.duplicate()
	if _player_index(action) >= 0:
		passed.append(player_id)
	return _farm().callv(action, passed)


## Why these can't be asked for, or "". The values are GameState's to judge.
func problem(action: StringName, arguments: Array) -> String:
	if not action in ACTIONS:
		return "'%s' is not a farm command." % action
	var expected: Array = _method(action)["args"]
	if _player_index(action) >= 0:
		expected = expected.slice(0, _player_index(action))
	if arguments.size() != expected.size():
		return "'%s' takes %d arguments, not %d." % [action, expected.size(), arguments.size()]
	for i: int in expected.size():
		if typeof(arguments[i]) != expected[i]["type"]:
			return "'%s' has a bad %s." % [action, expected[i]["name"]]
	return ""


## `reason`, shaped as the action's own answer. "no_answer" tells a screen
## that this is not GameState's answer, so it may try again.
func refusal(action: StringName, reason: String) -> Variant:
	match (_method(action)["return"]["type"] as int) if action in ACTIONS else TYPE_STRING:
		TYPE_BOOL:
			return false
		TYPE_INT:
			return 0
		TYPE_FLOAT:
			return -1.0
		TYPE_DICTIONARY:
			return { "ok": false, "refused": true, "no_answer": true, "reason": reason }
	return reason


## What a rover reports every tick. The host measures the rovers it simulates, so
## these are not actions: a guest can't send them, and its own rover changes nothing.
func rover_drove(meters: float) -> void:
	if not guest:
		_farm().add_rover_usage(meters, _farm().local_player_id)


func rover_uplink(rover_id: String, has_los: bool) -> void:
	if not guest:
		_farm().set_rover_uplink(rover_id, has_los)


func rover_parked(rover_id: String, at: Transform3D) -> void:
	if not guest:
		_farm().park_rover(rover_id, at)


## Where the player goes among the action's arguments, or -1. Anything after it
## is never asked for.
func _player_index(action: StringName) -> int:
	var args: Array = _method(action)["args"]
	for i: int in args.size():
		if args[i]["name"] in PLAYER_ARGUMENTS:
			return i
	return -1


func _method(action: StringName) -> Dictionary:
	for method: Dictionary in (_farm().get_script() as GDScript).get_script_method_list():
		if method["name"] == action:
			return method
	return {}


func _farm() -> Node:
	return state if state != null else GameState
