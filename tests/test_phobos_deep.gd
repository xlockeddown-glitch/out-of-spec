extends "res://tests/coop_net.gd"
## Phobos deep, depth 1 under the service tunnel (docs/design/zones.md section 13,
## slice 23): deterministic daily room grid from integer hash, reachability, reseed
## at 06:00, host-run finds (station data and robot parts), dust penalty and wipe
## stop, co-op guest path and sync, save/load, and isolation from other zones/strays.

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


func _on_phobos(body: Callable) -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = 6.25
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(717171)
	gs.local_player_id = HOST
	gs.player_places[HOST] = [Shuttle.PHOBOS, 0]
	var out: Variant = body.call(gs)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	GameClock.elapsed_days = held
	return problem


func test_layout_is_deterministic_reachable_and_reseeds_next_day() -> String:
	var a: Dictionary = PhobosDepth.layout(424242, 5)
	var b: Dictionary = PhobosDepth.layout(424242, 5)
	if a["grid"] != b["grid"] or a["finds"] != b["finds"]:
		return "Same seed and day must produce the exact same layout and finds."

	var changed_days: int = 0
	var prev_sig: String = ""
	for seed_val: int in [101, 424242, 999999]:
		prev_sig = ""
		for day: int in range(1, 16):
			var data: Dictionary = PhobosDepth.layout(seed_val, day)
			var grid: PackedStringArray = data["grid"]
			var finds: Array = data["finds"]
			if finds.size() < PhobosDepth.MIN_FINDS or finds.size() > PhobosDepth.MAX_FINDS:
				return "Seed %d day %d produced %d finds (expected %d..%d)." % [seed_val, day, finds.size(), PhobosDepth.MIN_FINDS, PhobosDepth.MAX_FINDS]
			var reached: Array[Vector2i] = ZoneDepth.reachable(grid, PhobosDepth.START_CELL)
			if not PhobosDepth.HATCH_CELL in reached or not PhobosDepth.WIPE_CELL in reached:
				return "Hatch or wipe stop unreachable on seed %d day %d." % [seed_val, day]
			var floor_count: int = 0
			for y: int in grid.size():
				for x: int in grid[y].length():
					if grid[y][x] == ".":
						floor_count += 1
			if reached.size() != floor_count:
				return "Seed %d day %d has unreachable floor cells (%d reached of %d)." % [seed_val, day, reached.size(), floor_count]
			for find: Dictionary in finds:
				var cell: Vector2i = find["cell"]
				if not cell in reached:
					return "Find %s at %s unreachable on seed %d day %d." % [find["id"], cell, seed_val, day]
				if cell in [PhobosDepth.START_CELL, PhobosDepth.HATCH_CELL, PhobosDepth.WIPE_CELL]:
					return "Find %s overlaps fixed cell %s." % [find["id"], cell]
			var sig: String = "|".join(grid) + "::" + str(finds)
			if prev_sig != "" and sig != prev_sig:
				changed_days += 1
			prev_sig = sig
	if changed_days < 35:
		return "Layouts did not reseed across days often enough (%d changes)." % changed_days
	return ""


func test_find_pays_once_refuses_second_take_and_refuses_off_phobos() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		var day: int = GameClock.get_day_index()
		var data: Dictionary = PhobosDepth.layout(gs.world_seed, day)
		var first: Dictionary = data["finds"][0]
		var fid: String = str(first["id"])
		var kind: String = str(first["kind"])
		var before_cr: int = gs.credits
		# Refused from the hub before entering Station deck 1.
		if gs.wipe_phobos_dust() == "" or gs.take_phobos_find(fid, day) == "":
			return "wipe_phobos_dust and take_phobos_find must be refused from the hub before enter_phobos_deep."
		if gs.credits != before_cr:
			return "Refused hub take must pay nothing."
		# Enter deck 1, then wipe so we verify base pay cleanly here.
		if gs.enter_phobos_deep() != "":
			return "enter_phobos_deep must succeed on Phobos."
		if gs.wipe_phobos_dust() != "":
			return "wipe_phobos_dust must succeed after enter_phobos_deep."
		var expected: int = PhobosDepth.reward_credits(kind, false)
		var err: String = gs.take_phobos_find(fid, day)
		if err != "":
			return "First take must succeed: '%s'" % err
		if gs.credits != before_cr + expected:
			return "Expected +%d credits for %s, got +%d." % [expected, kind, gs.credits - before_cr]
		if not fid in gs.phobos_finds_taken_today():
			return "Taken find id must be recorded today."
		var second: String = gs.take_phobos_find(fid, day)
		if second == "" or gs.credits != before_cr + expected:
			return "Second take of same find must be refused and pay nothing: '%s'" % second
		var stale: String = gs.take_phobos_find(str(data["finds"][1]["id"]), day - 1)
		if stale == "":
			return "Stale layout day must be refused."
		var missing: String = gs.take_phobos_find("d1_f99", day)
		if missing == "":
			return "Unknown find id must be refused."
		# Leaving the deck refuses further takes and wipes until re-entered.
		var next_id: String = str(data["finds"][1]["id"])
		if gs.leave_phobos_deep() != "":
			return "leave_phobos_deep must succeed."
		if gs.take_phobos_find(next_id, day) == "" or gs.wipe_phobos_dust() == "":
			return "take_phobos_find and wipe_phobos_dust must be refused after leave_phobos_deep."
		# Off Phobos (farm and Deimos) must be refused even if deck flag were set.
		gs.enter_phobos_deep()
		gs.player_places[HOST] = [ZonePresence.FARM, 0]
		var from_farm: String = gs.take_phobos_find(next_id, day)
		gs.player_places[HOST] = [Shuttle.DEIMOS, 0]
		var from_deimos: String = gs.take_phobos_find(next_id, day)
		if from_farm == "" or from_deimos == "" or gs.credits != before_cr + expected:
			return "Taking off Phobos must be refused: '%s' / '%s'" % [from_farm, from_deimos]
		return "")


func test_wiped_and_deck_flag_clear_on_forget_place_day_start_and_trip_end() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		var day: int = GameClock.get_day_index()
		var data: Dictionary = PhobosDepth.layout(gs.world_seed, day)
		var fid: String = str(data["finds"][0]["id"])
		gs.player_places[GUEST] = [Shuttle.PHOBOS, 0]

		# forget_place clears both _phobos_wiped and _on_phobos_deck for that player only.
		gs.enter_phobos_deep(HOST)
		gs.wipe_phobos_dust(HOST)
		gs.enter_phobos_deep(GUEST)
		gs.wipe_phobos_dust(GUEST)
		gs.forget_place(GUEST)
		if not gs.is_phobos_dusty(GUEST) or gs._on_phobos_deck.has(GUEST):
			return "forget_place must clear _phobos_wiped and _on_phobos_deck for the dropped player."
		if gs.is_phobos_dusty(HOST) or not bool(gs._on_phobos_deck.get(HOST, false)):
			return "forget_place(GUEST) must not clear HOST's Phobos deck or wipe state."

		# _on_day_started clears both _phobos_wiped and _on_phobos_deck for everyone.
		gs._on_day_started(day + 1)
		if not gs.is_phobos_dusty(HOST) or not gs._on_phobos_deck.is_empty():
			return "_on_day_started must clear _phobos_wiped and _on_phobos_deck."
		if gs.take_phobos_find(fid, day) == "" or gs.wipe_phobos_dust() == "":
			return "After _on_day_started, take and wipe must be refused until re-entering."

		# Ending a moon trip via shuttle_home clears _on_phobos_deck and _phobos_wiped.
		gs.shuttle_trips[HOST] = { "moon": Shuttle.PHOBOS, "ends_at": 1.0e9 }
		gs.player_places[HOST] = [Shuttle.PHOBOS, 0]
		gs.enter_phobos_deep(HOST)
		gs.wipe_phobos_dust(HOST)
		if gs.shuttle_home(HOST) != "":
			return "shuttle_home must succeed for a player on Phobos."
		if gs._on_phobos_deck.has(HOST) or not gs.is_phobos_dusty(HOST):
			return "Ending the moon trip must clear _on_phobos_deck and _phobos_wiped."
		return "")


func test_guest_find_and_wipe_go_through_host_and_sync_to_late_joiner() -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = 6.25
	var host: Node = _host()
	var farm: GameStateScript = host.commands.state
	farm.player_places[GUEST] = [Shuttle.PHOBOS, 0]
	var guest: Node = _guest(host)
	var day: int = GameClock.get_day_index()
	var data: Dictionary = PhobosDepth.layout(farm.world_seed, day)
	var first: Dictionary = data["finds"][0]
	var second: Dictionary = data["finds"][1]
	var problem: String = ""

	# Guest cannot take or wipe from the hub before enter_phobos_deep.
	var hub_take: Array = _request(guest, &"take_phobos_find", [str(first["id"]), day])
	_until(func() -> bool: return not hub_take.is_empty())
	var hub_wipe: Array = _request(guest, &"wipe_phobos_dust", [])
	_until(func() -> bool: return not hub_wipe.is_empty())
	if hub_take == [""] or hub_wipe == [""]:
		problem = "Guest take/wipe from hub before enter_phobos_deep must be refused: %s / %s" % [hub_take, hub_wipe]

	# Guest enters deck 1 via host.
	if problem == "":
		var entered: Array = _request(guest, &"enter_phobos_deep", [])
		_until(func() -> bool: return not entered.is_empty())
		if entered != [""] or not bool(farm._on_phobos_deck.get(GUEST, false)):
			problem = "Host must record guest enter_phobos_deep: %s" % [entered]

	# Guest takes first find while dusty -> host decides and pays 75 %.
	if problem == "":
		var before_cr: int = farm.credits
		var dusty_pay: int = PhobosDepth.reward_credits(str(first["kind"]), true)
		var got: Array = _request(guest, &"take_phobos_find", [str(first["id"]), day])
		_until(func() -> bool: return not got.is_empty())
		if got != [""] or farm.credits != before_cr + dusty_pay or not str(first["id"]) in farm.phobos_finds_taken_today():
			problem = "Host must process guest dusty find: reply=%s cr=%d" % [got, farm.credits - before_cr]
		elif not guest.commands.state.phobos_finds_taken_today().is_empty():
			problem = "Guest state must not mutate locally before host sync."

	# Guest wipes dust via host, then takes second find for full pay.
	if problem == "":
		var wiped: Array = _request(guest, &"wipe_phobos_dust", [])
		_until(func() -> bool: return not wiped.is_empty())
		if wiped != [""] or farm.is_phobos_dusty(GUEST):
			problem = "Host must wipe guest dust: %s" % [wiped]
	if problem == "":
		var cr_mid: int = farm.credits
		var full_pay: int = PhobosDepth.reward_credits(str(second["kind"]), false)
		var got2: Array = _request(guest, &"take_phobos_find", [str(second["id"]), day])
		_until(func() -> bool: return not got2.is_empty())
		if got2 != [""] or farm.credits != cr_mid + full_pay:
			problem = "Host must pay full credits after wipe: reply=%s cr=%d" % [got2, farm.credits - cr_mid]

	# Guest cannot retake first find.
	if problem == "":
		var again: Array = _request(guest, &"take_phobos_find", [str(first["id"]), day])
		_until(func() -> bool: return not again.is_empty())
		if again.is_empty() or again == [""]:
			problem = "Duplicate guest take must be refused: %s" % [again]

	# Late joiner / sync receives taken finds and emits phobos_finds_changed.
	if problem == "":
		var heard: Array[int] = [0]
		guest.commands.state.phobos_finds_changed.connect(func() -> void: heard[0] += 1)
		FarmCommands.guest = true
		var sync_err: String = FarmSync.update(FarmSync.capture(farm), guest.commands.state)
		FarmCommands.guest = false
		if sync_err != "" or heard[0] < 1 or guest.commands.state.phobos_finds_taken_today() != farm.phobos_finds_taken_today():
			problem = "Sync must deliver taken finds to guest: '%s', heard=%d" % [sync_err, heard[0]]
		var late: GameStateScript = GameStateScript.new()
		late.build_registry()
		var load_err: String = late.farm_from_dict(farm.farm_to_dict())
		if load_err != "" or late.phobos_finds_taken_today() != farm.phobos_finds_taken_today():
			problem = "Late joiner must receive taken finds: '%s'" % load_err
		late.free()

	GameClock.elapsed_days = held
	return _finish(problem)


func test_guest_cannot_spoof_player_id_and_off_phobos_guest_is_refused() -> String:
	var held: float = GameClock.elapsed_days
	GameClock.elapsed_days = 6.25
	var host: Node = _host()
	var farm: GameStateScript = host.commands.state
	farm.player_places[HOST] = [Shuttle.PHOBOS, 0]
	farm.enter_phobos_deep(HOST)
	farm.player_places[GUEST] = [ZonePresence.FARM, 0]
	var guest: Node = _guest(host)
	var day: int = GameClock.get_day_index()
	var data: Dictionary = PhobosDepth.layout(farm.world_seed, day)
	var fid: String = str(data["finds"][0]["id"])
	var before_cr: int = farm.credits
	var problem: String = ""

	# Guest off Phobos (on Farm) is refused for enter, wipe, and take.
	var off_enter: Array = _request(guest, &"enter_phobos_deep", [])
	_until(func() -> bool: return not off_enter.is_empty())
	var off_wipe: Array = _request(guest, &"wipe_phobos_dust", [])
	_until(func() -> bool: return not off_wipe.is_empty())
	var off_take: Array = _request(guest, &"take_phobos_find", [fid, day])
	_until(func() -> bool: return not off_take.is_empty())
	if off_enter == [""] or off_wipe == [""] or off_take == [""]:
		problem = "Guest on Farm must be refused Phobos deep actions: %s / %s / %s" % [off_enter, off_wipe, off_take]

	# Guest on Deimos is also refused.
	if problem == "":
		farm.player_places[GUEST] = [Shuttle.DEIMOS, 0]
		var deimos_enter: Array = _request(guest, &"enter_phobos_deep", [])
		_until(func() -> bool: return not deimos_enter.is_empty())
		var deimos_take: Array = _request(guest, &"take_phobos_find", [fid, day])
		_until(func() -> bool: return not deimos_take.is_empty())
		if deimos_enter == [""] or deimos_take == [""]:
			problem = "Guest on Deimos must be refused Phobos deep actions: %s / %s" % [deimos_enter, deimos_take]

	# Guest cannot spoof HOST's player_id via extra arguments: host rejects bad arg count and uses connection id.
	if problem == "":
		var spoof_enter: Array = _request(guest, &"enter_phobos_deep", [HOST])
		_until(func() -> bool: return not spoof_enter.is_empty())
		var spoof_wipe: Array = _request(guest, &"wipe_phobos_dust", [HOST])
		_until(func() -> bool: return not spoof_wipe.is_empty())
		var spoof_take: Array = _request(guest, &"take_phobos_find", [fid, day, HOST])
		_until(func() -> bool: return not spoof_take.is_empty())
		var spoof_leave: Array = _request(guest, &"leave_phobos_deep", [HOST])
		_until(func() -> bool: return not spoof_leave.is_empty())
		if spoof_enter == [""] or spoof_wipe == [""] or spoof_take == [""] or spoof_leave == [""]:
			problem = "Spoofed player_id arguments must be refused: %s / %s / %s / %s" % [spoof_enter, spoof_wipe, spoof_take, spoof_leave]
		elif not farm.is_phobos_dusty(HOST) or not bool(farm._on_phobos_deck.get(HOST, false)) or farm.credits != before_cr:
			problem = "Guest spoof attempts must not alter HOST's deck/dust state or farm credits."

	# Even when guest is on Phobos, guest's wipe/leave only affect GUEST, never HOST.
	if problem == "":
		farm.player_places[GUEST] = [Shuttle.PHOBOS, 0]
		var g_enter: Array = _request(guest, &"enter_phobos_deep", [])
		_until(func() -> bool: return not g_enter.is_empty())
		var g_wipe: Array = _request(guest, &"wipe_phobos_dust", [])
		_until(func() -> bool: return not g_wipe.is_empty())
		var g_leave: Array = _request(guest, &"leave_phobos_deep", [])
		_until(func() -> bool: return not g_leave.is_empty())
		if g_enter != [""] or g_wipe != [""] or g_leave != [""]:
			problem = "Valid guest Phobos deck actions failed: %s / %s / %s" % [g_enter, g_wipe, g_leave]
		elif not farm.is_phobos_dusty(HOST) or not bool(farm._on_phobos_deck.get(HOST, false)):
			problem = "Guest wipe/leave must only affect GUEST, not HOST."

	GameClock.elapsed_days = held
	return _finish(problem)


func test_dust_cuts_pay_until_wiped_reclogs_next_trip_and_never_blocks_leaving() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		var day: int = GameClock.get_day_index()
		var data: Dictionary = PhobosDepth.layout(gs.world_seed, day)
		var f0: Dictionary = data["finds"][0]
		var f1: Dictionary = data["finds"][1]
		var f2: Dictionary = data["finds"][2]
		if gs.enter_phobos_deep() != "":
			return "enter_phobos_deep must succeed on Phobos."
		if not gs.is_phobos_dusty():
			return "Player must start dusty on a trip down."
		var base0: int = PhobosDepth.reward_credits(str(f0["kind"]), false)
		var cut0: int = PhobosDepth.reward_credits(str(f0["kind"]), true)
		if cut0 >= base0 or cut0 != PhobosDepth.apply_dust(base0, true):
			return "Dust must reduce pay by %d %% (%d -> %d)." % [PhobosDepth.DUST_CUT_PCT, base0, cut0]

		var cr0: int = gs.credits
		if gs.take_phobos_find(str(f0["id"]), day) != "" or gs.credits != cr0 + cut0:
			return "Dusty take must pay reduced credits."
		if gs.wipe_phobos_dust() != "" or gs.is_phobos_dusty():
			return "Wipe stop must clear dust."
		var cr1: int = gs.credits
		var base1: int = PhobosDepth.reward_credits(str(f1["kind"]), false)
		if gs.take_phobos_find(str(f1["id"]), day) != "" or gs.credits != cr1 + base1:
			return "Wiped take must pay full credits."
		# A new trip down reclogs dust.
		if gs.enter_phobos_deep() != "" or not gs.is_phobos_dusty():
			return "enter_phobos_deep must mark the new trip dusty again."
		var cr2: int = gs.credits
		var cut2: int = PhobosDepth.reward_credits(str(f2["kind"]), true)
		if gs.take_phobos_find(str(f2["id"]), day) != "" or gs.credits != cr2 + cut2:
			return "New trip down must apply dust cut again."
		return "")


func test_scene_logs_dusty_on_enter_and_wipe_and_leaving_is_never_blocked() -> String:
	var held_clock: float = GameClock.elapsed_days
	var held_trips: Dictionary = GameState.shuttle_trips.duplicate(true)
	var held_places: Dictionary = GameState.player_places.duplicate(true)
	var held_finds: Dictionary = GameState.phobos_finds_taken.duplicate(true)
	var held_wiped: Dictionary = GameState._phobos_wiped.duplicate(true)
	var held_deck: Dictionary = GameState._on_phobos_deck.duplicate(true)
	var held_credits: int = GameState.credits
	GameClock.elapsed_days = 6.25
	GameState.shuttle_trips[GameState.local_player_id] = { "moon": Shuttle.PHOBOS, "ends_at": 1.0e9 }
	GameState.player_places[GameState.local_player_id] = [Shuttle.PHOBOS, 0]
	GameState.phobos_finds_taken = {}
	GameState._phobos_wiped = {}
	GameState._on_phobos_deck = {}

	var deep: PhobosDeep = _open(PhobosDeep.SCENE_PATH) as PhobosDeep
	var problem: String = ""
	if not deep.dusty or not "Dusty" in deep._hint.text:
		problem = "Entering Station deck 1 must start dusty and log 'Dusty' on HUD, got '%s'." % deep._hint.text
	elif not bool(GameState._on_phobos_deck.get(GameState.local_player_id, false)):
		problem = "Opening Station deck 1 must mark player on deck."
	# Leaving while dusty must NEVER be blocked, and clears _on_phobos_deck.
	if problem == "":
		var seen: Array[String] = []
		deep.change_scene = func(path: String) -> void: seen.append(path)
		deep.walker.position = PhobosDepth.cell_to_world(PhobosDepth.HATCH_CELL)
		deep._on_hatch_up()
		if seen != [PhobosServiceTunnel.SCENE_PATH]:
			problem = "Leaving up the hatch while dusty must not be blocked: %s" % [seen]
		elif not PhobosServiceTunnel.arrive_at_deep_hatch:
			problem = "Leaving up the hatch must set PhobosServiceTunnel.arrive_at_deep_hatch."
		elif GameState._on_phobos_deck.has(GameState.local_player_id):
			problem = "Leaving up the hatch must clear _on_phobos_deck."
	_drop(deep)

	# Re-enter and wipe dust -> logs "Dusty" wiped line.
	if problem == "":
		PhobosServiceTunnel.arrive_at_deep_hatch = false
		var deep2: PhobosDeep = _open(PhobosDeep.SCENE_PATH) as PhobosDeep
		deep2.walker.position = PhobosDepth.cell_to_world(PhobosDepth.WIPE_CELL)
		await deep2._on_wipe_stop()
		if deep2.dusty or not "Dusty" in deep2._hint.text:
			problem = "Wiping dust must clear dusty flag and log 'Dusty' wiped line, got '%s'." % deep2._hint.text
		# Even if local dusty were stale true while host is clean, reward toast must NOT claim a cut.
		if problem == "" and not deep2.find_ids.is_empty():
			deep2.dusty = true
			var fid: String = deep2.find_ids[0]
			var kind: String = deep2.find_kinds[0]
			var at: Vector3 = deep2.find_nodes[0].position
			deep2.walker.position = at
			await deep2._on_find_clicked(at, fid, kind, GameClock.get_day_index())
			if deep2.dusty or "cut" in deep2._hint.text or deep2._hint.text != PhobosDepth.reward_text(kind, false):
				problem = "Reward toast must match host clean payout and never claim a cut: '%s'" % deep2._hint.text
		_drop(deep2)

	# Service tunnel hatch leads down to Station deck 1.
	if problem == "":
		var tunnel: PhobosServiceTunnel = _open(PhobosServiceTunnel.SCENE_PATH) as PhobosServiceTunnel
		var seen2: Array[String] = []
		tunnel.change_scene = func(path: String) -> void: seen2.append(path)
		tunnel.walker.position = PhobosServiceTunnel.DEEP_HATCH_AT
		tunnel._on_deep_hatch()
		if seen2 != [PhobosDeep.SCENE_PATH]:
			problem = "Service tunnel deep hatch must open Station deck 1, got %s." % [seen2]
		_drop(tunnel)

	PhobosServiceTunnel.arrive_at_deep_hatch = false
	GameState.credits = held_credits
	GameState._on_phobos_deck = held_deck
	GameState._phobos_wiped = held_wiped
	GameState.phobos_finds_taken = held_finds
	GameState.player_places = held_places
	GameState.shuttle_trips = held_trips
	GameClock.elapsed_days = held_clock
	return problem


func test_old_saves_load_and_other_zones_and_strays_unchanged() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		var day: int = GameClock.get_day_index()
		var data: Dictionary = PhobosDepth.layout(gs.world_seed, day)
		var fid: String = str(data["finds"][0]["id"])
		gs.enter_phobos_deep()
		gs.take_phobos_find(fid, day)

		# Save round-trip & pruning of yesterday's finds.
		var saved: Dictionary = gs.farm_to_dict()
		var other: GameStateScript = GameStateScript.new()
		other.build_registry()
		var why: String = other.farm_from_dict(saved)
		var problem: String = ""
		if why != "" or other.phobos_finds_taken_today() != [fid]:
			problem = "Save must round-trip phobos_finds_taken: '%s' %s" % [why, other.phobos_finds_taken_today()]

		# Old save without phobos_finds_taken loads cleanly.
		if problem == "":
			var old: Dictionary = saved.duplicate(true)
			old.erase("phobos_finds_taken")
			var old_err: String = other.farm_from_dict(old)
			if old_err != "" or not other.phobos_finds_taken_today().is_empty():
				problem = "Old save without phobos_finds_taken must load: '%s'" % old_err

		# Yesterday's taken finds are pruned on save.
		if problem == "":
			gs.phobos_finds_taken = { "day": day - 1, "ids": [fid] }
			if not (gs.farm_to_dict()["phobos_finds_taken"] as Dictionary).is_empty():
				problem = "Yesterday's phobos_finds_taken must be pruned on save."

		# Corrupt phobos_finds_taken is rejected.
		if problem == "":
			var bad: Dictionary = saved.duplicate(true)
			bad["phobos_finds_taken"] = { "day": day, "ids": ["not_a_find"] }
			if other.farm_dict_problem(bad) == "":
				problem = "Invalid phobos_finds_taken id must be rejected."

		# Lava, Aquifer, Ice Caves, Mine, and strays are unchanged.
		if problem == "":
			if ZoneDepth.max_depth_of(ZoneDepth.ZONE) != ZoneDepth.MAX_DEPTH \
					or ZoneDepth.max_depth_of(AquiferDepth.ZONE) != AquiferDepth.MAX_DEPTH \
					or ZoneDepth.max_depth_of(MineDepth.ZONE) != MineDepth.MAX_DEPTH \
					or ZoneDepth.max_depth_of(IceDepth.ZONE) != IceDepth.MAX_DEPTH \
					or ZoneDepth.max_depth_of(Shuttle.PHOBOS) != 0:
				problem = "Other zone depth limits changed unexpectedly."
			var stray_idx: int = PhobosServiceTunnel.stray_indices_for_day(day)[0]
			var stray_err: String = gs.catch_stray(stray_idx, day)
			if stray_err != "" or not stray_idx in gs.strays_caught_today():
				problem = "Phobos strays must remain unchanged: '%s'" % stray_err

		other.free()
		return problem)


func test_protocol_and_commands_registered() -> String:
	for cmd: StringName in [&"enter_phobos_deep", &"leave_phobos_deep", &"take_phobos_find", &"wipe_phobos_dust"]:
		if not cmd in FarmCommands.ACTIONS or not cmd in FarmCommands.ON_A_MOON:
			return "%s must be in FarmCommands.ACTIONS and ON_A_MOON." % cmd
	if CoopSession.PROTOCOL != 52:
		return "CoopSession.PROTOCOL must be 52, got %d." % CoopSession.PROTOCOL
	return ""
