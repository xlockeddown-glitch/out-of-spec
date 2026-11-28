extends Node
## The one way a screen changes the farm: a named action with plain arguments.
## Alone, or as the host, it happens at once. In co-op a guest's goes to the host,
## which says who acts; the arguments never do.

## What a screen may ask for. Each is a GameState function; its own types are
## the argument types, and its player argument is filled in here.
const ACTIONS: Array[StringName] = [
	&"accept_job", &"add_robot_calibrate_card", &"add_robot_card", &"add_robot_collect_card",
	&"adjust_setpoint", &"book_expedition", &"book_lab_sitter", &"book_shuttle", &"build_block_stack", &"build_robot", &"buy_camp_supplies", &"buy_from_kestrel", &"buy_heater", &"buy_ice_studs", &"buy_mine_props", &"buy_pump", &"buy_standard", &"buy_wide_treads",
	&"calibrate_at_bench", &"cancel_lab_sitter", &"catch_sentinel", &"catch_stray", &"change_depth", &"check_with_block", &"clear_lab_area", &"collect_enclosure_spool", &"collect_spool", &"complete_job", &"dig", &"enter_deimos_deep", &"enter_phobos_deep", &"enter_vent", &"fast_travel", &"fill", &"fit_lab_area", &"get_into_rover", &"get_out_of_rover", &"get_up", &"go_to_bed",
	&"harvest_crop", &"hit_boulder", &"leave_deimos_deep", &"leave_phobos_deep", &"leave_zone", &"mine_fissure", &"move_rover", &"move_rover_aquifer", &"move_rover_ice", &"move_rover_mine", &"move_rover_valles", &"open_cache", &"open_deimos_crate", &"place_beacon", &"place_stone", &"plant_crop", &"read_farm_board", &"read_probe", &"release_robot", &"remove_robot_card", &"repair_lift", &"report_place",
	&"sell_harvest_to_lin", &"send_ice_core", &"send_to_oirm", &"service_wheels", &"set_interlock_override", &"set_loadout", &"set_rover_lights", &"shore_room", &"shut_valve", &"shuttle_home", &"slot_spool_into_relay", &"spend_xp_certificate",
	&"start_lab_grow", &"survey_ore", &"take_find", &"take_phobos_find", &"till", &"use_lift", &"use_pump", &"wipe_deimos_dust", &"wipe_phobos_dust", &"zero_steering",
]
## What a player in bed may do and stay in bed: going to bed, paperwork, and
## saying where they are.
const NO_WAKE: Array[StringName] = [&"buy_camp_supplies", &"go_to_bed", &"report_place", &"set_loadout", &"spend_xp_certificate"]
## What is done only in a zone. A late one from a player already carried out (a command
## in flight at the 02:00 rescue) is refused by the farm and must not wake them from the
## bed they were put in.
const BELOW_ONLY: Array[StringName] = [
	&"buy_camp_supplies", &"buy_heater", &"buy_mine_props", &"buy_pump", &"catch_sentinel", &"change_depth", &"enter_vent", &"hit_boulder", &"leave_zone", &"mine_fissure",
	&"place_beacon", &"repair_lift", &"set_interlock_override", &"shore_room", &"shut_valve", &"survey_ore", &"take_find", &"use_lift", &"use_pump",
]
## What is done at a cell of the farm's ground: the cell in front of the rover, or
## under it. The cell's middle is within this far of the rover [PLACEHOLDER]: the
## 2 m it digs ahead, half a cell's corner and what the host's word of the
## rover lags.
const AT_CELL: Array[StringName] = [&"adjust_setpoint", &"dig", &"fill", &"harvest_crop", &"place_stone", &"plant_crop", &"till"]
const CELL_REACH_M: float = 6.0
const FAR_REFUSAL: String = "Too far from the rover."
## What someone on a moon may ask for: the way home, saying where they are, and
## paperwork. The farm's work waits at the farm (zones doc section 8.1). Bed and getting
## up are the expedition camp's: GameState refuses a bed to a day-trip traveller.
const ON_A_MOON: Array[StringName] = [&"catch_stray", &"enter_deimos_deep", &"enter_phobos_deep", &"get_up", &"go_to_bed", &"leave_deimos_deep", &"leave_phobos_deep", &"open_cache", &"open_deimos_crate", &"report_place", &"set_loadout", &"shuttle_home", &"spend_xp_certificate", &"take_phobos_find", &"wipe_deimos_dust", &"wipe_phobos_dust"]
const MOON_REFUSAL: String = "You are away on the shuttle. Take the return shuttle home first."
const PLAYER_ARGUMENTS: Array[String] = ["player_id", "performed_by"]
## Actions that may carry a mini-game's score after their own arguments: a whole
## number. The host cuts it to what it allows (MinigameScore.allowed, or
## seat_allowed for the relay, or service_allowed for the wheel nuts); with
## none, or one it does not allow, the action is as it always was.
const SCORED: Array[StringName] = [&"calibrate_at_bench", &"slot_spool_into_relay", &"service_wheels"]

## True while a guest: nothing is done here, only asked for.
var guest: bool = false
## A guest's way to the host: called with (action, arguments), it returns the
## host's answer, maybe later.
var remote: Callable
## The farm acted on. Only tests set another.
var state: Node

var _waiting: bool = false
## The automatic place report has a wait flag of its own, so it never blocks a
## gameplay command and a gameplay command never blocks it.
var _waiting_place: bool = false


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
	var presence: bool = action == &"report_place"
	if _waiting_place if presence else _waiting:
		return refusal(action, "Still waiting for the host.")
	if presence:
		_waiting_place = true
	else:
		_waiting = true
	var answer: Variant = await remote.call(action, arguments)
	if presence:
		_waiting_place = false
	else:
		_waiting = false
	if typeof(answer) != _method(action)["return"]["type"]:
		return refusal(action, "The host gave no answer.")
	return answer


## On the host: does `action` as `player_id`, who must come from the connection.
func execute(player_id: String, action: StringName, arguments: Array) -> Variant:
	# GameState would take no name as the host's own.
	var reason: String = "No player is named." if player_id == "" else problem(action, arguments)
	if reason == "" and CoopWalkers.is_out(player_id) and not action in CoopWalkers.ON_FOOT:
		reason = CoopWalkers.REFUSAL
	if reason == "" and Shuttle.is_moon(_farm().place_of(player_id)) and not action in ON_A_MOON:
		reason = MOON_REFUSAL
	if reason == "" and player_id != _farm().local_player_id and not is_within_reach(action, arguments):
		reason = FAR_REFUSAL
		CoopSession.note_refusal(player_id, "refused %s: too far from the rover" % action)
	if reason != "":
		return refusal(action, reason)
	# Whoever does something is up, but for what can be done from bed.
	var stale: bool = action in BELOW_ONLY and _farm().place_of(player_id) in [ZonePresence.FARM, ZonePresence.DOME]
	if not action in NO_WAKE and not stale:
		CoopBeds.get_up(player_id)
	var passed: Array = arguments.duplicate()
	var scored: bool = action in SCORED
	# The bench's score works on the instrument's next calibration; the relay's
	# is handed to the farm with the seat, and the wheel nuts' with the service.
	var bench: bool = action == &"calibrate_at_bench"
	var seat: bool = action == &"slot_spool_into_relay"
	var service: bool = action == &"service_wheels"
	var score: int = MinigameScore.SKIPPED
	var sent: bool = scored and passed.size() > _own_count(action)
	if sent:
		# Never the sender's number as it came: the host's cut of it.
		# problem() has let only a whole number through. If this is ever reached
		# without that check, anything else is no score at all.
		var last: Variant = passed.pop_back()
		if last is int or last is float:
			var given: int = int(last)
			if bench:
				score = MinigameScore.allowed(_farm(), str(passed[0]), player_id, given)
			elif seat:
				score = MinigameScore.seat_allowed(_farm(), player_id, given)
			elif service:
				score = MinigameScore.service_allowed(_farm(), player_id, given)
	if action == &"build_block_stack" and not QuestEngine.has_minigame_step(_farm(), MinigameScore.WRING_THE_BLOCKS, "", player_id):
		# Wring the Blocks' score is the sender's own number: the host does not
		# play the game again, and does not see the blocks picked on the screen
		# (it builds the length from the pieces it holds). So it is taken only
		# where it can count, for a player with an open step that carries the
		# game. Anywhere else the build is a skip, whatever was sent.
		passed[1] = MinigameScore.SKIPPED
	if _player_index(action) >= 0:
		passed.append(player_id)
	if seat or service:
		# Thread the Spool and Torque to Spec: SKIPPED unless this player has an
		# open step that carries the game (MinigameScore.seat_allowed,
		# service_allowed).
		passed.append(score)
	if bench:
		MinigameScore.arm(_farm(), str(passed[0]), score)
	var result: Variant = _farm().callv(action, passed)
	if action == &"report_place":
		# Only where someone is: nothing for the quests to look at.
		return result
	if bench:
		# A refusal zeroes nothing, so the factor is taken back here.
		MinigameScore.disarm(_farm(), str(passed[0]))
		if sent and result is Dictionary and result.has("as_left"):
			# What the host counted, for the sender's screen. A copy: the farm's
			# own record is kept as it is, with no new field.
			result = (result as Dictionary).duplicate()
			result[MinigameScore.RECORD_KEY] = score
	# The quests only watch: after anything a player did, they look again. New
	# ones are offered in the morning, not on top of this command's own line.
	# A score the host counted for a calibration that happened is told to that
	# look, for a quest step that carries the game (section 7.2's quest grade).
	var played: Dictionary = {}
	if bench and score != MinigameScore.SKIPPED and result is Dictionary and result.has("as_left"):
		played = QuestEngine.played_game(MinigameScore.game_for(_farm(), str(passed[0])), str(passed[0]), player_id, score)
	# Wring the Blocks: the stack's score is the action's own argument, and the
	# farm's answer holds it cut to 0 to 100, or as a skip where the player has
	# no open step for it (above) or played another length than today's. A skip
	# (or a refusal) tells nothing.
	if action == &"build_block_stack" and result is Dictionary and int(result.get("score", MinigameScore.SKIPPED)) >= 0:
		played = QuestEngine.played_game(MinigameScore.WRING_THE_BLOCKS, "", player_id, int(result["score"]))
	# Thread the Spool: a score the host counted, for a spool that went in.
	if seat and score != MinigameScore.SKIPPED and result is bool and result:
		played = QuestEngine.played_game(MinigameScore.THREAD_THE_SPOOL, "", player_id, score)
	# Torque to Spec: a score the host counted, for a service that was done
	# (the farm's answer is "" then, and why not otherwise).
	if service and score != MinigameScore.SKIPPED and result is String and result == "":
		played = QuestEngine.played_game(MinigameScore.TORQUE_TO_SPEC, "", player_id, score)
	var none: Array[String] = []
	_farm().update_quests(none, false, played)
	return result


## True unless `action` acts at a cell farther from the farm's rover than a player
## in it reaches. Where the rover is not known or is in the tunnels, there is no reach
## to hold to: a player on foot acts where they stand (CoopWalkers), so it is allowed.
func is_within_reach(action: StringName, arguments: Array) -> bool:
	if not action in AT_CELL or arguments.is_empty() or not arguments[0] is Vector3i:
		return true
	var farm: Node = _farm()
	if not farm.rover_transforms.has(farm.ROVER) or farm.rover_is_away(farm.ROVER):
		return true
	var cell: Vector3i = arguments[0]
	var middle := Vector2((cell.x + 0.5) * Terrain.CELL_M, (cell.z + 0.5) * Terrain.CELL_M)
	var rover: Vector3 = farm.parked_rover_transform(farm.ROVER).origin
	return middle.distance_to(Vector2(rover.x, rover.z)) <= CELL_REACH_M


## Why these can't be asked for, or "". The values are GameState's to judge.
func problem(action: StringName, arguments: Array) -> String:
	if not action in ACTIONS:
		return "'%s' is not a farm command." % action
	var expected: Array = _method(action)["args"]
	if _player_index(action) >= 0:
		expected = expected.slice(0, _player_index(action))
	var given: int = arguments.size()
	if action in SCORED and given == expected.size() + 1:
		if typeof(arguments[-1]) != TYPE_INT:
			return "'%s' has a bad score." % action
		given -= 1
	if given != expected.size():
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
func rover_drove(meters: float, rover_id: String = "") -> void:
	if not guest:
		_farm().add_rover_usage(meters, _farm().local_player_id, rover_id)


func rover_uplink(rover_id: String, has_los: bool) -> void:
	if not guest:
		_farm().set_rover_uplink(rover_id, has_los)


func rover_parked(rover_id: String, at: Transform3D) -> void:
	if not guest:
		_farm().park_rover(rover_id, at)


func rover_at(rover_id: String, at: Vector3, speed_mps: float) -> void:
	if not guest:
		_farm().watch_sentinel(rover_id, at, speed_mps)


## Where the player goes among the action's arguments, or -1. Anything after it
## is never asked for.
func _player_index(action: StringName) -> int:
	var args: Array = _method(action)["args"]
	for i: int in args.size():
		if args[i]["name"] in PLAYER_ARGUMENTS:
			return i
	return -1


## How many arguments of its own the action takes, the player's left out.
func _own_count(action: StringName) -> int:
	return _player_index(action) if _player_index(action) >= 0 else (_method(action)["args"] as Array).size()


func _method(action: StringName) -> Dictionary:
	for method: Dictionary in (_farm().get_script() as GDScript).get_script_method_list():
		if method["name"] == action:
			return method
	return {}


func _farm() -> Node:
	return state if state != null else GameState
