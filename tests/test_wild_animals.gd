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
	# Gifts accumulate at dawn up to gift_cap_days (3 days' worth) and are not wiped when trust drops below 2.
	if problem == "":
		gs.feed_animals("dome_goat")
		_advance_dawn(gs) # trust 3, gifts 2
		gs.feed_animals("dome_goat")
		_advance_dawn(gs) # trust 4, gifts 3 (capped at 1 * 3)
		gs.feed_animals("dome_goat")
		_advance_dawn(gs) # trust 5, gifts still capped at 3
		if gs.animal_gifts_waiting("dome_goat") != 3:
			problem = "Expected gifts to stack and cap at 3 days' worth (3), got %d." % gs.animal_gifts_waiting("dome_goat")
	if problem == "":
		# Drop trust below 2 (unfed) -> waiting gifts must remain intact, no new gifts added.
		gs.animal_groups["dome_goat"]["trust"] = 2
		gs.animal_groups["dome_goat"]["unfed_streak"] = 2
		gs.animal_groups["dome_goat"]["gifts"] = 2
		_advance_dawn(gs) # trust drops to 1
		if gs.animal_trust("dome_goat") != 1 or gs.animal_gifts_waiting("dome_goat") != 2:
			problem = "Trust dropping below 2 must keep waiting gifts (2), got trust %d and gifts %d." % [gs.animal_trust("dome_goat"), gs.animal_gifts_waiting("dome_goat")]
		else:
			_advance_dawn(gs) # trust stays 1, no new gifts added
			if gs.animal_gifts_waiting("dome_goat") != 2:
				problem = "Trust below 2 must not add new gifts, got %d." % gs.animal_gifts_waiting("dome_goat")
	# Collect moves waiting gifts to harvest_bin, awards Agronomy XP, and prevents double collect.
	if problem == "":
		var xp_before: int = gs.skill_xp("agronomy", gs.local_player_id)
		var got1: int = gs.collect_animal_gifts("dome_goat", gs.local_player_id)
		var got2: int = gs.collect_animal_gifts("dome_goat", gs.local_player_id)
		var xp_after: int = gs.skill_xp("agronomy", gs.local_player_id)
		if got1 != 2 or got2 != 0:
			problem = "Expected collect 2 then 0 (no double collect), got %d and %d." % [got1, got2]
		elif xp_after != xp_before + 5:
			problem = "Expected +5 Agronomy XP on collect, got +%d." % (xp_after - xp_before)
		elif gs.harvest_bin.size() != 2:
			problem = "Expected 2 gift entries in harvest_bin, got %d." % gs.harvest_bin.size()
	# Mix in a harvested in-spec crop and sell both to Lin.
	if problem == "":
		gs.seed_crop_id = "biscuit_reed"
		gs.plant_crop(CELL)
		var days: int = int(gs.crop("biscuit_reed").get("growth_days", 3))
		for i: int in days:
			GameClock.elapsed_days = floorf(GameClock.elapsed_days) + 1.0
			gs._grow_crops()
		var crop_entry: Dictionary = gs.harvest_crop(CELL)
		var crop_price: int = gs.lin_pays(crop_entry, gs.local_player_id)
		var gift_price: int = int(gs.animal_group("dome_goat")["gift_price"]) * 2
		var credits_before: int = gs.credits
		var lin_lines: Array[String] = []
		gs.phone_message.connect(func(line: String) -> void: lin_lines.append(line))
		var paid: int = gs.sell_harvest_to_lin(gs.local_player_id)
		if paid != crop_price + gift_price or gs.credits != credits_before + paid:
			problem = "Expected Lin to pay %d CR (crop %d + gifts %d), paid %d." % [crop_price + gift_price, crop_price, gift_price, paid]
		elif int(gs.crops_sold_in_spec.get("biscuit_reed", 0)) != 1:
			problem = "In-spec crop must still count in crops_sold_in_spec."
		elif gs.crops_sold_in_spec.size() != 1:
			problem = "Gift entry must not be added to crops_sold_in_spec, got %s." % [gs.crops_sold_in_spec]
		elif lin_lines.any(func(line: String) -> bool: return "off spec" in line.to_lower()):
			problem = "Gift entries must not count as off spec in Lin's line: %s" % [lin_lines]
	_done(gs)
	return problem


func test_find_roll_deterministic_and_pays_once() -> String:
	var gs: GameStateScript = _make_state(777)
	var problem: String = ""
	var seed_value: int = gs.world_seed
	var find_denom: int = maxi(1, int(gs.animal_trust_rule("find_chance_denom", 5.0)))
	# Fixed expected roll for a known seed and day (checks real determinism).
	if not GameStateScript.animal_find_roll(777, "dome_rabbit", 6, 5) or GameStateScript.animal_find_roll(777, "dome_rabbit", 1, 5):
		problem = "Fixed expected roll for seed 777, dome_rabbit (day 6 true, day 1 false) did not match."
	var find_day: int = -1
	var non_find_day: int = -1
	for d: int in range(1, 50):
		var r1: bool = GameStateScript.animal_find_roll(seed_value, "dome_rabbit", d, find_denom)
		var r2: bool = GameStateScript.animal_find_roll(seed_value, "dome_rabbit", d, find_denom)
		if r1 != r2:
			problem = "animal_find_roll was not deterministic on day %d." % d
			break
		if r1 and find_day < 0:
			find_day = d
		if not r1 and non_find_day < 0:
			non_find_day = d
	if problem == "" and (find_day < 0 or non_find_day < 0):
		problem = "Expected both a find day and a non-find day in 50 days at 1-in-%d odds." % find_denom
	if problem == "":
		# Trust 3 unfed -> stays 3 -> cannot find even on find_day.
		gs.animal_groups["dome_rabbit"] = { "trust": 3, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }
		gs._step_animals_dawn(find_day)
		if gs.animal_trust("dome_rabbit") != 3 or gs.animal_find_pending("dome_rabbit"):
			problem = "Trust 3 unfed must stay 3 and not spawn a find."
	if problem == "":
		# Trust 3 fed -> becomes 4 at dawn -> can find on find_day.
		gs.animal_groups["dome_rabbit"] = { "trust": 3, "fed_today": true, "unfed_streak": 0, "gifts": 0, "find_pending": false }
		gs._step_animals_dawn(find_day)
		if gs.animal_trust("dome_rabbit") != 4 or not gs.animal_find_pending("dome_rabbit"):
			problem = "Trust 3 fed must become 4 and spawn a find on day %d." % find_day
	if problem == "":
		# Trust 4 unfed (streak 0) -> stays 4 at dawn -> can find on find_day.
		gs.animal_groups["dome_rabbit"] = { "trust": 4, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }
		gs._step_animals_dawn(find_day)
		if gs.animal_trust("dome_rabbit") != 4 or not gs.animal_find_pending("dome_rabbit"):
			problem = "Trust 4 unfed must stay 4 and spawn a find on day %d." % find_day
	if problem == "":
		# Pending find waits until collected, regardless of later rolls or trust dropping below 4.
		gs.animal_groups["dome_rabbit"]["unfed_streak"] = 2
		gs._step_animals_dawn(non_find_day) # trust drops to 3, non-find day
		if gs.animal_trust("dome_rabbit") != 3 or not gs.animal_find_pending("dome_rabbit"):
			problem = "Pending find must stay true until collected even if trust drops and a non-find day passes."
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


func test_unknown_find_kind_rejected_and_pays_nothing() -> String:
	var problem: String = ""
	if DataManager.animal_find_kind_problem("crystal_ore") != "" or DataManager.animal_find_kind_problem("credits") != "":
		return "Known find kinds must be accepted by DataManager.animal_find_kind_problem."
	if DataManager.animal_find_kind_problem("mystery_gem") == "":
		return "Unknown find kind must be reported by DataManager.animal_find_kind_problem."
	var gs: GameStateScript = _make_state(777)
	var raw_animals: Dictionary = DataManager.get_raw(&"animals") as Dictionary
	var find_reward: Dictionary = raw_animals["find_reward"] as Dictionary
	var orig_kind: Variant = find_reward["kind"]
	find_reward["kind"] = "mystery_gem"
	gs.animal_groups["dome_rabbit"] = { "trust": 4, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": true }
	var ore_before: int = gs.crystal_ore
	var credits_before: int = gs.credits
	var res: Dictionary = gs.collect_animal_find("dome_rabbit", gs.local_player_id)
	find_reward["kind"] = orig_kind
	if not res.is_empty() or gs.crystal_ore != ore_before or gs.credits != credits_before:
		problem = "Unknown find kind must pay nothing and return {}, got %s (ore %d->%d, cr %d->%d)." % [
			res, ore_before, gs.crystal_ore, credits_before, gs.credits]
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
	gs.animal_groups["dome_goat"] = { "trust": 2, "fed_today": false, "unfed_streak": 0, "gifts": 1, "find_pending": false }
	gs.collect_animal_gifts("dome_goat", gs.local_player_id)
	var saved: Dictionary = gs.farm_to_dict()

	var loaded: GameStateScript = _make_state(1)
	var dict_err: String = loaded.farm_dict_problem(saved)
	var err: String = loaded.farm_from_dict(saved)
	var problem: String = ""
	if dict_err != "":
		problem = "farm_dict_problem rejected valid save with gift in harvest_bin: %s" % dict_err
	elif err != "":
		problem = "Save round-trip failed: %s" % err
	elif int(loaded.feed_bin.get("husk_flakes", 0)) != 3:
		problem = "feed_bin did not round-trip: %s" % [loaded.feed_bin]
	elif loaded.animal_trust("dome_hen") != 3 or not loaded.animal_fed_today("dome_hen") or loaded.animal_gifts_waiting("dome_hen") != 2:
		problem = "animal_groups did not round-trip: %s" % [loaded.animal_groups]
	else:
		var expected_gift_price: int = int(loaded.animal_group("dome_goat")["gift_price"])
		var paid: int = loaded.sell_harvest_to_lin(loaded.local_player_id)
		if paid != expected_gift_price:
			problem = "Round-tripped gift in harvest_bin should sell for %d CR, paid %d." % [expected_gift_price, paid]

	# Old save without feed_bin or animal_groups resets non-zero animal state to clean defaults.
	if problem == "":
		var old_save: Dictionary = saved.duplicate(true)
		old_save.erase("feed_bin")
		old_save.erase("animal_groups")
		old_save["harvest_bin"] = []
		# `loaded` already has non-zero feed_bin, trust, fed_today and gifts for dome_hen.
		var old_err: String = loaded.farm_from_dict(old_save)
		if old_err != "":
			problem = "Old save without animal fields failed to load: %s" % old_err
		elif loaded.feed_bin_total() != 0 or loaded.animal_trust("dome_hen") != 0 or loaded.animal_fed_today("dome_hen") or loaded.animal_gifts_waiting("dome_hen") != 0:
			problem = "Old save must reset feed_bin, trust, fed_today and gifts to 0/false."

	loaded.free()
	_done(gs)
	return problem


func test_tool_roll_shows_gifts_in_harvest_bin() -> String:
	var saved_bin: Array[Dictionary] = GameState.harvest_bin.duplicate(true)
	GameState.harvest_bin = [
		{ "gift_id": "hen_egg", "group_id": "dome_hen", "gift_price": 12 },
		{ "gift_id": "hen_egg", "group_id": "dome_hen", "gift_price": 12 },
		{ "gift_id": "goat_cashmere", "group_id": "dome_goat", "gift_price": 30 },
		{ "gift_id": "rabbit_fur", "group_id": "dome_rabbit", "gift_price": 40 },
	]
	var items: Array[Dictionary] = ToolRollUI.slots(ToolRollUI.TAB_CROPS)
	GameState.harvest_bin = saved_bin
	var by_id: Dictionary = {}
	for item: Dictionary in items:
		by_id[item["id"]] = item
	if not by_id.has("gift:hen_egg") or by_id["gift:hen_egg"]["name"] != "Eggs" or by_id["gift:hen_egg"]["count"] != "2":
		return "Expected Eggs slot with count 2, got %s." % [by_id.get("gift:hen_egg", {})]
	if not by_id.has("gift:goat_cashmere") or by_id["gift:goat_cashmere"]["name"] != "Goat cashmere" or by_id["gift:goat_cashmere"]["count"] != "1":
		return "Expected Goat cashmere slot with count 1, got %s." % [by_id.get("gift:goat_cashmere", {})]
	if not by_id.has("gift:rabbit_fur") or by_id["gift:rabbit_fur"]["name"] != "Rabbit fur" or by_id["gift:rabbit_fur"]["count"] != "1":
		return "Expected Rabbit fur slot with count 1, got %s." % [by_id.get("gift:rabbit_fur", {})]
	return ""


func test_wild_animal_prompts_and_verbs() -> String:
	var saved_groups: Dictionary = GameState.animal_groups.duplicate(true)
	var wa := WildAnimals.new()
	wa._build_groups()
	var hen_spot: Vector3 = wa._groups["dome_hen"]["spot_pos"]
	var hen_find: Vector3 = wa._groups["dome_hen"]["find_pos"]
	var problem: String = ""

	# Unfed, no gifts -> Leave feed.
	GameState.animal_groups["dome_hen"] = { "trust": 0, "fed_today": false, "unfed_streak": 0, "gifts": 0, "find_pending": false }
	var t_feed: Dictionary = wa.interact_target(hen_spot)
	if t_feed.get("kind", "") != "feed" or t_feed.get("verb", "") != WildAnimals.VERB_FEED:
		problem = "Expected feed prompt when unfed, got %s." % [t_feed]

	# Already fed today, no gifts or find -> no prompt.
	if problem == "":
		GameState.animal_groups["dome_hen"]["fed_today"] = true
		var t_none: Dictionary = wa.interact_target(hen_spot)
		if not t_none.is_empty():
			problem = "Expected no prompt when already fed today and nothing waiting, got %s." % [t_none]

	# Gifts waiting -> Collect eggs (even if already fed today).
	if problem == "":
		GameState.animal_groups["dome_hen"]["gifts"] = 2
		var t_gift: Dictionary = wa.interact_target(hen_spot)
		if t_gift.get("kind", "") != "collect" or t_gift.get("verb", "") != "Collect eggs":
			problem = "Expected 'Collect eggs' when gifts waiting, got %s." % [t_gift]

	# Find pending -> Pick up find (distinct verb from gift collection).
	if problem == "":
		GameState.animal_groups["dome_hen"]["gifts"] = 0
		GameState.animal_groups["dome_hen"]["find_pending"] = true
		var t_find: Dictionary = wa.interact_target(hen_find)
		if t_find.get("kind", "") != "find" or t_find.get("verb", "") != WildAnimals.VERB_FIND:
			problem = "Expected '%s' when find pending, got %s." % [WildAnimals.VERB_FIND, t_find]

	wa.free()
	GameState.animal_groups = saved_groups
	return problem
