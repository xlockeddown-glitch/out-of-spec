extends RefCounted
## Save and load: the farm goes to plain data and a file and comes back exactly.
## The live GameState and GameClock are put back after each test.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const PATH: String = "user://test_farm.save"


func _make_state(seed_value: int = 424242) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(seed_value)
	gs.credits = 100000
	gs.crystal_ore = 50
	gs.tier1_unlocked = true
	gs.reset_credibility()
	gs.credibility = 60
	return gs


## Plays mornings so every kind of state has something in it.
func _play(gs: GameStateScript, from_day: int, days: int) -> void:
	for day: int in range(from_day, from_day + days):
		GameClock.elapsed_days = float(day)
		gs._on_time_advanced(1.0)
		gs._on_day_started(GameClock.get_day_index())
		gs._on_day_started_regrow()
		gs._tick_molt(0.001)
		gs.calibrate(gs.unit_ids()[day % gs.unit_ids().size()])
		gs.add_tire_usage(1000.0 / 3.0)
		var cell := Vector3i(day, 0, -day)
		if gs.till(cell):
			gs.plant_crop(cell)
		if not gs.job_board.is_empty():
			gs.accept_job(0)


func _worn() -> GameStateScript:
	var gs: GameStateScript = _make_state()
	gs.buy_standard("reference_gauge")
	gs.park_rover("rover_1", Transform3D(Basis(Vector3.UP, 0.1 + 0.2), Vector3(1.1, 2.2, 3.3)))
	gs.mined_fissures[&"FissureA"] = 2
	gs._spool_species.append(&"curlyhair")
	gs.optical_silk_spools = 1
	_play(gs, 1, 6)
	return gs


func _clean_files() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".unreadable", ".unreadable2", ".old", ".old.prev", ".new", ".new.tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _differs(a: Dictionary, b: Dictionary, when: String) -> String:
	for key: Variant in a:
		if var_to_bytes(a[key]) != var_to_bytes(b.get(key)):
			return "'%s' differs %s: %s vs %s" % [key, when, a[key], b.get(key)]
	return ""


func test_every_variable_is_saved_or_named_as_not() -> String:
	var gs: GameStateScript = GameStateScript.new()
	var problems: PackedStringArray = []
	var known: Array[String] = gs.SAVED_FIELDS + gs.SAVED_LATER + gs.NOT_SAVED
	var found: Array[String] = []
	for property: Dictionary in GameStateScript.get_script_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			found.append(property["name"])
			if not property["name"] in known:
				problems.append("'%s' is in neither SAVED_FIELDS, SAVED_LATER nor NOT_SAVED." % property["name"])
	for field: String in known:
		if not field in found:
			problems.append("'%s' is listed but is not a GameState variable." % field)
		if known.count(field) != 1:
			problems.append("'%s' is listed twice." % field)
	gs.free()
	return "\n".join(problems)


func test_round_trip_is_exact_and_play_continues_the_same() -> String:
	var elapsed: float = GameClock.elapsed_days
	var source: GameStateScript = _worn()
	var saved_day: float = GameClock.elapsed_days
	var data: Dictionary = bytes_to_var(var_to_bytes(source.farm_to_dict()))
	var target: GameStateScript = _make_state(7)
	_play(target, 1, 2)
	var old_steering: DriftingSensor = target.steering
	GameClock.elapsed_days = saved_day
	var problem: String = target.farm_from_dict(data)
	for list: String in ["cal_log", "plantings", "audit_log", "certificate_log", "active_jobs", "owned_standards"]:
		if problem == "" and data[list].is_empty():
			problem = "The test farm must have something in %s." % list
	if problem == "":
		problem = _differs(source.farm_to_dict(), target.farm_to_dict(), "after load")
	if problem == "" and (source.certificates != target.certificates or source.last_cal_records != target.last_cal_records):
		problem = "Certificates and last records must rebuild from the logs."
	if problem == "" and target.steering != old_steering:
		problem = "Sensors must be restored in place."
	for pair: Array in [[target.last_cal_records, target.cal_log], [target.certificates, target.certificate_log]]:
		for id: String in pair[0]:
			if problem == "" and not (pair[1] as Array).any(func(r: Dictionary) -> bool: return is_same(r, pair[0][id])):
				problem = "The latest record must be the log's own entry (%s)." % id
	if problem == "":
		_play(source, int(saved_day) + 1, 12)
		_play(target, int(saved_day) + 1, 12)
		problem = _differs(source.farm_to_dict(), target.farm_to_dict(), "12 days later")
	GameClock.elapsed_days = elapsed
	source.free()
	target.free()
	return problem


func test_saved_data_is_a_copy() -> String:
	var gs: GameStateScript = _make_state()
	gs.tilled_cells[Vector3i(1, 0, 1)] = true
	var data: Dictionary = gs.farm_to_dict()
	gs.tilled_cells[Vector3i(2, 0, 2)] = true
	var ok: bool = data["tilled_cells"].size() == 1
	var other: GameStateScript = _make_state(9)
	other.farm_from_dict(data)
	other.tilled_cells.clear()
	ok = ok and data["tilled_cells"].size() == 1
	gs.free()
	other.free()
	return "" if ok else "Saved data must not share with the farm."


func test_an_instrument_the_save_lacks_starts_new() -> String:
	var gs: GameStateScript = _make_state()
	var data: Dictionary = gs.farm_to_dict()
	var before: Dictionary = gs.steering.to_dict()
	data["sensors"].erase(gs.STEERING_ID)
	gs.steering.add_usage(1.0e6)
	var problem: String = gs.farm_from_dict(data)
	if problem == "" and gs.steering.to_dict() != before:
		problem = "A sensor missing from the save must not keep the old farm's state."
	gs.free()
	return problem


func test_bad_data_is_refused_whole() -> String:
	var gs: GameStateScript = _make_state()
	var good: Dictionary = gs.farm_to_dict()
	var before: PackedByteArray = var_to_bytes(good)
	var sensor_id: String = good["sensors"].keys()[0]
	var bads: Array[Dictionary] = []
	for change: Array in [["credits", "many"], ["credits", null], ["plantings", []], ["cal_log", [1]],
			["cal_log", [{}]], ["certificate_log", [{ "standard_id": 4 }]], ["phone_log", [{}]],
			["molt_progress", NAN], ["cal_log", [{ "instrument_id": "x", "mpe": NAN }]],
			["plantings", { Vector3i.ZERO: { "deep": [NAN] } }], ["rng_state", 1.5], ["sensors", []],
			["player_skill_xp", { "player_1": 5 }], ["player_skill_xp", { "player_1": { "calibration": "many" } }],
			["farm_skill_xp", { "husbandry": [] }], ["sensors", { sensor_id: { "error": NAN } }], ["sensors", { sensor_id: 3 }]]:
		var bad: Dictionary = good.duplicate(true)
		bad[change[0]] = change[1]
		bads.append(bad)
	var missing: Dictionary = good.duplicate(true)
	missing.erase("owned_standards")
	bads.append(missing)
	var problem: String = ""
	for i: int in bads.size():
		if gs.farm_from_dict(bads[i]) == "":
			problem = "Bad data %d loaded." % i
		elif var_to_bytes(gs.farm_to_dict()) != before:
			problem = "Refused data %d changed the farm." % i
	gs.free()
	return problem


## Runs `body` on the live autoloads and puts them back.
func _with_live(body: Callable) -> String:
	var held: Dictionary = SaveGame.snapshot()
	_clean_files()
	var problem: String = body.call()
	_clean_files()
	var back: String = SaveGame.restore(held)
	return problem if problem != "" else back


func test_file_round_trip_and_backup() -> String:
	return _with_live(_file_round_trip)


func _file_round_trip() -> String:
	for day: int in [1, 2, 3]:
		GameState.credits = 111 * day
		GameClock.elapsed_days = day + 1.0 / 3.0
		var problem: String = SaveGame.write(PATH)
		if problem != "":
			return problem
	GameState.credits = 999
	if SaveGame.read(PATH) != "" or GameState.credits != 333 or GameClock.elapsed_days != 3 + 1.0 / 3.0:
		return "The file must load what was saved last, exactly."
	DirAccess.remove_absolute(PATH)
	if not SaveGame.exists(PATH):
		return "A backup alone must count as a save."
	if SaveGame.read(PATH) != "" or GameState.credits != 222 or GameClock.elapsed_days != 2 + 1.0 / 3.0:
		return "With the save gone, the backup must load the save before."
	return ""


func test_damaged_foreign_and_newer_files_are_refused() -> String:
	return _with_live(_bad_files)


func _bad_files() -> String:
	if SaveGame.exists(PATH) or SaveGame.read(PATH) == "":
		return "A missing file must be refused."
	SaveGame.write(PATH)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var flipped: PackedByteArray = bytes.duplicate()
	flipped[flipped.size() - 20] ^= 0xFF
	var newer: PackedByteArray = bytes.duplicate()
	newer.encode_u32(SaveGame.MAGIC.length(), SaveGame.VERSION + 1)
	var cases: Array[PackedByteArray] = [flipped, newer, bytes.slice(0, bytes.size() - 1), bytes.slice(0, 10),
		"not a save file, but a long enough piece of text to pass".to_utf8_buffer(), PackedByteArray()]
	GameState.credits = 777
	for i: int in cases.size():
		var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
		file.store_buffer(cases[i])
		file.close()
		if SaveGame.read(PATH) == "" or GameState.credits != 777:
			return "Bad file %d must be refused." % i
	SaveGame.write(PATH)
	if FileAccess.file_exists(PATH + ".bak") or not FileAccess.file_exists(PATH + ".unreadable"):
		return "A file that won't load must be set aside, not become the backup."
	_damage(PATH)
	SaveGame.write(PATH)
	if not FileAccess.file_exists(PATH + ".unreadable2"):
		return "A second file that won't load must not replace the first."
	return ""


func test_new_farm_starts_over_and_sets_the_old_one_aside() -> String:
	return _with_live(_new_farm)


func _new_farm() -> String:
	GameClock.elapsed_days = 8.5
	GameState.credits = -1234
	GameState.tilled_cells[Vector3i(1, 0, 1)] = true
	GameState.steering.add_usage(1.0e5)
	var old_seed: int = GameState.world_seed
	SaveGame.write(PATH)
	SaveGame.write(PATH)
	var problem: String = SaveGame.start_new(PATH)
	SaveGame.farm_open = false
	if problem != "":
		return problem
	var expected: GameStateScript = GameStateScript.new()
	expected._set_up_farm(GameState.world_seed)
	problem = _differs(expected.farm_to_dict(), GameState.farm_to_dict(), "in a new farm")
	expected.free()
	if problem != "":
		return problem
	if GameState.world_seed == old_seed or GameClock.elapsed_days != 0.0:
		return "A new farm needs its own seed and day 1."
	var old: Dictionary = SaveGame.read_file(PATH + ".old")
	if not old.has("data") or old["data"]["farm"]["credits"] != -1234 or SaveGame.day_of(old["data"]) != 9:
		return "The old farm must be kept."
	if FileAccess.file_exists(PATH + ".bak"):
		return "The old farm's backup must not back up the new farm."
	return ""


func test_the_menu_hears_about_a_save_that_does_not_load() -> String:
	return _with_live(_menu_check)


func _menu_check() -> String:
	if not SaveGame.check(PATH).is_empty():
		return "No save, nothing to check."
	GameState.credits = 5
	SaveGame.write(PATH)
	SaveGame.write(PATH)
	if SaveGame.check(PATH).has("problem"):
		return "A good save has no problem."
	# Whole and undamaged, but not a farm that can load.
	var data: Dictionary = SaveGame.snapshot()
	data["farm"].erase("credits")
	SaveGame._write_data(data, PATH)
	SaveGame._write_data(data, PATH)
	var found: Dictionary = SaveGame.check(PATH)
	if not found.has("data") or not found.has("problem") or found["data"]["farm"]["credits"] != 5:
		return "The backup must be offered, with the problem."
	DirAccess.remove_absolute(PATH + ".bak")
	found = SaveGame.check(PATH)
	if found.has("data") or not found.has("problem"):
		return "With no backup there is only the problem."
	GameState.credits = 6
	if SaveGame.continue_farm(PATH) == "" or SaveGame.farm_open or GameState.credits != 6:
		return "A farm that can't load must not open."
	return ""


func _damage(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("damaged")
	file.close()


func test_interrupted_and_damaged_saves_fall_back() -> String:
	return _with_live(_fall_back)


func _fall_back() -> String:
	for credits: int in [10, 20]:
		GameState.credits = credits
		SaveGame.write(PATH)
	# Stopped between the two renames: the newest farm is in the temporary file.
	DirAccess.rename_absolute(PATH, PATH + ".tmp")
	GameState.credits = 0
	if not SaveGame.exists(PATH) or SaveGame.read(PATH) != "" or GameState.credits != 20:
		return "A finished temporary file must load when the save is missing."
	DirAccess.rename_absolute(PATH + ".tmp", PATH)
	_damage(PATH)
	if SaveGame.read(PATH) != "" or GameState.credits != 10:
		return "With the save damaged, the backup must load."
	# Whole and undamaged, but not a farm that can load: it must not become the backup.
	var data: Dictionary = SaveGame.snapshot()
	data["farm"]["cal_log"] = [{ "instrument_id": "x", "mpe": NAN }]
	SaveGame._write_data(data, PATH)
	GameState.credits = 30
	if SaveGame.write(PATH) != "" or SaveGame.read_file(PATH + ".bak")["data"]["farm"]["credits"] != 10:
		return "A save that can't load must not replace the backup."
	var log_size: int = GameState.cal_log.size()
	GameState.cal_log.append({ "instrument_id": "x", "mpe": NAN })
	var refused: String = SaveGame.write(PATH)
	GameState.cal_log.resize(log_size)
	if refused == "" or SaveGame.read_file(PATH)["data"]["farm"]["credits"] != 30:
		return "A farm that could not load again must not be written."
	return ""


func test_a_load_moves_a_live_rover() -> String:
	return _with_live(_rover_load)


func _rover_load() -> String:
	var spot := Transform3D(Basis.IDENTITY, Vector3(5, 0, 0))
	var rover: Node3D = (load("res://scripts/rover/rover_controller.gd") as GDScript).new()
	GameState.park_rover(rover.rover_id, spot)
	var data: Dictionary = SaveGame.snapshot()
	rover.transform = Transform3D(Basis.IDENTITY, Vector3(9, 0, 9))
	GameState.farm_loaded.connect(rover._unpark)
	SaveGame.restore(data)
	var at: Vector3 = rover.position
	var parked: Vector3 = GameState.parked_rover_transform(rover.rover_id).origin
	rover.free()
	return "" if at == spot.origin and parked == at else "A load must move the rover and keep the place it is parked (%s, %s)." % [at, parked]


func test_a_new_farm_that_fails_leaves_the_saved_one_alone() -> String:
	return _with_live(_new_farm_fails)


func _new_farm_fails() -> String:
	for credits: int in [10, 20]:
		GameState.credits = credits
		SaveGame.write(PATH)
	# A folder in the way stops the write (.new.tmp) or the move aside (.old).
	for blocked: String in [PATH + ".new.tmp", PATH + ".old"]:
		DirAccess.make_dir_absolute(blocked)
		var problem: String = SaveGame.start_new(PATH)
		DirAccess.remove_absolute(blocked)
		if problem == "" or SaveGame.farm_open:
			return "A new farm must not open with %s blocked." % blocked
		if SaveGame.read_file(PATH).get("data", {}).get("farm", {}).get("credits") != 20:
			return "The saved farm must stay, with %s blocked." % blocked
		if SaveGame.read_file(PATH + ".bak").get("data", {}).get("farm", {}).get("credits") != 10:
			return "The backup must stay, with %s blocked." % blocked
	# The second move fails: the first one is undone.
	_damage(PATH)
	DirAccess.make_dir_absolute(PATH + ".old")
	var problem: String = SaveGame.start_new(PATH)
	DirAccess.remove_absolute(PATH + ".old")
	if problem == "" or not FileAccess.file_exists(PATH) or FileAccess.file_exists(PATH + ".unreadable"):
		return "A move aside must be undone when a later one fails."
	return ""


func test_only_an_open_farm_autosaves_each_morning() -> String:
	var queued: Array[bool] = []
	for open: bool in [false, true]:
		SaveGame.farm_open = open
		SaveGame._on_day_started()
		queued.append(SaveGame._autosave_queued)
	# The queued call runs later, when no farm is open: it must write nothing.
	SaveGame.farm_open = false
	return "" if queued == [false, true] else "Only an open farm may queue an autosave: %s" % [queued]


func test_a_failed_new_farm_keeps_the_older_one() -> String:
	return _with_live(_failed_new_farm)


func _failed_new_farm() -> String:
	GameState.credits = 1
	SaveGame.write(PATH)
	DirAccess.rename_absolute(PATH, PATH + ".old")
	GameState.credits = 2
	SaveGame.write(PATH)
	DirAccess.rename_absolute(PATH, PATH + ".bak")
	# A folder in the save's place: the last step, placing the new farm, fails.
	DirAccess.make_dir_absolute(PATH)
	var problem: String = SaveGame.start_new(PATH)
	var opened: bool = SaveGame.farm_open
	SaveGame.farm_open = false
	DirAccess.remove_absolute(PATH)
	if problem == "" or opened:
		return "The new farm must not open."
	for pair: Array in [[".old", 1], [".bak", 2]]:
		if SaveGame.read_file(PATH + pair[0]).get("data", {}).get("farm", {}).get("credits") != pair[1]:
			return "The %s file must be put back." % pair[0]
	for suffix: String in [".old.prev", ".new", ".new.tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			return "A %s file is left behind." % suffix
	problem = SaveGame.start_new(PATH)
	SaveGame.farm_open = false
	if problem != "" or FileAccess.file_exists(PATH + ".old.prev"):
		return "Started for real, the older farm makes way: " + problem
	return "" if SaveGame.read_file(PATH + ".old")["data"]["farm"]["credits"] == 2 else "The last farm must be the one kept."


func test_the_title_menu_note() -> String:
	var menu: GDScript = preload("res://scripts/ui/title_menu.gd")
	if menu.note_for({}) != "" or menu.note_for({ "data": {} }) != "":
		return "Nothing to say without a problem."
	var with_backup: String = menu.note_for({ "data": {}, "problem": "Bad." })
	var without: String = menu.note_for({ "problem": "Bad." })
	if not with_backup.contains("Bad.") or not with_backup.contains("Continue") or not without.contains("Bad.") or without.contains("Continue"):
		return "%s / %s" % [with_backup, without]
	return ""
