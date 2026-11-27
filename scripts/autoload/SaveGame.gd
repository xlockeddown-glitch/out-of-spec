extends Node
## Writes the farm to one file and reads it back. Autoloaded as `SaveGame`.
##
## The farm is shared, so in co-op the host saves. Values are stored in Godot's
## binary form without objects: Godot's JSON rounds floats, and a loaded farm
## must continue exactly as the saved one would.
##
## File: MAGIC, format version (32 bits), SHA-256 of the payload, then the
## payload (var_to_bytes of { clock, farm }).

## Emitted just before a save is taken, so scenes can park their rovers.
signal saving
## An autosave failed; `text` says why. Shown to the player.
signal save_failed(text: String)
## A morning's autosave was written.
signal saved

const MAGIC: String = "OOSSAVE1"
const VERSION: int = 1
const DEFAULT_PATH: String = "user://farm.save"
const HASH_BYTES: int = 32
## An earlier ".old", held until the new farm is in place.
const PREVIOUS_OLD: String = ".old.prev"

## True once a farm was opened from the title menu. A scene run on its own (the
## editor, tests) never autosaves over the player's farm.
var farm_open: bool = false
## The scene the farm opened from the title menu starts in.
var open_scene: String = SceneSwitcher.FARM_SCENE
var _autosave_queued: bool = false


func _ready() -> void:
	GameClock.day_started.connect(_on_day_started.unbind(1))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and farm_open:
		_autosave()


## Each morning. Deferred, because a bench job can cross 06:00 partway through
## its own changes.
func _on_day_started() -> void:
	if farm_open and not _autosave_queued:
		_autosave_queued = true  # one write, however many mornings a job crosses
		_autosave.call_deferred()


func _autosave() -> void:
	_autosave_queued = false
	if not farm_open or FarmCommands.guest:
		return
	var problem: String = write()
	if problem != "":
		push_warning("SaveGame: " + problem)
		save_failed.emit("SAVE FAILED: " + problem)
	else:
		saved.emit()


## Starts a new farm and saves it. A saved farm already there is kept beside it
## as ".old". Returns "" or why not; on a problem no farm opens and the saved
## farm stays where it was.
func start_new(path: String = DEFAULT_PATH) -> String:
	farm_open = false
	GameClock.elapsed_days = 0.0
	GameState.new_farm()
	# The first quests are offered before the first save.
	GameState.update_quests()
	open_scene = SceneSwitcher.FARM_SCENE
	# Written whole before anything is moved, so a full disk costs nothing.
	var fresh: String = path + ".new"
	if FileAccess.file_exists(fresh):
		DirAccess.remove_absolute(fresh)
	var problem: String = write(fresh)
	if problem == "":
		problem = read_file(fresh).get("problem", "")
	var moved: Array[PackedStringArray] = []
	if problem == "":
		problem = _set_aside(path, moved)
	if problem == "":
		var error: Error = DirAccess.rename_absolute(fresh, path)
		if error != OK:
			problem = "Could not place %s (error %d)." % [path, error]
	if problem != "":
		moved.reverse()
		for pair: PackedStringArray in moved:
			# Stops at one that fails: the next could replace a farm still there.
			if DirAccess.rename_absolute(pair[1], pair[0]) != OK:
				break
		for leftover: String in [fresh, fresh + ".tmp"]:
			if FileAccess.file_exists(leftover):
				DirAccess.remove_absolute(leftover)
		return problem
	# Last: the old farm's other files must not back up the new one.
	for leftover: String in [path + ".tmp", path + ".bak", path + PREVIOUS_OLD]:
		if FileAccess.file_exists(leftover):
			DirAccess.remove_absolute(leftover)
	farm_open = true
	return ""


## Opens the saved farm. Returns "" or why not.
func continue_farm(path: String = DEFAULT_PATH) -> String:
	var problem: String = read(path)
	farm_open = problem == ""
	# A farm from before a quest existed is offered it now, not at a command.
	if farm_open:
		GameState.update_quests()
	# A farm that opens on the farm has its rover there, where it went in. A rover
	# below belongs to its depth (saved with it) and stays there: depth is never reset
	# as a side effect of continuing.
	if farm_open and open_scene == SceneSwitcher.FARM_SCENE and GameState.rover_in_tunnels and GameState.rover_depth == 0:
		GameState.rover_in_tunnels = false
		GameState.rover_place_changed.emit()
	return problem


## The day a save's data is on.
func day_of(data: Dictionary) -> int:
	return floori(data["clock"]["elapsed_days"]) + 1


## Moves the farm's files out of a new farm's way: the one that loads to ".old",
## one that doesn't to ".unreadable". A second one that loads is left in place.
## Adds [from, to] to `moved` for each.
func _set_aside(path: String, moved: Array[PackedStringArray]) -> String:
	var old_taken: bool = false
	for file_path: String in _candidates(path):
		var target: String = _unreadable_path(path)
		if read_file(file_path).has("data"):
			if old_taken:
				continue
			target = path + ".old"
			old_taken = true
			if FileAccess.file_exists(target):
				var previous: String = path + PREVIOUS_OLD
				var previous_error: Error = DirAccess.rename_absolute(target, previous)
				if previous_error != OK:
					return "Could not set aside %s (error %d)." % [target, previous_error]
				moved.append(PackedStringArray([target, previous]))
		var error: Error = DirAccess.rename_absolute(file_path, target)
		if error != OK:
			return "Could not set aside %s (error %d)." % [file_path, error]
		moved.append(PackedStringArray([file_path, target]))
	return ""


## Everything a save holds, as plain data.
func snapshot() -> Dictionary:
	saving.emit()
	return {
		"clock": { "elapsed_days": GameClock.elapsed_days },
		"farm": GameState.farm_to_dict(),
		"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "",
	}


## Restores snapshot(). Returns "" or why not; on a problem nothing changes.
## Scenes must reload afterward (they read GameState when they open).
func restore(data: Dictionary) -> String:
	var problem: String = data_problem(data)
	if problem != "":
		return problem
	# The clock first, so listeners see the loaded day.
	GameClock.elapsed_days = data["clock"]["elapsed_days"]
	problem = GameState.farm_from_dict(data["farm"])
	# Anything else, and a save from before this, opens the farm.
	var in_tunnels: bool = GameState.rover_in_tunnels and str(data.get("scene")) == SceneSwitcher.TUNNELS_SCENE
	# A day trip still on when the save was made carries on at its moon's hub.
	var on_a_moon: bool = GameState.shuttle_trips.has(GameState.local_player_id) 			and Shuttle.is_moon(GameState.place_of(GameState.local_player_id))
	var moon_scene: String = ZoneData.hub_scene(StringName(GameState.place_of(GameState.local_player_id))) if on_a_moon else ""
	open_scene = moon_scene if moon_scene != "" else (SceneSwitcher.TUNNELS_SCENE if in_tunnels else SceneSwitcher.FARM_SCENE)
	return problem


## Why `data` can't load, or "" if it can. Changes nothing.
func data_problem(data: Dictionary) -> String:
	var clock: Variant = data.get("clock")
	var farm: Variant = data.get("farm")
	if typeof(clock) != TYPE_DICTIONARY or typeof(farm) != TYPE_DICTIONARY:
		return "The save has no clock or no farm."
	var elapsed: Variant = clock.get("elapsed_days")
	if typeof(elapsed) != TYPE_FLOAT or not is_finite(elapsed) or elapsed < 0.0:
		return "The save's clock is bad."
	return GameState.farm_dict_problem(farm)


## Saves the farm. The save before it is kept beside it as ".bak". Returns ""
## or why it failed.
func write(path: String = DEFAULT_PATH) -> String:
	if FarmCommands.guest:
		return "Only the host saves the farm."
	var data: Dictionary = snapshot()
	# A farm that could not load again must not replace one that can.
	var problem: String = data_problem(data)
	if problem != "":
		return "The farm can't be saved: " + problem
	return _write_data(data, path)


func _write_data(data: Dictionary, path: String) -> String:
	# The new file is complete before it replaces the old one.
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return "Could not write %s (error %d)." % [temp, FileAccess.get_open_error()]
	file.store_buffer(to_bytes(data))
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return "Could not write %s (error %d)." % [temp, write_error]
	if FileAccess.file_exists(path):
		# A file this game can't read (damaged, or from a newer version) is set
		# aside: it must not replace a good backup, or be lost.
		var aside: String = path + ".bak" if read_file(path).has("data") else _unreadable_path(path)
		var aside_error: Error = DirAccess.rename_absolute(path, aside)
		if aside_error != OK:
			return "Could not back up %s (error %d)." % [path, aside_error]
	# Stopped here, the farm is in the temporary file; _candidates() finds it.
	var move_error: Error = DirAccess.rename_absolute(temp, path)
	if move_error != OK:
		return "Could not replace %s (error %d)." % [path, move_error]
	return ""


## A name for a file that can't be read. One set aside earlier is kept.
func _unreadable_path(path: String) -> String:
	var aside: String = path + ".unreadable"
	var number: int = 2
	while FileAccess.file_exists(aside):
		aside = "%s.unreadable%d" % [path, number]
		number += 1
	return aside


## The files that can hold the farm, newest first. The temporary file counts
## only while the save is missing: a write stopped between its two renames.
func _candidates(path: String) -> Array[String]:
	var found: Array[String] = []
	for file_path: String in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(file_path) and not (file_path == path + ".tmp" and path in found):
			found.append(file_path)
	return found


## True if there is a save, or a file that stands in for one, to try.
func exists(path: String = DEFAULT_PATH) -> bool:
	return not _candidates(path).is_empty()


## What Continue would load: { data }, with { problem } too when the newest save
## won't load and one before it is used instead; { problem } alone when none
## loads; {} when there is no save.
func check(path: String = DEFAULT_PATH) -> Dictionary:
	var found: Dictionary = {}
	for file_path: String in _candidates(path):
		var result: Dictionary = read_file(file_path)
		if result.has("data"):
			found["data"] = result["data"]
			break
		if not found.has("problem"):
			found["problem"] = result["problem"]
	return found


## Loads what check() found. Returns "" or why it failed; on a problem nothing
## changes.
func read(path: String = DEFAULT_PATH) -> String:
	var found: Dictionary = check(path)
	if found.has("data"):
		return restore(found["data"])
	return found.get("problem", "There is no saved farm.")


## { data } from a save file that can load, or { problem }.
func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { "problem": "%s does not exist." % path }
	return from_bytes(FileAccess.get_file_as_bytes(path), path)


## `data` as a save file holds it.
func to_bytes(data: Dictionary) -> PackedByteArray:
	var payload: PackedByteArray = var_to_bytes(data)
	var bytes: PackedByteArray = MAGIC.to_ascii_buffer()
	bytes.resize(MAGIC.length() + 4)
	bytes.encode_u32(MAGIC.length(), VERSION)
	bytes.append_array(_hash(payload))
	bytes.append_array(payload)
	return bytes


## { data } that can load from to_bytes(), or { problem } about `path`.
func from_bytes(bytes: PackedByteArray, path: String) -> Dictionary:
	var header: int = MAGIC.length() + 4 + HASH_BYTES
	if bytes.size() <= header or bytes.slice(0, MAGIC.length()) != MAGIC.to_ascii_buffer():
		return { "problem": "%s is not a save file." % path }
	var version: int = bytes.decode_u32(MAGIC.length())
	if version != VERSION:
		return { "problem": "%s is save version %d; this game reads version %d." % [path, version, VERSION] }
	var payload: PackedByteArray = bytes.slice(header)
	if _hash(payload) != bytes.slice(MAGIC.length() + 4, header):
		return { "problem": "%s is damaged." % path }
	var data: Variant = bytes_to_var(payload)
	if typeof(data) != TYPE_DICTIONARY:
		return { "problem": "%s holds no farm." % path }
	var problem: String = data_problem(data)
	if problem != "":
		return { "problem": "%s can't load: %s" % [path, problem] }
	return { "data": data }


func _hash(payload: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return context.finish()
