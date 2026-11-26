extends Node
## Who this player is on friends' farms, and the skills earned there: a file on
## this PC that the player may edit. Autoloaded as `CoopProfile`. It is read
## and written only to join a farm, and as a guest.

const PATH: String = "user://coop_player.json"
const KEY_BYTES: int = 16
## More XP than any skill can need. JSON keeps whole numbers this big exactly.
const MOST_XP: int = 1000000000
## So that they fit in a guest's message.
const MOST_SKILLS: int = 16
const MAX_FILE_BYTES: int = 8192
## Written to the file as "curve". 2 is XP counted on the 99-level curve, from
## when Robotics and Husbandry were a farm's and crops fed Field Ops. 3 is that
## with every skill the player's own and crop XP in Agronomy (4 of
## GameState.KNOWN_CURVES; the lab level changed no player's XP, so no file says
## that one). A file without it is from the 10-level curve.
const CURVE: int = 3
## The curves a file may say. A 2 loads as it is: nothing says how much of its
## Field Ops came from crops, so none of it becomes Agronomy [ASSUMPTION].
const KNOWN_CURVES: Array[int] = [2, 3]
## Skills there once were. A file that has one loads without it.
const GONE_SKILLS: Array[String] = ["instrumentation"]

## Only tests set others. "" keeps no file.
var path: String = PATH
var session: Node
var farm: Node

## Made when there is no file, and kept in case none can be written.
var _key: String = ""
var _failed: bool = false


func _ready() -> void:
	start(CoopSession, GameState)
	CoopSync.farm_ready.connect(keep)


func start(with_session: Node, with_farm: Node) -> void:
	session = with_session
	farm = with_farm
	farm.skill_xp_changed.connect(_on_xp_changed)


## What a host is told: { key, skills }. The key is a secret: whoever has it can
## join as this player.
func card() -> Dictionary:
	var out: Dictionary = _read()
	if out.is_empty():
		_key = _new_key() if _key == "" else _key
		out = { "key": _key, "skills": {} }
		_write(out)
	return out


## Guest: keeps the XP this player has here, unless more is kept already.
func keep() -> void:
	if not session.is_guest():
		return
	var mine: Dictionary = card()
	var before: Dictionary = mine["skills"].duplicate()
	for skill: String in farm.skill_ids():
		if not farm.is_farm_skill(skill):
			var xp: int = clampi(farm.skill_xp(skill), 0, MOST_XP)
			if xp > mine["skills"].get(skill, 0):
				mine["skills"][skill] = xp
	if mine["skills"] != before:
		_write(mine)


static func is_key(value: Variant) -> bool:
	if not value is String or value.length() != KEY_BYTES * 2:
		return false
	for letter: String in value:
		if not letter in "0123456789abcdef":
			return false
	return true


## Whole XP by skill id. Which skills there are is for the farm to say.
static func are_skills(value: Variant) -> bool:
	if not value is Dictionary or value.size() > MOST_SKILLS:
		return false
	for skill: Variant in value:
		if not skill is String or skill == "" or skill.length() > CoopSession.MAX_TEXT:
			return false
		if not value[skill] is int or value[skill] < 0:
			return false
	return true


func _on_xp_changed(player_id: String, _skill_id: String) -> void:
	if player_id == farm.local_player_id:
		keep()


func _new_key() -> String:
	return Crypto.new().generate_random_bytes(KEY_BYTES).hex_encode()


## {} if there is none. One that can't be read is set aside.
func _read() -> Dictionary:
	if path == "":
		return {}
	# The temporary file is left when the game stopped just short of renaming it.
	for at: String in [path, path + ".tmp"]:
		if not FileAccess.file_exists(at):
			continue
		var got: Dictionary = _parse(FileAccess.get_file_as_bytes(at))
		if not got.is_empty():
			return got
		DirAccess.rename_absolute(at, SaveGame._unreadable_path(at))
	return {}


## Godot reports an error for text it can't read, so it gets only text.
static func _parse(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_FILE_BYTES or not CoopSession._is_text(bytes, 0, bytes.size()):
		return {}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {}
	var skills: Variant = json.data.get("skills")
	if not is_key(json.data.get("key")) or not skills is Dictionary:
		return {}
	# XP from the 10-level curve converts as a farm's does (GameState._convert_old_xp).
	# A curve this build does not know is refused rather than guessed at.
	if json.data.has("curve") and not (json.data["curve"] is float and json.data["curve"] == floorf(json.data["curve"]) and int(json.data["curve"]) in KNOWN_CURVES):
		return {}
	var factor: float = 1.0 if json.data.has("curve") else DataManager.get_number(&"skills", "old_curve/xp_factor", 5.0)
	var whole: Dictionary = {}
	for skill: Variant in skills:
		if skill in GONE_SKILLS:
			continue
		if not skills[skill] is float or skills[skill] < 0.0 or skills[skill] > MOST_XP:
			return {}
		whole[skill] = mini(roundi(skills[skill] * factor), MOST_XP)
	return { "key": json.data["key"], "skills": whole } if are_skills(whole) else {}


func _write(data: Dictionary) -> void:
	if path == "":
		return
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	var done: bool = file != null
	if done:
		file.store_string(JSON.stringify({ "key": data["key"], "skills": data["skills"], "curve": CURVE }, "\t"))
		done = file.get_error() == OK
		file.close()
	# The new file is complete before it replaces the old one.
	done = done and DirAccess.rename_absolute(temp, path) == OK
	if not done and not _failed:
		SaveGame.save_failed.emit("SKILLS NOT SAVED: could not write %s." % path)
	_failed = not done
