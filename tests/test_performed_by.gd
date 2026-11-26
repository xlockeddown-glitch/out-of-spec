extends RefCounted
## Calibration records name the player by id (co-op groundwork); the screen
## shows "You" only for the local player.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")


func _make_state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	return gs


func test_records_hold_player_ids() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = _make_state()
	gs.local_player_id = "player_2"
	var by_default: Dictionary = gs.calibrate(gs.STEERING_ID, "", false)
	var by_other: Dictionary = gs.calibrate(gs.STEERING_ID, "player_1", false)
	var at_bench: Dictionary = gs.calibrate_at_bench(gs.HYGROMETER_ID)
	var at_bench_other: Dictionary = gs.calibrate_at_bench(gs.HYGROMETER_ID, "player_1")
	GameClock.elapsed_days = saved
	gs.free()
	if by_default.get("performed_by", "") != "player_2" or at_bench.get("performed_by", "") != "player_2":
		return "With no player named, the local player's id must be recorded: %s, %s" % [by_default, at_bench]
	if by_other.get("performed_by", "") != "player_1" or at_bench_other.get("performed_by", "") != "player_1":
		return "A named player's id must be recorded: %s, %s" % [by_other, at_bench_other]
	return ""


func test_performer_names() -> String:
	var gs: GameStateScript = _make_state()
	gs.local_player_id = "player_2"
	var names: Array[String] = []
	for id: String in ["player_2", "player_1", gs.MANAGER_ID, "You", ""]:
		names.append(gs.performer_name(id))
	gs.free()
	if names != ["You", "player_1", "Manager", "You", "You"]:
		return "Only the local player and old records read 'You', got %s" % [names]
	return ""


## Scenes that call GameState must say whose action it is: in co-op the state may
## be another machine's. FarmCommands does so for the screens.
func test_callers_name_the_player() -> String:
	var actions: Dictionary = {}
	for method: Dictionary in GameStateScript.get_script_method_list():
		var args: Array = method["args"].map(func(arg: Dictionary) -> String: return arg["name"])
		if not "player_id" in args and not "performed_by" in args:
			continue
		# These only read, for the player at this screen.
		if not str(method["name"]) in ["performer_name", "calibration_budget", "skill_xp", "skill_level", "skill_factor",
				"has_skill_unlock", "skill_text", "skill_effects_text", "robot_build_problem", "robot_card_slots",
				"robot_job_gate", "robot_calibrate_targets", "robot_calibrate_gaps", "job_bench_problem",
				"job_minutes", "job_finish_day", "lin_pays", "harvest_bin_value",
				"held_xp_certificates", "level_with_xp", "xp_certificate_problem", "has_had_xp_certificate"]:
			actions[str(method["name"])] = args.find("player_id") if "player_id" in args else args.find("performed_by")
	var call_site: RegEx = RegEx.create_from_string(r"GameState\.(\w+)(?:\.bind)?\(")
	var comment: RegEx = RegEx.create_from_string(r"(?m)(^|\s)#.*$")
	var problems: PackedStringArray = []
	for dir: String in ["res://scripts", "res://scripts/camera", "res://scripts/dome", "res://scripts/rover", "res://scripts/ui", "res://scripts/world"]:
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var text: String = comment.sub(FileAccess.get_file_as_string(dir + "/" + file), "", true)
			for found: RegExMatch in call_site.search_all(text):
				if not actions.has(found.get_string(1)):
					continue
				# The arguments, up to the closing parenthesis. A bracket or comma
				# inside a string isn't told apart, so it could only fail the test.
				var end: int = found.get_end()
				var depth: int = 1
				var passed: PackedStringArray = [""]
				while end < text.length():
					if text[end] in "([{":
						depth += 1
					elif text[end] in ")]}":
						depth -= 1
					if depth == 0:
						break
					if text[end] == "," and depth == 1:
						passed.append("")
					else:
						passed[-1] += text[end]
					end += 1
				var index: int = actions[found.get_string(1)]
				if index >= passed.size() or passed[index].strip_edges() != "GameState.local_player_id":
					problems.append("%s: %s%s)" % [file, found.get_string(), ",".join(passed)])
	if actions.size() < 6:
		return "It found only %d functions, so it checks nothing." % actions.size()
	return "\n".join(problems)
