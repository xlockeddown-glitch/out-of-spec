extends RefCounted
## The hazard system (docs/design/zones.md sections 5 and 13, build step 8): the vents'
## places from the integer hash, the cycle as a pure function of the clock, the host's
## heat command, and the trip multiplier that ends with every trip.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST := "player_1"
const GUEST := "player_2"
const SEED := 424242
const ZONE: String = "lava_tubes"
const DAY := 4  # the day index the tests' clock stands in


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	gs.zones_unlocked.append(ZONE)
	return gs


func _vents(day: int, seed_value: int = SEED) -> Array:
	return ZoneHazards.vents_for(seed_value, ZONE, 1, day)


## The clock (days) on DAY at which `vent` is `cycle_minute` minutes into its cycle.
func _clock_at(vent: Dictionary, cycle_minute: int) -> float:
	var start: int = (DAY - 1) * 1440
	var k: int = posmod(cycle_minute - int(vent["phase"]) - start, ZoneHazards.PERIOD) + 200
	return float(DAY - 1) + float(k) / 1440.0


## Runs `body` with the global clock at `elapsed` days and restores it.
func _at(elapsed: float, body: Callable) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = elapsed
	var out: Variant = body.call()
	GameClock.elapsed_days = held
	return out if out is String else ""


func _cell_at(cell: Vector2i) -> Vector3:
	return TunnelRock.at_in(ZoneDepth.layout(SEED, ZONE, 1, DAY)["grid"], cell)


## HOST below with the tunnel rover at `vent`'s cell.
func _below(gs: GameStateScript, vent: Dictionary) -> void:
	gs.player_places[HOST] = [ZONE, ZoneDepth.DEPTH]
	gs.rover_zone = ZONE
	gs.rover_depth = ZoneDepth.DEPTH
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, _cell_at(vent["cell"]))


func _commander(gs: GameStateScript) -> Node:
	var commands: Node = CommandsScript.new()
	commands.state = gs
	return commands


# --- Where the vents are ----------------------------------------------------------

func test_the_same_day_gives_the_same_vents_and_another_farm_or_day_differs() -> String:
	for day: int in [0, 1, 4, 365]:
		if _vents(day) != _vents(day):
			return "Day %d changed between two calls." % day
	var seen: Dictionary = {}
	for day: int in range(0, 30):
		seen[str(_vents(day))] = true
	if seen.size() < 12:
		return "Thirty days gave only %d different vent sets." % seen.size()
	var differs: bool = false
	for day: int in range(0, 30):
		if _vents(day) != _vents(day, SEED + 1):
			differs = true
	return "" if differs else "Another farm drew the same vents for thirty days."


func test_one_or_two_vents_only_at_depth_one_of_the_lava_tubes() -> String:
	var counts: Dictionary = {}
	for day: int in range(0, 60):
		counts[_vents(day).size()] = true
	if counts.keys().any(func(n: int) -> bool: return n < 1 or n > 2):
		return "A day had %s vents." % [counts.keys()]
	if counts.size() < 2:
		return "Sixty days never changed the number of vents."
	if not ZoneHazards.vents_for(SEED, "flooded_aquifer", 1, 4).is_empty() \
			or not ZoneHazards.vents_for(SEED, ZONE, 0, 4).is_empty() \
			or not ZoneHazards.vents_for(SEED, ZONE, 2, 4).is_empty():
		return "Vents were drawn where there is no depth one."
	return ""


func test_vents_are_on_trunk_floor_never_on_the_start_the_way_up_or_a_find() -> String:
	var problems: Array[String] = []
	for seed_value: int in [SEED, 7, 99991]:
		for day: int in range(0, 80):
			var layout: Dictionary = ZoneDepth.layout(seed_value, ZONE, 1, day)
			var finds: Array[Vector2i] = []
			for find: Dictionary in layout["finds"]:
				finds.append(find["cell"])
			var used: Array[Vector2i] = []
			for vent: Dictionary in _vents(day, seed_value):
				var cell: Vector2i = vent["cell"]
				if layout["grid"][cell.y][cell.x] != ".":
					problems.append("Seed %d day %d: a vent in rock at %s" % [seed_value, day, cell])
				if not ZoneHazards.TRUNK.has_point(cell):
					problems.append("Seed %d day %d: a vent off the trunk at %s" % [seed_value, day, cell])
				if cell == ZoneDepth.START_CELL or cell == ZoneDepth.UP_CELL or cell in finds:
					problems.append("Seed %d day %d: a vent on the start, the way up or a find at %s" % [seed_value, day, cell])
				if cell in used:
					problems.append("Seed %d day %d: two vents in %s" % [seed_value, day, cell])
				used.append(cell)
	return "\n".join(problems.slice(0, 5))


func test_there_is_always_a_way_out_round_the_vents() -> String:
	var problems: Array[String] = []
	for seed_value: int in [SEED, 7, 99991, 12345]:
		for day: int in range(0, 80):
			var layout: Dictionary = ZoneDepth.layout(seed_value, ZONE, 1, day)
			var cells: Array = []
			for vent: Dictionary in _vents(day, seed_value):
				cells.append(vent["cell"])
			if not ZoneHazards.leaves_a_way(layout["grid"], cells):
				problems.append("Seed %d day %d: the vents %s leave no way round" % [seed_value, day, cells])
			# Blocked, the way up and every find are still reachable from the start.
			var open: PackedStringArray = PackedStringArray()
			for y: int in (layout["grid"] as PackedStringArray).size():
				var line: String = layout["grid"][y]
				for cell: Vector2i in cells:
					if cell.y == y:
						line = line.substr(0, cell.x) + "#" + line.substr(cell.x + 1)
				open.append(line)
			var reach: Array = ZoneDepth.reachable(open, ZoneDepth.START_CELL)
			if not ZoneDepth.UP_CELL in reach:
				problems.append("Seed %d day %d: the way up is cut off" % [seed_value, day])
			for find: Dictionary in layout["finds"]:
				if not find["cell"] in reach:
					problems.append("Seed %d day %d: find %s is cut off" % [seed_value, day, find["id"]])
	return "\n".join(problems.slice(0, 5))


func test_two_vents_leave_a_clear_row_between_them() -> String:
	for day: int in range(0, 200):
		var vents: Array = _vents(day)
		if vents.size() == 2 and absi((vents[0]["cell"] as Vector2i).y - (vents[1]["cell"] as Vector2i).y) < ZoneHazards.MIN_ROW_GAP:
			return "Day %d: two vents in neighbouring rows." % day
	return ""


# --- The cycle ----------------------------------------------------------------------

func test_the_cycle_is_hot_then_cool_and_repeats() -> String:
	var vent: Dictionary = { "id": "v0", "cell": Vector2i(11, 8), "phase": 0 }
	var hot: int = 0
	var flips: int = 0
	var last: bool = ZoneHazards.is_hot(vent, 0.0)
	for minute: int in range(0, ZoneHazards.PERIOD * 3):
		var clock: float = float(minute) / 1440.0
		if ZoneHazards.is_hot(vent, clock):
			hot += 1
		if ZoneHazards.is_hot(vent, clock) != ZoneHazards.is_hot(vent, clock + float(ZoneHazards.PERIOD) / 1440.0):
			return "Minute %d: the cycle did not repeat after one period." % minute
		if ZoneHazards.is_hot(vent, clock) != last:
			flips += 1
			last = not last
	if hot != ZoneHazards.HOT_MINUTES * 3:
		return "Hot for %d of %d minutes." % [hot, ZoneHazards.PERIOD * 3]
	return "" if flips == 5 else "Expected 5 flips in three periods, saw %d." % flips


func test_the_phase_moves_the_cycle_and_minutes_left_counts_to_the_flip() -> String:
	var vent: Dictionary = { "id": "v0", "cell": Vector2i(11, 8), "phase": 30 }
	# Phase 30 at minute 0: 30 minutes in, 10 minutes of heat left.
	if not ZoneHazards.is_hot(vent, 0.0) or ZoneHazards.minutes_left(vent, 0.0) != ZoneHazards.HOT_MINUTES - 30:
		return "Phase 30 should be hot with %d min left." % (ZoneHazards.HOT_MINUTES - 30)
	var after: float = float(ZoneHazards.minutes_left(vent, 0.0)) / 1440.0
	if ZoneHazards.is_hot(vent, after) or ZoneHazards.minutes_left(vent, after) != ZoneHazards.COOL_MINUTES:
		return "It should turn cool at exactly the minute it said."
	var late: float = float(ZoneHazards.minutes_left(vent, 0.0) + ZoneHazards.COOL_MINUTES) / 1440.0
	if not ZoneHazards.is_hot(vent, late):
		return "It should turn hot again after the cool half."
	return ""


func test_the_glow_warns_before_the_heat() -> String:
	var vent: Dictionary = { "id": "v0", "cell": Vector2i(11, 8), "phase": 0 }
	var hot: float = ZoneHazards.glow(vent, 5.0 / 1440.0)
	var warn: float = ZoneHazards.glow(vent, float(ZoneHazards.PERIOD - 3) / 1440.0)
	var cool: float = ZoneHazards.glow(vent, float(ZoneHazards.HOT_MINUTES + 20) / 1440.0)
	if not (hot > warn and warn > cool and cool > 0.0):
		return "Glow should fall hot %f, warn %f, cool %f." % [hot, warn, cool]
	if ZoneHazards.hint(vent, 5.0 / 1440.0) == ZoneHazards.hint(vent, float(ZoneHazards.HOT_MINUTES + 20) / 1440.0):
		return "A hot and a cool vent should not say the same."
	return ""


func test_the_cycle_reads_only_the_clock() -> String:
	var vents: Array = _vents(DAY)
	var again: Array = _vents(DAY)
	for index: int in vents.size():
		for minute: int in range(0, 400, 7):
			var clock: float = float(DAY - 1) + float(minute) / 1440.0
			if ZoneHazards.is_hot(vents[index], clock) != ZoneHazards.is_hot(again[index], clock):
				return "Two copies of a vent disagreed at minute %d." % minute
	return ""


func test_a_position_maps_to_its_cell() -> String:
	var grid: PackedStringArray = ZoneDepth.layout(SEED, ZONE, 1, DAY)["grid"]
	for cell: Vector2i in [Vector2i(11, 8), Vector2i(12, 10), Vector2i(0, 0), Vector2i(23, 21)]:
		if ZoneHazards.cell_of(TunnelRock.at_in(grid, cell)) != cell:
			return "Cell %s did not come back from its middle." % [cell]
	return ""


# --- The host's command ---------------------------------------------------------------

func test_the_host_takes_a_hot_vent_and_sets_the_trip() -> String:
	var gs: GameStateScript = _state()
	var vent: Dictionary = _vents(DAY)[0]
	_below(gs, vent)
	var told: Array[String] = []
	gs.phone_message.connect(func(text: String) -> void: told.append(text))
	var out: Array[String] = []
	_at(_clock_at(vent, 5), func() -> String:
		out.append(gs.enter_vent(vent["id"], DAY, HOST))
		out.append(gs.enter_vent(vent["id"], DAY, HOST))
		return "")
	var tripped: bool = gs.zone_heat_trip
	gs.free()
	if out != ["", ""]:
		return "A hot vent in reach was refused: %s" % [out]
	if not tripped:
		return "The trip was not marked hot."
	return "" if told.size() == 1 else "The phone should say it once, said %d times." % told.size()


func test_the_host_refuses_a_cool_vent() -> String:
	var gs: GameStateScript = _state()
	var vent: Dictionary = _vents(DAY)[0]
	_below(gs, vent)
	var reason: Array[String] = []
	_at(_clock_at(vent, ZoneHazards.HOT_MINUTES + 20), func() -> String:
		reason.append(gs.enter_vent(vent["id"], DAY, HOST))
		return "")
	var tripped: bool = gs.zone_heat_trip
	gs.free()
	if reason[0] == "":
		return "A cool vent was accepted."
	return "A refused entry still set the trip." if tripped else ""


func test_the_host_refuses_a_player_who_is_elsewhere() -> String:
	var gs: GameStateScript = _state()
	var vent: Dictionary = _vents(DAY)[0]
	_below(gs, vent)
	var refusals: Array[String] = []
	_at(_clock_at(vent, 5), func() -> String:
		refusals.append(gs.enter_vent(vent["id"], DAY, GUEST))  # the guest is on the farm
		gs.player_places[GUEST] = [ZONE, 0]  # in the hub
		refusals.append(gs.enter_vent(vent["id"], DAY, GUEST))
		gs.player_places[GUEST] = [ZonePresence.DOME, 0]
		refusals.append(gs.enter_vent(vent["id"], DAY, GUEST))
		gs.player_places[GUEST] = [ZONE, ZoneDepth.DEPTH]
		refusals.append(gs.enter_vent(vent["id"], DAY - 1, GUEST))  # yesterday's floor
		refusals.append(gs.enter_vent("v9", DAY, GUEST))  # no such vent
		refusals.append(gs.enter_vent("", DAY, GUEST))
		gs.rover_depth = 0  # the rover is not down there
		refusals.append(gs.enter_vent(vent["id"], DAY, GUEST))
		return "")
	var tripped: bool = gs.zone_heat_trip
	gs.free()
	for index: int in refusals.size():
		if refusals[index] == "":
			return "Refusal %d was missing." % index
	return "A refused entry still set the trip." if tripped else ""


func test_the_host_refuses_a_rover_that_is_not_at_the_vent() -> String:
	var gs: GameStateScript = _state()
	var vent: Dictionary = _vents(DAY)[0]
	_below(gs, vent)
	var spot: Vector3 = _cell_at(vent["cell"])
	var results: Array[String] = []
	_at(_clock_at(vent, 5), func() -> String:
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, spot + Vector3(ZoneHazards.ENTRY_M + ZoneDepth.HOST_REACH_SLACK_M + 0.1, 0.0, 0.0))
		results.append(gs.enter_vent(vent["id"], DAY, HOST))
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, spot + Vector3(ZoneHazards.ENTRY_M + ZoneDepth.HOST_REACH_SLACK_M - 0.1, 0.0, 0.0))
		results.append(gs.enter_vent(vent["id"], DAY, HOST))
		return "")
	gs.free()
	if results[0] == "":
		return "A rover just past the slack was struck."
	return results[1]


func test_the_command_is_on_the_list_and_runs_through_the_commander() -> String:
	if not &"enter_vent" in CommandsScript.ACTIONS:
		return "enter_vent is not a command."
	var gs: GameStateScript = _state()
	var commands: Node = _commander(gs)
	var vent: Dictionary = _vents(DAY)[0]
	var home: Array = []
	var struck: Array = []
	_at(_clock_at(vent, 5), func() -> String:
		home.append(commands.execute(HOST, &"enter_vent", [vent["id"], DAY]))
		_below(gs, vent)
		struck.append(commands.execute(HOST, &"enter_vent", [vent["id"], DAY]))
		return "")
	var wrong_type: Variant = commands.execute(HOST, &"enter_vent", [3, DAY])
	commands.free()
	var tripped: bool = gs.zone_heat_trip
	gs.free()
	if home[0] == "":
		return "A player not below was struck."
	if struck[0] != "" or not tripped:
		return "The commander refused a hot vent in reach: %s" % [struck]
	return "" if wrong_type != "" else "A number for a vent id was accepted."


func test_the_rules_alone_judge_an_entry() -> String:
	var vents: Array = _vents(DAY)
	var vent: Dictionary = vents[0]
	var hot: float = _clock_at(vent, 5)
	var cool: float = _clock_at(vent, ZoneHazards.HOT_MINUTES + 20)
	var id: String = vent["id"]
	if ZoneHazards.entry_problem(id, vents, hot, ZONE, 1, 1) != "":
		return "A hot vent for a player below was refused."
	if ZoneHazards.entry_problem(id, vents, cool, ZONE, 1, 1) == "":
		return "A cool vent was taken."
	if ZoneHazards.entry_problem(id, vents, hot, ZONE, 0, 1) == "" or ZoneHazards.entry_problem(id, vents, hot, "", 0, 0) == "" \
			or ZoneHazards.entry_problem(id, vents, hot, ZONE, 1, 0) == "":
		return "A player or rover not below was struck."
	return ""


# --- The multiplier ---------------------------------------------------------------------

func _wear(heat: bool) -> Array[float]:
	var gs: GameStateScript = _state()
	gs.zone_heat_trip = heat
	var before_steer: float = gs.steering.error
	var tire: DriftingSensor = gs.get_sensor(gs.TIRE_ID)
	var before_tire: float = tire.error
	var wheels: float = gs.wheel_meters
	gs.add_rover_usage(100.0, HOST, gs.TUNNEL_ROVER)
	var out: Array[float] = [absf(gs.steering.error - before_steer), absf(tire.error - before_tire) if gs.is_in_service(gs.TIRE_ID) else 0.0, gs.wheel_meters - wheels]
	gs.free()
	return out


func test_a_heat_trip_doubles_the_wear_that_is_already_there() -> String:
	var plain: Array[float] = _wear(false)
	var hot: Array[float] = _wear(true)
	if plain[0] <= 0.0:
		return "Plain driving should wear the steering encoder."
	if not is_equal_approx(hot[0], plain[0] * ZoneHazards.DRIFT_MULTIPLIER):
		return "Steering wear %f was not %f times %f." % [hot[0], ZoneHazards.DRIFT_MULTIPLIER, plain[0]]
	if not is_equal_approx(hot[1], plain[1] * ZoneHazards.DRIFT_MULTIPLIER):
		return "Tire wear %f was not %f times %f." % [hot[1], ZoneHazards.DRIFT_MULTIPLIER, plain[1]]
	return "" if is_equal_approx(hot[2], plain[2]) else "Heat changed the wheel nuts' metres."


func test_heat_changes_no_reading_by_itself() -> String:
	var gs: GameStateScript = _state()
	var before: float = gs.steering.error
	gs.zone_heat_trip = true
	var same: bool = is_equal_approx(gs.steering.error, before)
	gs.free()
	return "" if same else "Setting the trip changed a reading."


# --- Trip ends and saves -------------------------------------------------------------------

func _hot_trip(gs: GameStateScript) -> void:
	gs.zone_heat_trip = true


func test_a_released_field_rover_ends_the_trip() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZONE
	_hot_trip(gs)
	gs._release_field_rover()
	var cleared: bool = not gs.zone_heat_trip
	gs.free()
	return "" if cleared else "_release_field_rover left the trip hot."


func test_a_lent_rover_coming_home_by_the_mouth_ends_the_trip() -> String:
	var gs: GameStateScript = _state()
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_PAD)
	var problems: Array[String] = []
	if gs.move_rover(true) != "":
		problems.append("The rover could not be lent in")
	_hot_trip(gs)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_EXIT)
	if gs.move_rover(false) != "" or gs.zone_heat_trip:
		problems.append("move_rover(false) left the trip hot")
	gs.move_rover(true)
	_hot_trip(gs)
	gs.bring_rover_home()
	if gs.zone_heat_trip or gs.rover_in_tunnels:
		problems.append("bring_rover_home left the trip hot")
	gs.free()
	return "\n".join(problems)


func test_a_field_rover_sent_home_ends_the_trip() -> String:
	var gs: GameStateScript = _state()
	gs.rover_zone = ZONE  # a field rover, not lent
	gs.rover_transforms[gs.TUNNEL_ROVER] = gs.TUNNEL_START
	_hot_trip(gs)
	gs.bring_rover_home()
	var cleared: bool = not gs.zone_heat_trip and gs.rover_zone == ""
	gs.free()
	return "" if cleared else "bring_rover_home left a field rover's trip hot."


func test_the_last_one_out_and_a_rescue_end_the_trip() -> String:
	var gs: GameStateScript = _state()
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(3.0, 0.0, 3.0))
	gs.player_places[HOST] = [ZonePresence.DOME, 0]
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = TunnelRecall.at_hour(1, 12.0)
	var problems: Array[String] = []
	gs.fast_travel(ZONE, HOST)
	_hot_trip(gs)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_EXIT)
	if gs.leave_zone(HOST) != "" or gs.zone_heat_trip:
		problems.append("leave_zone, last out, left the trip hot")
	gs.player_places[HOST] = [ZonePresence.DOME, 0]
	gs.fast_travel(ZONE, HOST)
	_hot_trip(gs)
	gs.rescue_from_tunnels(HOST)
	if gs.zone_heat_trip or gs.rover_zone != "":
		problems.append("A rescue left the trip hot")
	GameClock.elapsed_days = held
	gs.free()
	return "\n".join(problems)


func test_a_leave_with_a_friend_still_below_keeps_the_trip_and_a_new_trip_starts_cool() -> String:
	var gs: GameStateScript = _state()
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(3.0, 0.0, 3.0))
	gs.player_places[HOST] = [ZonePresence.DOME, 0]
	gs.player_places[GUEST] = [ZonePresence.DOME, 0]
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = TunnelRecall.at_hour(1, 12.0)
	var problems: Array[String] = []
	gs.fast_travel(ZONE, HOST)
	gs.fast_travel(ZONE, GUEST)
	_hot_trip(gs)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, gs.TUNNEL_EXIT)
	gs.leave_zone(HOST)
	if not gs.zone_heat_trip:
		problems.append("The rover is still on its trip with a friend below: the heat stays")
	gs.leave_zone(GUEST)
	if gs.zone_heat_trip:
		problems.append("The last one out ended it")
	gs.zone_heat_trip = true
	gs.fast_travel(ZONE, HOST)
	if gs.zone_heat_trip:
		problems.append("A new trip started hot")
	GameClock.elapsed_days = held
	gs.free()
	return "\n".join(problems)


func test_the_trip_is_not_saved_and_a_load_clears_it() -> String:
	var gs: GameStateScript = _state()
	_hot_trip(gs)
	var data: Dictionary = gs.farm_to_dict()
	gs.free()
	if data.has("zone_heat_trip"):
		return "The trip was saved."
	var back: GameStateScript = _state()
	_hot_trip(back)
	var loaded: String = back.farm_from_dict(bytes_to_var(var_to_bytes(data)))
	var cleared: bool = not back.zone_heat_trip
	back.free()
	if loaded != "":
		return "The save did not load: %s" % loaded
	return "" if cleared else "A load left the trip hot."


func test_the_trip_is_listed_as_not_saved() -> String:
	return "" if "zone_heat_trip" in GameStateScript.NOT_SAVED else "zone_heat_trip is not in NOT_SAVED."
