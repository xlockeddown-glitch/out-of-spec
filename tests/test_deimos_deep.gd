extends "res://tests/coop_net.gd"
## Deimos deep stores, depth 1 under the Deimos hub (docs/design/zones.md section 13,
## slice 24): deterministic daily store-room grid from integer hash, reachability, reseed
## at 06:00, hatch clearance, host-run crates (unlocked, locked with Kestrel's proof,
## mislabelled paying less and revealed only once opened), dust penalty and wipe stop,
## co-op guest path and sync, save/load, and isolation from other zones/hubs.

const HOST: String = "player_1"
const GUEST: String = "player_2"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _open(scene_path: String) -> Node:
	var node: Node = (load(scene_path) as PackedScene).instantiate()
	_root().add_child(node)
	return node


func _drop(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _on_deimos(body: Callable) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = 6.25
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(818181)
	gs.local_player_id = HOST
	gs.player_places[HOST] = [Shuttle.DEIMOS, 0]
	var out: Variant = body.call(gs)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	GameClock.elapsed_days = held
	return problem


func _grant_proof(gs: GameStateScript, who: String) -> void:
	var counts: Dictionary = gs.action_counts.get_or_add(who, {}) as Dictionary
	counts["reached_deimos"] = { "count": 1, "xp": 0 }
	QuestEngine.update(gs, [who])


func _find_crate(crates: Array, want_locked: bool, want_mislabeled: int = -1) -> Dictionary:
	for entry: Variant in crates:
		if not entry is Dictionary:
			continue
		var c: Dictionary = entry as Dictionary
		if bool(c.get("locked", false)) != want_locked:
			continue
		if want_mislabeled >= 0 and bool(c.get("mislabeled", false)) != (want_mislabeled == 1):
			continue
		return c
	return {}


func test_layout_is_deterministic_reachable_reseeds_and_hatch_is_clear() -> String:
	var a: Dictionary = DeimosDepth.layout(515151, 5)
	var b: Dictionary = DeimosDepth.layout(515151, 5)
	if a["grid"] != b["grid"] or a["crates"] != b["crates"]:
		return "Same seed and day must produce the exact same layout and crates."

	var changed_days: int = 0
	var mislabeled_days: int = 0
	var normal_days: int = 0
	for seed_val: int in [101, 515151, 999999]:
		var prev_sig: String = ""
		for day: int in range(1, 16):
			var data: Dictionary = DeimosDepth.layout(seed_val, day)
			var grid: PackedStringArray = data["grid"]
			var crates: Array = data["crates"]
			if crates.size() < DeimosDepth.MIN_CRATES or crates.size() > DeimosDepth.MAX_CRATES:
				return "Seed %d day %d produced %d crates (expected %d..%d)." % [seed_val, day, crates.size(), DeimosDepth.MIN_CRATES, DeimosDepth.MAX_CRATES]
			var reached: Array[Vector2i] = ZoneDepth.reachable(grid, DeimosDepth.START_CELL)
			if not DeimosDepth.HATCH_CELL in reached or not DeimosDepth.WIPE_CELL in reached:
				return "Hatch or wipe stop unreachable on seed %d day %d." % [seed_val, day]
			var floor_count: int = 0
			for y: int in grid.size():
				for x: int in grid[y].length():
					if grid[y][x] == ".":
						floor_count += 1
			if reached.size() != floor_count:
				return "Seed %d day %d has unreachable floor cells (%d reached of %d)." % [seed_val, day, reached.size(), floor_count]
			var locked_n: int = 0
			var unlocked_n: int = 0
			var wrong_n: int = 0
			for crate: Dictionary in crates:
				var cell: Vector2i = crate["cell"]
				if not cell in reached:
					return "Crate %s at %s unreachable on seed %d day %d." % [crate["id"], cell, seed_val, day]
				if cell in [DeimosDepth.START_CELL, DeimosDepth.HATCH_CELL, DeimosDepth.WIPE_CELL]:
					return "Crate %s overlaps fixed cell %s." % [crate["id"], cell]
				if bool(crate["locked"]):
					locked_n += 1
				else:
					unlocked_n += 1
				if bool(crate["mislabeled"]):
					wrong_n += 1
			if locked_n < 1 or unlocked_n < 1:
				return "Seed %d day %d must have at least one locked and one unlocked crate." % [seed_val, day]
			if wrong_n > 1:
				return "Seed %d day %d has %d mislabelled crates (max 1)." % [seed_val, day, wrong_n]
			if wrong_n == 1:
				mislabeled_days += 1
			else:
				normal_days += 1
			var sig: String = "|".join(grid) + "::" + str(crates)
			if prev_sig != "" and sig != prev_sig:
				changed_days += 1
			prev_sig = sig
	if changed_days < 35:
		return "Layouts did not reseed across days often enough (%d changes)." % changed_days
	if mislabeled_days == 0 or normal_days == 0:
		return "Expected both mislabelled and normal days across 45 layouts (%d / %d)." % [mislabeled_days, normal_days]

	# Hatch in DeimosHub must be clear of camp, cache, pod, console, board, and shuttle pad.
	var hatch: Vector3 = DeimosHub.DEEP_HATCH_AT
	var forbidden: Dictionary = {
		"Camp": Camp.position(Shuttle.DEIMOS),
		"Cache": DeimosHub.DEIMOS_SPOTS["Cache"],
		"Pod": DeimosHub.DEIMOS_SPOTS["Pod"],
		"Console": DeimosHub.DEIMOS_SPOTS["Console"],
		"Board": DeimosHub.DEIMOS_SPOTS["Board"],
		"ShuttlePad": Vector3(-14.0, 0.0, 1.0),
		"Arrive": DeimosHub.ARRIVE_AT,
	}
	for label: String in forbidden:
		var spot: Vector3 = forbidden[label]
		var dist: float = Vector2(hatch.x - spot.x, hatch.z - spot.z).length()
		if dist < 5.0:
			return "DeimosHub DEEP_HATCH_AT is too close to %s (%.2f m)." % [label, dist]
	return ""


func test_crate_pays_once_locked_needs_proof_and_mislabelled_pays_less() -> String:
	return _on_deimos(func(gs: GameStateScript) -> String:
		# Find a day for this seed that has a mislabelled unlocked crate and a locked crate.
		var chosen_day: int = -1
		var unlocked_crate: Dictionary = {}
		var locked_crate: Dictionary = {}
		var wrong_crate: Dictionary = {}
		for d: int in range(1, 40):
			var data: Dictionary = DeimosDepth.layout(gs.world_seed, d)
			var crates: Array = data["crates"]
			var u: Dictionary = _find_crate(crates, false, 0)
			var l: Dictionary = _find_crate(crates, true, -1)
			var w: Dictionary = {}
			for c: Dictionary in crates:
				if bool(c["mislabeled"]) and str(c["id"]) != str(u.get("id", "")):
					w = c
					break
			if not u.is_empty() and not l.is_empty() and not w.is_empty():
				chosen_day = d
				unlocked_crate = u
				locked_crate = l
				wrong_crate = w
				break
		if chosen_day < 0:
			return "Could not find a day with normal unlocked, locked, and mislabelled crates."
		GameClock.elapsed_days = float(chosen_day - 1) + 0.25

		var u_id: String = str(unlocked_crate["id"])
		var l_id: String = str(locked_crate["id"])
		var w_id: String = str(wrong_crate["id"])
		var before_cr: int = gs.credits

		# Refused from the hub before entering Deep stores.
		if gs.wipe_deimos_dust() == "" or gs.open_deimos_crate(u_id, chosen_day) == "":
			return "wipe_deimos_dust and open_deimos_crate must be refused before enter_deimos_deep."
		if gs.credits != before_cr:
			return "Refused hub open must pay nothing."

		# Enter Deep stores and wipe dust to verify clean payouts.
		if gs.enter_deimos_deep() != "" or gs.wipe_deimos_dust() != "":
			return "enter_deimos_deep and wipe_deimos_dust must succeed on Deimos."

		# Normal unlocked crate pays once and refuses a second open.
		var u_pay: int = DeimosDepth.reward_credits(str(unlocked_crate["kind"]), false, false, false)
		var err: String = gs.open_deimos_crate(u_id, chosen_day)
		if err != "" or gs.credits != before_cr + u_pay:
			return "Unlocked crate must pay +%d credits, err='%s' got=+%d." % [u_pay, err, gs.credits - before_cr]
		if not u_id in gs.deimos_crates_opened_today():
			return "Opened crate id must be recorded today."
		if gs.open_deimos_crate(u_id, chosen_day) == "" or gs.credits != before_cr + u_pay:
			return "Second open of same crate must be refused and pay nothing."

		# Stale layout day and unknown id are refused.
		if gs.open_deimos_crate(l_id, chosen_day - 1) == "" or gs.open_deimos_crate("d1_c99", chosen_day) == "":
			return "Stale day and unknown crate id must be refused."

		# Locked crate refuses without Kestrel's proof and opens with it.
		var cr_before_lock: int = gs.credits
		var no_proof: String = gs.open_deimos_crate(l_id, chosen_day)
		if no_proof != DeimosDepth.LOCKED_REFUSAL_TEXT or gs.credits != cr_before_lock:
			return "Locked crate without proof must be refused cleanly: '%s'" % no_proof
		_grant_proof(gs, HOST)
		var l_pay: int = DeimosDepth.reward_credits(
			str(locked_crate["kind"]),
			true,
			bool(locked_crate["mislabeled"]),
			false
		)
		var with_proof: String = gs.open_deimos_crate(l_id, chosen_day)
		if with_proof != "" or gs.credits != cr_before_lock + l_pay:
			return "Locked crate with Kestrel's proof must open and pay +%d: err='%s' got=+%d." % [l_pay, with_proof, gs.credits - cr_before_lock]

		# Mislabelled crate pays strictly less than its labelled value.
		var normal_label_pay: int = DeimosDepth.reward_credits(str(wrong_crate["kind"]), bool(wrong_crate["locked"]), false, false)
		var wrong_pay: int = DeimosDepth.reward_credits(str(wrong_crate["kind"]), bool(wrong_crate["locked"]), true, false)
		if wrong_pay >= normal_label_pay:
			return "Mislabelled crate must pay less than its label (%d vs %d)." % [wrong_pay, normal_label_pay]
		if w_id != l_id:
			var cr_before_wrong: int = gs.credits
			var w_err: String = gs.open_deimos_crate(w_id, chosen_day)
			if w_err != "" or gs.credits != cr_before_wrong + wrong_pay:
				return "Mislabelled crate must pay +%d, err='%s' got=+%d." % [wrong_pay, w_err, gs.credits - cr_before_wrong]

		# Leaving deck or leaving Deimos refuses opens and wipes.
		if gs.leave_deimos_deep() != "":
			return "leave_deimos_deep must succeed."
		if gs.open_deimos_crate(u_id, chosen_day) == "" or gs.wipe_deimos_dust() == "":
			return "open_deimos_crate and wipe_deimos_dust must be refused after leave_deimos_deep."
		gs.enter_deimos_deep()
		gs.player_places[HOST] = [ZonePresence.FARM, 0]
		var from_farm: String = gs.open_deimos_crate(u_id, chosen_day)
		gs.player_places[HOST] = [Shuttle.PHOBOS, 0]
		var from_phobos: String = gs.open_deimos_crate(u_id, chosen_day)
		if from_farm == "" or from_phobos == "":
			return "Opening off Deimos must be refused: '%s' / '%s'" % [from_farm, from_phobos]
		return "")


func test_dust_cuts_pay_and_deck_and_wipe_flags_clear_on_drop_day_start_and_trip_end() -> String:
	return _on_deimos(func(gs: GameStateScript) -> String:
		var day: int = GameClock.get_day_index()
		var data: Dictionary = DeimosDepth.layout(gs.world_seed, day)
		var crates: Array = data["crates"]
		_grant_proof(gs, HOST)
		var c0: Dictionary = crates[0]
		var c1: Dictionary = crates[1]

		if gs.enter_deimos_deep() != "" or not gs.is_deimos_dusty():
			return "Entering Deep stores must start dusty."
		var full0: int = DeimosDepth.reward_credits(str(c0["kind"]), bool(c0["locked"]), bool(c0["mislabeled"]), false)
		var cut0: int = DeimosDepth.reward_credits(str(c0["kind"]), bool(c0["locked"]), bool(c0["mislabeled"]), true)
		if cut0 >= full0 or cut0 != DeimosDepth.apply_dust(full0, true):
			return "Deimos dust must cut pay by %d %% (%d -> %d)." % [DeimosDepth.DUST_CUT_PCT, full0, cut0]

		var cr0: int = gs.credits
		if gs.open_deimos_crate(str(c0["id"]), day) != "" or gs.credits != cr0 + cut0:
			return "Dusty open must pay reduced credits."
		if gs.wipe_deimos_dust() != "" or gs.is_deimos_dusty():
			return "Wipe stop must clear Deimos dust."
		var cr1: int = gs.credits
		var full1: int = DeimosDepth.reward_credits(str(c1["kind"]), bool(c1["locked"]), bool(c1["mislabeled"]), false)
		if gs.open_deimos_crate(str(c1["id"]), day) != "" or gs.credits != cr1 + full1:
			return "Wiped open must pay full credits."

		# forget_place clears _deimos_wiped and _on_deimos_deck for that player only.
		gs.player_places[GUEST] = [Shuttle.DEIMOS, 0]
		gs.enter_deimos_deep(GUEST)
		gs.wipe_deimos_dust(GUEST)
		gs.forget_place(GUEST)
		if not gs.is_deimos_dusty(GUEST) or gs._on_deimos_deck.has(GUEST):
			return "forget_place must clear _deimos_wiped and _on_deimos_deck for the dropped player."
		if gs.is_deimos_dusty(HOST) or not bool(gs._on_deimos_deck.get(HOST, false)):
			return "forget_place(GUEST) must not clear HOST's Deimos deck or wipe state."

		# _on_day_started clears both flags for everyone.
		gs._on_day_started(day + 1)
		if not gs.is_deimos_dusty(HOST) or not gs._on_deimos_deck.is_empty():
			return "_on_day_started must clear _deimos_wiped and _on_deimos_deck."
		if gs.wipe_deimos_dust() == "":
			return "After _on_day_started, wipe_deimos_dust must be refused until re-entering."

		# Ending a Deimos trip via shuttle_home clears both flags.
		var held_walkers: Dictionary = CoopWalkers.out.duplicate(true)
		gs.shuttle_trips[HOST] = { "moon": Shuttle.DEIMOS, "ends_at": 1.0e9 }
		gs.player_places[HOST] = [Shuttle.DEIMOS, 0]
		gs.enter_deimos_deep(HOST)
		gs.wipe_deimos_dust(HOST)
		var home_err: String = gs.shuttle_home(HOST)
		CoopWalkers.out = held_walkers
		if home_err != "":
			return "shuttle_home must succeed for a player on Deimos."
		if gs._on_deimos_deck.has(HOST) or not gs.is_deimos_dusty(HOST):
			return "Ending the Deimos trip must clear _on_deimos_deck and _deimos_wiped."
		return "")


func test_guest_crate_and_wipe_go_through_host_cannot_spoof_and_sync_to_late_joiner() -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = 6.25
	var host: Node = _host()
	var farm: GameStateScript = host.commands.state
	farm.player_places[HOST] = [Shuttle.DEIMOS, 0]
	farm.enter_deimos_deep(HOST)
	farm.player_places[GUEST] = [ZonePresence.FARM, 0]
	var guest: Node = _guest(host)
	var day: int = GameClock.get_day_index()
	var data: Dictionary = DeimosDepth.layout(farm.world_seed, day)
	var unlocked: Dictionary = _find_crate(data["crates"], false, -1)
	var locked: Dictionary = _find_crate(data["crates"], true, -1)
	var u_id: String = str(unlocked["id"])
	var l_id: String = str(locked["id"])
	var problem: String = ""

	# Guest off Deimos is refused and cannot spoof HOST's player_id.
	var off_enter: Array = _request(guest, &"enter_deimos_deep", [])
	_until(func() -> bool: return not off_enter.is_empty())
	var off_open: Array = _request(guest, &"open_deimos_crate", [u_id, day])
	_until(func() -> bool: return not off_open.is_empty())
	var spoof_enter: Array = _request(guest, &"enter_deimos_deep", [HOST])
	_until(func() -> bool: return not spoof_enter.is_empty())
	var spoof_wipe: Array = _request(guest, &"wipe_deimos_dust", [HOST])
	_until(func() -> bool: return not spoof_wipe.is_empty())
	var spoof_open: Array = _request(guest, &"open_deimos_crate", [u_id, day, HOST])
	_until(func() -> bool: return not spoof_open.is_empty())
	var spoof_leave: Array = _request(guest, &"leave_deimos_deep", [HOST])
	_until(func() -> bool: return not spoof_leave.is_empty())
	if off_enter == [""] or off_open == [""] or spoof_enter == [""] or spoof_wipe == [""] or spoof_open == [""] or spoof_leave == [""]:
		problem = "Off-Deimos or spoofed guest commands must be refused."
	elif not farm.is_deimos_dusty(HOST) or not bool(farm._on_deimos_deck.get(HOST, false)):
		problem = "Guest spoof attempts must not alter HOST's Deimos deck or dust state."

	# Put guest on Deimos: refused before enter_deimos_deep, then enters and opens unlocked crate while dusty.
	if problem == "":
		farm.player_places[GUEST] = [Shuttle.DEIMOS, 0]
		var hub_open: Array = _request(guest, &"open_deimos_crate", [u_id, day])
		_until(func() -> bool: return not hub_open.is_empty())
		if hub_open == [""]:
			problem = "Guest open from hub before enter_deimos_deep must be refused."
	if problem == "":
		var entered: Array = _request(guest, &"enter_deimos_deep", [])
		_until(func() -> bool: return not entered.is_empty())
		if entered != [""] or not bool(farm._on_deimos_deck.get(GUEST, false)):
			problem = "Host must record guest enter_deimos_deep: %s" % [entered]
	if problem == "":
		var before_cr: int = farm.credits
		var dusty_pay: int = DeimosDepth.reward_credits(str(unlocked["kind"]), false, bool(unlocked["mislabeled"]), true)
		var got: Array = _request(guest, &"open_deimos_crate", [u_id, day])
		_until(func() -> bool: return not got.is_empty())
		if got != [""] or farm.credits != before_cr + dusty_pay or not u_id in farm.deimos_crates_opened_today():
			problem = "Host must process guest dusty crate open: reply=%s cr=%d" % [got, farm.credits - before_cr]
		elif not guest.commands.state.deimos_crates_opened_today().is_empty():
			problem = "Guest state must not mutate locally before host sync."

	# Locked crate refused for guest without proof, then opens after wipe + proof.
	if problem == "":
		var locked_ref: Array = _request(guest, &"open_deimos_crate", [l_id, day])
		_until(func() -> bool: return not locked_ref.is_empty())
		if locked_ref != [DeimosDepth.LOCKED_REFUSAL_TEXT]:
			problem = "Guest without proof must be refused locked crate: %s" % [locked_ref]
	if problem == "":
		_grant_proof(farm, GUEST)
		var wiped: Array = _request(guest, &"wipe_deimos_dust", [])
		_until(func() -> bool: return not wiped.is_empty())
		if wiped != [""] or farm.is_deimos_dusty(GUEST) or not farm.is_deimos_dusty(HOST):
			problem = "Guest wipe must clear only GUEST's dust, not HOST's."
	if problem == "":
		var cr_mid: int = farm.credits
		var full_pay: int = DeimosDepth.reward_credits(str(locked["kind"]), true, bool(locked["mislabeled"]), false)
		var got2: Array = _request(guest, &"open_deimos_crate", [l_id, day])
		_until(func() -> bool: return not got2.is_empty())
		if got2 != [""] or farm.credits != cr_mid + full_pay:
			problem = "Host must open locked crate for guest with proof: reply=%s cr=%d" % [got2, farm.credits - cr_mid]

	# Sync to guest and late joiner.
	if problem == "":
		var heard: Array[int] = [0]
		guest.commands.state.deimos_crates_changed.connect(func() -> void: heard[0] += 1)
		FarmCommands.guest = true
		var sync_err: String = FarmSync.update(FarmSync.capture(farm), guest.commands.state)
		FarmCommands.guest = false
		if sync_err != "" or heard[0] < 1 or guest.commands.state.deimos_crates_opened_today() != farm.deimos_crates_opened_today():
			problem = "Sync must deliver opened crates to guest: '%s', heard=%d" % [sync_err, heard[0]]
		var late: GameStateScript = GameStateScript.new()
		late.build_registry()
		var load_err: String = late.farm_from_dict(farm.farm_to_dict())
		if load_err != "" or late.deimos_crates_opened_today() != farm.deimos_crates_opened_today():
			problem = "Late joiner must receive opened crates: '%s'" % load_err
		late.free()

	GameClock.elapsed_days = held
	return _finish(problem)


func test_scene_leaving_never_blocked_wrong_label_hidden_until_opened_and_hub_hatch() -> String:
	var held_clock: float = GameClock.elapsed_days
	var held_trips: Dictionary = GameState.shuttle_trips.duplicate(true)
	var held_places: Dictionary = GameState.player_places.duplicate(true)
	var held_opened: Dictionary = GameState.deimos_crates_opened.duplicate(true)
	var held_wiped: Dictionary = GameState._deimos_wiped.duplicate(true)
	var held_deck: Dictionary = GameState._on_deimos_deck.duplicate(true)
	var held_quests: Dictionary = GameState.player_quest_state.duplicate(true)
	var held_actions: Dictionary = GameState.action_counts.duplicate(true)
	var held_walkers: Dictionary = CoopWalkers.out.duplicate(true)
	var held_credits: int = GameState.credits

	# Pick a day that has a mislabelled crate for GameState.world_seed.
	var test_day: int = 6
	for d: int in range(1, 30):
		var layout: Dictionary = DeimosDepth.layout(GameState.world_seed, d)
		for c: Dictionary in layout["crates"]:
			if bool(c["mislabeled"]):
				test_day = d
				break
		if test_day == d:
			break
	GameClock.elapsed_days = float(test_day - 1) + 0.25
	GameState.shuttle_trips[GameState.local_player_id] = { "moon": Shuttle.DEIMOS, "ends_at": 1.0e9 }
	GameState.player_places[GameState.local_player_id] = [Shuttle.DEIMOS, 0]
	CoopWalkers.out.erase(GameState.local_player_id)
	GameState.deimos_crates_opened = {}
	GameState._deimos_wiped = {}
	GameState._on_deimos_deck = {}
	var counts: Dictionary = GameState.action_counts.get_or_add(GameState.local_player_id, {}) as Dictionary
	counts["reached_deimos"] = { "count": 1, "xp": 0 }
	QuestEngine.update(GameState, [GameState.local_player_id])

	var deep: DeimosDeep = _open(DeimosDeep.SCENE_PATH) as DeimosDeep
	var problem: String = ""
	if not deep.dusty or not "Dusty" in deep._hint.text:
		problem = "Entering Deep stores must start dusty and log 'Dusty' on HUD, got '%s'." % deep._hint.text
	elif not bool(GameState._on_deimos_deck.get(GameState.local_player_id, false)):
		problem = "Opening Deep stores must mark player on deck (deck=%s, place=%s, guest=%s)." % [GameState._on_deimos_deck, GameState.place_of(GameState.local_player_id), FarmCommands.guest]
	elif deep.walker.moon != Shuttle.DEIMOS:
		problem = "DeimosDeep walker must use Deimos gravity."

	# Hover hints must never reveal a wrong label before opening.
	if problem == "":
		for i: int in deep.crate_clicks.size():
			if "Wrong" in deep.crate_clicks[i].hint or "scrap" in deep.crate_clicks[i].hint:
				problem = "Crate hint must not reveal mislabelled status before opening: '%s'" % deep.crate_clicks[i].hint
				break

	# Leaving while dusty must NEVER be blocked and clears _on_deimos_deck.
	if problem == "":
		var seen: Array[String] = []
		deep.change_scene = func(path: String) -> void: seen.append(path)
		deep.walker.position = DeimosDepth.cell_to_world(DeimosDepth.HATCH_CELL)
		deep._on_hatch_up()
		if seen != [SceneSwitcher.DEIMOS_SCENE]:
			problem = "Leaving up the hatch while dusty must not be blocked: %s" % [seen]
		elif not DeimosHub.arrive_at_deep_hatch:
			problem = "Leaving up the hatch must set DeimosHub.arrive_at_deep_hatch."
		elif GameState._on_deimos_deck.has(GameState.local_player_id):
			problem = "Leaving up the hatch must clear _on_deimos_deck."
	_drop(deep)

	# Re-enter, wipe dust, and open the mislabelled crate -> toast reveals "Wrong label".
	if problem == "":
		DeimosHub.arrive_at_deep_hatch = false
		var deep2: DeimosDeep = _open(DeimosDeep.SCENE_PATH) as DeimosDeep
		deep2.walker.position = DeimosDepth.cell_to_world(DeimosDepth.WIPE_CELL)
		await deep2._on_wipe_stop()
		if deep2.dusty or not "Dusty" in deep2._hint.text:
			problem = "Wiping dust must clear dusty flag and log wipe line, got '%s'." % deep2._hint.text
		if problem == "":
			var wrong_i: int = -1
			for i: int in deep2.crate_mislabeled.size():
				if deep2.crate_mislabeled[i]:
					wrong_i = i
					break
			if wrong_i >= 0:
				var at: Vector3 = deep2.crate_nodes[wrong_i].position
				deep2.walker.position = at
				await deep2._on_crate_clicked(at, deep2.crate_ids[wrong_i], deep2.crate_kinds[wrong_i], deep2.crate_locked[wrong_i], true, test_day)
				if not "Wrong label" in deep2._hint.text:
					problem = "Opening a mislabelled crate must reveal 'Wrong label', got '%s'." % deep2._hint.text
		_drop(deep2)

	# DeimosHub hatch leads down to Deep stores, and arrive_at_deep_hatch positions the walker beside it.
	if problem == "":
		DeimosHub.arrive_at_deep_hatch = true
		var hub: DeimosHub = _open(SceneSwitcher.DEIMOS_SCENE) as DeimosHub
		if hub.walker.position != DeimosHub.DEEP_HATCH_AT + DeimosHub.DEEP_HATCH_ARRIVE_OFFSET:
			problem = "DeimosHub must place walker beside deep hatch on return, got %s." % hub.walker.position
		var seen2: Array[String] = []
		hub.change_scene = func(path: String) -> void: seen2.append(path)
		hub.walker.position = DeimosHub.DEEP_HATCH_AT
		hub._on_deep_hatch()
		if seen2 != [DeimosDeep.SCENE_PATH]:
			problem = "DeimosHub deep hatch must open Deep stores, got %s." % [seen2]
		_drop(hub)

	DeimosHub.arrive_at_deep_hatch = false
	GameState.credits = held_credits
	CoopWalkers.out = held_walkers
	GameState.action_counts = held_actions
	GameState.player_quest_state = held_quests
	GameState._on_deimos_deck = held_deck
	GameState._deimos_wiped = held_wiped
	GameState.deimos_crates_opened = held_opened
	GameState.player_places = held_places
	GameState.shuttle_trips = held_trips
	GameClock.elapsed_days = held_clock
	return problem


func test_old_saves_load_and_other_zones_and_deimos_hub_features_unchanged() -> String:
	return _on_deimos(func(gs: GameStateScript) -> String:
		var day: int = GameClock.get_day_index()
		var data: Dictionary = DeimosDepth.layout(gs.world_seed, day)
		var unlocked: Dictionary = _find_crate(data["crates"], false, -1)
		var cid: String = str(unlocked["id"])
		gs.enter_deimos_deep()
		gs.open_deimos_crate(cid, day)

		# Save round-trip.
		var saved: Dictionary = gs.farm_to_dict()
		var other: GameStateScript = GameStateScript.new()
		other.build_registry()
		var why: String = other.farm_from_dict(saved)
		var problem: String = ""
		if why != "" or other.deimos_crates_opened_today() != [cid]:
			problem = "Save must round-trip deimos_crates_opened: '%s' %s" % [why, other.deimos_crates_opened_today()]

		# Old save without deimos_crates_opened loads cleanly.
		if problem == "":
			var old: Dictionary = saved.duplicate(true)
			old.erase("deimos_crates_opened")
			var old_err: String = other.farm_from_dict(old)
			if old_err != "" or not other.deimos_crates_opened_today().is_empty():
				problem = "Old save without deimos_crates_opened must load: '%s'" % old_err

		# Yesterday's opened crates are pruned on save.
		if problem == "":
			gs.deimos_crates_opened = { "day": day - 1, "ids": [cid] }
			if not (gs.farm_to_dict()["deimos_crates_opened"] as Dictionary).is_empty():
				problem = "Yesterday's deimos_crates_opened must be pruned on save."

		# Corrupt deimos_crates_opened is rejected.
		if problem == "":
			var bad: Dictionary = saved.duplicate(true)
			bad["deimos_crates_opened"] = { "day": day, "ids": ["not_a_crate"] }
			if other.farm_dict_problem(bad) == "":
				problem = "Invalid deimos_crates_opened id must be rejected."

		# Phobos deep, Deimos cache, Deimos camp, Lava, Aquifer, Ice Caves, and Mine unchanged.
		if problem == "":
			if ZoneDepth.max_depth_of(ZoneDepth.ZONE) != ZoneDepth.MAX_DEPTH \
					or ZoneDepth.max_depth_of(AquiferDepth.ZONE) != AquiferDepth.MAX_DEPTH \
					or ZoneDepth.max_depth_of(MineDepth.ZONE) != MineDepth.MAX_DEPTH \
					or ZoneDepth.max_depth_of(IceDepth.ZONE) != IceDepth.MAX_DEPTH \
					or ZoneDepth.max_depth_of(Shuttle.DEIMOS) != 0 \
					or PhobosDepth.MAX_DEPTH != 1 \
					or not Camp.has_camp(Shuttle.DEIMOS):
				problem = "Other zone depth limits or Deimos camp changed unexpectedly."
		if problem == "":
			_grant_proof(gs, HOST)
			var cache_reply: String = gs.open_cache(HOST)
			if not gs.deimos_cache_opened_today():
				problem = "Deimos cache must still open normally: '%s'" % cache_reply
		if problem == "":
			gs.player_places[HOST] = [Shuttle.PHOBOS, 0]
			var p_data: Dictionary = PhobosDepth.layout(gs.world_seed, day)
			var p_fid: String = str(p_data["finds"][0]["id"])
			if gs.enter_phobos_deep(HOST) != "" or gs.take_phobos_find(p_fid, day, HOST) != "":
				problem = "Phobos deep must remain unchanged."

		other.free()
		return problem)


func test_protocol_and_commands_registered() -> String:
	for cmd: StringName in [&"enter_deimos_deep", &"leave_deimos_deep", &"open_deimos_crate", &"wipe_deimos_dust"]:
		if not cmd in FarmCommands.ACTIONS or not cmd in FarmCommands.ON_A_MOON:
			return "%s must be in FarmCommands.ACTIONS and ON_A_MOON." % cmd
	if CoopSession.PROTOCOL != 48:
		return "CoopSession.PROTOCOL must be 48, got %d." % CoopSession.PROTOCOL
	return ""
