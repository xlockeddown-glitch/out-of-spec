extends "res://tests/coop_net.gd"
## The terraform test pod in the Ice Caves hub and Kestrel's story quest "The Test Pod"
## (docs/design/zones.md, Ice Caves step 15; docs/decisions.md, 2026-11-28, feat/test-pod):
## host-run open_test_pod, once a day for the farm, the Rime Carapace Spinner through
## catch_species, the one-time credit fallback, the empty line, daily pruning, save, old saves,
## co-op sync, the quest (done by the pod or by a Kestrel purchase) and what stays unchanged.

const HOST: String = "player_1"
const GUEST: String = "player_2"
const SPINNER: String = "rime_carapace_spinner"
const QUEST: String = "test_pod"
const FM3: String = "field_meter_dc"
const HM3: String = "multi_source_calibrator"


## A farm with the host in the Ice Caves, on a day of its own. Frees it and puts the clock back.
func _in_the_caves(body: Callable, place: String = IceDepth.ZONE) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = 5.2
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(707070)
	gs.local_player_id = HOST
	gs.player_places[HOST] = [place, 0]
	var out: Variant = body.call(gs)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	GameClock.elapsed_days = held
	return problem


func _count(gs: GameStateScript, who: String, key: String) -> int:
	return gs.action_count(key, who)


func _quest() -> Dictionary:
	for quest: Dictionary in QuestEngine.quests():
		if str(quest.get("id", "")) == QUEST:
			return quest
	return {}


func test_opening_gives_the_spinner_once_with_its_origin() -> String:
	return _in_the_caves(func(gs: GameStateScript) -> String:
		if gs.test_pod_opened_today():
			return "The pod starts shut."
		var reply: String = gs.open_test_pod(HOST)
		if reply != "" or not gs.test_pod_opened_today() or not gs.is_caught(SPINNER):
			return "First opening must give the Spinner through catch_species: '%s'" % reply
		if gs.enclosure_origins.get(SPINNER, "") != GameStateScript.TEST_POD_ORIGIN:
			return "Origin must be test_pod: %s" % [gs.enclosure_origins]
		if not gs.enclosure_text(SPINNER).ends_with(GameStateScript.TEST_POD_LINE):
			return "The enclosure line must say it came from the pod: '%s'" % gs.enclosure_text(SPINNER)
		if _count(gs, HOST, GameStateScript.TEST_POD_COUNT) != 1:
			return "Opening must count once."
		var err: String = gs.farm_dict_problem(gs.farm_to_dict())
		if err != "":
			return "A farm holding the Spinner from the pod must pass the save check: %s" % err
		return "")


func test_a_second_open_today_is_refused_and_changes_nothing_then_a_new_day_opens() -> String:
	return _in_the_caves(func(gs: GameStateScript) -> String:
		gs.open_test_pod(HOST)
		var enclosures: int = gs.enclosures.size()
		var credits: int = gs.credits
		var second: String = gs.open_test_pod(HOST)
		if second == "" or gs.enclosures.size() != enclosures or gs.credits != credits or _count(gs, HOST, GameStateScript.TEST_POD_COUNT) != 1:
			return "A second opening today must be refused and change nothing: '%s'" % second
		GameClock.elapsed_days += 1.0
		if gs.test_pod_opened_today():
			return "A new day must reset today's opening."
		gs.open_test_pod(HOST)
		if not gs.test_pod_opened_today() or _count(gs, HOST, GameStateScript.TEST_POD_COUNT) != 2:
			return "A new day's opening must work."
		return "")


func test_the_farm_shares_one_opening_a_day() -> String:
	return _in_the_caves(func(gs: GameStateScript) -> String:
		gs.player_places[GUEST] = [IceDepth.ZONE, 0]
		gs.open_test_pod(HOST)
		if gs.open_test_pod(GUEST) == "" or _count(gs, GUEST, GameStateScript.TEST_POD_COUNT) != 0:
			return "The pod opens once a day for the farm, not once per player."
		return "")


func test_it_refuses_outside_the_ice_caves_and_changes_nothing() -> String:
	var places: Array[String] = [ZonePresence.FARM, Shuttle.DEIMOS, Shuttle.PHOBOS]
	for place: String in places:
		var problem: String = _in_the_caves(func(gs: GameStateScript) -> String:
			var credits: int = gs.credits
			var why: String = gs.open_test_pod(HOST)
			if why == "" or gs.test_pod_opened_today() or not gs.enclosures.is_empty() or gs.credits != credits or _count(gs, HOST, GameStateScript.TEST_POD_COUNT) != 0:
				return "Must refuse in '%s' and change nothing: '%s'" % [place, why]
			return "", place)
		if problem != "":
			return problem
	return ""


func test_the_spinner_then_the_fallback_once_then_nothing() -> String:
	return _in_the_caves(func(gs: GameStateScript) -> String:
		gs.catch_species(SPINNER)
		var before: int = gs.credits
		var first: String = gs.open_test_pod(HOST)
		if first == "" or not first.contains("CR") or gs.credits != before + GameStateScript.TEST_POD_FALLBACK_CREDITS:
			return "The first opening with the Spinner held must pay %d CR: '%s'" % [GameStateScript.TEST_POD_FALLBACK_CREDITS, first]
		if not gs.test_pod_fallback_paid() or _count(gs, HOST, GameStateScript.TEST_POD_COUNT) != 1:
			return "The fallback must be marked paid and the opening counted."
		GameClock.elapsed_days += 1.0
		if gs.test_pod_opened_today() or not gs.test_pod_fallback_paid():
			return "A new day resets opened but keeps fallback_paid."
		var credits: int = gs.credits
		var second: String = gs.open_test_pod(HOST)
		if second != GameStateScript.TEST_POD_EMPTY_LINE or gs.credits != credits:
			return "Every later opening is the empty line and pays nothing: '%s'" % second
		if _count(gs, HOST, GameStateScript.TEST_POD_COUNT) != 2:
			return "The empty opening still counts."
		GameClock.elapsed_days += 1.0
		var saved: Dictionary = gs.farm_to_dict()
		if saved.get("test_pod", {}) != { "fallback_paid": true }:
			return "A later day saves fallback_paid only: %s" % [saved.get("test_pod")]
		return "")


func test_state_saves_prunes_loads_old_saves_and_rejects_bad_ones() -> String:
	return _in_the_caves(func(gs: GameStateScript) -> String:
		gs.open_test_pod(HOST)
		var saved: Dictionary = gs.farm_to_dict()
		if saved.get("test_pod", {}) != { "day": GameClock.get_day_index(), "opened": true }:
			return "Saved test_pod shape wrong: %s" % [saved.get("test_pod")]
		var loaded: GameStateScript = GameStateScript.new()
		loaded.build_registry()
		var problem: String = ""
		var err: String = loaded.farm_from_dict(saved)
		if err != "" or not loaded.test_pod_opened_today() or loaded.enclosure_origins != gs.enclosure_origins:
			problem = "Save and load must round-trip: '%s'" % err
		if problem == "":
			gs.test_pod = { "day": GameClock.get_day_index() - 1, "opened": true }
			if not (gs.farm_to_dict()["test_pod"] as Dictionary).is_empty():
				problem = "Yesterday's test_pod must be pruned on save."
			var stale: Dictionary = saved.duplicate(true)
			stale["test_pod"] = { "day": GameClock.get_day_index() - 1, "opened": true }
			if problem == "" and (loaded.farm_from_dict(stale) != "" or loaded.test_pod_opened_today()):
				problem = "Yesterday's test_pod must be pruned on load."
		if problem == "":
			loaded.test_pod = { "day": GameClock.get_day_index(), "opened": true, "fallback_paid": true }
			var old: Dictionary = saved.duplicate(true)
			old.erase("test_pod")
			old.erase("enclosure_origins")
			old["enclosures"] = {}
			if loaded.farm_from_dict(old) != "" or not loaded.test_pod.is_empty() or loaded.test_pod_opened_today() or loaded.test_pod_fallback_paid():
				problem = "An old save without test_pod must load and reset it."
		if problem == "":
			var bad: Dictionary = saved.duplicate(true)
			bad["test_pod"] = { "day": -1, "opened": true }
			if loaded.farm_dict_problem(bad) == "":
				problem = "A malformed test_pod must not load."
		loaded.free()
		return problem)


func test_state_syncs_to_a_guest_and_a_late_joiner() -> String:
	return _in_the_caves(func(gs: GameStateScript) -> String:
		gs.open_test_pod(HOST)
		var guest: GameStateScript = GameStateScript.new()
		guest.build_registry()
		var heard: Array[int] = [0]
		guest.test_pod_changed.connect(func() -> void: heard[0] += 1)
		var held_guest: bool = FarmCommands.guest
		FarmCommands.guest = true
		var upd: String = FarmSync.update(FarmSync.capture(gs), guest)
		FarmCommands.guest = held_guest
		var problem: String = ""
		if upd != "" or heard[0] < 1 or not guest.test_pod_opened_today():
			problem = "FarmSync must sync test_pod and emit test_pod_changed: '%s', heard=%d" % [upd, heard[0]]
		guest.free()
		if problem != "":
			return problem
		var late: GameStateScript = GameStateScript.new()
		late.build_registry()
		var load_err: String = late.farm_from_dict(gs.farm_to_dict())
		if load_err != "" or not late.test_pod_opened_today() or not late.is_caught(SPINNER):
			problem = "A late joiner must load the pod state: '%s'" % load_err
		late.free()
		return problem)


func test_registration_protocol_and_guest_loopback_cannot_spoof_a_player() -> String:
	if not &"open_test_pod" in FarmCommands.ACTIONS or not &"open_test_pod" in FarmCommands.BELOW_ONLY:
		return "open_test_pod must be in FarmCommands.ACTIONS and BELOW_ONLY."
	if &"open_test_pod" in FarmCommands.ON_A_MOON:
		return "open_test_pod must not be allowed on a moon."
	if FarmCommands.problem(&"open_test_pod", []) != "" or FarmCommands.problem(&"open_test_pod", ["player_1"]) == "":
		return "open_test_pod takes no client arguments: a guest cannot name another player."
	if CoopSession.PROTOCOL != 51:
		return "PROTOCOL must be 51, got %d." % CoopSession.PROTOCOL
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = 5.2
	var host: Node = _host()
	var farm: GameStateScript = host.commands.state
	farm.player_places[GUEST] = [IceDepth.ZONE, 0]
	var guest: Node = _guest(host)
	var problem: String = ""
	var spoof: Array = _request(guest, &"open_test_pod", ["player_1"])
	_until(func() -> bool: return not spoof.is_empty())
	if spoof == [""] or farm.test_pod_opened_today():
		problem = "A guest naming another player must be refused: %s" % [spoof]
	var got: Array = _request(guest, &"open_test_pod", [])
	_until(func() -> bool: return not got.is_empty())
	if problem == "" and (got != [""] or not farm.test_pod_opened_today() or not farm.is_caught(SPINNER)):
		problem = "Guest open_test_pod over loopback must succeed on the host: %s" % [got]
	elif problem == "" and (_count(farm, GUEST, GameStateScript.TEST_POD_COUNT) != 1 or _count(farm, HOST, GameStateScript.TEST_POD_COUNT) != 0):
		problem = "The opening must count for the guest who opened it, not the host."
	GameClock.elapsed_days = held
	return _finish(problem)


func test_the_quest_is_in_data_clean_and_offered_only_after_reaching_the_ice_caves() -> String:
	var found: Dictionary = _quest()
	if found.is_empty():
		return "test_pod is not in data/quests.json."
	if str(found.get("giver", "")) != "kestrel" or str(found.get("kind", "")) != "story" or str(found.get("zone", "")) != IceDepth.ZONE:
		return "The Test Pod must be Kestrel's story quest in the Ice Caves."
	if int((found.get("rewards", {}) as Dictionary).get("quest_points", 0)) != 1:
		return "The Test Pod pays 1 quest point."
	var data_err: String = QuestEngine.data_problem(found)
	if data_err != "":
		return "test_pod is not clean: %s" % data_err
	return _in_the_caves(func(gs: GameStateScript) -> String:
		var present: Array[String] = [HOST]
		QuestEngine.update(gs, present)
		if gs.quest_state.has(QUEST):
			return "Not offered before the farm has reached the Ice Caves."
		gs.action_counts[HOST] = { "reached_ice_caves": { "count": 1, "xp": 0 } }
		QuestEngine.update(gs, present)
		if not gs.quest_state.has(QUEST):
			return "Offered once the farm has reached the Ice Caves."
		if QuestEngine.is_done(gs, QUEST, HOST):
			return "Not done before the pod is opened."
		return "")


func test_the_pod_finishes_the_quest_and_it_pays_once() -> String:
	return _in_the_caves(func(gs: GameStateScript) -> String:
		var present: Array[String] = [HOST]
		gs.action_counts[HOST] = { "reached_ice_caves": { "count": 1, "xp": 0 } }
		QuestEngine.update(gs, present)
		gs.open_test_pod(HOST)
		QuestEngine.update(gs, present)
		if not QuestEngine.is_done(gs, QUEST, HOST) or QuestEngine.points_of(gs, HOST) != 1:
			return "Opening the pod must finish The Test Pod and pay 1 quest point: points=%d" % QuestEngine.points_of(gs, HOST)
		GameClock.elapsed_days += 1.0
		gs.open_test_pod(HOST)
		QuestEngine.update(gs, present)
		if QuestEngine.points_of(gs, HOST) != 1:
			return "The quest point is paid once."
		return "")


func test_a_kestrel_purchase_finishes_the_quest_without_the_zone_and_pays_once() -> String:
	return _in_the_caves(func(gs: GameStateScript) -> String:
		var present: Array[String] = [HOST]
		gs.lab_gates_kept = gs.all_lab_gate_ids()
		gs.credits = 100000
		gs.tier1_unlocked = true
		gs.crystal_ore = 100
		for id: String in gs.sensors:
			gs.get_sensor(id).max_error = INF
		gs.action_counts[HOST] = { "reached_ice_caves": { "count": 1, "xp": 0 } }
		QuestEngine.update(gs, present)
		gs.player_places[HOST] = [ZonePresence.FARM, 0]
		var flare_day: int = int(DataManager.get_number(&"sensor_drift_config", "flares/first_day", 0.0))
		var start_hour: float = DataManager.get_number(&"sensor_drift_config", "flares/start_hour", 0.0)
		GameClock.elapsed_days = GameClock.elapsed_at_hour(flare_day, start_hour + 1.0)
		if gs.buy_standard(FM3, HOST) != "":
			return "Could not buy the FM-3 to open the OIRM account."
		gs.oirm_calibrate(FM3, GameClock.get_day_index())
		gs.send_to_oirm(FM3)
		gs.at_oirm.clear()
		if not gs.kestrel_present():
			return "Kestrel must be here on the flare night."
		if gs.buy_from_kestrel(HM3, HOST) != "":
			return "The Kestrel purchase failed: " + gs.kestrel_purchase_problem(HM3)
		if _count(gs, HOST, GameStateScript.TEST_POD_KESTREL_COUNT) != 1 or gs.test_pod_opened_today():
			return "A purchase counts for the quest and does not open the pod."
		QuestEngine.update(gs, present)
		if not QuestEngine.is_done(gs, QUEST, HOST) or QuestEngine.points_of(gs, HOST) != 1:
			return "A Kestrel purchase must finish The Test Pod: points=%d" % QuestEngine.points_of(gs, HOST)
		QuestEngine.update(gs, present)
		if QuestEngine.points_of(gs, HOST) != 1:
			return "The quest point is paid once."
		return "")


func test_the_cache_the_strays_the_finds_and_the_cold_are_unchanged() -> String:
	return _in_the_caves(func(gs: GameStateScript) -> String:
		var before: Dictionary = {
			"deimos_cache": gs.deimos_cache.duplicate(true),
			"strays_caught": gs.strays_caught.duplicate(true),
			"finds_taken": gs.finds_taken.duplicate(true),
			"phobos_finds_taken": gs.phobos_finds_taken.duplicate(true),
			"cold_since": gs.cold_since.duplicate(true),
			"deimos_crates_opened": gs.deimos_crates_opened.duplicate(true),
		}
		gs.open_test_pod(HOST)
		for key: String in before:
			if gs.get(key) != before[key]:
				return "Opening the pod must not touch %s." % key
		gs.player_places[HOST] = [Shuttle.DEIMOS, 0]
		gs.action_counts[HOST] = { "reached_deimos": { "count": 1, "xp": 0 } }
		QuestEngine.update(gs, [HOST])
		if gs.open_cache(HOST) != "" or not gs.is_caught("low_g_titan_carapace") or gs.enclosure_origins.get("low_g_titan_carapace", "") != GameStateScript.CACHE_ORIGIN:
			return "The Deimos cache must work as before."
		if gs.enclosure_origins.get(SPINNER, "") != GameStateScript.TEST_POD_ORIGIN:
			return "The Spinner keeps its pod origin beside the cache stock."
		var bad: Dictionary = gs.farm_to_dict()
		(bad["enclosure_origins"] as Dictionary)[SPINNER] = GameStateScript.CACHE_ORIGIN
		if gs.farm_dict_problem(bad) == "":
			return "A pod species with the cache origin must not pass the save check."
		return "")


func test_the_pod_stands_in_the_ice_hub_with_a_line_and_a_look() -> String:
	var at: Vector3 = IceDepth.pod_position()
	if not IceDepth.near_pod(at) or IceDepth.near_pod(at + Vector3(ZoneDepth.REACH_M * 3.0, 0.0, 0.0)):
		return "near_pod must hold at the pod and not far from it."
	if IceDepth.POD_LINE == "":
		return "The pod needs a line."
	var parent := Node3D.new()
	var pod: Node3D = IceLook.add_test_pod(parent, at)
	var problem: String = ""
	if pod == null or pod.get_child_count() == 0:
		problem = "The pod must be built from primitives."
	parent.free()
	return problem


func test_a_pod_spinner_with_no_dome_tank_neither_molts_nor_gives_silk() -> String:
	return _in_the_caves(func(gs: GameStateScript) -> String:
		gs.open_test_pod(HOST)
		gs._tick_enclosures(500.0)
		if float(gs.enclosures[SPINNER]["molt_progress"]) != 0.0:
			return "The Spinner has no dome tank yet, so it must not molt."
		gs.enclosures[SPINNER] = { "molt_progress": 1.0, "molt_stage": int(GameStateScript.MoltStage.MOLTED), "exuvia_until_day": 0 }
		var spools: float = gs.optical_silk_spools
		gs.lab_sitter = LabSitter.new_booking(GameClock.get_day_index())
		gs._sitter_tend()
		if gs.is_enclosure_spool_ready(SPINNER) or gs.collect_enclosure_spool(SPINNER, HOST) or gs.optical_silk_spools != spools:
			return "Nothing may collect silk from a tank nobody can see."
		return "")


func test_it_refuses_below_the_hub_and_changes_nothing() -> String:
	return _in_the_caves(func(gs: GameStateScript) -> String:
		gs.player_places[HOST] = [IceDepth.ZONE, 1]
		var why: String = gs.open_test_pod(HOST)
		if why == "" or gs.test_pod_opened_today() or not gs.enclosures.is_empty() or _count(gs, HOST, GameStateScript.TEST_POD_COUNT) != 0:
			return "Depth 1 must not open the hub pod: '%s'" % why
		gs.player_places[HOST] = [IceDepth.ZONE, 0]
		if gs.open_test_pod(HOST) != "" or not gs.test_pod_opened_today():
			return "The hub must still open it."
		return "")


func test_a_kestrel_purchase_before_the_offer_leaves_the_quest_open() -> String:
	return _in_the_caves(func(gs: GameStateScript) -> String:
		var present: Array[String] = [HOST]
		gs.lab_gates_kept = gs.all_lab_gate_ids()
		gs.credits = 100000
		gs.tier1_unlocked = true
		gs.crystal_ore = 100
		for id: String in gs.sensors:
			gs.get_sensor(id).max_error = INF
		gs.player_places[HOST] = [ZonePresence.FARM, 0]
		var flare_day: int = int(DataManager.get_number(&"sensor_drift_config", "flares/first_day", 0.0))
		var start_hour: float = DataManager.get_number(&"sensor_drift_config", "flares/start_hour", 0.0)
		GameClock.elapsed_days = GameClock.elapsed_at_hour(flare_day, start_hour + 1.0)
		if gs.buy_standard(FM3, HOST) != "":
			return "Could not buy the FM-3 to open the OIRM account."
		gs.oirm_calibrate(FM3, GameClock.get_day_index())
		gs.send_to_oirm(FM3)
		gs.at_oirm.clear()
		if gs.buy_from_kestrel(HM3, HOST) != "":
			return "The Kestrel purchase failed: " + gs.kestrel_purchase_problem(HM3)
		gs.action_counts[HOST]["reached_ice_caves"] = { "count": 1, "xp": 0 }
		QuestEngine.update(gs, present)
		QuestEngine.update(gs, present)
		if not gs.quest_state.has(QUEST) or QuestEngine.is_done(gs, QUEST, HOST):
			return "A purchase made before the offer must not finish the quest (it counts from acceptance)."
		return "")
