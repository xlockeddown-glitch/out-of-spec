extends "res://tests/coop_net.gd"
## Co-op sessions, over real connections on this machine only.


func test_nothing_opens_unless_asked() -> String:
	if CoopSession._peer != null or CoopSession.is_processing() or FarmCommands.guest or FarmCommands.remote.is_valid():
		return "Playing alone must open nothing"
	return ""


func test_a_bad_address_opens_nothing() -> String:
	var session: Node = _host()
	session.leave()
	for bad: Array in [["nowhere", 0], ["", 0], ["127.0.0.1", -1], ["127.0.0.1", 65536]]:
		if session.host(bad[1], bad[0]) == "" or session._peer != null:
			return _finish("%s must not open" % [bad])
	return _finish("")


func test_only_enet_is_available() -> String:
	var session: Node = _session()
	for way: String in ["steam", "Enet", ""]:
		var host_problem: String = session.host(0, LOCAL, way)
		var join_problem: String = session.join(LOCAL, 1, way)
		if host_problem == "" or join_problem != host_problem or (host_problem == SessionScript.NO_STEAM) != (way == "steam"):
			return _finish("'%s' got '%s', '%s'" % [way, host_problem, join_problem])
		if session._peer != null or session.is_hosting() or session.port() != 0 or session.is_processing():
			return _finish("'%s' must open nothing" % way)
	if session.host(0, LOCAL, "enet") != "" or not session._peer is ENetMultiplayerPeer or session.port() == 0:
		return _finish("ENet must still open after a refusal")
	if session.host(0, LOCAL, "steam") != "Leave the co-op farm first.":
		return _finish("An open farm comes first")
	var guest: Node = _session()
	if guest.join(LOCAL, session.port(), "enet") != "" or not _until(func() -> bool: return _got(guest, "joined")):
		return _finish("And be joined")
	session.leave()
	return _finish("" if session.port() == 0 else "A closed farm has no port")


func test_joining_and_leaving() -> String:
	var host: Node = _host()
	var first: Node = _guest(host)
	var second: Node = _guest(host)
	_until(func() -> bool: return _got(first, "player_joined", "player_3"))
	if not _got(first, "joined", "player_2") or not _got(second, "joined", "player_3") or not _got(first, "player_joined", "player_3"):
		return _finish("Got %s" % [_log])
	if host.players != ["player_1", "player_2", "player_3"] or second.players != host.players or first.players != host.players:
		return _finish("The players are %s, %s, %s" % [host.players, first.players, second.players])
	if not first.commands.guest or first.commands.state.local_player_id != "player_2" or host.commands.guest:
		return _finish("The guest must be a guest")
	if first.host(0, LOCAL) == "" or first.join(LOCAL, 1) == "":
		return _finish("A guest must leave before anything else")
	first.leave()
	if first.commands.guest or first.commands.state.local_player_id != "player_1":
		return _finish("Leaving must end being a guest")
	if not _until(func() -> bool: return _got(host, "player_left", "player_2") and _got(second, "player_left", "player_2")):
		return _finish("Everyone must hear who left")
	var third: Node = _guest(host)
	if not _got(third, "joined", "player_4"):
		return _finish("A newcomer must not take a leaver's id")
	host.leave()
	var again: GameStateScript = GameStateScript.new()
	again.build_registry()
	again.farm_from_dict(host.commands.state.farm_to_dict())
	host.commands.state.free()
	host.commands.state = again
	host.host(0, LOCAL)
	return _finish("" if _got(_guest(host), "joined", "player_5") else "Nor after the farm is loaded and hosted again")


func test_two_leaving_at_once() -> String:
	var host: Node = _host()
	var guests: Array[Node] = [_guest(host), _guest(host), _guest(host)]
	guests[0].leave()
	guests[1].leave()
	OS.delay_msec(50)
	var heard: bool = _until(func() -> bool: return _got(guests[2], "player_left", "player_2") and _got(guests[2], "player_left", "player_3"))
	return _finish("" if heard and host.players.size() == 2 else "Both must be known gone")


func test_only_whole_good_messages_are_read() -> String:
	var typed: Array[String] = ["a"]
	var typed_map: Dictionary[String, int] = { "a": 1 }
	var deep: Variant = []
	for i: int in SessionScript.MAX_DEPTH - 1:
		deep = [deep]
	for good: Variant in [[null, true, 1, -1099511627776, 2.5, 0.1, "héllo 🕷", &"n", Vector3i(-1, 2, 3)], [{ "k": [{}] }, {}],
			[typed, typed_map], [PackedByteArray([1, 2, 3])], deep, [""]]:
		var bytes: PackedByteArray = var_to_bytes(good)
		if SessionScript._end_of(bytes, 0) != bytes.size() or not SessionScript.is_plain(good):
			return "Must be read: %s" % [good]
		for cut: int in bytes.size():
			if SessionScript._end_of(bytes.slice(0, cut), 0) == cut:
				return "Cut to %d must not: %s" % [cut, good]
	for bad: Variant in [[deep], [Vector3.ZERO], [NodePath("a")], [RefCounted.new()], [[PackedStringArray(["a"])]]]:
		var bytes: PackedByteArray = var_to_bytes(bad)
		if SessionScript._end_of(bytes, 0) == bytes.size():
			return "Must not be read: %s" % [bad]
	var text: PackedByteArray = var_to_bytes(["abcd"])
	for spelling: Array in [[0xff, 1, 1, 1], [0xc0, 0x80, 1, 1], [0xed, 0xa0, 0x80, 1], [0xe2, 0x82, 1, 1], [1, 1, 1, 0xe2], [1, 0, 1, 1], [0xf4, 0x90, 0x80, 0x80]]:
		for i: int in 4:
			text[text.size() - 4 + i] = spelling[i]
		if SessionScript._end_of(text, 0) != -1:
			return "Not text: %s" % [spelling]
	var extra: PackedByteArray = var_to_bytes([1])
	extra.append_array([0, 0, 0, 0])
	return "" if SessionScript._end_of(extra, 0) != extra.size() else "Bytes after the message must not be read"


func test_a_full_farm_refuses() -> String:
	var host: Node = _host()
	for i: int in 3:
		_guest(host)
	var extra: Node = _guest(host)
	if not _got(extra, "refused", SessionScript.REASONS["full"]) or extra.commands.guest or host.players.size() != 4:
		return _finish("Got %s" % [_log])
	return _finish("")


func test_another_version_is_refused() -> String:
	var host: Node = _host()
	host.protocol += 1
	var guest: Node = _guest(host)
	if not _got(guest, "refused", SessionScript.REASONS["version"]) or guest.commands.guest or host.players.size() != 1:
		return _finish("Got %s" % [_log])
	return _finish("")


func test_no_host_is_refused() -> String:
	var guest: Node = _session()
	guest.join_timeout_ms = 50
	guest.join(LOCAL, 1)
	_until(func() -> bool: return _got(guest, "refused"))
	if not _got(guest, "refused", SessionScript.NO_HOST) or guest.commands.guest:
		return _finish("Got %s" % [_log])
	var idle: Node = _session()
	for bad: Array in [["example.com", 5], [LOCAL, 0], [LOCAL, 70000]]:
		if idle.join(bad[0], bad[1]) == "":
			return _finish("%s must not be tried" % [bad])
	SaveGame.farm_open = true
	var problem: String = idle.join(LOCAL, 1)
	SaveGame.farm_open = false
	return _finish("" if problem != "" else "A guest must not have its own farm open")


func test_a_command_runs_as_the_sender() -> String:
	var saved: float = GameClock.elapsed_days
	var host: Node = _host()
	_guest(host)
	var guest: Node = _guest(host)
	var typed: Array[String] = [GameStateScript.HYGROMETER_ID]
	var got: Array = _request(guest, &"calibrate_at_bench", typed)
	_until(func() -> bool: return not got.is_empty())
	GameClock.elapsed_days = saved
	if got.is_empty() or got[0].get("performed_by", "") != "player_3":
		return _finish("Got %s" % [got])
	if host.commands.state.cal_log.size() != 1 or not guest.commands.state.cal_log.is_empty():
		return _finish("Only the host's farm may change")
	if got[0] != host.commands.state.cal_log[0]:
		return _finish("The answer must arrive whole: %s" % [got])
	return _finish("")


func test_cells_and_names_arrive() -> String:
	var host: Node = _host()
	var guest: Node = _guest(host)
	var host_farm: Node = host.commands.state
	var cell := Vector3i(GameStateScript.PLOT.position.x, 0, GameStateScript.PLOT.position.y)
	var tilled: Array = _request(guest, &"till", [cell])
	_until(func() -> bool: return not tilled.is_empty())
	var ore: int = host_farm.crystal_ore
	var mined: Array = _request(guest, &"mine_fissure", [&"FissureA"])
	_until(func() -> bool: return not mined.is_empty())
	if tilled != [true] or not host_farm.tilled_cells.has(cell) or not guest.commands.state.tilled_cells.is_empty():
		return _finish("A cell must reach the host's farm, got %s" % [tilled])
	if mined != [true] or host_farm.crystal_ore <= ore:
		return _finish("A fissure's name must reach the host's farm, got %s" % [mined])
	return _finish("")


func test_strangers_and_forgeries_are_dropped() -> String:
	var bench: Array = [SessionScript.COMMAND, 1, "calibrate_at_bench", [GameStateScript.HYGROMETER_ID]]
	var too_long: String = "x".repeat(SessionScript.MAX_TEXT + 1)
	var typed: Array[String] = [GameStateScript.HYGROMETER_ID]
	var hello: Callable = func(key: String, skills: Dictionary) -> Array: return [SessionScript.HELLO, SessionScript.PROTOCOL, key, skills, ProfileScript.no_record()]
	var with: Callable = func(part: String, value: Variant) -> Array:
		var record: Dictionary = ProfileScript.no_record()
		record[part] = value
		return [SessionScript.HELLO, SessionScript.PROTOCOL, "0".repeat(32), {}, record]
	var bad: Array = [
		# Not let in yet.
		[false, bench], [false, [SessionScript.HELLO, "1"]], [false, [SessionScript.HELLO, SessionScript.PROTOCOL]],
		[false, hello.call("0".repeat(31), {})], [false, hello.call("A".repeat(32), {})], [false, hello.call("0".repeat(32), { 1: 1 })],
		[false, hello.call("0".repeat(32), { "calibration": -1 })], [false, hello.call("0".repeat(32), { "calibration": 1.5 })],
		[false, hello.call("-" + "0".repeat(31), {})], [false, hello.call("0".repeat(32), {}) + [1]],
		 [false, [SessionScript.WELCOME, "player_1", []]],
		# A hello from before the record, and records that are not one.
		[false, [SessionScript.HELLO, SessionScript.PROTOCOL, "0".repeat(32), {}]],
		[false, [SessionScript.HELLO, SessionScript.PROTOCOL, "0".repeat(32), {}, {}]],
		[false, with.call("quest_points", { "q": -1 })], [false, with.call("quest_points", { "q": 1.5 })], [false, with.call("quest_points", { 1: 1 })],
		[false, with.call("quest_points", { too_long: 1 })], [false, with.call("xp_certificates", { "q": 0 })],
		[false, with.call("xp_certificates", { "q": ProfileScript.MOST_XP + 1 })],
		[false, with.call("xp_certificates_spent", ["q", "q"])], [false, with.call("xp_certificates_spent", [1])], [false, with.call("xp_certificates_spent", {})],
		[false, with.call("quests", { "q": {} })], [false, with.call("quests", { "q": { "done": 1, "steps": [], "counts": {} } })],
		[false, with.call("quests", { "q": { "done": true, "steps": [""], "counts": {} } })],
		[false, with.call("quests", { "q": { "done": true, "steps": [], "counts": { "s": -1 } } })],
		[false, with.call("quests", { "q": { "done": true, "steps": [], "counts": {}, "more": 1 } })],
		[false, with.call("more", 1)],
		[false, hello.call("0".repeat(32), {}) + ["x".repeat(SessionScript.MAX_HELLO_BYTES)]],
		# The host's messages, from a guest.
		[true, [SessionScript.WELCOME, "player_1", []]], [true, [SessionScript.STATE, {}]], [true, [SessionScript.ANSWER, 1, ""]],
		[true, [SessionScript.LEFT, "player_1"]], [true, [SessionScript.HELLO, SessionScript.PROTOCOL]],
		# Bad parts, or too much of them.
		[true, []], [true, {}], [true, bench + ["player_1"]], [true, [SessionScript.COMMAND, 1, too_long, []]],
		[true, [SessionScript.COMMAND, 1, "start_lab_grow", [too_long]]], [true, [SessionScript.COMMAND, 1, "mine_fissure", [StringName(too_long)]]],
		[true, [SessionScript.COMMAND, 1, "till", [Vector3.ZERO]]], [true, [SessionScript.COMMAND, 1, "start_lab_grow", [{}]]],
		[true, [SessionScript.COMMAND, 1, "start_lab_grow", range(SessionScript.MAX_ARGUMENTS + 1)]],
		[true, [SessionScript.COMMAND, 1, "x".repeat(SessionScript.MAX_GUEST_BYTES), []]],
		[true, [SessionScript.COMMAND, 1, "calibrate_at_bench", typed]],
		[true, [SessionScript.COMMAND, 1, "start_lab_grow", [RefCounted.new()]]],
	]
	for attempt: Array in bad:
		var host: Node = _host()
		var peer: ENetMultiplayerPeer = _stranger(host, attempt[0])
		if host._links.size() != 1 or (host.players.size() == 2) != attempt[0]:
			return _finish("The stranger never connected")
		peer.put_packet(var_to_bytes(attempt[1]))
		_until(func() -> bool: return host._links.is_empty())
		if not host._links.is_empty() or host.players != ["player_1"] or not host.commands.state.cal_log.is_empty() or host.commands.guest:
			return _finish("Must be dropped and do nothing: %s" % str(attempt).left(200))
		_finish("")
	return ""


func test_naming_another_player_does_nothing() -> String:
	var host: Node = _host()
	var peer: ENetMultiplayerPeer = _stranger(host, true)
	for attempt: Array in [["calibrate_at_bench", [GameStateScript.HYGROMETER_ID, "player_1"]], ["add_credits", [1000]], ["free", []]]:
		peer.put_packet(var_to_bytes([SessionScript.COMMAND, 1, attempt[0], attempt[1]]))
	var credits: int = host.commands.state.credits
	# WELCOME, then three answers.
	if not _until(func() -> bool: return peer.get_available_packet_count() == 4):
		return _finish("Each must be answered, got %d" % peer.get_available_packet_count())
	return _finish("" if host.commands.state.credits == credits and host.commands.state.cal_log.is_empty() else "The farm changed")


func test_a_flood_and_a_silent_connection_are_dropped() -> String:
	var host: Node = _host()
	var peer: ENetMultiplayerPeer = _stranger(host, true)
	for i: int in SessionScript.BURST * 3:
		peer.put_packet(var_to_bytes([SessionScript.COMMAND, i, "add_credits", [1]]))
	if not _until(func() -> bool: return host._links.is_empty()):
		return _finish("A flood must be dropped")
	host.join_timeout_ms = 50
	_stranger(host, false)
	return _finish("" if _until(func() -> bool: return host._links.is_empty()) else "A silent connection must be dropped")


func test_someone_joining_is_only_until_the_handshake_ends() -> String:
	var host: Node = _host()
	if host.someone_joining():
		return _finish("No one is joining a fresh host")
	host.join_timeout_ms = 200
	_stranger(host, false)
	if not _until(func() -> bool: return host.someone_joining()):
		return _finish("A connection that has not joined must count as joining")
	if not _until(func() -> bool: return not host.someone_joining()):
		return _finish("A silent handshake must time out and stop counting")
	var guest: Node = _guest(host)
	return _finish("" if guest.is_guest() and not host.someone_joining() else "A joined guest is not joining")


func test_a_host_that_makes_no_sense_is_left() -> String:
	for bad: Array in [[SessionScript.COMMAND, 1, "start_lab_grow", []], [SessionScript.LEFT, "player_2"],
			[SessionScript.JOINED, ""], [SessionScript.STATE, { "o": RefCounted.new() }]]:
		var host: Node = _host()
		var guest: Node = _guest(host)
		host._tell_guests(bad)
		if not _until(func() -> bool: return _got(guest, "lost")) or not guest.commands.guest:
			return _finish("Must be left: %s" % [bad])
		_finish("")
	return ""


func test_losing_the_host_answers_and_locks() -> String:
	var host: Node = _host()
	var guest: Node = _guest(host)
	var got: Array = _request(guest, &"start_lab_grow")
	host.leave()
	_until(func() -> bool: return not got.is_empty())
	if got != ["The host gave no answer."] or not _got(guest, "lost"):
		return _finish("Got %s, %s" % [got, _log])
	var again: Array = _request(guest, &"start_lab_grow")
	if again != ["Not connected to the host."] or not guest.commands.guest or not guest.commands.state.lab_build.is_empty():
		return _finish("A cut-off guest must stay locked, got %s" % [again])
	if guest.join(LOCAL, 1) == "":
		return _finish("A cut-off guest must leave first")
	guest.leave()
	return _finish("" if not guest.commands.guest else "Leaving must unlock")


func test_leaving_answers_too() -> String:
	var host: Node = _host()
	var guest: Node = _guest(host)
	var got: Array = _request(guest, &"start_lab_grow")
	guest.leave()
	return _finish("" if got == ["The host gave no answer."] else "Got %s" % [got])


func test_a_late_answer_is_dropped() -> String:
	var host: Node = _host()
	var guest: Node = _guest(host)
	guest.answer_timeout_ms = -1
	var late: Array = _request(guest, &"start_lab_grow")
	# The answer is already here when the guest next looks.
	for i: int in 20:
		guest._peer.poll()
		host.poll()
		OS.delay_msec(2)
	if not late.is_empty() or guest._peer.get_available_packet_count() == 0:
		return _finish("The answer must be waiting, unread")
	guest.poll()
	if late != ["The host gave no answer."]:
		return _finish("A late answer must not be waited for, got %s" % [late])
	guest.answer_timeout_ms = 3000
	# The first answer is on its way, and is not this one's.
	var next: Array = _request(guest, &"set_interlock_override", ["no_robot", true])
	_until(func() -> bool: return not next.is_empty())
	var expected: Variant = host.commands.state.set_interlock_override("no_robot", true)
	return _finish("" if next == [expected] and late.size() == 1 and guest.commands.guest else "Got %s, %s" % [late, next])


func test_state_reaches_guests_only() -> String:
	var host: Node = _host()
	var guest: Node = _guest(host)
	var data: Dictionary = { "big": "x".repeat(1024 * 1024), "where": Vector3i(1, 2, 3), "list": [1, 2.5, true] }
	if not host.send_state(data, "player_2") or not _until(func() -> bool: return _got(guest, "state_received")):
		return _finish("A state must arrive")
	if not _got(guest, "state_received", data):
		return _finish("The state must arrive whole")
	if guest.send_state({}) or host.send_state({}, "player_9") or host.send_state({ "node": guest }):
		return _finish("Only the host sends, only plain data, only to guests")
	var deep: Dictionary = {}
	for i: int in SessionScript.MAX_DEPTH - 1:
		deep = { "in": deep }
	if host.send_state(deep) or not host.send_state(deep["in"]):
		return _finish("What is sent must be what can be read")
	var vectors: Array[Vector3] = []
	var by_vector: Dictionary[Vector3, int] = {}
	var ints: Array[int] = []
	for odd: Variant in [vectors, by_vector, String.chr(0xFEFF) + "mark", StringName(String.chr(0xFEFF) + "mark")]:
		if host.send_state({ "odd": odd }) or SessionScript._end_of(var_to_bytes(odd), 0) >= 0:
			return _finish("%s must not be sent" % [odd])
	if not host.send_state({ "ints": ints }):
		return _finish("An empty typed list is plain")
	if host.send_state({ "huge": "x".repeat(SessionScript.MAX_HOST_BYTES) }):
		return _finish("A state has a size limit")
	return _finish("")


func test_the_game_has_no_rpcs() -> String:
	var pending: Array[String] = ["res://scripts"]
	while not pending.is_empty():
		var dir: String = pending.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			pending.append(dir + "/" + sub)
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd") and "@rpc" in FileAccess.get_file_as_string(dir + "/" + file):
				return "%s has an RPC: co-op goes through CoopSession and FarmCommands" % file
	return ""


## An exported game reads its scripts without the invisible byte order mark,
## so one written into a script's text is gone there. CoopSession's was, and every
## string, so every hello, failed is_plain() in the exported game only.
func test_no_script_hides_a_byte_order_mark() -> String:
	var mark: String = String.chr(0xFEFF)
	if SessionScript.is_plain([mark + "text"]) or not SessionScript.is_plain(["text", ""]):
		return "is_plain() must refuse only text that starts with a byte order mark"
	# The reader keeps a mark inside text (not at its start), or the scan below would pass on anything.
	if mark not in ("x" + mark).to_utf8_buffer().get_string_from_utf8():
		return "a byte order mark does not survive being read back"
	var pending: Array[String] = ["res://scripts", "res://tests"]
	while not pending.is_empty():
		var dir: String = pending.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			pending.append(dir + "/" + sub)
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd") and mark in FileAccess.get_file_as_string(dir + "/" + file):
				return "%s has a byte order mark in its text: write String.chr(0xFEFF)" % file
	return ""
