extends RefCounted
## The Polar Ice Caves (docs/design/zones.md section 13, build step 15): the ramp, the hub,
## depth 1 from the hash, the cold and the heater, the saved field and the recall. Every
## number is a [PLACEHOLDER].

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


## Runs `body` with the global clock at `elapsed` days and restores it.
func _at(elapsed: float, body: Callable) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = elapsed
	var out: Variant = body.call()
	GameClock.elapsed_days = held
	return out if out is String else "The test stopped early or did not return a String."


## A farm whose rover has driven into the caves from the ramp (the host is in them, at the hub).
func _inside(gs: GameStateScript) -> String:
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, GameState.ICE_PAD)
	return gs.move_rover_ice(true, HOST)


## The rover at the hub's heater crate.
func _at_crate(gs: GameStateScript) -> void:
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, IceDepth.crate_position())


# --- The entrance --------------------------------------------------------------------

func test_under_lab_level_eighteen_the_ramp_warns_and_still_lets_you_in() -> String:
	if ZoneData.warning_text(&"ice_caves", 3) == "" or ZoneData.warning_text(&"ice_caves", 17) == "":
		return "A lab level under 18 got no warning at the ramp."
	if ZoneData.warning_text(&"ice_caves", ZoneData.band(&"ice_caves").x) != "":
		return "The band's first level is in the band: no warning."
	var gs: GameStateScript = _state()
	var let_in: String = _inside(gs)  # the warning is the screen's; the host does not gate on level
	var zone: String = gs.rover_zone
	var lent: bool = gs.rover_lent
	var depth: int = gs.rover_depth
	gs.free()
	return "" if let_in == "" and zone == ZONE and lent and depth == 0 else "The warned ramp kept the rover out: '%s' '%s' lent %s depth %d." % [let_in, zone, lent, depth]


func test_the_ice_caves_are_a_playable_zone_with_a_scene_and_a_fast_travel_choice() -> String:
	if not ZoneData.is_playable(&"ice_caves") or ZoneData.hub_scene(&"ice_caves") != SceneSwitcher.ICE_SCENE:
		return "The Ice Caves are not playable, or their hub scene is not SceneSwitcher.ICE_SCENE."
	if SceneSwitcher.scene_for_zone(ZONE) != SceneSwitcher.ICE_SCENE or not SceneSwitcher.is_zone_scene(SceneSwitcher.ICE_SCENE):
		return "SceneSwitcher does not map the Ice Caves to their scene."
	for row: Dictionary in FastTravel.destinations(18, []):
		if row["id"] == ZONE:
			return "The Ice Caves are listed before the first visit."
	for row: Dictionary in FastTravel.destinations(18, [ZONE]):
		if row["id"] == ZONE:
			return ""
	return "The Ice Caves are not listed after the first visit."


func test_the_scene_loads_and_builds_its_hub() -> String:
	var packed: PackedScene = load("res://scenes/ice_caves.tscn")
	if packed == null or not packed.can_instantiate():
		return "scenes/ice_caves.tscn does not load."
	var crate := Node3D.new()
	IceLook.add_heater_crate(crate, Vector3.ZERO)
	IceLook.add_ice_wall(crate, Vector3.ZERO, Vector2(2.0, 1.0), 2.0)
	var heater: bool = crate.get_node_or_null("HeaterCrate") != null
	var walls: Node = crate.get_node_or_null("IceWall")
	var bands: int = walls.get_child_count() if walls != null else 0
	crate.free()
	return "" if heater and bands == IceLook.BANDS.size() else "The crate or the layered wall did not build (crate %s, %d bands)." % [heater, bands]


# --- Depth 1 -------------------------------------------------------------------------

func test_depth_one_is_the_same_for_the_same_seed_and_day_and_new_the_next_day() -> String:
	var a: Dictionary = IceDepth.layout(SEED, 1, 5)
	var b: Dictionary = IceDepth.layout(SEED, 1, 5)
	if a.is_empty() or var_to_bytes(a) != var_to_bytes(b):
		return "The same seed and day gave two depth-1 layouts."
	var differs: bool = false
	for day: int in [6, 7, 8, 9]:
		differs = differs or var_to_bytes(IceDepth.layout(SEED, 1, day)) != var_to_bytes(a)
	if not differs:
		return "Four new days gave the same depth 1."
	if (a["finds"] as Array).size() != IceDepth.find_count() or a.has("rockfalls"):
		return "Depth 1 has %d finds (want %d), or has rockfalls." % [(a["finds"] as Array).size(), IceDepth.find_count()]
	if not IceDepth.layout(SEED, 0, 5).is_empty() or not IceDepth.layout(SEED, 2, 5).is_empty() or ZoneDepth.max_depth_of(ZONE) != 1:
		return "The Ice Caves have a depth other than 1."
	for find: Dictionary in a["finds"]:
		if not str(find["kind"]) in IceDepth.KINDS or IceDepth.reward(str(find["kind"])).is_empty():
			return "A find has no kind or no reward: %s" % [find]
	return ""


func test_a_find_is_taken_host_run_and_once() -> String:
	var problems: Array[String] = []
	var day: int = 6
	var run: String = _at(float(day - 1), func() -> String:
		var gs: GameStateScript = _state()
		var why_in: String = _inside(gs)
		if why_in != "":
			return "The rover did not go in: '%s'." % why_in
		var data: Dictionary = IceDepth.layout(SEED, 1, day)
		var find: Dictionary = (data["finds"] as Array)[0]
		var at: Vector3 = TunnelRock.at_in(data["grid"], find["cell"])
		gs.rover_depth = 1
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, at)
		gs.player_places[HOST] = [ZONE, 1]
		var pay: Dictionary = IceDepth.reward(str(find["kind"]))
		var credits: int = gs.credits
		var ore: int = gs.crystal_ore
		var why: String = gs.take_find(str(find["id"]), day, HOST)
		if why != "":
			problems.append("A find was refused: '%s'" % why)
		if gs.credits != credits + int(pay.get("credits", 0)) or gs.crystal_ore != ore + int(pay.get("crystal_ore", 0)):
			problems.append("The reward is not the Ice Caves': %s" % [pay])
		if not str(find["id"]) in ZoneDepth.taken_today(gs.finds_taken, ZONE, day) or gs.finds_taken.has("lava_tubes"):
			problems.append("The find was not recorded under the Ice Caves.")
		if gs.take_find(str(find["id"]), day, HOST) == "":
			problems.append("A find was taken twice.")
		if gs.take_find(str(find["id"]), day - 1, HOST) == "":
			problems.append("Yesterday's floor was accepted.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_the_ice_commands_are_on_the_list_and_the_heater_is_a_zone_command() -> String:
	var actions: Array = FarmCommands.ACTIONS
	for name: StringName in [&"buy_heater", &"move_rover_ice"]:
		if not name in actions:
			return "%s is not a farm command." % name
	if not &"buy_heater" in FarmCommands.BELOW_ONLY:
		return "buy_heater is not limited to a player below ground."
	return ""


# --- The cold ------------------------------------------------------------------------

func test_cold_rises_with_time_in_the_caves_and_is_nothing_outside() -> String:
	var problems: Array[String] = []
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		if gs.cold_of(HOST) != 0.0:
			problems.append("A farm with nobody in the caves has cold %f." % gs.cold_of(HOST))
		if _inside(gs) != "":
			return "The rover did not go in."
		if gs.cold_of(HOST) != 0.0:
			problems.append("The cold starts above 0 on the way in: %f." % gs.cold_of(HOST))
		GameClock.elapsed_days = 3.0 + 2.0 * HOUR
		var two: float = gs.cold_of(HOST)
		GameClock.elapsed_days = 3.0 + 4.0 * HOUR
		var four: float = gs.cold_of(HOST)
		if not is_equal_approx(two, 2.0 * IceDepth.COLD_PER_HOUR) or not four > two:
			problems.append("The cold does not rise by %f %% an hour: %f then %f." % [IceDepth.COLD_PER_HOUR, two, four])
		GameClock.elapsed_days = 3.0 + 40.0 * HOUR
		if gs.cold_of(HOST) != IceDepth.COLD_MAX:
			problems.append("The cold does not stop at %f: %f." % [IceDepth.COLD_MAX, gs.cold_of(HOST)])
		if IceDepth.cold(5.0, 4.0) != 0.0:
			problems.append("A stamp in the future is cold.")
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_past_the_threshold_the_instruments_drift_and_the_hud_line_says_so() -> String:
	var problems: Array[String] = []
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		if _inside(gs) != "":
			return "The rover did not go in."
		var start: float = gs.steering.error
		gs.add_rover_usage(100.0, HOST, gs.TUNNEL_ROVER)
		var calm: float = absf(gs.steering.error - start)
		GameClock.elapsed_days = 3.0 + 6.0 * HOUR  # 60 %: past the 50 % threshold
		if not IceDepth.is_drifting(gs.cold_of(HOST)):
			problems.append("60 % cold is not drifting.")
		var before: float = gs.steering.error
		gs.add_rover_usage(100.0, HOST, gs.TUNNEL_ROVER)
		var cold_step: float = absf(gs.steering.error - before)
		if calm <= 0.0 or not is_equal_approx(cold_step, calm * IceDepth.DRIFT_MULTIPLIER):
			problems.append("Drifting wear is not %.1f times the calm wear: %f vs %f." % [IceDepth.DRIFT_MULTIPLIER, cold_step, calm])
		if IceDepth.drift_multiplier(IceDepth.COLD_THRESHOLD - 1.0) != 1.0 or IceDepth.drift_multiplier(IceDepth.COLD_THRESHOLD) != IceDepth.DRIFT_MULTIPLIER:
			problems.append("The drift switches on somewhere other than the threshold.")
		if not IceDepth.cold_text(60.0).contains("drift") or IceDepth.cold_text(20.0).contains("drift"):
			problems.append("The HUD line does not say the instruments drift exactly past the threshold.")
		gs.free()
		return "")
	return run if run != "" else "
".join(problems)


func test_a_heater_resets_the_cold_is_charged_once_and_refused_when_short() -> String:
	var problems: Array[String] = []
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		gs.credits = IceDepth.HEATER_COST_CREDITS
		if _inside(gs) != "":
			return "The rover did not go in."
		gs.rover_depth = 0
		GameClock.elapsed_days = 3.0 + 7.0 * HOUR
		var heard: Array[int] = [0]
		gs.ice_changed.connect(func() -> void: heard[0] += 1)
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, IceDepth.crate_position() + Vector3(30.0, 0.0, 0.0))
		var far: String = gs.buy_heater(HOST)
		if far == "" or gs.credits != IceDepth.HEATER_COST_CREDITS:
			problems.append("A heater was sold away from the crate: '%s' (%d credits)." % [far, gs.credits])
		_at_crate(gs)
		var done: String = gs.buy_heater(HOST)
		if done != "":
			problems.append("A heater was refused at the crate with the credits: '%s'." % done)
		if gs.credits != 0 or gs.cold_of(HOST) != 0.0 or heard[0] != 1:
			problems.append("The heater must cost %d credits once and reset the cold: %d credits, cold %f, told %d." % [IceDepth.HEATER_COST_CREDITS, gs.credits, gs.cold_of(HOST), heard[0]])
		GameClock.elapsed_days = 3.0 + 9.0 * HOUR
		var short: String = gs.buy_heater(HOST)
		if short == "" or not short.contains("%d credits" % IceDepth.HEATER_COST_CREDITS) or gs.credits != 0:
			problems.append("A short player was sold a heater or charged: '%s' (%d credits)." % [short, gs.credits])
		if not is_equal_approx(gs.cold_of(HOST), 2.0 * IceDepth.COLD_PER_HOUR):
			problems.append("The cold did not start again from the heater: %f." % gs.cold_of(HOST))
		var out: GameStateScript = _state()
		out.credits = 500
		if out.buy_heater(HOST) == "" or out.credits != 500:
			problems.append("A heater was sold to a player who is not in the caves.")
		out.free()
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_leaving_the_caves_resets_the_cold() -> String:
	var problems: Array[String] = []
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		if _inside(gs) != "":
			return "The rover did not go in."
		GameClock.elapsed_days = 3.0 + 8.0 * HOUR
		if gs.cold_of(HOST) <= 0.0 or not gs.cold_since.has(HOST):
			problems.append("There is no cold to reset.")
		var out: String = gs.move_rover_ice(false, HOST)
		if out != "":
			problems.append("The rover could not come out: '%s'." % out)
		if gs.cold_of(HOST) != 0.0 or gs.cold_since.has(HOST):
			problems.append("Leaving did not reset the cold: %f, stamps %s." % [gs.cold_of(HOST), gs.cold_since])
		GameClock.elapsed_days = 3.0 + 30.0 * HOUR
		if _inside(gs) != "" or gs.cold_of(HOST) != 0.0:
			problems.append("Coming in again did not start from 0 (%f)." % gs.cold_of(HOST))
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_back_within_the_grace_resumes_the_paused_cold_and_later_starts_from_nothing() -> String:
	var problems: Array[String] = []
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		if _inside(gs) != "":
			return "The rover did not go in."
		GameClock.elapsed_days = 3.0 + 5.0 * HOUR
		if gs.move_rover_ice(false, HOST) != "":
			return "The rover could not come out."
		if gs.cold_since.has(HOST) or gs.cold_of(HOST) != 0.0:
			problems.append("Outside the caves there is still a stamp: %s." % [gs.cold_since])
		GameClock.elapsed_days = 3.0 + 5.5 * HOUR
		if _inside(gs) != "":
			return "The rover did not go in again."
		# Five hours in, half an hour out: the cold paused at five hours' worth.
		if not is_equal_approx(gs.cold_of(HOST), 5.0 * IceDepth.COLD_PER_HOUR):
			problems.append("Back within the grace did not resume the paused cold: %f." % gs.cold_of(HOST))
		GameClock.elapsed_days = 3.0 + 6.0 * HOUR
		if not is_equal_approx(gs.cold_of(HOST), 5.5 * IceDepth.COLD_PER_HOUR):
			problems.append("The resumed cold did not keep rising from there: %f." % gs.cold_of(HOST))
		gs.move_rover_ice(false, HOST)
		GameClock.elapsed_days = 3.0 + (6.0 + IceDepth.COLD_GRACE_HOURS + 0.5) * HOUR
		if _inside(gs) != "" or gs.cold_of(HOST) != 0.0:
			problems.append("Back after the grace did not start from 0: %f." % gs.cold_of(HOST))
		GameClock.elapsed_days = 3.0 + 10.0 * HOUR
		gs.move_rover_ice(false, HOST)
		gs.farm_from_dict(gs.farm_to_dict())
		GameClock.elapsed_days = 3.0 + 10.2 * HOUR
		if _inside(gs) != "" or gs.cold_of(HOST) != 0.0:
			problems.append("A load kept the grace: %f." % gs.cold_of(HOST))
		gs.free()
		return "")
	return run if run != "" else "
".join(problems)


func test_the_crate_refuses_a_heater_below_the_cold_floor() -> String:
	var problems: Array[String] = []
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		gs.credits = IceDepth.HEATER_COST_CREDITS
		if _inside(gs) != "":
			return "The rover did not go in."
		gs.rover_depth = 0
		_at_crate(gs)
		GameClock.elapsed_days = 3.0 + 0.5 * HOUR
		var early: String = gs.buy_heater(HOST)
		if not early.contains("not cold enough") or gs.credits != IceDepth.HEATER_COST_CREDITS:
			problems.append("A heater was sold below %f %% cold: '%s' (%d credits)." % [IceDepth.HEATER_MIN_COLD, early, gs.credits])
		GameClock.elapsed_days = 3.0 + (IceDepth.HEATER_MIN_COLD / IceDepth.COLD_PER_HOUR + 0.1) * HOUR
		var later: String = gs.buy_heater(HOST)
		if later != "" or gs.credits != 0:
			problems.append("A heater was refused at the floor: '%s' (%d credits)." % [later, gs.credits])
		if IceDepth.heater_problem(ZONE, 0, 100, true, IceDepth.HEATER_MIN_COLD) != "":
			problems.append("The floor itself must be enough cold.")
		gs.free()
		return "")
	return run if run != "" else "
".join(problems)


func test_a_guest_sees_the_cold_and_only_the_hosts_copy_is_stamped() -> String:
	var problems: Array[String] = []
	var held_guest: bool = FarmCommands.guest
	var run: String = _at(3.0, func() -> String:
		var host: GameStateScript = _state()
		var guest: GameStateScript = _state()
		if _inside(host) != "":
			return "The rover did not go in."
		GameClock.elapsed_days = 3.0 + 3.0 * HOUR
		FarmCommands.guest = true
		guest.local_player_id = GUEST
		var joined: String = FarmSync.join(FarmSync.capture(host), guest)
		if joined != "":
			problems.append("The join was refused: %s" % joined)
		if not is_equal_approx(guest.cold_of(HOST), 3.0 * IceDepth.COLD_PER_HOUR):
			problems.append("A joining guest does not see the cold: %f." % guest.cold_of(HOST))
		FarmCommands.guest = false
		host.cold_since[HOST] = 3.0 + 1.0 * HOUR
		var heard: Array[int] = [0]
		guest.ice_changed.connect(func() -> void: heard[0] += 1)
		FarmCommands.guest = true
		var updated: String = FarmSync.update(FarmSync.capture(host), guest)
		FarmCommands.guest = false
		if updated != "":
			problems.append("The update was refused: %s" % updated)
		if not is_equal_approx(guest.cold_of(HOST), 2.0 * IceDepth.COLD_PER_HOUR) or heard[0] < 1:
			problems.append("The guest was not told of the heater: %f, told %d." % [guest.cold_of(HOST), heard[0]])
		host.free()
		guest.free()
		return "")
	FarmCommands.guest = held_guest
	return run if run != "" else "\n".join(problems)


# --- Save ----------------------------------------------------------------------------

func test_the_new_field_round_trips_and_an_old_save_loads() -> String:
	var problems: Array[String] = []
	var run: String = _at(3.0, func() -> String:
		var gs: GameStateScript = _state()
		if _inside(gs) != "":
			return "The rover did not go in."
		var data: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
		var back: GameStateScript = _state()
		var saved: Dictionary = data.get("cold_since", {})
		if not saved.has(HOST) or not is_equal_approx(float(saved[HOST]), 3.0):
			problems.append("The cold stamp was not saved: %s." % [saved])
		# A load clears the places, so it drops the stamps with them; arriving stamps again.
		if back.farm_from_dict(data) != "" or not back.cold_since.is_empty():
			problems.append("A load kept a stamp with no place: %s." % [back.cold_since])
		for bad: Variant in [3, { 7: 1.0 }, { HOST: "now" }, { HOST: -1.0 }, { HOST: INF }]:
			var junk: Dictionary = gs.farm_to_dict()
			junk["cold_since"] = bad
			if gs.farm_dict_problem(junk) == "":
				problems.append("A bad cold_since was accepted: %s" % [bad])
		if not "cold_since" in GameStateScript.SAVED_LATER:
			problems.append("cold_since is not in SAVED_LATER.")
		var old: Dictionary = gs.farm_to_dict()
		old.erase("cold_since")
		var fresh: GameStateScript = _state()
		if fresh.farm_from_dict(old) != "" or not fresh.cold_since.is_empty():
			problems.append("A save from before the Ice Caves did not load with no cold.")
		fresh.free()
		var in_caves: Dictionary = gs.farm_to_dict()
		in_caves["rover_zone"] = ZONE
		var there: GameStateScript = _state()
		if there.farm_from_dict(in_caves) != "" or there.rover_zone != ZONE:
			problems.append("A save with the rover in the Ice Caves did not load.")
		there.free()
		# A save made with nobody in the caves keeps no stale stamp.
		gs.cold_since["player_9"] = 1.0
		if (gs.farm_to_dict()["cold_since"] as Dictionary).has("player_9"):
			problems.append("A stamp for a player who is not in the caves was saved.")
		gs.free()
		back.free()
		return "")
	return run if run != "" else "\n".join(problems)


## The host joins a rover that is already in the caves (a scene swap with no host command), or
## loads a save with the rover there and no stamp: arriving still starts the host's cold.
func test_a_host_who_joins_a_rover_already_in_the_caves_gets_a_cold_stamp() -> String:
	var problems: Array[String] = []
	var run: String = _at(4.0, func() -> String:
		var gs: GameStateScript = _state()
		gs.rover_zone = ZONE
		gs.rover_in_tunnels = true
		if gs.cold_since.has(HOST):
			return "The host had a stamp before arriving."
		# The arrival path: the scene reports its place and nothing else.
		gs._set_place(HOST, ZONE, 0)
		if not gs.cold_since.has(HOST) or not is_equal_approx(float(gs.cold_since[HOST]), 4.0):
			problems.append("Joining a rover already in the caves gave no stamp: %s." % [gs.cold_since])
		# A save with the rover in the caves and no stamp for the host.
		var data: Dictionary = gs.farm_to_dict()
		data["rover_zone"] = ZONE
		data.erase("cold_since")
		var back: GameStateScript = _state()
		if back.farm_from_dict(data) != "":
			problems.append("The save with no stamp did not load.")
		GameClock.elapsed_days = 4.5
		back._set_place(HOST, ZONE, 0)
		if not back.cold_since.has(HOST) or not is_equal_approx(float(back.cold_since[HOST]), 4.5):
			problems.append("A loaded save with the rover in the caves gave no stamp on arrival: %s." % [back.cold_since])
		# A second report from the same place keeps the stamp it has.
		GameClock.elapsed_days = 5.0
		back._set_place(HOST, ZONE, 1)
		if not is_equal_approx(float(back.cold_since.get(HOST, -1.0)), 4.5):
			problems.append("Going down a depth restarted the cold.")
		gs.free()
		back.free()
		return "")
	return run if run != "" else "
".join(problems)


func test_the_protocol_is_the_current_one() -> String:
	return "" if CoopSession.PROTOCOL == 52 else "The protocol is %d, not 52." % CoopSession.PROTOCOL


# --- Presence and recall -------------------------------------------------------------

func test_zone_presence_accepts_depth_one_in_the_caves_and_no_deeper() -> String:
	for depth: int in [0, 1]:
		if ZonePresence.place_problem(ZONE, depth) != "":
			return "Depth %d in the Ice Caves was refused: %s" % [depth, ZonePresence.place_problem(ZONE, depth)]
	return "" if ZonePresence.place_problem(ZONE, 2) != "" else "Depth 2 in the Ice Caves was accepted: there is none."


func test_the_two_oclock_rescue_brings_a_player_home_from_the_caves_and_ends_the_cold() -> String:
	var problems: Array[String] = []
	var run: String = _at(TunnelRecall.at_hour(1, 2.0) - 3.0 * HOUR, func() -> String:
		var gs: GameStateScript = _state()
		gs.credits = 500
		gs.recall_beds = _NoBeds.new()
		gs.recall_in_tunnels = func() -> bool: return true
		if _inside(gs) != "":
			return "The rover did not go in."
		GameClock.elapsed_days = TunnelRecall.at_hour(1, 2.0)
		gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, Vector3(40.0, 0.0, 40.0))
		gs._tick_recall()
		if gs._recall_rescued_day != 1:
			problems.append("The 02:00 rescue did not run in the Ice Caves (rescued day %d)." % gs._recall_rescued_day)
		if gs.credits != 450:
			problems.append("The rescue costs 50 CR as in the tunnels: %d CR left." % gs.credits)
		if gs.rover_zone != "" or gs.place_of(HOST) != ZonePresence.FARM:
			problems.append("The player and the rover are not home: zone '%s'." % gs.rover_zone)
		if gs.cold_since.has(HOST) or gs.cold_of(HOST) != 0.0:
			problems.append("The rescue left the player cold.")
		var home: Vector3 = (gs.rover_transforms[gs.ROVER] as Transform3D).origin
		if home.distance_to(GameState.ICE_PAD) > GameState.TUNNEL_PAD_REACH_M:
			problems.append("The rover came home to %s, not the ramp." % [home])
		gs.free()
		return "")
	return run if run != "" else "\n".join(problems)


func test_the_midnight_warning_covers_the_caves_once() -> String:
	var gs: GameStateScript = _state()
	gs.recall_in_tunnels = func() -> bool: return true
	var inside: String = _at(TunnelRecall.at_hour(1, 0.5), func() -> String:
		var why: String = _inside(gs)
		gs._tick_recall()
		gs._tick_recall()
		return why)
	var warned: int = 0
	for line: String in gs.phone_log:
		if line.contains("Recall in 2 hours"):
			warned += 1
	var rescued: int = gs._recall_rescued_day
	gs.free()
	return "" if warned == 1 and rescued == 0 else "One warning, no rescue yet: %d warnings, rescued day %d (%s)." % [warned, rescued, inside]
