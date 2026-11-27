extends "res://tests/coop_net.gd"
## Playtest text fixes: the Sentinel's rules, the cup's pointer at the hygrometer,
## humidity units, one overdue wording and the README key table.

const SENTINEL: String = "cobalt_sentinel"
const NEAR := Vector3(3.0, 0.0, 0.0)


func _out(farm: GameStateScript) -> void:
	farm.rover_in_tunnels = true
	farm.rover_lights = false
	farm.sentinel_out = true
	farm.sentinel_sighted = false
	farm.sentinel_days_unseen = 4
	farm.hygrometer.error = 0.0
	farm.phone_log.clear()
	farm.park_rover(farm.TUNNEL_ROVER, Transform3D(Basis.IDENTITY, farm.SENTINEL_AT + NEAR))
	farm.rover_zone = farm.TUNNELS_ZONE
	farm.rover_depth = 0
	farm.player_places["player_2"] = [farm.TUNNELS_ZONE, 0]  # a guest asks from the rover's place


func _run(body: Callable) -> String:
	var elapsed: float = GameClock.elapsed_days
	GameClock.elapsed_days = 0.0
	var farm: GameStateScript = GameStateScript.new()
	farm.build_registry()
	farm.hygrometer.max_error = INF
	_out(farm)
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(farm)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	farm.free()
	GameClock.elapsed_days = elapsed
	return problem


func test_the_sentinel_rules_are_told_once_per_sighting() -> String:
	return _run(func(farm: GameStateScript) -> String:
		farm.watch_sentinel(farm.TUNNEL_ROVER, farm.SENTINEL_AT + Vector3(9.0, 0.0, 0.0), 1.0)
		if not farm.phone_log.is_empty():
			return "Out of its sight there is nothing to say."
		for step: int in 3:
			farm.watch_sentinel(farm.TUNNEL_ROVER, farm.SENTINEL_AT + NEAR, 1.0)
		var hint: String = GameStateScript.SENTINEL_HINT
		if farm.phone_log != [hint]:
			return "One line, once: %s" % [farm.phone_log]
		if not "Lights low (L)" in hint or not "creep" in hint or not "stop short" in hint or "m/s" in hint:
			return "Wrong words, and no speed readout: " + hint
		# It bolts for lights; the next sighting is a new one.
		farm.rover_lights = true
		farm.watch_sentinel(farm.TUNNEL_ROVER, farm.SENTINEL_AT + NEAR, 1.0)
		if farm.sentinel_out or farm.phone_log.size() != 2 or not "lights" in farm.phone_log[1]:
			return "It must bolt for lights, after the hint: %s" % [farm.phone_log]
		_out(farm)
		farm.watch_sentinel(farm.TUNNEL_ROVER, farm.SENTINEL_AT + NEAR, 1.0)
		if farm.phone_log != [hint]:
			return "A new sighting gets the line again: %s" % [farm.phone_log]
		if farm.farm_to_dict().has("sentinel_sighted"):
			return "The told flag is not part of the save."
		if farm.farm_from_dict(farm.farm_to_dict()) != "" or farm.sentinel_sighted:
			return "A loaded farm has told nothing yet."
		return "")


func test_the_cup_points_at_the_hygrometer_when_the_reading_was_in_band() -> String:
	return _run(func(farm: GameStateScript) -> String:
		# Error, reading, wrong air, hint expected.
		for case: Array in [[6.0, 80.0, true, true], [-7.0, 80.0, true, true], [10.0, 84.0, true, true],
				[0.0, 74.0, true, false], [0.0, 86.0, true, false], [-6.0, 86.0, true, false],
				[6.0, 84.0, false, false], [0.0, 80.0, false, false]]:
			_out(farm)
			farm.enclosures.clear()
			farm.hygrometer.error = case[0]
			farm.catch_sentinel(case[1])
			var line: String = "" if farm.phone_log.is_empty() else farm.phone_log[farm.phone_log.size() - 1]
			var asked: String = "The hygrometer read %s %%. Was it right?" % SP811.number(case[1], 0)
			if case[3] != line.contains(asked) or (not case[3] and "hygrometer" in line):
				return "Wrong for %s: %s" % [case, line]
			if case[2] and (not line.contains("It bolted") or not line.contains("The cup was too ")):
				return "The bolt line stays: %s" % line
		return "")


func test_a_guest_hears_the_cup_pointer() -> String:
	var host: Node = _host()
	var farm: GameStateScript = host.commands.state
	_out(farm)
	farm.hygrometer.error = 6.0
	var guest: Node = _guest(host)
	var got: Array = _request(guest, &"catch_sentinel", [80.0])
	_until(func() -> bool: return not got.is_empty())
	var problem: String = ""
	var line: String = "" if farm.phone_log.is_empty() else farm.phone_log[farm.phone_log.size() - 1]
	if got != [""] or farm.is_caught(SENTINEL) or not "The hygrometer read 80 %. Was it right?" in line:
		problem = "The host decides: %s, %s" % [got, line]
	elif not SessionScript.is_plain([line]):
		problem = "The line must travel as plain data."
	return _finish(problem)


func test_a_humidity_error_is_in_percentage_points() -> String:
	var sensor := DriftingSensor.new()
	sensor.error_unit = "percentage_points_rh"
	var text: String = sensor.format_value(5.25)
	if not text.ends_with(" percentage points") or " %" in text:
		return "A humidity difference is not a share of the reading: " + text
	var unsigned: String = sensor.format_value(5.0).trim_prefix("+")
	if not unsigned.begins_with("5") or " %" in unsigned:
		return "MPE and U print the same way: " + unsigned
	var angle := DriftingSensor.new()
	angle.error_unit = "degrees"
	if not angle.format_value(0.5).ends_with("°"):
		return "Other units stay as they were."
	return ""


func test_overdue_has_one_wording_and_never_day_0() -> String:
	if DriftingSensor.overdue_text(0) != "OVERDUE since day 1" or DriftingSensor.overdue_text(6) != "OVERDUE since day 7":
		return "Overdue starts the day after the due day: %s" % DriftingSensor.overdue_text(0)
	return _run(func(farm: GameStateScript) -> String:
		GameClock.elapsed_days = 2.0
		var probe: DriftingSensor = farm.get_sensor(farm.SOIL_PROBE_ID)
		probe.cal_due_day = 0
		farm.hygrometer.cal_due_day = 0
		var texts: Array[String] = [farm.soil_probe_text(), farm.traceability_chain(farm.SOIL_PROBE_ID)["text"],
			farm.traceability_chain(farm.HYGROMETER_ID)["text"]]
		for text: String in texts:
			if "due day 0" in text or "lapsed" in text:
				return "Wrong overdue wording: " + text
		if not "OVERDUE since day 1" in texts[0]:
			return "The probe line says it: " + texts[0]
		return "")


func test_no_script_says_day_0_or_lapsed() -> String:
	var found: PackedStringArray = []
	var pattern := RegEx.create_from_string("OVERDUE \\(due|lapsed \\(due|calibration lapsed|CAL OVERDUE \\(")
	var dirs: Array[String] = ["res://scripts"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			dirs.append(dir + "/" + sub)
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd") and pattern.search(FileAccess.get_file_as_string(dir + "/" + file)) != null:
				found.append(file)
	return "" if found.is_empty() else "Old overdue wording in %s" % ", ".join(found)


## The README key table lists every key the game reads.
func test_the_readme_key_table_lists_every_key() -> String:
	var readme: String = FileAccess.get_file_as_string("res://README.md")
	var start: int = readme.find("| Input | Action |")
	var end: int = readme.find("\n\n", start)
	if start < 0 or end < 0:
		return "The key table is missing."
	var listed: Dictionary = {}
	for row: String in readme.substr(start, end - start).split("\n"):
		var cells: PackedStringArray = row.split("|")
		if cells.size() < 3:
			continue
		var first: String = cells[1].strip_edges()
		for token: String in first.replace("(", " ").replace(")", " ").replace(",", " ").replace("/", " ").split(" ", false):
			listed[token] = true
		if "WASD" in first:
			for letter: String in ["W", "A", "S", "D"]:
				listed[letter] = true
	var wanted: Dictionary = {}
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var pressed := event as InputEventKey
				var shown: String = OS.get_keycode_string(pressed.physical_keycode if pressed.physical_keycode != 0 else pressed.keycode)
				wanted[{"BracketLeft": "[", "BracketRight": "]", "Escape": "Esc"}.get(shown, shown)] = String(action)
	var names: Dictionary = {"Bracketleft": "[", "Bracketright": "]", "BracketLeft": "[", "BracketRight": "]", "Escape": "Esc"}
	var key := RegEx.create_from_string("\\bKEY_([A-Z0-9]+)\\b")
	for path: String in ["res://scripts/main_farm.gd", "res://scripts/basalt_tunnels.gd", "res://scripts/ui/skills_ui.gd",
			"res://scripts/ui/coop_ui.gd", "res://scripts/autoload/GameState.gd"]:
		for found: RegExMatch in key.search_all(FileAccess.get_file_as_string(path)):
			var name: String = found.get_string(1)
			wanted[names.get(name.capitalize(), name)] = path
	var missing: PackedStringArray = []
	for name: String in wanted:
		if name in ["Up", "Down", "Left", "Right"]:
			continue
		if not listed.has(name):
			missing.append("%s (%s)" % [name, wanted[name]])
	return "" if missing.is_empty() else "Not in the README key table: %s" % ", ".join(missing)
