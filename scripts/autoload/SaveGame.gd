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

const MAGIC: String = "OOSSAVE1"
const VERSION: int = 1
const DEFAULT_PATH: String = "user://farm.save"
const HASH_BYTES: int = 32

## True once a farm was opened from the title menu. A scene run on its own (the
## editor, tests) never autosaves over the player's farm.
var farm_open: bool = false
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
		_autosave_queued = true
		_autosave.call_deferred()


func _autosave() -> void:
	_autosave_queued = false
	var problem: String = write()
	if problem != "":
		push_warning("SaveGame: " + problem)
		save_failed.emit("SAVE FAILED: " + problem)


## Starts a new farm and saves it. A saved farm already there is kept beside it
## as ".old". Returns "" or why not; on a problem no farm opens.
func start_new(path: String = DEFAULT_PATH) -> String:
	var problem: String = _set_aside(path)
	if problem != "":
		return problem
	GameClock.elapsed_days = 0.0
	GameState.new_farm()
	problem = write(path)
	farm_open = problem == ""
	return problem


## Opens the saved farm. Returns "" or why not.
func continue_farm(path: String = DEFAULT_PATH) -> String:
	var problem: String = read(path)
	farm_open = problem == ""
	return problem


## The day a save's data is on.
func day_of(data: Dictionary) -> int:
	return floori(data["clock"]["elapsed_days"]) + 1


## Moves the farm's files out of a new farm's way: the one that loads to ".old",
## one that doesn't to ".unreadable".
func _set_aside(path: String) -> String:
	var old_taken: bool = false
	for file_path: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(file_path):
			continue
		var error: Error = OK
		if not read_file(file_path).has("data"):
			error = DirAccess.rename_absolute(file_path, path + ".unreadable")
		elif old_taken:
			error = DirAccess.remove_absolute(file_path)
		else:
			error = DirAccess.rename_absolute(file_path, path + ".old")
			old_taken = true
		if error != OK:
			return "Could not set aside %s (error %d)." % [file_path, error]
	return ""


## Everything a save holds, as plain data.
func snapshot() -> Dictionary:
	saving.emit()
	return {
		"clock": { "elapsed_days": GameClock.elapsed_days },
		"farm": GameState.farm_to_dict(),
	}


## Restores snapshot(). Returns "" or why not; on a problem nothing changes.
## Scenes must reload afterward (they read GameState when they open).
func restore(data: Dictionary) -> String:
	var problem: String = data_problem(data)
	if problem != "":
		return problem
	# The clock first, so listeners see the loaded day.
	GameClock.elapsed_days = data["clock"]["elapsed_days"]
	return GameState.farm_from_dict(data["farm"])


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
	return _write_data(snapshot(), path)


func _write_data(data: Dictionary, path: String) -> String:
	var payload: PackedByteArray = var_to_bytes(data)
	# The new file is complete before it replaces the old one.
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return "Could not write %s (error %d)." % [temp, FileAccess.get_open_error()]
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_32(VERSION)
	file.store_buffer(_hash(payload))
	file.store_buffer(payload)
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return "Could not write %s (error %d)." % [temp, write_error]
	if FileAccess.file_exists(path):
		# A file this game can't read (damaged, or from a newer version) is set
		# aside: it must not replace a good backup, or be lost.
		var aside: String = ".bak" if read_file(path).has("data") else ".unreadable"
		var aside_error: Error = DirAccess.rename_absolute(path, path + aside)
		if aside_error != OK:
			return "Could not back up %s (error %d)." % [path, aside_error]
	var move_error: Error = DirAccess.rename_absolute(temp, path)
	if move_error != OK:
		return "Could not replace %s (error %d)." % [path, move_error]
	return ""


## True if there is a save or a backup to load.
func exists(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## What Continue would load: { data }, with { problem } too when the newest save
## won't load and the backup is used instead; { problem } alone when neither
## loads; {} when there is no save.
func check(path: String = DEFAULT_PATH) -> Dictionary:
	if not exists(path):
		return {}
	var newest: Dictionary = read_file(path)
	if newest.has("data") or not FileAccess.file_exists(path + ".bak"):
		return newest
	var backup: Dictionary = read_file(path + ".bak")
	if backup.has("data"):
		newest["data"] = backup["data"]
	return newest


## Loads the farm, or the backup if the save is missing or won't load.
## Returns "" or why it failed; on a problem nothing changes.
func read(path: String = DEFAULT_PATH) -> String:
	var found: Dictionary = check(path)
	if found.has("data"):
		return restore(found["data"])
	return found.get("problem", "There is no saved farm.")


## { data } from a save file that can load, or { problem }.
func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { "problem": "%s does not exist." % path }
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
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
