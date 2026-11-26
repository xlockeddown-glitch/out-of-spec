extends Node
## Who this player is on friends' farms, and what they earned there: their
## skills, quest points, XP certificates and their own quests. A file on this PC
## that the player may edit. Autoloaded as `CoopProfile`. It is read and written
## only to join a farm, and as a guest.
##
## The file is the guest's record of every farm they have been on; each host is
## the authority for its own farm. They meet when the guest joins
## (GameState.let_in_guest) and whenever the host's farm changes (keep). Both
## only ever take the higher value or the union, so nothing is counted twice by
## joining two hosts or by coming back.

const PATH: String = "user://coop_player.json"
const KEY_BYTES: int = 16
## More XP than any skill can need. JSON keeps whole numbers this big exactly.
const MOST_XP: int = 1000000000
## So that they fit in a guest's message.
const MOST_SKILLS: int = 16
## Room for any record of MAX_RECORD_BYTES as JSON writes it, with the key and
## the skills [PLACEHOLDER].
const MAX_FILE_BYTES: int = 131072
## The quests a record may name in its points, in its certificates held and in
## its certificates spent [PLACEHOLDER]. More than data/quests.json has
## (tests/test_coop_quests.gd checks), so none of these is ever left out: they
## are what stops a quest paying twice.
const MOST_QUESTS: int = 128
## The player's own quests a record may keep progress in, and the steps of one
## of them [PLACEHOLDER].
const MOST_PROGRESS: int = 64
const MOST_STEPS: int = 12
## The most a record weighs as var_to_bytes() gives it, in the file and in a
## hello alike (fitted) [PLACEHOLDER]. Points, certificates held and spent at
## MOST_QUESTS each, and MOST_PROGRESS quests marked done, are under 40000
## bytes, so they always fit. With the key and the skills it is under
## CoopSession.MAX_HELLO_BYTES.
const MAX_RECORD_BYTES: int = 49152
## Written to the file as "curve". 2 is XP counted on the 99-level curve, from
## when Robotics and Husbandry were a farm's and crops fed Field Ops. 3 is that
## with every skill the player's own and crop XP in Agronomy (4 of
## GameState.KNOWN_CURVES; the lab level changed no player's XP, so no file says
## that one). A file without it is from the 10-level curve. The record added at
## build step 8 of quests_levels_story.md changed no XP either: a file without
## it loads with an empty one.
const CURVE: int = 3
## The curves a file may say. A 2 loads as it is: nothing says how much of its
## Field Ops came from crops, so none of it becomes Agronomy [ASSUMPTION].
const KNOWN_CURVES: Array[int] = [2, 3]
## Skills there once were. A file that has one loads without it.
const GONE_SKILLS: Array[String] = ["instrumentation"]
## The record, in the file and in a guest's hello:
##   quest_points           quest id -> the points that quest paid this player
##   xp_certificates        quest id -> the XP of the certificate held from it
##   xp_certificates_spent  ids of the quests whose certificate is spent
##   quests                 quest id -> { done, steps, counts }: the player's
##                          own quests (QuestEngine.travelling)
const RECORD_KEYS: Array[String] = ["quest_points", "xp_certificates", "xp_certificates_spent", "quests"]
const QUEST_KEYS: Array[String] = ["done", "steps", "counts"]

## Only tests set others. "" keeps no file.
var path: String = PATH
var session: Node
var farm: Node
## What says whether the host's farm has come (CoopSync). Tests leave it null.
var sync: Node

## Made when there is no file, and kept in case none can be written.
var _key: String = ""
var _failed: bool = false


func _ready() -> void:
	start(CoopSession, GameState)
	sync = CoopSync
	CoopSync.farm_ready.connect(keep)


func start(with_session: Node, with_farm: Node) -> void:
	session = with_session
	farm = with_farm
	farm.skill_xp_changed.connect(_on_xp_changed)
	farm.quests_changed.connect(keep)
	farm.xp_certificates_changed.connect(keep)


## What a host is told: { key, skills }. The key is a secret: whoever has it can
## join as this player.
func card() -> Dictionary:
	var all: Dictionary = _all()
	return { "key": all["key"], "skills": all["skills"] }


## What a host is told besides: the RECORD_KEYS, small enough for a hello.
func record() -> Dictionary:
	var all: Dictionary = _all()
	var out: Dictionary = {}
	for key: String in RECORD_KEYS:
		out[key] = all[key]
	return fitted(out)


## `record`, or a copy of it that weighs no more than MAX_RECORD_BYTES. Only
## progress in the player's own quests is given up: first the steps and counts
## of the quests that are done (nothing reads them: done is done), then the
## quests under way, the biggest first. Points, certificates held and spent,
## and which quests are done, are never dropped.
static func fitted(record: Dictionary) -> Dictionary:
	if var_to_bytes(record).size() <= MAX_RECORD_BYTES:
		return record
	var out: Dictionary = record.duplicate(true)
	var quests: Dictionary = out["quests"]
	for id: Variant in quests:
		if quests[id]["done"] == true:
			quests[id] = { "done": true, "steps": [], "counts": {} }
	var dropped: int = 0
	while var_to_bytes(out).size() > MAX_RECORD_BYTES:
		var biggest: Variant = null
		var most: int = -1
		for id: Variant in quests:
			var size: int = -1 if quests[id]["done"] == true else var_to_bytes([id, quests[id]]).size()
			if size > most:
				most = size
				biggest = id
		if biggest == null:
			break
		quests.erase(biggest)
		dropped += 1
	push_warning("CoopProfile: the record was over %d bytes; the progress of %d quest(s) under way was left out. Points and certificates are all kept." % [MAX_RECORD_BYTES, dropped])
	return out


static func no_record() -> Dictionary:
	return { "quest_points": {}, "xp_certificates": {}, "xp_certificates_spent": [], "quests": {} }


## Guest: keeps what this player has here, unless more is kept already: the XP,
## and the record.
func keep() -> void:
	# Between the host's welcome and its farm, the farm here is still this
	# player's own: nothing of it is a guest's to keep.
	if not session.is_guest() or (sync != null and not sync.has_farm()):
		return
	var mine: Dictionary = _all()
	var changed: bool = false
	for skill: String in farm.skill_ids():
		if not farm.is_farm_skill(skill):
			var xp: int = clampi(farm.skill_xp(skill), 0, MOST_XP)
			if xp > mine["skills"].get(skill, 0):
				mine["skills"][skill] = xp
				changed = true
	if _keep_record(mine) or changed:
		_write(mine)


## The host's copy of this player's record goes into `mine`. Points and counts
## by the higher value, steps and spent certificates by union; a certificate is
## held until it is spent anywhere. True if `mine` changed. Points and
## certificates have their own room (MOST_QUESTS each), apart from quest
## progress (MOST_PROGRESS), so progress can never crowd them out.
func _keep_record(mine: Dictionary) -> bool:
	var me: String = farm.local_player_id
	var changed: bool = false
	if _keep_counts(mine["quest_points"], farm.quest_points.get(me, {}), MOST_QUESTS):
		changed = true
	var spent: Array = mine["xp_certificates_spent"]
	for source: Variant in farm.xp_certificates_spent.get(me, []):
		if not _is_name(source) or source in spent:
			continue
		if spent.size() >= MOST_QUESTS:
			# More spent certificates than there are quests: not from this game's data.
			push_warning("CoopProfile: no room to keep that the certificate of '%s' is spent." % source)
			continue
		spent.append(source)
		changed = true
	var held: Dictionary = mine["xp_certificates"]
	var here: Dictionary = {}
	var theirs: Dictionary = farm.xp_certificates.get(me, {})
	for id: Variant in theirs:
		var source: String = farm.xp_certificate_source(str(id))
		here[source] = maxi(int(theirs[id]), int(here.get(source, 0)))
	if _keep_counts(held, here, MOST_QUESTS):
		changed = true
	for source: Variant in held.keys():
		if source in spent:
			held.erase(source)
			changed = true
	var quests: Dictionary = mine["quests"]
	var now: Dictionary = QuestEngine.travelling(farm, me)
	for id: Variant in now:
		if not _is_name(id) or not (quests.has(id) or quests.size() < MOST_PROGRESS):
			continue
		var moved: bool = not quests.has(id)
		var kept: Dictionary = quests.get(id, { "done": false, "steps": [], "counts": {} })
		if now[id]["done"] and not kept["done"]:
			kept["done"] = true
			moved = true
		for step: Variant in now[id]["steps"]:
			if _is_name(step) and not step in kept["steps"] and kept["steps"].size() < MOST_STEPS:
				kept["steps"].append(step)
				moved = true
		if _keep_counts(kept["counts"], now[id]["counts"], MOST_STEPS):
			moved = true
		if moved:
			quests[id] = kept
			changed = true
	return changed


## Each count of `theirs` that is higher goes into `kept`, up to `most` names.
static func _keep_counts(kept: Dictionary, theirs: Dictionary, most: int) -> bool:
	var changed: bool = false
	for id: Variant in theirs:
		if not _is_name(id) or not theirs[id] is int or not (kept.has(id) or kept.size() < most):
			continue
		var count: int = clampi(theirs[id], 0, MOST_XP)
		if count > int(kept.get(id, 0)):
			kept[id] = count
			changed = true
	return changed


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


## A record as the file and a hello may have it: every key, names and whole
## numbers, and no more of them than fit. Which quests there are, and what they
## pay, is for the farm to say.
static func is_record(value: Variant) -> bool:
	if not value is Dictionary or value.size() != RECORD_KEYS.size() or not value.has_all(RECORD_KEYS):
		return false
	if not _are_counts(value["quest_points"], 0, MOST_QUESTS) or not _are_counts(value["xp_certificates"], 1, MOST_QUESTS):
		return false
	if not _are_names(value["xp_certificates_spent"], MOST_QUESTS):
		return false
	var quests: Variant = value["quests"]
	if not quests is Dictionary or quests.size() > MOST_PROGRESS:
		return false
	for id: Variant in quests:
		var quest: Variant = quests[id]
		if not _is_name(id) or not quest is Dictionary or quest.size() != QUEST_KEYS.size() or not quest.has_all(QUEST_KEYS):
			return false
		if not quest["done"] is bool or not _are_names(quest["steps"], MOST_STEPS) or not _are_counts(quest["counts"], 0, MOST_STEPS):
			return false
	return true


## Counted in bytes, so that what a record may weigh is known (MAX_RECORD_BYTES).
static func _is_name(value: Variant) -> bool:
	return value is String and value != "" and value.to_utf8_buffer().size() <= CoopSession.MAX_TEXT


## A list of names, each once.
static func _are_names(value: Variant, most: int) -> bool:
	if not value is Array or value.size() > most:
		return false
	for name: Variant in value:
		if not _is_name(name) or value.count(name) > 1:
			return false
	return true


## Whole numbers by name, from `least` up.
static func _are_counts(value: Variant, least: int, most: int) -> bool:
	if not value is Dictionary or value.size() > most:
		return false
	for name: Variant in value:
		if not _is_name(name) or not value[name] is int or value[name] < least or value[name] > MOST_XP:
			return false
	return true


func _on_xp_changed(player_id: String, _skill_id: String) -> void:
	if player_id == farm.local_player_id:
		keep()


func _new_key() -> String:
	return Crypto.new().generate_random_bytes(KEY_BYTES).hex_encode()


## The whole file: key, skills and the record. Made if there is none.
func _all() -> Dictionary:
	var out: Dictionary = _read()
	if out.is_empty():
		_key = _new_key() if _key == "" else _key
		out = { "key": _key, "skills": {} }
		out.merge(no_record())
		_write(out)
	return out


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
	var kept: Dictionary = _record_of(json.data)
	if not are_skills(whole) or kept.is_empty():
		return {}
	var out: Dictionary = { "key": json.data["key"], "skills": whole }
	out.merge(kept)
	return out


## The record a file has, with JSON's numbers made whole: empty parts for a file
## from before there was one, and {} for one that is not a record.
static func _record_of(data: Dictionary) -> Dictionary:
	var out: Dictionary = no_record()
	for key: String in ["quest_points", "xp_certificates"]:
		out[key] = _whole(data.get(key, {}))
	out["xp_certificates_spent"] = data.get("xp_certificates_spent", [])
	var quests: Variant = data.get("quests", {})
	if not quests is Dictionary:
		return {}
	for id: Variant in quests:
		var quest: Variant = quests[id]
		if not quest is Dictionary:
			return {}
		out["quests"][id] = { "done": quest.get("done"), "steps": quest.get("steps"), "counts": _whole(quest.get("counts")) }
	return out if is_record(out) else {}


## JSON's numbers as whole numbers; anything else is left for is_record() to refuse.
static func _whole(counts: Variant) -> Variant:
	if not counts is Dictionary:
		return counts
	var out: Dictionary = {}
	for name: Variant in counts:
		var count: Variant = counts[name]
		out[name] = int(count) if count is float and count == floorf(count) and absf(count) <= MOST_XP else count
	return out


func _write(data: Dictionary) -> void:
	if path == "":
		return
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	var done: bool = file != null
	if done:
		var record: Dictionary = {}
		for key: String in RECORD_KEYS:
			record[key] = data[key]
		var all: Dictionary = { "key": data["key"], "skills": data["skills"], "curve": CURVE }
		# What is too big gives up quest progress, never points or certificates.
		all.merge(fitted(record))
		var text: String = JSON.stringify(all, "\t")
		# A file too big to read back is not written over one that can be. A
		# fitted record is never that big (MAX_FILE_BYTES).
		done = text.to_utf8_buffer().size() <= MAX_FILE_BYTES
		if not done:
			push_warning("CoopProfile: %s not written: %d bytes is over %d." % [path, text.to_utf8_buffer().size(), MAX_FILE_BYTES])
		if done:
			file.store_string(text)
			done = file.get_error() == OK
		file.close()
	# The new file is complete before it replaces the old one.
	done = done and DirAccess.rename_absolute(temp, path) == OK
	if not done and not _failed:
		SaveGame.save_failed.emit("SKILLS NOT SAVED: could not write %s." % path)
	_failed = not done
