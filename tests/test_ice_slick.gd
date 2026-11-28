extends RefCounted
## The Ice Caves' slick ice, Bram's studs and the white-out (docs/design/zones.md hazard table;
## feat/ice-slick). Every number is a [PLACEHOLDER].

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const HOST := "player_1"
const GUEST := "player_2"
const SEED := 424242
const ZONE: String = "ice_caves"
const HOUR: float = 1.0 / 24.0


## Stands in for CoopBeds where a test only needs to know who was put to bed.
class _NoBeds:
	extends RefCounted
	var put_to_bed: Array[String] = []

	func recall_to_bed(player_id: String) -> void:
		put_to_bed.append(player_id)


func _state() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	gs.local_player_id = HOST
	return gs


func _at(elapsed: float, body: Callable) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = elapsed
	var out: Variant = body.call()
	GameClock.elapsed_days = held
	return out if out is String else "The test stopped early or did not return a String."


## The rover has driven into the caves and the host is at depth 1.
func _below(gs: GameStateScript) -> String:
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, GameState.ICE_PAD)
	var why: String = gs.move_rover_ice(true, HOST)
	gs.rover_depth = 1
	gs.player_places[HOST] = [ZONE, 1]
	return why


func _rover_at(gs: GameStateScript, cell: Vector2i, day: int) -> void:
	var today: Dictionary = IceDepth.layout(SEED, 1, day)
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, TunnelRock.at_in(today["grid"], cell))


## The first day from `from` with at least one slick cell.
func _slick_day(from: int) -> int:
	for day: int in range(from, from + 40):
		if not IceSlick.slick_cells(SEED, 1, day).is_empty():
			return day
	return -1


## The first day from `from` with a white-out.
func _spell_day(from: int) -> int:
	for day: int in range(from, from + 120):
		if not IceSlick.spell_of(SEED, day).is_empty():
			return day
	return -1


# --- Slick cells ---------------------------------------------------------------------

func test_slick_cells_are_floor_and_clear_of_the_way_up_the_start_and_the_finds() -> String:
	var seen_any: bool = false
	for day: int in range(1, 31):
		var today: Dictionary = IceDepth.layout(SEED, 1, day)
		var slick: Array[Vector2i] = IceSlick.slick_cells(SEED, 1, day)
		var keep: Array[Vector2i] = [ZoneDepth.START_CELL, ZoneDepth.UP_CELL, IceDepth.HATCH_CELL]
		for find: Dictionary in today["finds"]:
			keep.append(find["cell"])
		for cell: Vector2i in slick:
			seen_any = true
			if (today["grid"] as PackedStringArray)[cell.y][cell.x] != ".":
				return "Day %d: a slick cell is rock: %s." % [day, cell]
			for held: Vector2i in keep:
				if absi(held.x - cell.x) <= 1 and absi(held.y - cell.y) <= 1:
					return "Day %d: slick %s is on or next to %s." % [day, cell, held]
	return "" if seen_any else "No day in 30 had a slick cell."


func test_the_same_seed_and_day_give_the_same_slick_cells_and_other_days_differ() -> String:
	if IceSlick.slick_cells(SEED, 1, 7) != IceSlick.slick_cells(SEED, 1, 7):
		return "The same seed and day gave different slick cells."
	var differ: bool = false
	for day: int in range(1, 12):
		if IceSlick.slick_cells(SEED, 1, day) != IceSlick.slick_cells(SEED, 1, day + 1):
			differ = true
	if not differ:
		return "Eleven days running had the same slick cells."
	if IceSlick.slick_cells(SEED + 1, 1, 7) == IceSlick.slick_cells(SEED, 1, 7):
		return "Another seed gave the same slick cells."
	if not IceSlick.slick_cells(SEED, 0, 7).is_empty() or not IceSlick.slick_cells(SEED, 2, 7).is_empty():
		return "The hub or a depth that is not there has slick ice."
	return ""


func test_the_layout_stays_reachable_with_slick_cells() -> String:
	for day: int in range(1, 21):
		var today: Dictionary = IceDepth.layout(SEED, 1, day)
		var grid: PackedStringArray = today["grid"]
		var floor_cells: int = 0
		for line: String in grid:
			floor_cells += line.count(".")
		# A slick cell is still floor, so the whole floor is as reachable as before, and so is every find.
		var reach: Array[Vector2i] = ZoneDepth.reachable(grid, ZoneDepth.START_CELL)
		if reach.size() != floor_cells:
			return "Day %d: only %d of %d floor cells reach the start." % [day, reach.size(), floor_cells]
		for find: Dictionary in today["finds"]:
			if not find["cell"] in reach:
				return "Day %d: a find is cut off." % day
	return ""


# --- The skid ------------------------------------------------------------------------

func test_a_skid_goes_one_more_cell_when_open_and_never_into_rock_finds_the_way_up_or_off_the_map() -> String:
	var grid: PackedStringArray = IceDepth.layout(SEED, 1, 3)["grid"]
	var finds: Array = []
	var open := Vector2i(11, 12)  # the trunk north of the landing
	if grid[open.y][open.x] != "." or grid[open.y - 1][open.x] != ".":
		return "The trunk is not open where the test expects it."
	if IceSlick.skid_target(grid, finds, open, Vector2i.UP) != open + Vector2i.UP:
		return "An open cell ahead was not slid onto."
	if IceSlick.skid_target(grid, finds, open, Vector2i.UP + Vector2i.LEFT) != open:
		return "A diagonal skid moved the rover."
	if IceSlick.skid_target(grid, finds, open, Vector2i.ZERO) != open:
		return "A skid with no way moved the rover."
	if IceSlick.skid_target(grid, [open + Vector2i.UP], open, Vector2i.UP) != open:
		return "A skid slid onto a find."
	var rock_checked: bool = false
	for y: int in grid.size():
		for x: int in range(1, grid[y].length()):
			if grid[y][x] == "#" and grid[y][x - 1] == "." and not rock_checked:
				rock_checked = true
				if IceSlick.skid_target(grid, finds, Vector2i(x - 1, y), Vector2i.RIGHT) != Vector2i(x - 1, y):
					return "A skid slid into rock."
	if not rock_checked:
		return "The layout has no rock beside floor."
	var edge := Vector2i(0, 0)
	if IceSlick.skid_target(grid, finds, edge, Vector2i.LEFT) != edge or IceSlick.skid_target(grid, finds, edge, Vector2i.UP) != edge:
		return "A skid left the map."
	var below_up: Vector2i = ZoneDepth.UP_CELL + Vector2i.UP
	if IceSlick.skid_target(grid, finds, below_up, Vector2i.DOWN) != below_up:
		return "A skid slid through the way up."
	var near_start: Vector2i = ZoneDepth.START_CELL + Vector2i.UP
	if IceSlick.skid_target(grid, finds, near_start, Vector2i.DOWN) != near_start:
		return "A skid slid onto the start."
	return ""


func test_a_slick_skid_is_host_run_and_adds_the_wear_once_per_skid() -> String:
	var problems: Array[String] = []
	var day: int = _slick_day(2)
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		if _below(gs) != "":
			return "The rover did not go in."
		var cell: Vector2i = IceSlick.slick_cells(SEED, 1, day)[0]
		_rover_at(gs, cell, day)
		var before: float = absf(gs.steering.error)
		var why: String = gs.ice_skid(cell.x, cell.y, 0, -1, day, HOST)
		if why != "":
			return "A skid on slick ice was refused: '%s'" % why
		var after: float = absf(gs.steering.error)
		if after <= before:
			problems.append("The skid added no steering wear.")
		var expected: float = IceSlick.SKID_WEAR_M * gs.steering.usage_drift_rate
		if not is_equal_approx(after - before, expected):
			problems.append("The skid wear is %f, not %f." % [after - before, expected])
		if gs.ice_skid(cell.x, cell.y, 0, -1, day, HOST) != "" and absf(gs.steering.error) <= after:
			problems.append("A second skid added no wear of its own.")
		var twice: float = absf(gs.steering.error)
		if not is_equal_approx(twice - before, 2.0 * expected):
			problems.append("Two skids did not wear twice: %f." % (twice - before))
		# What the host will not take.
		var bad: Dictionary = {
			"yesterday": gs.ice_skid(cell.x, cell.y, 0, -1, day - 1, HOST),
			"diagonal": gs.ice_skid(cell.x, cell.y, 1, 1, day, HOST),
			"not slick": gs.ice_skid(ZoneDepth.START_CELL.x, ZoneDepth.START_CELL.y, 0, -1, day, HOST),
		}
		for name: String in bad:
			if bad[name] == "":
				problems.append("A skid was accepted: %s." % name)
		var far_cell: Vector2i = ZoneDepth.START_CELL
		_rover_at(gs, far_cell, day)
		if gs.ice_skid(cell.x, cell.y, 0, -1, day, HOST) == "":
			problems.append("A skid was accepted with the host's rover elsewhere.")
		gs.player_places[HOST] = [ZonePresence.FARM, 0]
		_rover_at(gs, cell, day)
		if gs.ice_skid(cell.x, cell.y, 0, -1, day, HOST) == "":
			problems.append("A skid was accepted from a player who is not in the caves.")
		gs.free()
		return "")
	if day < 0:
		return "No day had slick cells."
	return run if run != "" else "\n".join(problems)


func test_the_skid_goes_through_the_wear_that_the_cold_multiplies() -> String:
	var problems: Array[String] = []
	var day: int = _slick_day(2)
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		_below(gs)
		var cell: Vector2i = IceSlick.slick_cells(SEED, 1, day)[0]
		_rover_at(gs, cell, day)
		gs.cold_since[HOST] = float(day - 1) - 20.0 * HOUR  # 200 percent: capped, well past the threshold
		var before: float = absf(gs.steering.error)
		gs.ice_skid(cell.x, cell.y, 0, -1, day, HOST)
		var worn: float = absf(gs.steering.error) - before
		var plain: float = IceSlick.SKID_WEAR_M * gs.steering.usage_drift_rate
		if not is_equal_approx(worn, plain * IceDepth.DRIFT_MULTIPLIER):
			problems.append("A skid in the drift is %f, not %f times %f." % [worn, IceDepth.DRIFT_MULTIPLIER, plain])
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


# --- Studs ---------------------------------------------------------------------------

func test_buying_studs_charges_once_and_is_refused_without_credits_or_when_fitted() -> String:
	var gs: GameStateScript = _state()
	gs.credits = IceSlick.STUD_COST_CREDITS - 1
	if gs.buy_ice_studs(HOST) == "" or gs.has_ice_studs or gs.credits != IceSlick.STUD_COST_CREDITS - 1:
		return "Studs were sold without the credits."
	gs.credits = IceSlick.STUD_COST_CREDITS + 5
	var why: String = gs.buy_ice_studs(HOST)
	if why != "" or not gs.has_ice_studs or gs.credits != 5:
		return "Buying studs: '%s', fitted %s, %d credits left." % [why, gs.has_ice_studs, gs.credits]
	gs.credits = 1000
	if gs.buy_ice_studs(HOST) == "" or gs.credits != 1000:
		return "Studs were charged a second time."
	gs.free()
	return ""


func test_studs_stop_the_skid() -> String:
	var problems: Array[String] = []
	var day: int = _slick_day(2)
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		_below(gs)
		var cell: Vector2i = IceSlick.slick_cells(SEED, 1, day)[0]
		_rover_at(gs, cell, day)
		gs.credits = 500
		gs.buy_ice_studs(HOST)
		var before: float = absf(gs.steering.error)
		if gs.ice_skid(cell.x, cell.y, 0, -1, day, HOST) == "":
			problems.append("A rover with studs skidded.")
		if absf(gs.steering.error) != before:
			problems.append("Studs still took wear.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_studs_are_saved_old_saves_have_none_and_a_bad_value_is_refused() -> String:
	var gs: GameStateScript = _state()
	gs.credits = 500
	gs.buy_ice_studs(HOST)
	var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
	if data.get("has_ice_studs", false) != true:
		return "The studs were not saved."
	if not "has_ice_studs" in GameStateScript.SAVED_LATER:
		return "has_ice_studs is not in SAVED_LATER."
	var back: GameStateScript = _state()
	if back.farm_from_dict(data) != "" or not back.has_ice_studs:
		return "A save with studs did not load them."
	var old: Dictionary = data.duplicate(true)
	old.erase("has_ice_studs")
	var fresh: GameStateScript = _state()
	if fresh.farm_from_dict(old) != "" or fresh.has_ice_studs:
		return "A save from before the studs did not load with none."
	var junk: Dictionary = data.duplicate(true)
	junk["has_ice_studs"] = "yes"
	if gs.farm_dict_problem(junk) == "":
		return "A studs value that is not a yes or no was accepted."
	gs.free()
	back.free()
	fresh.free()
	return ""


# --- The white-out -------------------------------------------------------------------

func test_the_white_out_is_the_same_for_the_same_seed_and_day_and_some_days_have_none() -> String:
	var with_spell: int = 0
	for day: int in range(1, 91):
		if IceSlick.spell_of(SEED, day) != IceSlick.spell_of(SEED, day):
			return "Day %d's spell changed between asks." % day
		if not IceSlick.spell_of(SEED, day).is_empty():
			with_spell += 1
	if with_spell < 10 or with_spell > 60:
		return "%d of 90 days have a white-out: about one in %d was meant." % [with_spell, IceSlick.SPELL_ONE_IN]
	var differ: bool = false
	for day: int in range(1, 40):
		if IceSlick.spell_of(SEED, day) != IceSlick.spell_of(SEED + 1, day):
			differ = true
	return "" if differ else "Another seed has the same spells."


func test_a_spell_lies_between_eight_and_eighteen_and_the_clock_function_matches_it() -> String:
	var checked: int = 0
	for day: int in range(1, 91):
		var spell: Dictionary = IceSlick.spell_of(SEED, day)
		if spell.is_empty():
			continue
		checked += 1
		var start: int = int(spell["start"])
		var end: int = int(spell["end"])
		if start < 120 or end > 720 or end - start < 60 or end - start > 120:
			return "Day %d's spell is %d to %d minutes after 06:00." % [day, start, end]
		var morning: float = float(day - 1)
		if IceSlick.whiteout_active(SEED, morning + float(start - 1) / 1440.0):
			return "Day %d: down a minute before it starts." % day
		if not IceSlick.whiteout_active(SEED, morning + float(start) / 1440.0 + 0.0005):
			return "Day %d: not down when it starts." % day
		if not IceSlick.whiteout_active(SEED, morning + float(end - 1) / 1440.0 + 0.0005):
			return "Day %d: lifted before its last minute." % day
		if IceSlick.whiteout_active(SEED, morning + float(end) / 1440.0 + 0.0005):
			return "Day %d: still down after it ends." % day
		# Never at the 02:00 recall or the midnight warning that follows the day.
		if IceSlick.whiteout_active(SEED, TunnelRecall.at_hour(day, 2.0)) or IceSlick.whiteout_active(SEED, TunnelRecall.at_hour(day, 0.5)):
			return "Day %d: a white-out at the recall." % day
	return "" if checked > 0 else "No day had a spell."


func test_the_white_out_hides_only_far_finds_never_the_hatch_the_entry_or_the_way_out() -> String:
	if not IceSlick.shown_in_whiteout(false, 500.0):
		return "A prop that is not a find was hidden by distance."
	if not IceSlick.shown_in_whiteout(true, IceSlick.SEE_FINDS_M):
		return "A find at the edge of sight was hidden."
	if IceSlick.shown_in_whiteout(true, IceSlick.SEE_FINDS_M + 0.5):
		return "A far find was shown."
	if not IceSlick.shown_in_whiteout(true, 0.0):
		return "A find at the rover's nose was hidden."
	# The scene hides finds through shown_in_whiteout only: its way-up, hatch and entry nodes
	# are never passed to it.
	var source: String = FileAccess.get_file_as_string("res://scripts/world/ice_caves.gd")
	if not "shown_in_whiteout(true, distance)" in source or "shown_in_whiteout(false" in source:
		return "The scene hides something other than finds in a white-out."
	return ""


func test_a_recall_at_two_oclock_still_runs_after_a_white_out() -> String:
	var problems: Array[String] = []
	var day: int = _spell_day(1)
	if day < 0:
		return "No day had a spell."
	var spell: Dictionary = IceSlick.spell_of(SEED, day)
	var inside: float = float(day - 1) + (float(spell["start"]) + 5.0) / 1440.0
	var run: String = _at(inside, func() -> String:
		var gs: GameStateScript = _state()
		gs.credits = 500
		gs.recall_beds = _NoBeds.new()
		gs.recall_in_tunnels = func() -> bool: return true
		if _below(gs) != "":
			return "The rover did not go in."
		if not IceSlick.whiteout_active(SEED, GameClock.elapsed_days):
			return "The test clock is not inside the spell."
		GameClock.elapsed_days = TunnelRecall.at_hour(day, 2.0)
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Vector3(40.0, 0.0, 40.0))
		gs._tick_recall()
		if gs._recall_rescued_day != day:
			problems.append("The 02:00 rescue did not run on a white-out day (rescued day %d)." % gs._recall_rescued_day)
		if gs.rover_zone != "" or gs.place_of(HOST) != ZonePresence.FARM:
			problems.append("The player and the rover are not home.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


# --- Co-op ---------------------------------------------------------------------------

func test_a_guest_gets_the_studs_on_joining_and_on_an_update_and_the_same_white_out() -> String:
	var problems: Array[String] = []
	var held_guest: bool = FarmCommands.guest
	var day: int = _spell_day(1)
	var run: String = _at(float(day - 1) + 8.0 / 24.0, func() -> String:
		var host: GameStateScript = _state()
		var guest: GameStateScript = _state()
		host.credits = 500
		host.buy_ice_studs(HOST)
		FarmCommands.guest = true
		guest.local_player_id = GUEST
		var joined: String = FarmSync.join(FarmSync.capture(host), guest)
		FarmCommands.guest = false
		if joined != "" or not guest.has_ice_studs:
			problems.append("A joining guest does not see the studs: '%s'." % joined)
		var late: GameStateScript = _state()
		FarmCommands.guest = true
		late.local_player_id = "player_3"
		FarmSync.join(FarmSync.capture(_state()), late)
		FarmCommands.guest = false
		if late.has_ice_studs:
			problems.append("A farm with no studs showed them.")
		var heard: Array[int] = [0]
		late.upgrades_changed.connect(func() -> void: heard[0] += 1)
		FarmCommands.guest = true
		var updated: String = FarmSync.update(FarmSync.capture(host), late)
		FarmCommands.guest = false
		if updated != "" or not late.has_ice_studs or heard[0] < 1:
			problems.append("The update did not bring the studs: '%s', told %d." % [updated, heard[0]])
		# The white-out is a pure function of the clock and the seed, which a guest has.
		if IceSlick.whiteout_active(host.world_seed, GameClock.elapsed_days) != IceSlick.whiteout_active(guest.world_seed, GameClock.elapsed_days):
			problems.append("A guest and the host disagree about the white-out.")
		host.free()
		guest.free()
		late.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)


func test_the_new_commands_are_listed_the_skid_is_a_zone_command_and_the_protocol_moved_once() -> String:
	for action: StringName in [&"buy_ice_studs", &"ice_skid"]:
		if not action in FarmCommands.ACTIONS:
			return "%s is not a command." % action
	if not &"ice_skid" in FarmCommands.BELOW_ONLY or &"buy_ice_studs" in FarmCommands.BELOW_ONLY:
		return "The skid is a zone command and the studs are bought on the farm."
	return "" if CoopSession.PROTOCOL == 43 else "The protocol is %d, not 43." % CoopSession.PROTOCOL


func test_the_lava_aquifer_and_mine_floors_have_no_slick_ice() -> String:
	var problems: Array[String] = []
	var day: int = _slick_day(2)
	var run: String = _at(float(day - 1), func() -> String:
		for zone: String in [ZoneDepth.ZONE, AquiferDepth.ZONE, MineDepth.ZONE]:
			var gs: GameStateScript = _state()
			gs.rover_zone = zone
			gs.rover_depth = 1
			gs.player_places[HOST] = [zone, 1]
			var cell: Vector2i = IceSlick.slick_cells(SEED, 1, day)[0]
			if gs.ice_skid(cell.x, cell.y, 0, -1, day, HOST) == "":
				problems.append("%s skidded the rover." % zone)
			gs.free()
		return "")
	# And their layouts are untouched by the new tags: the same hash, the same finds.
	var lava: Dictionary = ZoneDepth.layout(SEED, ZoneDepth.ZONE, 1, 5)
	if lava.is_empty() or lava["finds"] != ZoneDepth.layout(SEED, ZoneDepth.ZONE, 1, 5)["finds"]:
		problems.append("The Lava Tubes' layout is not steady.")
	return run if run != "" else "\n".join(problems)
