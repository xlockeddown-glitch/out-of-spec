extends "res://tests/coop_net.gd"
## Deimos smuggler cache and Kestrel's personal quest "A Quiet Crate" (docs/design/zones.md
## §2, §5, §10.3): proof on quest accept, host-run open_cache, deterministic Deimos species
## pick through catch_species with deimos_cache origin, all-held credit fallback, wrong-label
## days, daily pruning, save/load/old-save compatibility, co-op sync and DeimosHub look.

const HOST: String = "player_1"
const GUEST: String = "player_2"
const LOW_G: String = "low_g_titan_carapace"
const BRASS: String = "brass_glint_reticle"


## A farm with the host on Deimos, on a day of its own. Frees it and puts the clock back.
func _on_deimos(body: Callable, with_proof: bool = true) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = 5.2
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(707070)
	gs.local_player_id = HOST
	gs.player_places[HOST] = [Shuttle.DEIMOS, 0]
	if with_proof:
		gs.action_counts[HOST] = { "reached_deimos": { "count": 1, "xp": 0 } }
		QuestEngine.update(gs, [HOST])
	var out: Variant = body.call(gs)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	GameClock.elapsed_days = held
	return problem


func _count(gs: GameStateScript, who: String, key: String) -> int:
	return gs.action_count(key, who)


func test_the_quest_is_in_data_clean_and_offered_only_after_reaching_deimos() -> String:
	var found: Dictionary = {}
	for quest: Dictionary in QuestEngine.quests():
		if str(quest.get("id", "")) == GameStateScript.CACHE_QUEST:
			found = quest
			break
	if found.is_empty():
		return "a_quiet_crate is not in data/quests.json."
	if str(found.get("giver", "")) != "kestrel" or str(found.get("kind", "")) != "personal" \
			or str(found.get("scope", "")) != "player" or str(found.get("zone", "")) != Shuttle.DEIMOS:
		return "a_quiet_crate must be Kestrel's personal Deimos quest with player scope."
	var data_err: String = QuestEngine.data_problem(found)
	if data_err != "":
		return "a_quiet_crate is not clean: %s" % data_err
	return _on_deimos(func(gs: GameStateScript) -> String:
		var present: Array[String] = [HOST, GUEST]
		QuestEngine.update(gs, present)
		if (gs.player_quest_state.get(HOST, {}) as Dictionary).has(GameStateScript.CACHE_QUEST):
			return "Not offered before a player has reached Deimos."
		if gs.has_kestrel_proof(HOST):
			return "No proof before the quest is accepted."
		gs.action_counts[HOST] = { "reached_deimos": { "count": 1, "xp": 0 } }
		QuestEngine.update(gs, present)
		if not (gs.player_quest_state.get(HOST, {}) as Dictionary).has(GameStateScript.CACHE_QUEST):
			return "Offered to host once they have reached Deimos."
		if (gs.player_quest_state.get(GUEST, {}) as Dictionary).has(GameStateScript.CACHE_QUEST):
			return "Not offered to a guest who has not reached Deimos."
		if not gs.has_kestrel_proof(HOST) or gs.has_kestrel_proof(GUEST):
			return "Accepting grants proof only to the player who accepted it."
		return "", false)


func test_no_proof_is_refused_and_changes_nothing() -> String:
	return _on_deimos(func(gs: GameStateScript) -> String:
		var credits_before: int = gs.credits
		var why: String = gs.open_cache(HOST)
		if why != GameStateScript.DEIMOS_CACHE_LOCKED_LINE:
			return "Expected locked refusal without proof, got: '%s'" % why
		if gs.deimos_cache_opened_today() or not gs.enclosures.is_empty() or gs.credits != credits_before or _count(gs, HOST, GameStateScript.CACHE_COUNT) != 0:
			return "A refusal without proof must change nothing."
		return "", false)


func test_not_on_deimos_is_refused_and_changes_nothing() -> String:
	return _on_deimos(func(gs: GameStateScript) -> String:
		gs.player_places[HOST] = [ZonePresence.FARM, 0]
		var farm_why: String = gs.open_cache(HOST)
		gs.player_places[HOST] = [Shuttle.PHOBOS, 0]
		var phobos_why: String = gs.open_cache(HOST)
		if farm_why == "" or phobos_why == "":
			return "Must refuse when not on Deimos: '%s' '%s'" % [farm_why, phobos_why]
		if gs.deimos_cache_opened_today() or not gs.enclosures.is_empty() or _count(gs, HOST, GameStateScript.CACHE_COUNT) != 0:
			return "Refusal off Deimos must change nothing."
		return "")


func test_with_proof_on_deimos_opens_once_a_day_and_refuses_second_try() -> String:
	return _on_deimos(func(gs: GameStateScript) -> String:
		var first: String = gs.open_cache(HOST)
		if first != "" or not gs.deimos_cache_opened_today():
			return "First opening with proof must succeed: '%s'" % first
		if _count(gs, HOST, GameStateScript.CACHE_COUNT) != 1:
			return "Opening must increment open_cache once."
		var enclosures_after_first: int = gs.enclosures.size()
		var credits_after_first: int = gs.credits
		var second: String = gs.open_cache(HOST)
		if second == "" or gs.enclosures.size() != enclosures_after_first or gs.credits != credits_after_first or _count(gs, HOST, GameStateScript.CACHE_COUNT) != 1:
			return "Second opening the same day must be refused and change nothing: '%s'" % second
		GameClock.elapsed_days += 1.0
		if gs.deimos_cache_opened_today():
			return "A new day must reset today's cache state."
		var next_day: String = gs.open_cache(HOST)
		if next_day != "" or not gs.deimos_cache_opened_today() or _count(gs, HOST, GameStateScript.CACHE_COUNT) != 2:
			return "A new day's cache must open again: '%s'" % next_day
		return "")


func test_species_pick_is_deterministic_prefers_low_g_and_uses_catch_species_with_origin() -> String:
	return _on_deimos(func(gs: GameStateScript) -> String:
		var pick_a: String = GameStateScript.pick_deimos_cache_species(707070, {})
		var pick_b: String = GameStateScript.pick_deimos_cache_species(707070, {})
		if pick_a != pick_b or pick_a != LOW_G:
			return "Deterministic pick with none held must prefer low_g Deimos stock: '%s' vs '%s'" % [pick_a, pick_b]
		var reply: String = gs.open_cache(HOST)
		if reply != "" or not gs.is_caught(LOW_G):
			return "First opening must catch %s through catch_species: '%s'" % [LOW_G, reply]
		if gs.enclosure_origins.get(LOW_G, "") != GameStateScript.CACHE_ORIGIN:
			return "Origin must be deimos_cache: %s" % [gs.enclosure_origins]
		var line: String = gs.enclosure_text(LOW_G)
		if not line.ends_with(GameStateScript.CACHE_LINE):
			return "Enclosure line must say smuggled stock: '%s'" % line
		gs._tick_enclosures(500.0)
		if float(gs.enclosures[LOW_G]["molt_progress"]) != 0.0:
			return "A Deimos species with no dome tank yet must not molt."
		var second_pick: String = GameStateScript.pick_deimos_cache_species(707070, gs.enclosures)
		if second_pick != BRASS:
			return "Next unheld Deimos species must be %s, got '%s'" % [BRASS, second_pick]
		GameClock.elapsed_days += 1.0
		var second_open: String = gs.open_cache(HOST)
		if second_open != "" or not gs.is_caught(BRASS) or gs.enclosure_origins.get(BRASS, "") != GameStateScript.CACHE_ORIGIN:
			return "Second day's opening must catch %s with deimos_cache origin: '%s'" % [BRASS, second_open]
		return "")


func test_every_id_the_picker_returns_passes_the_save_check() -> String:
	return _on_deimos(func(gs: GameStateScript) -> String:
		var held: Dictionary = {}
		var picked: Array[String] = []
		while true:
			var id: String = GameStateScript.pick_deimos_cache_species(707070, held)
			if id == "":
				break
			if id in picked:
				return "Picker repeated '%s'." % id
			picked.append(id)
			held[id] = true
			if not gs.catch_species(id):
				return "Picker returned uncatchable id '%s'." % id
			gs.enclosure_origins[id] = GameStateScript.CACHE_ORIGIN
			var err: String = gs.farm_dict_problem(gs.farm_to_dict())
			if err != "":
				return "Picker id '%s' failed save check: %s" % [id, err]
		if picked.size() != GameStateScript.DEIMOS_CACHE_SPECIES.size():
			return "Expected %d picked ids, got %d." % [GameStateScript.DEIMOS_CACHE_SPECIES.size(), picked.size()]
		return "")


func test_all_held_fallback_pays_credits_once_then_empty_and_still_counts() -> String:
	return _on_deimos(func(gs: GameStateScript) -> String:
		gs.catch_species(LOW_G)
		gs.catch_species(BRASS)
		var credits_before: int = gs.credits
		var reply: String = gs.open_cache(HOST)
		if reply == "" or not reply.contains("CR"):
			return "First all-held fallback must return a credit reply: '%s'" % reply
		if gs.credits != credits_before + GameStateScript.DEIMOS_CACHE_FALLBACK_CREDITS:
			return "First all-held fallback must pay %d CR, got %d." % [GameStateScript.DEIMOS_CACHE_FALLBACK_CREDITS, gs.credits - credits_before]
		if not gs.deimos_cache_opened_today() or not gs.deimos_cache_fallback_paid() or _count(gs, HOST, GameStateScript.CACHE_COUNT) != 1:
			return "First all-held fallback must mark opened, mark fallback_paid, and count open_cache."
		# Next day: second all-held opening pays nothing, gives the empty line, and still counts.
		GameClock.elapsed_days += 1.0
		if gs.deimos_cache_opened_today() or not gs.deimos_cache_fallback_paid():
			return "New day must reset opened state while keeping fallback_paid."
		var credits_after_first: int = gs.credits
		var second_reply: String = gs.open_cache(HOST)
		if second_reply != GameStateScript.DEIMOS_CACHE_EMPTY_LINE:
			return "Second all-held opening must return empty-crate line, got: '%s'" % second_reply
		if gs.credits != credits_after_first:
			return "Second all-held opening must pay nothing, got %d CR." % (gs.credits - credits_after_first)
		if not gs.deimos_cache_opened_today() or _count(gs, HOST, GameStateScript.CACHE_COUNT) != 2:
			return "Second all-held opening must still mark opened and count open_cache."
		# Save/load on a new day retains fallback_paid while pruning day/opened.
		GameClock.elapsed_days += 1.0
		var saved: Dictionary = gs.farm_to_dict()
		if saved.get("deimos_cache", {}) != { "fallback_paid": true }:
			return "Saved deimos_cache on a later day must keep fallback_paid only: %s" % [saved.get("deimos_cache")]
		var loaded: GameStateScript = GameStateScript.new()
		loaded.build_registry()
		var err: String = loaded.farm_from_dict(saved)
		var problem: String = ""
		if err != "" or loaded.deimos_cache_opened_today() or not loaded.deimos_cache_fallback_paid():
			problem = "Reloaded farm must keep fallback_paid and stay unopened today: '%s'" % err
		loaded.free()
		return problem)


func test_counter_finishes_quest_for_opener_only_and_pays_xp_once() -> String:
	return _on_deimos(func(gs: GameStateScript) -> String:
		var present: Array[String] = [HOST, GUEST]
		gs.action_counts[GUEST] = { "reached_deimos": { "count": 1, "xp": 0 } }
		QuestEngine.update(gs, present)
		if QuestEngine.is_done(gs, GameStateScript.CACHE_QUEST, HOST) or QuestEngine.is_done(gs, GameStateScript.CACHE_QUEST, GUEST):
			return "Neither player's quest is done before opening."
		var host_xp_before: int = gs.skill_xp("husbandry", HOST)
		var guest_xp_before: int = gs.skill_xp("husbandry", GUEST)
		if gs.open_cache(HOST) != "":
			return "Host open failed."
		QuestEngine.update(gs, present)
		if not QuestEngine.is_done(gs, GameStateScript.CACHE_QUEST, HOST):
			return "Opening must finish a_quiet_crate for the opener."
		if QuestEngine.is_done(gs, GameStateScript.CACHE_QUEST, GUEST):
			return "Opening must not finish a_quiet_crate for another player."
		var paid: int = gs.skill_xp("husbandry", HOST) - host_xp_before
		if paid != 150 or gs.skill_xp("husbandry", GUEST) != guest_xp_before:
			return "Expected 150 Husbandry XP for host only, got host=%d guest=%d." % [paid, gs.skill_xp("husbandry", GUEST) - guest_xp_before]
		GameClock.elapsed_days += 1.0
		gs.open_cache(HOST)
		QuestEngine.update(gs, present)
		if gs.skill_xp("husbandry", HOST) - host_xp_before != paid:
			return "Quest XP must be paid once."
		return "")


func test_opened_state_prunes_saves_loads_old_save_and_syncs_to_guest() -> String:
	return _on_deimos(func(gs: GameStateScript) -> String:
		gs.open_cache(HOST)
		var saved: Dictionary = gs.farm_to_dict()
		if saved.get("deimos_cache", {}) != { "day": GameClock.get_day_index(), "opened": true }:
			return "Saved deimos_cache shape wrong: %s" % [saved.get("deimos_cache")]
		var loaded: GameStateScript = GameStateScript.new()
		loaded.build_registry()
		var err: String = loaded.farm_from_dict(saved)
		var problem: String = ""
		if err != "" or not loaded.deimos_cache_opened_today() or loaded.enclosure_origins != gs.enclosure_origins:
			problem = "Save/load round-trip failed: '%s', opened=%s" % [err, loaded.deimos_cache_opened_today()]
		# Yesterday's entry is pruned on save and on load.
		if problem == "":
			gs.deimos_cache = { "day": GameClock.get_day_index() - 1, "opened": true }
			if not (gs.farm_to_dict()["deimos_cache"] as Dictionary).is_empty():
				problem = "Yesterday's deimos_cache must be pruned on save."
			else:
				var stale: Dictionary = saved.duplicate(true)
				stale["deimos_cache"] = { "day": GameClock.get_day_index() - 1, "opened": true }
				if loaded.farm_from_dict(stale) != "" or loaded.deimos_cache_opened_today():
					problem = "Yesterday's deimos_cache must be pruned on load."
		# Old save without deimos_cache resets a non-empty deimos_cache cleanly.
		if problem == "":
			loaded.deimos_cache = { "day": GameClock.get_day_index(), "opened": true, "fallback_paid": true }
			var old: Dictionary = saved.duplicate(true)
			old.erase("deimos_cache")
			old.erase("enclosure_origins")
			old["enclosures"] = {}
			if loaded.farm_from_dict(old) != "" or not loaded.deimos_cache.is_empty() or loaded.deimos_cache_opened_today() or loaded.deimos_cache_fallback_paid():
				problem = "Old save without deimos_cache must reset deimos_cache cleanly."
		# Malformed deimos_cache is rejected.
		if problem == "":
			var bad: Dictionary = saved.duplicate(true)
			bad["deimos_cache"] = { "day": -1, "opened": true }
			if loaded.farm_dict_problem(bad) == "":
				problem = "Malformed deimos_cache must not load."
		# FarmSync sends deimos_cache to a guest and emits deimos_cache_changed.
		if problem == "":
			gs.deimos_cache = { "day": GameClock.get_day_index(), "opened": true }
			var guest: GameStateScript = GameStateScript.new()
			guest.build_registry()
			var heard: Array[int] = [0]
			guest.deimos_cache_changed.connect(func() -> void: heard[0] += 1)
			FarmCommands.guest = true
			var upd: String = FarmSync.update(FarmSync.capture(gs), guest)
			FarmCommands.guest = false
			if upd != "" or heard[0] < 1 or not guest.deimos_cache_opened_today():
				problem = "FarmSync must sync deimos_cache and emit deimos_cache_changed: '%s', heard=%d" % [upd, heard[0]]
			guest.free()
		loaded.free()
		return problem)


func test_wrong_label_day_is_deterministic_and_still_opens() -> String:
	return _on_deimos(func(gs: GameStateScript) -> String:
		var saw_true: int = -1
		var saw_false: int = -1
		for d: int in range(1, 30):
			var a: bool = GameStateScript.deimos_cache_wrong_label(707070, d)
			var b: bool = GameStateScript.deimos_cache_wrong_label(707070, d)
			if a != b:
				return "Wrong-label hash must be deterministic for day %d." % d
			if a and saw_true < 0:
				saw_true = d
			if not a and saw_false < 0:
				saw_false = d
		if saw_true < 0 or saw_false < 0:
			return "Expected both wrong-label and normal-label days across 1..29."
		GameClock.elapsed_days = float(saw_true - 1) + 0.2
		if not gs.is_deimos_cache_mislabeled():
			return "Day %d should be mislabeled." % saw_true
		var why: String = gs.open_cache(HOST)
		if why != "" or not gs.deimos_cache_opened_today():
			return "Opening must still work on a wrong-label day: '%s'" % why
		return "")


func test_command_registration_protocol_and_guest_loopback() -> String:
	if not &"open_cache" in FarmCommands.ACTIONS or not &"open_cache" in FarmCommands.ON_A_MOON:
		return "open_cache must be in FarmCommands.ACTIONS and ON_A_MOON."
	if FarmCommands.problem(&"open_cache", []) != "" or FarmCommands.problem(&"open_cache", ["player_1"]) == "":
		return "open_cache takes no client arguments."
	if CoopSession.PROTOCOL != 53:
		return "PROTOCOL must be 53, got %d." % CoopSession.PROTOCOL
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = 5.2
	var host: Node = _host()
	var farm: GameStateScript = host.commands.state
	farm.player_places[GUEST] = [Shuttle.DEIMOS, 0]
	farm.action_counts[GUEST] = { "reached_deimos": { "count": 1, "xp": 0 } }
	QuestEngine.update(farm, [GUEST])
	var guest: Node = _guest(host)
	var problem: String = ""
	var got: Array = _request(guest, &"open_cache", [])
	_until(func() -> bool: return not got.is_empty())
	if got != [""] or not farm.deimos_cache_opened_today() or not farm.is_caught(LOW_G):
		problem = "Guest open_cache over loopback must succeed on host: %s" % [got]
	elif _count(farm, GUEST, GameStateScript.CACHE_COUNT) != 1:
		problem = "open_cache must count for the guest who opened it."
	else:
		QuestEngine.update(farm, [HOST, GUEST], false)
		if not QuestEngine.is_done(farm, GameStateScript.CACHE_QUEST, GUEST):
			problem = "Opening via loopback must finish a_quiet_crate for the guest."
	GameClock.elapsed_days = held
	return _finish(problem)


func _world_aabb(node: MeshInstance3D) -> AABB:
	return node.global_transform * node.mesh.get_aabb()


func test_deimos_hub_switches_between_shut_and_opened_look() -> String:
	var held_cache: Dictionary = GameState.deimos_cache.duplicate(true)
	var held_clock: float = GameClock.elapsed_days
	GameClock.elapsed_days = 5.2
	GameState.deimos_cache = {}
	var hub: DeimosHub = (load(SceneSwitcher.DEIMOS_SCENE) as PackedScene).instantiate() as DeimosHub
	(Engine.get_main_loop() as SceneTree).root.add_child(hub)
	var problem: String = ""
	var padlock: Node3D = hub.get_node_or_null("CachePadlock") as Node3D
	var opened_group: Node3D = hub.get_node_or_null("CacheOpened") as Node3D
	var trim: Node3D = hub.get_node_or_null("CacheTrim") as Node3D
	var trim_lock: Node3D = null
	if trim != null:
		for child: Node in trim.get_children():
			var part: Node3D = child as Node3D
			if part != null and part.position.z > 0.4:
				trim_lock = part
	if padlock == null or opened_group == null or trim_lock == null:
		problem = "DeimosHub must build CachePadlock, CacheOpened, and CacheTrim's lock block."
	elif not padlock.visible or not trim_lock.visible or opened_group.visible:
		problem = "Shut cache must show padlock and trim lock and hide CacheOpened."
	else:
		GameState.deimos_cache = { "day": GameClock.get_day_index(), "opened": true }
		GameState.deimos_cache_changed.emit()
		if padlock.visible or trim_lock.visible or not opened_group.visible:
			problem = "Opened cache must hide padlock and trim lock and show CacheOpened."
		else:
			var crate_a: MeshInstance3D = hub.get_node_or_null("CrateA") as MeshInstance3D
			var lid_open: MeshInstance3D = opened_group.get_node_or_null("CacheLidOpen") as MeshInstance3D
			if crate_a == null or lid_open == null:
				problem = "DeimosHub must have CrateA and CacheLidOpen."
			else:
				var a_box: AABB = _world_aabb(crate_a)
				var lid_box: AABB = _world_aabb(lid_open)
				if lid_box.position.y < a_box.end.y or lid_box.intersects(a_box):
					problem = "Open lid must sit above CrateA's top without overlapping it: lid=%s crate=%s" % [lid_box, a_box]
				for other_name: String in ["CrateB", "CrateC"]:
					var other: MeshInstance3D = hub.get_node_or_null(other_name) as MeshInstance3D
					if other == null:
						problem = "DeimosHub must have %s." % other_name
						break
					var o_box: AABB = _world_aabb(other)
					var xz_overlap: bool = o_box.position.x < a_box.end.x and o_box.end.x > a_box.position.x and o_box.position.z < a_box.end.z and o_box.end.z > a_box.position.z
					if o_box.intersects(a_box) or (xz_overlap and o_box.position.y >= a_box.end.y - 0.05):
						problem = "%s must not sit on or overlap opened CrateA: other=%s crate=%s" % [other_name, o_box, a_box]
						break
	(Engine.get_main_loop() as SceneTree).root.remove_child(hub)
	hub.free()
	GameState.deimos_cache = held_cache
	GameClock.elapsed_days = held_clock
	return problem
