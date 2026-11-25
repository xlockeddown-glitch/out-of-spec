extends "res://tests/coop_net.gd"
## A guest's own skills, kept on the guest's PC, and coming back to a farm.

const FILE: String = "user://test_coop_player.json"


func test_a_friend_who_returns_is_the_same_player() -> String:
	var host: Node = _host()
	var first: Node = _guest(host)
	var second: Node = _guest(host)
	var farm: Node = host.commands.state
	farm.player_skill_xp["player_2"] = { "calibration": 120 }
	first.leave()
	_until(func() -> bool: return host.players.size() == 2)
	var other: Node = _guest(host)
	first.join(LOCAL, host.port())
	_until(func() -> bool: return host.players.size() == 4 and first.is_guest())
	if first.commands.state.local_player_id != "player_2" or other.commands.state.local_player_id != "player_4":
		return _finish("Got %s and %s" % [first.commands.state.local_player_id, other.commands.state.local_player_id])
	if farm.player_skill_xp["player_2"] != { "calibration": 120 } or second.players.size() != 4:
		return _finish("Got %s" % [farm.player_skill_xp])
	# A saved farm still knows them.
	var loaded: Node = GameStateScript.new()
	loaded.build_registry()
	var problem: String = loaded.farm_dict_problem(farm.farm_to_dict())
	loaded.farm_from_dict(farm.farm_to_dict())
	var again: String = loaded.let_in_guest(first.profile.card()["key"], {}, ["player_1"] as Array[String])
	loaded.free()
	return _finish("" if problem == "" and again == "player_2" else "Got '%s', %s" % [problem, again])


func test_a_player_is_in_once() -> String:
	var host: Node = _host()
	var first: Node = _guest(host)
	var twin: Node = _session()
	twin.profile._key = first.profile.card()["key"]
	twin.join(LOCAL, host.port())
	_until(func() -> bool: return _got(twin, "refused"))
	var ok: bool = _got(twin, "refused", SessionScript.REASONS["here"]) and host.players == ["player_1", "player_2"] and first.is_guest()
	return _finish("" if ok else "Got %s" % [_log])


func test_skills_come_with_the_guest() -> String:
	var farm: Node = GameStateScript.new()
	farm.build_registry()
	var top: int = farm.xp_for_level(farm.max_skill_level())
	var players: Array[String] = ["player_1"]
	var key: String = "a".repeat(32)
	var brought: Dictionary = { "calibration": 130, "uncertainty": top * 9, "robotics": 500, "no_such_skill": 5 }
	var id: String = farm.let_in_guest(key, brought, players)
	var got: Dictionary = farm.player_skill_xp[id].duplicate()
	# The farm's is better now, then the guest's.
	farm.player_skill_xp[id]["calibration"] = 200
	farm.let_in_guest(key, { "calibration": 150, "field_ops": 10 }, players)
	var later: Dictionary = farm.player_skill_xp[id]
	var problem: String = ""
	if got != { "calibration": 130, "uncertainty": top } or farm.skill_xp("robotics", id) != 0:
		problem = "Got %s" % [got]
	elif later != { "calibration": 200, "uncertainty": top, "field_ops": 10 }:
		problem = "Then got %s" % [later]
	elif key in str(farm.farm_to_dict()):
		problem = "The key itself must not be on the farm: every guest gets the farm"
	farm.free()
	return problem


func test_strangers_can_t_fill_the_farm() -> String:
	var farm: Node = GameStateScript.new()
	farm.build_registry()
	var players: Array[String] = ["player_1"]
	var stays: String = farm.let_in_guest("f".repeat(32), {}, players)
	players.append(stays)
	for i: int in GameStateScript.MAX_KNOWN_GUESTS + 5:
		farm.let_in_guest("%032x" % i, { "calibration": 1 }, players)
	var ok: bool = farm.guest_ids.size() == GameStateScript.MAX_KNOWN_GUESTS and stays in farm.guest_ids.values() and farm.player_skill_xp.size() <= GameStateScript.MAX_KNOWN_GUESTS + 1
	var problem: String = farm.farm_dict_problem(farm.farm_to_dict())
	farm.free()
	return problem if ok else "The farm must forget, but not who is in"


func test_the_file_keeps_a_guest_s_skills() -> String:
	_clear()
	var host: Node = _host()
	var guest: Node = _session()
	var farm: Node = guest.commands.state
	var profile: Node = guest.profile
	profile.path = FILE
	profile.start(guest, farm)
	farm.player_skill_xp["player_1"] = { "calibration": 900 }
	farm.skill_xp_changed.emit("player_1", "calibration")
	if FileAccess.file_exists(FILE):
		return _end("Their own farm's skills stay there")
	guest.join(LOCAL, host.port())
	_until(func() -> bool: return guest.is_guest())
	var key: String = profile.card()["key"]
	farm.player_skill_xp["player_2"] = { "calibration": 60 }
	farm.farm_skill_xp["robotics"] = 70
	farm.skill_xp_changed.emit("player_3", "calibration")
	var early: Dictionary = profile.card()["skills"]
	farm.skill_xp_changed.emit("player_2", "calibration")
	farm.player_skill_xp["player_2"] = { "calibration": 10 }
	profile.keep()
	guest.leave()
	farm.player_skill_xp["player_1"] = { "calibration": 950 }
	profile.keep()
	var read: Node = ProfileScript.new()
	read.path = FILE
	var card: Dictionary = read.card()
	read.free()
	if not early.is_empty() or card != { "key": key, "skills": { "calibration": 60 } }:
		return _end("Got %s, then %s" % [early, card])
	return _end("")


func test_a_bad_file_is_set_aside() -> String:
	var key: String = "0".repeat(32)
	for text: String in ["", "{", "[]", "{}", '{"key":"%s"}' % key, '{"key":"x","skills":{}}', '{"key":"%s","skills":{"calibration":-1}}' % key,
			'{"key":"%s","skills":{"calibration":"9"}}' % key, '{"key":"%s","skills":{"calibration":1e300}}' % key,
			'{"key":"%s","skills":{"":1}}' % key, " ".repeat(ProfileScript.MAX_FILE_BYTES + 1)]:
		if not ProfileScript._parse(text.to_utf8_buffer()).is_empty():
			return "Must not be read: %s" % text.left(80)
	if not ProfileScript._parse(PackedByteArray([0xff, 0xfe])).is_empty():
		return "Not text"
	_clear()
	_put_file(FILE, "broken")
	var profile: Node = ProfileScript.new()
	profile.path = FILE
	var made: Dictionary = profile.card()
	var same: bool = profile.card() == made and ProfileScript.is_key(made["key"])
	var aside: bool = FileAccess.file_exists(FILE + ".unreadable")
	# Stopped just short of renaming.
	DirAccess.rename_absolute(FILE, FILE + ".tmp")
	var found: bool = profile.card() == made
	profile.free()
	_clear()
	return "" if same and aside and found else "Got %s, %s, %s" % [same, aside, found]


func _put_file(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _clear() -> void:
	for ending: String in ["", ".tmp", ".unreadable"]:
		if FileAccess.file_exists(FILE + ending):
			DirAccess.remove_absolute(FILE + ending)


func _end(problem: String) -> String:
	_clear()
	return _finish(problem)
