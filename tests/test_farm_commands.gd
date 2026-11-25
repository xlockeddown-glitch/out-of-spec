extends RefCounted
## Screens change the farm through FarmCommands, which the co-op host will run.

const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")

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
		if method.is_empty() or not method["return"]["type"] in [TYPE_STRING, TYPE_BOOL, TYPE_DICTIONARY]:
			bad.append(action)
			continue
		for arg: Dictionary in method["args"]:
			if not arg["type"] in [TYPE_STRING, TYPE_BOOL, TYPE_INT]:
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
			[&"set_interlock_override", ["robot_1", 1]], [&"calibrate_at_bench", [null]],
			[&"calibrate_at_bench", ["air_hygrometer", "player_9"]], [&"collect_spool", ["player_9", true, true]]]:
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


## It knows only the listed actions: another GameState change would pass unseen.
## main_farm.gd, the rover and the grid come in the next change.
func test_screens_do_not_change_the_farm_directly() -> String:
	var direct: RegEx = RegEx.create_from_string(r"GameState\s*\.\s*(%s)\b" % "|".join(CommandsScript.ACTIONS))
	var asks: RegEx = RegEx.create_from_string(r"FarmCommands\.request(?:\.bind)?\(&\"(\w+)\"")
	var comment: RegEx = RegEx.create_from_string(r"(?m)(^|\s)#.*$")
	var problems: PackedStringArray = []
	var asked: Dictionary = {}
	for dir: String in ["res://scripts/dome", "res://scripts/ui"]:
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var text: String = comment.sub(FileAccess.get_file_as_string(dir + "/" + file), "", true)
			for found: RegExMatch in direct.search_all(text):
				problems.append("%s: %s" % [file, found.get_string()])
			for found: RegExMatch in asks.search_all(text):
				asked[StringName(found.get_string(1))] = true
	for action: StringName in CommandsScript.ACTIONS:
		if not asked.has(action):
			problems.append("No screen asks for %s" % action)
	for action: StringName in asked:
		if not action in CommandsScript.ACTIONS:
			problems.append("%s is not an action" % action)
	return "\n".join(problems)
