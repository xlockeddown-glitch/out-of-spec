extends RefCounted
## Bram's wheel service (docs/decisions.md, 2026-11-26): the rover's wheel nuts
## come due after so many meters driven, and Bram re-torques them for Robotics
## XP and lab XP. Nothing is worse while they are overdue. Torque to Spec
## (docs/design/quests_levels_story.md section 7.1) plugs into this action: its
## score rides as the command's last argument, and tests/test_torque_to_spec.gd
## has what the host does with one. Here no quest step is open, so a score is
## a skip.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const SessionScript: GDScript = preload("res://scripts/autoload/CoopSession.gd")
const ProfileScript: GDScript = preload("res://scripts/autoload/CoopProfile.gd")
const KEY: String = "abcdef0123456789abcdef0123456789"
const HOST: String = "player_1"
const ACTION: StringName = &"service_wheels"
const SOURCE: String = "service_wheels"
const LAB_SOURCE: String = "lab_wheels"
const SKILL: String = "robotics"
const FARM_SEED: int = 77
const DUE_LINE: String = "BRAM: Your wheel nuts are due"

signal answered(answer: Variant)

var _asked: Array = []
var _nodes: Array[Node] = []


func _ask_host(action: StringName, arguments: Array) -> Variant:
	_asked.append([action, arguments])
	return await answered


func _run(body: Callable) -> String:
	var saved_day: float = GameClock.elapsed_days
	var saved_players: Array[String] = CoopSession.players.duplicate()
	var saved_out: Dictionary = CoopWalkers.out.duplicate(true)
	GameClock.elapsed_days = 0.0
	CoopSession.players.clear()
	CoopWalkers.out.clear()
	FarmCommands.guest = false
	_asked.clear()
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call()
	for node: Node in _nodes:
		node.free()
	_nodes.clear()
	FarmCommands.guest = false
	CoopWalkers.out.clear()
	CoopWalkers.out.merge(saved_out)
	CoopSession.players.assign(saved_players)
	GameClock.elapsed_days = saved_day
	return out if out is String else "The test stopped early or did not return a String."


func _farm() -> Node:
	var gs: Node = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(FARM_SEED)
	gs.reset_credibility()
	var commands: Node = CommandsScript.new()
	commands.state = gs
	_nodes.append(gs)
	_nodes.append(commands)
	return commands


func _lines(gs: Node, start: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.begins_with(start):
			count += 1
	return count


func test_the_nuts_come_due_with_the_meters_driven() -> String:
	return _run(func() -> String:
		var gs: Node = _farm().state
		var due: float = gs.wheel_service_due_m()
		if due <= 0.0 or gs.wheel_meters != 0.0 or gs.wheels_due():
			return "A new rover's nuts are not due, and the distance is in the data: %f." % due
		gs.add_rover_usage(due - 1.0, HOST)
		if gs.wheels_due() or _lines(gs, DUE_LINE) != 0 or not gs.wheel_service_text().begins_with("WHEEL NUTS OK"):
			return "One meter short the nuts are not due: %s" % gs.wheel_service_text()
		gs.add_rover_usage(1.0, HOST)
		if not gs.wheels_due() or _lines(gs, DUE_LINE) != 1 or gs.wheel_service_text() != "RE-TORQUE WHEEL NUTS":
			return "At the distance the nuts are due and Bram says so: %s" % [gs.phone_log]
		gs.add_rover_usage(due * 3.0, HOST)
		if _lines(gs, DUE_LINE) != 1:
			return "Bram says it once, not on every meter after."
		for bad: float in [NAN, INF, -5.0]:
			var before: float = gs.wheel_meters
			gs.add_rover_usage(bad, HOST)
			if gs.wheel_meters != before:
				return "A distance that is no distance counts for nothing."
		return "")


func test_the_due_signal_is_heard() -> String:
	return _run(func() -> String:
		var commands: Node = _farm()
		var gs: Node = commands.state
		var heard: Array = []
		gs.wheels_changed.connect(func() -> void: heard.append(gs.wheels_due()))
		gs.add_rover_usage(gs.wheel_service_due_m(), HOST)
		if heard.is_empty() or heard[-1] != true:
			return "wheels_changed is heard when the nuts come due: %s" % [heard]
		heard.clear()
		if commands.execute(HOST, ACTION, []) != "" or heard != [false]:
			return "wheels_changed is heard once when Bram is done: %s" % [heard]
		return "")


func test_overdue_nuts_change_nothing_else() -> String:
	return _run(func() -> String:
		var driven: Node = _farm().state
		var plain: Node = _farm().state
		driven.add_rover_usage(driven.wheel_service_due_m() * 4.0, HOST)
		plain.add_rover_usage(plain.wheel_service_due_m() * 4.0, HOST)
		# The second farm is the same but for the meters and Bram's one line.
		plain.wheel_meters = 0.0
		var a: Dictionary = driven.farm_to_dict()
		var b: Dictionary = plain.farm_to_dict()
		if a.get("wheel_meters", -1.0) != driven.wheel_meters:
			return "The meters are saved."
		a.erase("wheel_meters")
		b.erase("wheel_meters")
		if var_to_str(a) != var_to_str(b):
			return "Nothing but the meters is different on a farm with overdue nuts."
		return "")


func test_bram_refuses_with_a_reason() -> String:
	return _run(func() -> String:
		var commands: Node = _farm()
		var gs: Node = commands.state
		var not_due: Variant = commands.execute(HOST, ACTION, [])
		if not not_due is String or not (not_due as String).begins_with("The wheel nuts are not due"):
			return "Not due is refused in words: %s" % [not_due]
		gs.add_rover_usage(gs.wheel_service_due_m(), HOST)
		gs.rover_in_tunnels = true
		var away: Variant = commands.execute(HOST, ACTION, [])
		if not away is String or not (away as String).begins_with("The rover is in the tunnels"):
			return "A rover in the tunnels is refused in words: %s" % [away]
		gs.rover_in_tunnels = false
		CoopWalkers.out[HOST] = [0.0, 0.0, 0.0, 0.0, 0.0]
		var on_foot: Variant = commands.execute(HOST, ACTION, [])
		CoopWalkers.out.erase(HOST)
		if on_foot != CoopWalkers.REFUSAL:
			return "On foot is refused: %s" % [on_foot]
		if commands.execute("", ACTION, []) == "":
			return "No player named is refused."
		# Torque to Spec's score is one whole number, or there is none.
		if not ACTION in CommandsScript.SCORED or commands.problem(ACTION, ["100"]) == "" or commands.problem(ACTION, [90, 90]) == "":
			return "A score is one whole number or none."
		if gs.skill_xp(SKILL, HOST) != 0 or gs.lab_xp != 0 or not gs.wheels_due() or gs.action_count(SOURCE, HOST) != 0:
			return "A refusal changes nothing."
		return "")


func test_a_service_gives_robotics_xp_and_lab_xp() -> String:
	return _run(func() -> String:
		var commands: Node = _farm()
		var gs: Node = commands.state
		gs.add_rover_usage(gs.wheel_service_due_m() + 40.0, HOST)
		var credits: int = gs.credits
		var ore: int = gs.crystal_ore
		var lab: int = roundi(gs._lab_source_xp(LAB_SOURCE) * gs.lab_xp_scale())
		if commands.problem(ACTION, []) != "" or commands.execute(HOST, ACTION, []) != "":
			return "Due nuts are serviced: %s" % [commands.execute(HOST, ACTION, [])]
		if gs.wheel_meters != 0.0 or gs.wheels_due():
			return "The meters start again from nothing."
		if gs.skill_xp(SKILL, HOST) != 25 or gs.lab_xp != lab or lab <= 0:
			return "A service gives 25 Robotics XP and the lab's XP: %d, %d of %d." % [gs.skill_xp(SKILL, HOST), gs.lab_xp, lab]
		for skill: String in gs.player_skill_xp.get(HOST, {}):
			if skill != SKILL and gs.skill_xp(skill, HOST) != 0:
				return "Only Robotics is taught: %s." % skill
		if gs.credits != credits or gs.crystal_ore != ore:
			return "The service is free."
		# What a quest's `counter` step reads.
		if gs.action_count(SOURCE, HOST) != 1 or gs.action_xp(SOURCE, HOST) != 25:
			return "The service is counted for a quest step: %d." % gs.action_count(SOURCE, HOST)
		if commands.execute(HOST, ACTION, []) == "" or gs.action_count(SOURCE, HOST) != 1:
			return "A second service straight after is not due."
		gs.add_rover_usage(gs.wheel_service_due_m(), HOST)
		if _lines(gs, DUE_LINE) != 2 or commands.execute(HOST, ACTION, []) != "" or gs.action_count(SOURCE, HOST) != 2:
			return "After the distance again Bram says so again and services again."
		return "")


func test_a_score_with_no_quest_step_is_a_skip() -> String:
	return _run(func() -> String:
		# No morning has gone by, so no quest carries Torque to Spec.
		var skip: Node = _farm()
		var best: Node = _farm()
		for commands: Node in [skip, best]:
			commands.state.add_rover_usage(commands.state.wheel_service_due_m(), HOST)
		if skip.execute(HOST, ACTION, []) != "" or best.execute(HOST, ACTION, [100]) != "":
			return "Both are serviced."
		if var_to_str(skip.state.farm_to_dict()) != var_to_str(best.state.farm_to_dict()):
			return "With no quest step open the host makes a score a skip."
		# The farm's own function takes the score as given: the host's cut is in FarmCommands.
		var direct: Node = _farm().state
		direct.add_rover_usage(direct.wheel_service_due_m(), HOST)
		if direct.service_wheels(HOST, 100) != "" or direct.action_xp(SOURCE, HOST) != roundi(25 * 1.5) or direct.wheel_meters != 0.0:
			return "A graded score multiplies the service's XP and nothing else: %d." % direct.action_xp(SOURCE, HOST)
		return "")


func test_a_guest_asks_the_host() -> String:
	return _run(func() -> String:
		# The guest's own PC: it asks, and does nothing itself.
		var theirs: Node = _farm()
		theirs.state.wheel_meters = theirs.state.wheel_service_due_m()
		theirs.guest = true
		theirs.remote = _ask_host
		var got: Array = []
		var ask: Callable = func() -> void: got.append(await theirs.request(ACTION))
		ask.call()
		if not got.is_empty() or _asked != [[ACTION, []]] or not theirs.state.wheels_due():
			return "The host is asked, and nothing is done on the guest's PC: %s, %s" % [got, _asked]
		answered.emit("")
		if got != [""] or theirs.state.skill_xp(SKILL, HOST) != 0:
			return "The guest gets the host's answer and no XP of its own making: %s" % [got]
		# A guest's driving does not count on its own PC: the host's rover counts.
		FarmCommands.guest = true
		theirs.state.wheel_meters = 0.0
		theirs.state.add_rover_usage(500.0, HOST)
		FarmCommands.guest = false
		if theirs.state.wheel_meters != 0.0:
			return "A guest's PC counts no meters."
		# The host's PC: the guest's ask is run there, and the XP is the guest's.
		var commands: Node = _farm()
		var host: Node = commands.state
		var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		if id == "":
			return "The guest was not let in."
		CoopSession.players.assign([HOST, id])
		host.add_rover_usage(host.wheel_service_due_m(), id)
		if commands.execute(id, ACTION, []) != "":
			return "The host services the wheels for a guest: %s" % [commands.execute(id, ACTION, [])]
		if host.skill_xp(SKILL, id) != 25 or host.skill_xp(SKILL, HOST) != 0 or host.action_count(SOURCE, id) != 1 or host.action_count(SOURCE, HOST) != 0:
			return "The XP and the count are the guest's own: %d." % host.skill_xp(SKILL, id)
		if host.wheels_due() or host.lab_xp <= 0:
			return "The rover and the lab are the farm's: the nuts are done for everyone."
		return "")


func test_the_meters_are_saved() -> String:
	return _run(func() -> String:
		var gs: Node = _farm().state
		gs.add_rover_usage(gs.wheel_service_due_m() + 12.5, HOST)
		var saved: Dictionary = gs.farm_to_dict()
		var copy: Node = _farm().state
		var problem: String = copy.farm_from_dict(saved)
		if problem != "" or copy.wheel_meters != gs.wheel_meters or not copy.wheels_due():
			return "The meters come back from a save: %s, %f." % [problem, copy.wheel_meters]
		# A save from before the wheel service has no such field.
		var old: Dictionary = saved.duplicate(true)
		old.erase("wheel_meters")
		var from_old: Node = _farm().state
		from_old.wheel_meters = 99.0
		problem = from_old.farm_from_dict(old)
		if problem != "" or from_old.wheel_meters != 0.0 or from_old.wheels_due():
			return "An old save loads with nothing driven: %s, %f." % [problem, from_old.wheel_meters]
		var bad: Dictionary = saved.duplicate(true)
		bad["wheel_meters"] = -1.0
		if _farm().state.farm_from_dict(bad) == "":
			return "A distance below nothing is refused."
		return "")


func test_no_save_version_or_message_changed() -> String:
	if SessionScript.PROTOCOL != 16:
		return "The service rides the command path: the protocol is still 16."
	if SaveGame.VERSION != 1:
		return "The meters are a later field: the save version is still 1."
	if not "wheel_meters" in GameStateScript.SAVED_LATER:
		return "wheel_meters is a field added after version 1."
	if not ACTION in CommandsScript.ACTIONS:
		return "The service is a farm command."
	return ""
