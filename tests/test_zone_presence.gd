extends RefCounted
## Where things are, by zone: the rover's zone id (saved, with old saves still
## loading) and each player's place (host-checked, never saved, shown on the
## co-op page). docs/design/zones.md section 12 and build step 4.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const ScenesScript: GDScript = preload("res://scripts/autoload/CoopScenes.gd")


class _Session:
	extends Node
	signal player_left(player_id: String)


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
	data["rover_zone"] = "flooded_aquifer"
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
