extends RefCounted
## Screens change the farm through FarmCommands, which the co-op host will run.

const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")

## Not actions, and not for a screen to call either.
const RAW: Array[StringName] = [&"add_rover_usage", &"calibrate", &"park_rover", &"set_rover_uplink"]

signal answered(answer: Variant)

var _asked: Array = []


func _make() -> Node:
	var commands: Node = CommandsScript.new()
	commands.state = GameStateScript.new()
	commands.state.build_registry()
	return commands


func _free(commands: Node) -> void:
	commands.state.free()
	commands.free()


func _ask_host(action: StringName, arguments: Array) -> Variant:
	_asked.append([action, arguments])
	return await answered


func test_every_action_is_a_typed_function() -> String:
	var commands: Node = _make()
	var bad: PackedStringArray = []
	for action: StringName in CommandsScript.ACTIONS:
		var method: Dictionary = commands._method(action)
		if method.is_empty() or not method["return"]["type"] in [TYPE_STRING, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_DICTIONARY]:
			bad.append(action)
			continue
		for arg: Dictionary in method["args"]:
			if not arg["type"] in [TYPE_STRING, TYPE_STRING_NAME, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_VECTOR3I]:
				bad.append("%s %s" % [action, arg["name"]])
	_free(commands)
	return "" if bad.is_empty() else "Not plain, typed actions: " + ", ".join(bad)


func test_it_acts_for_the_named_player() -> String:
	var saved: float = GameClock.elapsed_days
	var commands: Node = _make()
	commands.state.local_player_id = "player_2"
	var mine: Dictionary = commands.request(&"calibrate_at_bench", [commands.state.HYGROMETER_ID])
	var theirs: Dictionary = commands.execute("player_3", &"calibrate_at_bench", [commands.state.HYGROMETER_ID])
	GameClock.elapsed_days = saved
	_free(commands)
	if mine.get("performed_by", "") != "player_2" or theirs.get("performed_by", "") != "player_3":
		return "Got %s and %s" % [mine, theirs]
	return ""


func test_bad_requests_are_refused() -> String:
	var commands: Node = _make()
	var problems: PackedStringArray = []
	var credits: int = commands.state.credits
	for bad: Array in [[&"add_credits", [1000]], [&"free", []], [&"set_interlock_override", ["robot_1"]],
			[&"set_interlock_override", ["robot_1", 1]],
			[&"calibrate", ["steering"]], [&"add_rover_usage", [1.0]], [&"park_rover", ["tractor", Transform3D.IDENTITY]],
			[&"rover_drove", [1.0]], [&"till", [Vector3(0.0, 0.0, 0.0)]], [&"mine_fissure", ["FissureA"]],
			[&"calibrate_at_bench", [null]],
			[&"calibrate_at_bench", ["air_hygrometer", "player_9"]], [&"collect_spool", ["player_9", true, true]],
			[&"catch_species", ["cobalt_sentinel"]], [&"collect_enclosure_spool", []], [&"collect_enclosure_spool", [3]],
			[&"catch_sentinel", ["80"]], [&"catch_sentinel", []], [&"set_rover_lights", [1]], [&"watch_sentinel", ["rover_1_tunnels", Vector3.ZERO, 0.0]]]:
		if commands.problem(bad[0], bad[1]) == "":
			problems.append(str(bad))
	var kinds: Array = [commands.refusal(&"start_lab_grow", "no"), commands.refusal(&"collect_spool", "no"),
		commands.refusal(&"send_to_oirm", "no"), commands.refusal(&"add_credits", "no")]
	for bad: Array in [["player_2", &"add_credits", [1000]], ["", &"calibrate_at_bench", [commands.state.HYGROMETER_ID]]]:
		var answer: Variant = commands.execute(bad[0], bad[1], bad[2])
		if commands.state.credits != credits or not commands.state.cal_log.is_empty() or (answer is Dictionary and not answer.get("no_answer", false)):
			problems.append(str(bad))
	_free(commands)
	if not problems.is_empty():
		return "These must be refused: " + ", ".join(problems)
	if kinds[0] != "no" or kinds[1] != false or kinds[2].get("reason", "") != "no" or kinds[2]["ok"] or kinds[3] != "no":
		return "A refusal must have the action's own type, got %s" % [kinds]
	return ""


func test_a_guest_waits_for_the_host() -> String:
	var commands: Node = _make()
	commands.guest = true
	var cut_off: Variant = commands.request(&"start_lab_grow")
	if cut_off != "Not connected to the host." or not commands.state.lab_build.is_empty():
		_free(commands)
		return "A guest cut off from the host must do nothing, got %s" % cut_off
	commands.remote = _ask_host
	var got: Array = []
	var ask: Callable = func() -> void: got.append(await commands.request(&"start_lab_grow"))
	ask.call()
	if not got.is_empty() or _asked != [[&"start_lab_grow", []]]:
		_free(commands)
		return "The host must be asked, and nothing done here: %s, %s" % [got, _asked]
	ask.call()
	answered.emit("Not enough credits.")
	ask.call()
	answered.emit(7)
	var lab_build: Dictionary = commands.state.lab_build
	var asked: int = _asked.size()
	_free(commands)
	if got != ["Still waiting for the host.", "Not enough credits.", "The host gave no answer."] or asked != 2 or not lab_build.is_empty():
		return "Got %s after %d requests" % [got, asked]
	return ""


func test_a_guest_cannot_make_soil_or_ore() -> String:
	var commands: Node = _make()
	var problems: PackedStringArray = []
	for cell: Vector3i in [Vector3i(6, 0, 0), Vector3i(0, 0, -7), Vector3i(0, 1, 0)]:
		if commands.execute("player_2", &"till", [cell]):
			problems.append("Tilled off the plot: %s" % cell)
	if commands.execute("player_2", &"mine_fissure", [&"made_up"]) or commands.state.crystal_ore != 0:
		problems.append("Mined a fissure that is not there")
	if not commands.execute("player_2", &"till", [Vector3i(5, 0, -6)]) or not commands.execute("player_2", &"mine_fissure", [&"FissureH"]):
		problems.append("Real soil and fissures must work")
	if commands.execute("player_2", &"plant_crop", [Vector3i(5, 0, -6), "no_such_crop", 0]) == "":
		problems.append("Planted a crop that is not in the data")
	var kinds: Array = [commands.refusal(&"sell_harvest_to_lin", "no"), commands.refusal(&"adjust_setpoint", "no")]
	if typeof(kinds[0]) != TYPE_INT or kinds[0] != 0 or kinds[1] != -1.0:
		problems.append("Refusals of the wrong kind: %s" % [kinds])
	_free(commands)
	var named: RegEx = RegEx.create_from_string(r"\[node name=.(\w+). type=.Node3D. parent=.WorldView/WorldViewport/World/Fissures.")
	var fissures: Array[StringName] = []
	for found: RegExMatch in named.search_all(FileAccess.get_file_as_string("res://scenes/main_farm.tscn")):
		fissures.append(StringName(found.get_string(1)))
	if fissures != GameStateScript.FISSURES:
		problems.append("GameState.FISSURES is not the scene's: %s" % [fissures])
	return "\n".join(problems)


func test_a_guest_breaks_only_boulders_that_stand() -> String:
	var commands: Node = _make()
	var problems: PackedStringArray = []
	for arguments: Array in [[], [&""], [&"FissureA"], [&"RockE"], [&"rocka"], ["RockA"], [0], [&"RockA", "player_1"]]:
		if commands.execute("player_2", &"hit_boulder", arguments) != 0:
			problems.append("Hit %s" % [arguments])
	if not commands.state.boulder_hits.is_empty():
		problems.append("A refused hit must change nothing")
	var told: Array = [0]
	commands.state.boulders_changed.connect(func() -> void: told[0] += 1)
	for hit: int in range(1, GameStateScript.BOULDER_HITS + 1):
		if commands.state.is_boulder_broken(&"RockA") or commands.execute("player_2", &"hit_boulder", [&"RockA"]) != hit:
			problems.append("Hit %d must count" % hit)
	if not commands.state.is_boulder_broken(&"RockA") or commands.state.is_boulder_broken(&"RockB"):
		problems.append("The last hit must break that boulder only")
	if commands.execute("player_2", &"hit_boulder", [&"RockA"]) != 0 or told[0] != GameStateScript.BOULDER_HITS:
		problems.append("A broken boulder can't be hit, and each hit is told once")
	_free(commands)
	var named: RegEx = RegEx.create_from_string(r"\[node name=.(\w+). type=.StaticBody3D. parent=.WorldView/WorldViewport/World/Rocks.")
	var boulders: Array[StringName] = []
	for found: RegExMatch in named.search_all(FileAccess.get_file_as_string("res://scenes/main_farm.tscn")):
		boulders.append(StringName(found.get_string(1)))
	if boulders != GameStateScript.BOULDERS:
		problems.append("GameState.BOULDERS is not the scene's: %s" % [boulders])
	return "\n".join(problems)


func test_a_boulder_must_be_close_in_front_and_stand() -> String:
	var boulder := Boulder.new()
	boulder.name = "RockD"
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(4, 3, 2)
	var model := Node3D.new()
	model.name = "Model"
	boulder.add_child(shape)
	boulder.add_child(model)
	var saved: Dictionary = GameState.boulder_hits.duplicate()
	GameState.boulder_hits.clear()
	(Engine.get_main_loop() as SceneTree).root.add_child(boulder)
	boulder.position = Vector3(10, 0, 10)
	var problems: PackedStringArray = []
	for near: Vector3 in [Vector3(12.6, 5, 10), Vector3(10, 0, 8.4), Vector3(8, 0, 11.6), Vector3(10, 0, 10)]:
		if not boulder.is_in_reach(near):
			problems.append("%s must be in reach" % near)
	for far: Vector3 in [Vector3(12.8, 0, 10), Vector3(10, 0, 8.2), Vector3(12.6, 0, 11.6), Vector3.ZERO]:
		if boulder.is_in_reach(far):
			problems.append("%s must be out of reach" % far)
	var whole: float = model.scale.x
	GameState.hit_boulder(&"RockD")
	if model.scale.x >= whole or not model.visible:
		problems.append("A hit must show")
	for hit: int in GameState.BOULDER_HITS:
		GameState.hit_boulder(&"RockD")
	if boulder.is_in_reach(Vector3(10, 0, 8.4)) or model.visible:
		problems.append("A broken boulder must be gone")
	boulder.free()
	GameState.boulder_hits.assign(saved)
	return "\n".join(problems)


func test_a_guest_digs_and_fills_only_by_the_rules() -> String:
	var commands: Node = _make()
	var problems: PackedStringArray = []
	for cell: Vector3i in [Vector3i(0, 0, 0), Vector3i(20, 1, 20), Vector3i(2147483647, 0, -2147483648), Vector3i(-59, 0, 59)]:
		if commands.execute("player_2", &"dig", [cell]) == "" or commands.execute("player_2", &"fill", [cell]) == "":
			problems.append("Changed the ground at %s" % cell)
	for arguments: Array in [[], [Vector2i(20, 20)], [Vector3(20, 0, 20)], ["x"], [Vector3i(20, 0, 20), "player_1"]]:
		for action: StringName in [&"dig", &"fill"]:
			if commands.execute("player_2", action, arguments) == "":
				problems.append("Did %s with %s" % [action, arguments])
	if not commands.state.dug.is_empty():
		problems.append("A refused dig must change nothing")
	var told: Array = [0]
	commands.state.terrain_changed.connect(func() -> void: told[0] += 1)
	var cell := Vector3i(20, 0, 20)
	if commands.execute("player_2", &"dig", [cell]) != "" or commands.state.dug.get(Vector2i(20, 20), 0) != 1:
		problems.append("A guest must dig")
	if commands.execute("player_2", &"dig", [cell]) == "" or commands.state.dug[Vector2i(20, 20)] != 1:
		problems.append("Dug too steep")
	if commands.execute("player_2", &"fill", [cell]) != "" or not commands.state.dug.is_empty() or told[0] != 2:
		problems.append("A guest must fill, and each change be told")
	_free(commands)
	return "\n".join(problems)


func test_zero_steering_is_no_calibration() -> String:
	var saved: float = GameClock.elapsed_days
	var commands: Node = _make()
	var record: Dictionary = commands.execute("player_2", &"zero_steering", [])
	var logged: int = commands.state.cal_log.size()
	GameClock.elapsed_days = saved
	_free(commands)
	if record.get("performed_by", "") != "player_2" or record.get("traceable", true) or logged != 1:
		return "Got %s, %d logged" % [record, logged]
	return ""


func test_rover_reports_are_the_hosts_alone() -> String:
	var commands: Node = _make()
	var gs: Node = commands.state
	var problems: PackedStringArray = []
	var error: float = gs.steering.error
	var asked: int = _asked.size()
	commands.guest = true
	commands.remote = _ask_host
	commands.rover_drove(100.0)
	commands.rover_uplink("tractor", true)
	commands.rover_parked("tractor", Transform3D.IDENTITY)
	if gs.steering.error != error or not gs.rover_uplinks.is_empty() or not gs.rover_transforms.is_empty() or _asked.size() != asked:
		problems.append("A guest's rover must change and ask nothing")
	commands.guest = false
	for bad: float in [NAN, INF, -5.0]:
		commands.rover_drove(bad)
	commands.rover_parked("tractor", Transform3D(Basis.IDENTITY, Vector3(NAN, 0.0, 0.0)))
	if gs.steering.error != error or not gs.rover_transforms.is_empty():
		problems.append("Bad reports must be ignored")
	commands.rover_drove(100.0)
	commands.rover_uplink("tractor", true)
	commands.rover_parked("tractor", Transform3D.IDENTITY)
	if gs.steering.error == error or not gs.rover_uplinks.has("tractor") or not gs.rover_transforms.has("tractor"):
		problems.append("The host's rover must count")
	_free(commands)
	return "\n".join(problems)


func test_a_refused_till_is_not_shown() -> String:
	var saved: Dictionary = GameState.tilled_cells.duplicate()
	var grid := FarmGrid.new()
	grid._ready()
	var cell := Vector3i(2, 0, 2)
	GameState.tilled_cells.erase(cell)
	grid.set_cell_item(cell, FarmGrid.Tile.SOIL_UNTILLED)
	FarmCommands.guest = true  # and not connected
	var result: int = await grid.till_cell(cell)
	FarmCommands.guest = false
	var item: int = grid.get_cell_item(cell)
	grid.free()
	GameState.tilled_cells = saved
	if result != FarmGrid.TillResult.REFUSED or item != FarmGrid.Tile.SOIL_UNTILLED:
		return "Got result %d, tile %d" % [result, item]
	return ""


## It knows only the listed actions, and the calls named here that must not be
## made raw: another GameState change would pass unseen. The seed and starting set
## point (cycle_seed, adjust_planting_offset) are choices, sent with each planting.
func test_screens_do_not_change_the_farm_directly() -> String:
	var direct: RegEx = RegEx.create_from_string(r"GameState\s*\.\s*(%s)\b" % "|".join(CommandsScript.ACTIONS + RAW))
	var asks: RegEx = RegEx.create_from_string(r"FarmCommands\.request(?:\.bind)?\(&\"(\w+)\"")
	var comment: RegEx = RegEx.create_from_string(r"(?m)(^|\s)#.*$")
	var problems: PackedStringArray = []
	var asked: Dictionary = {}
	for dir: String in ["res://scripts", "res://scripts/camera", "res://scripts/dome", "res://scripts/metrology",
			"res://scripts/rover", "res://scripts/ui", "res://scripts/world"]:
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var text: String = comment.sub(FileAccess.get_file_as_string(dir + "/" + file), "", true)
			for found: RegExMatch in direct.search_all(text):
				problems.append("%s: %s" % [file, found.get_string()])
			for found: RegExMatch in asks.search_all(text):
				asked[StringName(found.get_string(1))] = true
	for action: StringName in CommandsScript.ACTIONS:
		# book_shuttle waits for the Landing Field pad's terminal (biomes step 12).
		if not asked.has(action) and action != &"book_shuttle":
			problems.append("No screen asks for %s" % action)
	for action: StringName in asked:
		if not action in CommandsScript.ACTIONS:
			problems.append("%s is not an action" % action)
	return "\n".join(problems)


func test_a_guest_far_from_the_rover_acts_on_nothing_there() -> String:
	var commands: Node = _make()
	var state: Node = commands.state
	state.local_player_id = "player_1"
	# Before the rover's place is known, or in the tunnels, nothing is judged.
	var anywhere: Vector3i = Vector3i(30, 0, 30)
	if not commands.is_within_reach(&"dig", [anywhere]):
		_free(commands)
		return "No place is known"
	state.rover_transforms[state.ROVER] = Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 1.0))
	var near: Array = [commands.is_within_reach(&"dig", [Vector3i(0, 0, 0)]), commands.is_within_reach(&"till", [Vector3i(1, 0, 1)]),
		commands.is_within_reach(&"fill", [Vector3i(0, 0, 2)])]
	var far: Array = [commands.is_within_reach(&"dig", [anywhere]), commands.is_within_reach(&"plant_crop", [anywhere, "", 0]),
		commands.is_within_reach(&"place_stone", [anywhere, 0]), commands.is_within_reach(&"harvest_crop", [anywhere])]
	var guest_dig: Variant = commands.execute("player_2", &"dig", [anywhere])
	var guest_till: Variant = commands.execute("player_2", &"till", [Vector3i(0, 0, 0)])
	var host_dig: Variant = commands.execute("player_1", &"dig", [anywhere])
	var other: bool = commands.is_within_reach(&"get_into_rover", [])
	state.rover_in_tunnels = true
	var away: bool = commands.is_within_reach(&"dig", [anywhere])
	_free(commands)
	if near.has(false):
		return "Near the rover must be in reach: %s" % [near]
	if far.has(true) or str(guest_dig) != CommandsScript.FAR_REFUSAL:
		return "Far must be refused: %s, %s" % [far, guest_dig]
	if str(guest_till) == CommandsScript.FAR_REFUSAL:
		return "Near the rover must be done"
	if str(host_dig) == CommandsScript.FAR_REFUSAL:
		return "The host's own screen judges its own reach"
	return "" if other and away else "Only cells, and only on the farm"
