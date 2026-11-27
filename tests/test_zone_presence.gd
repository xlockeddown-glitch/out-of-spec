extends RefCounted
## Where things are, by zone: the rover's zone id (saved, with old saves still
## loading) and each player's place (host-checked, never saved, shown on the
## co-op page). docs/design/zones.md section 12 and build step 4.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const ScenesScript: GDScript = preload("res://scripts/autoload/CoopScenes.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")

signal _answered(answer: Variant)


class _Session:
	extends Node
	signal player_left(player_id: String)
	signal recalled(step: String)


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(424242)
	return gs


func _load(data: Dictionary) -> String:
	var gs: GameStateScript = _state()
	var problem: String = gs.farm_from_dict(data)
	var zone: String = gs.rover_zone
	gs.free()
	return problem if problem != "" else zone


# --- The rover's zone ----------------------------------------------------------

func test_rover_zone_survives_a_save() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = "lava_tubes"
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	gs.free()
	if data.get("rover_zone") != "lava_tubes" or data.has("rover_in_tunnels"):
		return "The save must say rover_zone and no longer the bool: %s" % [data.get("rover_zone")]
	var got: String = _load(data)
	return "" if got == "lava_tubes" else "Loaded '%s'" % got


func test_an_old_save_with_only_the_bool_still_loads() -> String:
	var gs: GameStateScript = _state()
	var data: Dictionary = gs.farm_to_dict()
	gs.free()
	data.erase("rover_zone")
	data["rover_in_tunnels"] = true
	var inside: String = _load(data)
	data["rover_in_tunnels"] = false
	var home: String = _load(data)
	data.erase("rover_in_tunnels")
	var none: String = _load(data)
	if inside != "lava_tubes" or home != "" or none != "":
		return "Old true gave '%s', old false '%s', neither '%s'" % [inside, home, none]
	return ""


func test_the_bool_is_the_zone_seen_as_yes_or_no() -> String:
	var gs: GameStateScript = _state()
	gs.rover_in_tunnels = true
	var inside: String = gs.rover_zone
	gs.rover_in_tunnels = false
	var out: bool = gs.rover_in_tunnels or gs.rover_zone != ""
	gs.rover_zone = "lava_tubes"
	var yes: bool = gs.rover_in_tunnels
	gs.free()
	return "" if inside == "lava_tubes" and not out and yes else "The bool and the zone disagree."


func test_an_unknown_zone_is_refused() -> String:
	var gs: GameStateScript = _state()
	var data: Dictionary = gs.farm_to_dict()
	var problems: Array[String] = []
	data["rover_zone"] = "atlantis"
	problems.append(gs.farm_dict_problem(data))
	data["rover_zone"] = 3
	problems.append(gs.farm_dict_problem(data))
	# A zone with no scene yet is not somewhere the rover can be.
	data["rover_zone"] = "flooded_aquifer"
	problems.append(gs.farm_dict_problem(data))
	data["rover_zone"] = "lava_tubes"
	var known: String = gs.farm_dict_problem(data)
	data["rover_zone"] = ""
	data["rover_in_tunnels"] = "yes"
	problems.append(gs.farm_dict_problem(data))
	gs.free()
	if "" in problems:
		return "A bad rover zone was accepted: %s" % [problems]
	return "" if known == "" else "A known zone was refused: %s" % known


# --- Places --------------------------------------------------------------------

func test_the_validator_judges_a_report() -> String:
	var here: Array[String] = ["player_1", "player_2"]
	var cases: Array = [
		["farm", 0, "player_2", "player_2", true],
		["dome", 0, "player_2", "player_2", true],
		["lava_tubes", 0, "player_2", "player_2", true],
		["lava_tubes", ZonePresence.MAX_DEPTH, "player_2", "player_2", true],
		["atlantis", 0, "player_2", "player_2", false],
		["", 0, "player_2", "player_2", false],
		["lava_tubes", -1, "player_2", "player_2", false],
		["lava_tubes", ZonePresence.MAX_DEPTH + 1, "player_2", "player_2", false],
		["farm", 1, "player_2", "player_2", false],
		["lava_tubes", 4, "player_2", "player_2", false],
		["flooded_aquifer", 0, "player_2", "player_2", false],
		["flooded_aquifer", 1, "player_2", "player_2", false],
		["farm", 0, "player_1", "player_2", false],
		["farm", 0, "player_9", "player_9", false],
		["farm", 0, "", "", false],
	]
	for row: Array in cases:
		var problem: String = ZonePresence.problem(row[0], row[1], row[2], row[3], here)
		if (problem == "") != row[4]:
			return "%s gave '%s'" % [row, problem]
	return ""


func test_the_host_keeps_the_place_it_was_told() -> String:
	var gs: GameStateScript = _state()
	var me: String = gs.local_player_id
	var out: Array[String] = [gs.report_place("lava_tubes", 0, me), gs.report_place("atlantis", 0, me), gs.report_place("farm", 0, "")]
	var where: String = gs.place_of(me)
	var others: String = gs.place_of("player_7")
	var here: Array[String] = [me, "player_7"]
	var in_tubes: Array[String] = gs.players_in("lava_tubes", here)
	var on_farm: Array[String] = gs.players_in("farm", here)
	gs.free()
	if out[0] != "" or out[1] == "" or out[2] == "":
		return "Reports answered %s" % [out]
	if where != "lava_tubes" or others != "farm":
		return "Places were '%s' and '%s'" % [where, others]
	return "" if in_tubes == [me] and on_farm == ["player_7"] else "Lists were %s and %s" % [in_tubes, on_farm]


func test_a_player_who_leaves_is_forgotten() -> String:
	var gs: GameStateScript = _state()
	gs.player_places["player_2"] = ["lava_tubes", 0]
	gs.player_places["player_3"] = ["dome", 0]
	var session := _Session.new()
	var scenes: Node = ScenesScript.new()
	scenes.start(session, gs)
	session.player_left.emit("player_2")
	var gone: bool = gs.place_of("player_2") == "farm" and not gs.player_places.has("player_2")
	var kept: bool = gs.place_of("player_3") == "dome"
	# A loaded farm has everyone on the farm.
	var data: Dictionary = gs.farm_to_dict()
	gs.farm_from_dict(data)
	var cleared: bool = gs.player_places.is_empty()
	scenes.free()
	session.free()
	gs.free()
	return "" if gone and kept and cleared else "gone %s, kept %s, cleared %s" % [gone, kept, cleared]


func test_scenes_are_places() -> String:
	var got: Array = [ZonePresence.for_scene(SceneSwitcher.FARM_SCENE), ZonePresence.for_scene(SceneSwitcher.DOME_SCENE),
		ZonePresence.for_scene(SceneSwitcher.TUNNELS_SCENE), ZonePresence.for_scene(SceneSwitcher.TITLE_SCENE), ZonePresence.for_scene("")]
	return "" if got == [["farm", 0], ["dome", 0], ["lava_tubes", 0], [], []] else "Got %s" % [got]


func test_a_guest_can_report_and_the_report_does_not_wake_it() -> String:
	if not &"report_place" in FarmCommands.ACTIONS or not &"report_place" in FarmCommands.NO_WAKE \
			or not &"report_place" in CoopWalkers.ON_FOOT:
		return "report_place must be a command a sleeper or a walker may send"
	return FarmCommands.problem(&"report_place", ["lava_tubes", 0])


func test_the_host_clock_carries_places_to_a_guest() -> String:
	var elapsed: float = GameClock.elapsed_days
	var speed: float = GameClock.seconds_per_day
	var paused: bool = GameClock.paused
	var host: GameStateScript = _state()
	var guest: GameStateScript = _state()
	host.player_places["player_2"] = ["lava_tubes", 0]
	FarmCommands.guest = true
	var first: String = FarmSync.follow_clock(FarmSync.clock(host), guest)
	var copy: Dictionary = guest.player_places.duplicate(true)
	var bad: Dictionary = FarmSync.clock(host)
	bad["places"] = { "player_2": ["atlantis", 0] }
	var refused: String = FarmSync.follow_clock(bad, guest)
	var kept: bool = guest.player_places == copy
	# The same rule as the host's command: no depth on the farm, no scene-less zone.
	var also_bad: Array[String] = []
	for entry: Array in [["farm", 1], ["dome", 1], ["flooded_aquifer", 0], ["lava_tubes", 4]]:
		bad["places"] = { "player_2": entry }
		also_bad.append(FarmSync.follow_clock(bad, guest))
	if "" in also_bad:
		kept = false
	FarmCommands.guest = false
	GameClock.elapsed_days = elapsed
	GameClock.seconds_per_day = speed
	GameClock.paused = paused
	host.free()
	guest.free()
	if first != "" or copy != { "player_2": ["lava_tubes", 0] }:
		return "The guest got %s from '%s'" % [copy, first]
	return "" if refused != "" and kept else "A bad table was taken: '%s'" % refused


func test_the_protocol_moved_with_the_wire_format() -> String:
	return "" if CoopSession.PROTOCOL >= 17 else "The farm dict and clock changed; PROTOCOL must be 17 or more."


# --- The co-op page ------------------------------------------------------------

func test_the_page_says_where_each_player_is() -> String:
	var both: Array[String] = ["player_1", "player_2"]
	var places: Dictionary = { "player_2": ["lava_tubes", 0] }
	var who: String = CoopUI.players_text(both, "player_1", places, true)
	if who != "PLAYER 1  HOST  YOU  FARM\nPLAYER 2  LAVA TUBES":
		return "Got %s" % who.replace("\n", " | ")
	if ZonePresence.label("lava_tubes", 2) != "Lava Tubes, depth 2" or ZonePresence.label("dome") != "Dome":
		return "Labels were '%s' and '%s'" % [ZonePresence.label("lava_tubes", 2), ZonePresence.label("dome")]
	return ""


# --- Review fixes --------------------------------------------------------------

func test_the_clock_and_the_command_share_one_rule() -> String:
	for entry: Array in [["farm", 1], ["dome", 1], ["flooded_aquifer", 0], ["flooded_aquifer", 1], ["lava_tubes", 4], ["lava_tubes", -1], ["nowhere", 0]]:
		if ZonePresence.place_problem(entry[0], entry[1]) == "" or ZonePresence.table_problem({ "player_2": entry }) == "":
			return "%s was accepted" % [entry]
	for entry: Array in [["farm", 0], ["dome", 0], ["lava_tubes", 0], ["lava_tubes", 1]]:
		if ZonePresence.place_problem(entry[0], entry[1]) != "" or ZonePresence.table_problem({ "player_2": entry }) != "":
			return "%s was refused" % [entry]
	return "" if ZoneData.is_playable(&"lava_tubes") and not ZoneData.is_playable(&"flooded_aquifer") else "Playable zones are wrong."


func test_only_the_newest_place_is_sent() -> String:
	var farm: Array = ["farm", 0]
	var dome: Array = ["dome", 0]
	# Farm told, then a quick trip to the dome and back: nothing is left to send.
	if not ZonePresence.next_to_send(farm, farm).is_empty():
		return "Sent what the host already has"
	# Told the farm, the player is now in the dome: the dome, never an older place.
	if ZonePresence.next_to_send(farm, dome) != dome:
		return "Did not send the newest place"
	# Nothing told yet, the newest is the farm after dome and back.
	var latest: Array = dome
	latest = farm
	return "" if ZonePresence.next_to_send([], latest) == farm else "An older place would be sent"


func test_a_quick_trip_ends_with_the_last_place_told() -> String:
	ZonePresence.reset_reports()
	var me: String = GameState.local_player_id
	var before: Variant = GameState.player_places.get(me)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	# Alone, each report is answered at once; the last scene must be the last said.
	ZonePresence.report_scene(SceneSwitcher.FARM_SCENE, tree, 1, 0.0)
	ZonePresence.report_scene(SceneSwitcher.DOME_SCENE, tree, 1, 0.0)
	ZonePresence.report_scene(SceneSwitcher.FARM_SCENE, tree, 1, 0.0)
	var told: String = GameState.place_of(me)
	ZonePresence.reset_reports()
	if before == null:
		GameState.player_places.erase(me)
	else:
		GameState.player_places[me] = before
	return "" if told == "farm" else "The last place told was %s" % told


func test_a_place_report_does_not_use_the_command_slot() -> String:
	var commands: Node = CommandsScript.new()
	commands.state = _state()
	commands.guest = true
	var got: Array = []
	var ask: Callable = func(action: StringName, _arguments: Array) -> Variant:
		return await _answered
	commands.remote = ask
	var place: Callable = func() -> void: got.append(await commands.request(&"report_place", ["farm", 0]))
	var bed: Callable = func() -> void: got.append(await commands.request(&"go_to_bed"))
	place.call()
	# The report is out and unanswered: a real command must not be refused for it.
	bed.call()
	var bed_refused: bool = not got.is_empty()
	place.call()
	var twice_refused: bool = got.size() == 1 and str(got[0]) == "Still waiting for the host."
	_answered.emit("")
	_answered.emit(false)
	commands.state.free()
	commands.free()
	return "" if not bed_refused and twice_refused else "bed_refused %s, second report refused %s, got %s" % [bed_refused, twice_refused, got]


func test_a_session_ending_forgets_other_places() -> String:
	var gs: GameStateScript = _state()
	var me: String = gs.local_player_id
	gs.player_places[me] = ["dome", 0]
	gs.player_places["player_2"] = ["lava_tubes", 0]
	gs.clear_other_places()
	var kept: bool = gs.player_places == { me: ["dome", 0] }
	# The real session close does it through the commands' farm.
	gs.player_places["player_2"] = ["lava_tubes", 0]
	var old: Node = FarmCommands.state
	FarmCommands.state = gs
	CoopSession.leave()
	FarmCommands.state = old
	var closed: bool = gs.player_places == { me: ["dome", 0] }
	gs.free()
	return "" if kept and closed else "kept %s, closed %s" % [kept, closed]


func test_the_host_runs_a_place_report_without_the_quest_look() -> String:
	var gs: GameStateScript = _state()
	var commands: Node = CommandsScript.new()
	commands.state = gs
	var answer: Variant = commands.execute(gs.local_player_id, &"report_place", ["lava_tubes", 0])
	var where: String = gs.place_of(gs.local_player_id)
	commands.free()
	gs.free()
	return "" if answer == "" and where == "lava_tubes" else "Answer '%s', place %s" % [answer, where]


func test_a_lost_answer_leaves_the_host_unknown() -> String:
	var dome: Array = [ZonePresence.DOME, 0]
	var farm: Array = [ZonePresence.FARM, 0]
	# No answer: the host may or may not hold the dome, so the farm must still go.
	var known: Array = ZonePresence.acknowledged_after(dome, ZonePresence.NO_ANSWER)
	if not known.is_empty():
		return "A lost answer counted as taken"
	if ZonePresence.next_to_send(known, farm) != farm:
		return "The place after a lost answer was not sent"
	# Answered, taken or refused: the host has had its word on it.
	if ZonePresence.acknowledged_after(dome, "") != dome:
		return "A taken place was not counted"
	return "" if ZonePresence.acknowledged_after(dome, "That player is not on this farm.") == dome \
			else "A refused place would be sent again and again"


func test_a_session_change_stops_the_old_sender() -> String:
	ZonePresence.reset_reports()
	ZonePresence.forget_acknowledged()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	# After the reset a new report must still go out (the flag is not left stuck).
	var me: String = GameState.local_player_id
	var before: Variant = GameState.player_places.get(me)
	ZonePresence.report_scene(SceneSwitcher.DOME_SCENE, tree, 1, 0.0)
	var told: String = GameState.place_of(me)
	ZonePresence.reset_reports()
	if before == null:
		GameState.player_places.erase(me)
	else:
		GameState.player_places[me] = before
	return "" if told == ZonePresence.DOME else "A report after a session change was not sent"
