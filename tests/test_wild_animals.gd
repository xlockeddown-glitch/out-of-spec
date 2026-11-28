extends RefCounted
## Wild animals on the farm (docs/design/farm_animals.md):
## data loading, feed bin from crop harvest, trust rules, dawn gifts & finds,
## Lin sales, no double collect, host-authoritative co-op, and save compatibility.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const FarmCommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const CELL: Vector3i = Vector3i(1, 0, 1)


func _make_state(seed_value: int = 12345) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(seed_value)
	gs.reset_credibility()
	gs.credits = 1000
	gs.tilled_cells[CELL] = true
	gs.get_sensor(gs.SOIL_PROBE_ID).error = 0.0
	gs.set_meta(&"saved_clock", GameClock.elapsed_days)
	GameClock.elapsed_days = 0.0
	return gs


func _done(gs: GameStateScript) -> void:
	GameClock.elapsed_days = float(gs.get_meta(&"saved_clock"))
	gs.free()


func _advance_dawn(gs: GameStateScript) -> int:
	GameClock.elapsed_days = floorf(GameClock.elapsed_days) + 1.0
	var day: int = GameClock.get_day_index()
	gs._step_animals_dawn(day)
	return day


func test_animals_data_loaded() -> String:
	var gs: GameStateScript = _make_state()
	var ids: Array[String] = gs.animal_group_ids()
	var hen: Dictionary = gs.animal_group("dome_hen")
	var goat: Dictionary = gs.animal_group("dome_goat")
	var rabbit: Dictionary = gs.animal_group("dome_rabbit")
	var max_trust: int = int(gs.animal_trust_rule("max", -1.0))
	var problem: String = ""
	if ids.size() != 3 or not ("dome_hen" in ids and "dome_goat" in ids and "dome_rabbit" in ids):
		problem = "Expected 3 animal groups, got %s." % [ids]
	elif int(hen.get("gift_price", 0)) != 12 or int(goat.get("gift_price", 0)) != 30 or int(rabbit.get("gift_price", 0)) != 40:
		problem = "Unexpected gift prices: %s / %s / %s." % [hen.get("gift_price"), goat.get("gift_price"), rabbit.get("gift_price")]
	elif max_trust != 5:
		problem = "Expected trust/max 5, got %d." % max_trust
	_done(gs)
	return problem


func test_harvest_adds_byproduct_to_feed_bin_and_feeding_rules() -> String:
	var gs: GameStateScript = _make_state()
	gs.seed_crop_id = "biscuit_reed"
	gs.plant_crop(CELL)
	var days: int = int(gs.crop("biscuit_reed").get("growth_days", 3))
	for i: int in days:
		GameClock.elapsed_days = floorf(GameClock.elapsed_days) + 1.0
		gs._grow_crops()
	var entry: Dictionary = gs.harvest_crop(CELL)
	var problem: String = ""
	if entry.is_empty():
		problem = "Expected crop to harvest."
	elif int(gs.feed_bin.get("reed_chaff", 0)) != 1 or gs.feed_bin_total() != 1:
		problem = "Harvesting biscuit_reed should add 1 reed_chaff to feed_bin, got %s." % [gs.feed_bin]
	else:
		# Feeding once succeeds and uses the feed.
		var first: String = gs.feed_animals("dome_hen")
		var second_same_day: String = gs.feed_animals("dome_hen")
		var no_feed: String = gs.feed_animals("dome_goat")
		if first != "":
			problem = "First feed with feed in bin must succeed, got: %s" % first
		elif gs.feed_bin_total() != 0 or not gs.animal_fed_today("dome_hen"):
			problem = "Feeding must consume 1 feed and mark fed_today."
		elif second_same_day == "":
			problem = "Feeding the same group twice in one day must be refused."
		elif no_feed == "":
			problem = "Feeding with an empty feed bin must be refused."
	_done(gs)
	return problem


func test_trust_up_down_and_floor_at_zero() -> String:
	var gs: GameStateScript = _make_state()
	gs.feed_bin["reed_chaff"] = 10
	var problem: String = ""
	# Feed for 2 days -> trust rises to 2.
	gs.feed_animals("dome_hen")
	_advance_dawn(gs)
	if gs.animal_trust("dome_hen") != 1:
		problem = "Expected trust 1 after 1 fed day, got %d." % gs.animal_trust("dome_hen")
	if problem == "":
		gs.feed_animals("dome_hen")
		_advance_dawn(gs)
		if gs.animal_trust("dome_hen") != 2:
			problem = "Expected trust 2 after 2 fed days, got %d." % gs.animal_trust("dome_hen")
	# 2 unfed days -> still trust 2.
	if problem == "":
		_advance_dawn(gs)
		_advance_dawn(gs)
		if gs.animal_trust("dome_hen") != 2:
			problem = "Trust should not drop after only 2 unfed days, got %d." % gs.animal_trust("dome_hen")
	# 3rd unfed day -> drops to 1.
	if problem == "":
		_advance_dawn(gs)
		if gs.animal_trust("dome_hen") != 1:
			problem = "Trust should drop by 1 after 3 unfed days, got %d." % gs.animal_trust("dome_hen")
	# 6 more unfed days -> drops to 0 and never goes below 0.
	if problem == "":
		for i: int in 6:
			_advance_dawn(gs)
		if gs.animal_trust("dome_hen") != 0:
			problem = "Trust must floor at 0, got %d." % gs.animal_trust("dome_hen")
	_done(gs)
	return problem


func test_gifts_threshold_collect_xp_and_lin_sale() -> String:
	var gs: GameStateScript = _make_state()
	gs.feed_bin["root_coir"] = 5
	var problem: String = ""
	# Day 1 fed -> trust 1 (no gifts).
	gs.feed_animals("dome_goat")
	_advance_dawn(gs)
	if gs.animal_gifts_waiting("dome_goat") != 0:
		problem = "No gifts should appear below trust 2, got %d." % gs.animal_gifts_waiting("dome_goat")
	# Day 2 fed -> trust 2 (gifts appear).
	if problem == "":
		gs.feed_animals("dome_goat")
		_advance_dawn(gs)
		if gs.animal_gifts_waiting("dome_goat") != 1:
			problem = "Expected 1 gift for dome_goat at trust 2, got %d." % gs.animal_gifts_waiting("dome_goat")
	# Collect moves gift to harvest_bin, awards Agronomy XP, and prevents double collect.
	if problem == "":
		var xp_before: int = gs.skill_xp("agronomy", gs.local_player_id)
		var got1: int = gs.collect_animal_gifts("dome_goat", gs.local_player_id)
		var got2: int = gs.collect_animal_gifts("dome_goat", gs.local_player_id)
		var xp_after: int = gs.skill_xp("agronomy", gs.local_player_id)
		if got1 != 1 or got2 != 0:
			problem = "Expected collect 1 then 0 (no double collect), got %d and %d." % [got1, got2]
		elif xp_after != xp_before + 5:
			problem = "Expected +5 Agronomy XP on collect, got +%d." % (xp_after - xp_before)
		elif gs.harvest_bin.size() != 1:
			problem = "Expected 1 gift entry in harvest_bin, got %d." % gs.harvest_bin.size()
	# Mix in a harvested in-spec crop and sell both to Lin.
	if problem == "":
		gs.seed_crop_id = "biscuit_reed"
		gs.plant_crop(CELL)
		var days: int = int(gs.crop("biscuit_reed").get("growth_days", 3))
		for i: int in days:
			GameClock.elapsed_days = floorf(GameClock.elapsed_days) + 1.0
			gs._grow_crops()
		gs.harvest_crop(CELL)
		var crop_price: int = int(gs.crop("biscuit_reed")["base_sell_credits"])
		var gift_price: int = int(gs.animal_group("dome_goat")["gift_price"])
		var credits_before: int = gs.credits
		var paid: int = gs.sell_harvest_to_lin(gs.local_player_id)
		if paid != crop_price + gift_price or gs.credits != credits_before + paid:
			problem = "Expected Lin to pay %d CR (crop %d + gift %d), paid %d." % [crop_price + gift_price, crop_price, gift_price, paid]
		elif int(gs.crops_sold_in_spec.get("biscuit_reed", 0)) != 1:
			problem = "In-spec crop must still count in crops_sold_in_spec."
		elif gs.crops_sold_in_spec.size() != 1:
			problem = "Gift entry must not be added to crops_sold_in_spec, got %s." % [gs.crops_sold_in_spec]
	_done(gs)
	return problem


func test_find_roll_deterministic_and_pays_once() -> String:
	var gs: GameStateScript = _make_state(777)
	var problem: String = ""
	# Deterministic check: same inputs always give same bool.
	var find_day: int = -1
	for d: int in range(1, 50):
		var r1: bool = GameStateScript.animal_find_roll(777, "dome_rabbit", d, 5)
		var r2: bool = GameStateScript.animal_find_roll(777, "dome_rabbit", d, 5)
		if r1 != r2:
			problem = "animal_find_roll was not deterministic on day %d." % d
			break
		if r1 and find_day < 0:
			find_day = d
	if problem == "" and find_day < 0:
		problem = "Expected at least one find day in 50 days at 1-in-5 odds."
	if problem == "":
		# At trust 3, no find even on find_day.
		gs.animal_groups["dome_rabbit"] = { "trust": 3, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }
		gs._step_animals_dawn(find_day)
		if gs.animal_find_pending("dome_rabbit"):
			problem = "Find must not spawn below trust 4."
	if problem == "":
		# At trust 4, find spawns on find_day and pays once.
		gs.animal_groups["dome_rabbit"] = { "trust": 4, "fed_today": true, "unfed_streak": 0, "gifts": 0, "find_pending": false }
		gs._step_animals_dawn(find_day)
		if not gs.animal_find_pending("dome_rabbit"):
			problem = "Expected find_pending at trust 4+ on deterministic find_day %d." % find_day
		else:
			var ore_before: int = gs.crystal_ore
			var first: Dictionary = gs.collect_animal_find("dome_rabbit", gs.local_player_id)
			var second: Dictionary = gs.collect_animal_find("dome_rabbit", gs.local_player_id)
			if not first.get("ok", false) or not second.is_empty():
				problem = "Find must pay once, got %s then %s." % [first, second]
			elif gs.crystal_ore != ore_before + 1:
				problem = "Expected +1 crystal_ore from find, got %d -> %d." % [ore_before, gs.crystal_ore]
	_done(gs)
	return problem


func test_guest_request_goes_through_host_and_syncs() -> String:
	var host: GameStateScript = _make_state(42)
	var guest_state: GameStateScript = _make_state(42)
	host.feed_bin["pod_pith"] = 2
	host.animal_groups["dome_hen"] = { "trust": 2, "fed_today": false, "unfed_streak": 0, "gifts": 2, "find_pending": false }

	var host_cmd: FarmCommandsScript = FarmCommandsScript.new()
	host_cmd.state = host
	var guest_cmd: FarmCommandsScript = FarmCommandsScript.new()
	guest_cmd.state = guest_state
	guest_cmd.guest = true
	var routed: Array[StringName] = []
	guest_cmd.remote = func(action: StringName, arguments: Array) -> Variant:
		routed.append(action)
		return host_cmd.execute("player_2", action, arguments)

	var problem: String = ""
	var feed_res: Variant = await guest_cmd.request(&"feed_animals", ["dome_hen"])
	var collect_res1: Variant = await guest_cmd.request(&"collect_animal_gifts", ["dome_hen"])
	var collect_res2: Variant = await guest_cmd.request(&"collect_animal_gifts", ["dome_hen"])

	if routed.size() != 3 or routed[0] != &"feed_animals" or routed[1] != &"collect_animal_gifts":
		problem = "Guest actions must route through host remote, got %s." % [routed]
	elif feed_res != "" or not host.animal_fed_today("dome_hen"):
		problem = "Host should have marked dome_hen fed, got %s." % [feed_res]
	elif int(collect_res1) != 2 or int(collect_res2) != 0:
		problem = "Host must prevent double collect from guest (got %s then %s)." % [collect_res1, collect_res2]
	elif host.skill_xp("agronomy", "player_2") != 5:
		problem = "Collecting guest should receive +5 Agronomy XP on host, got %d." % host.skill_xp("agronomy", "player_2")
	else:
		# Verify FarmSync propagates animal state and emits animals_changed on guest.
		var was_guest: bool = FarmCommands.guest
		FarmCommands.guest = false
		var bytes: PackedByteArray = FarmSync.capture(host)
		FarmCommands.guest = true
		var emitted: Array[bool] = [false]
		guest_state.animals_changed.connect(func() -> void: emitted[0] = true)
		var sync_err: String = FarmSync.update(bytes, guest_state)
		FarmCommands.guest = was_guest
		if sync_err != "":
			problem = "FarmSync.update failed: %s" % sync_err
		elif not emitted[0]:
			problem = "FarmSync.update should emit animals_changed on guest."
		elif not guest_state.animal_fed_today("dome_hen") or guest_state.animal_trust("dome_hen") != 2:
			problem = "Guest state did not sync animal trust/fed_today."

	guest_cmd.free()
	host_cmd.free()
	guest_state.free()
	_done(host)
	return problem


func test_save_round_trip_and_old_save_compatibility() -> String:
	var gs: GameStateScript = _make_state(99)
	gs.feed_bin["husk_flakes"] = 3
	gs.animal_groups["dome_hen"] = { "trust": 3, "fed_today": true, "unfed_streak": 0, "gifts": 2, "find_pending": false }
	var saved: Dictionary = gs.farm_to_dict()

	var loaded: GameStateScript = _make_state(1)
	var err: String = loaded.farm_from_dict(saved)
	var problem: String = ""
	if err != "":
		problem = "Save round-trip failed: %s" % err
	elif int(loaded.feed_bin.get("husk_flakes", 0)) != 3:
		problem = "feed_bin did not round-trip: %s" % [loaded.feed_bin]
	elif loaded.animal_trust("dome_hen") != 3 or not loaded.animal_fed_today("dome_hen") or loaded.animal_gifts_waiting("dome_hen") != 2:
		problem = "animal_groups did not round-trip: %s" % [loaded.animal_groups]

	# Old save without feed_bin or animal_groups loads with clean defaults.
	if problem == "":
		var old_save: Dictionary = saved.duplicate(true)
		old_save.erase("feed_bin")
		old_save.erase("animal_groups")
		var old_loaded: GameStateScript = _make_state(1)
		var old_err: String = old_loaded.farm_from_dict(old_save)
		if old_err != "":
			problem = "Old save without animal fields failed to load: %s" % old_err
		elif old_loaded.feed_bin_total() != 0 or old_loaded.animal_trust("dome_hen") != 0:
			problem = "Old save should default feed_bin and animal_groups to empty/0."
		old_loaded.free()

	loaded.free()
	_done(gs)
	return problem
