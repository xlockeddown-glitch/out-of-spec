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
		# Wiped first so we verify base pay cleanly here.
		if gs.wipe_phobos_dust() != "":
			return "wipe_phobos_dust must succeed on Phobos."
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
		# Off Phobos (farm and Deimos) must be refused.
		var next_id: String = str(data["finds"][1]["id"])
		gs.player_places[HOST] = [ZonePresence.FARM, 0]
		var from_farm: String = gs.take_phobos_find(next_id, day)
		gs.player_places[HOST] = [Shuttle.DEIMOS, 0]
		var from_deimos: String = gs.take_phobos_find(next_id, day)
		if from_farm == "" or from_deimos == "" or gs.credits != before_cr + expected:
			return "Taking off Phobos must be refused: '%s' / '%s'" % [from_farm, from_deimos]
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

	# Guest takes first find while dusty -> host decides and pays 75 %.
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


func test_dust_cuts_pay_until_wiped_reclogs_next_trip_and_never_blocks_leaving() -> String:
	return _on_phobos(func(gs: GameStateScript) -> String:
		var day: int = GameClock.get_day_index()
		var data: Dictionary = PhobosDepth.layout(gs.world_seed, day)
		var f0: Dictionary = data["finds"][0]
		var f1: Dictionary = data["finds"][1]
		var f2: Dictionary = data["finds"][2]
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
	GameClock.elapsed_days = 6.25
	GameState.shuttle_trips[GameState.local_player_id] = { "moon": Shuttle.PHOBOS, "ends_at": 1.0e9 }
	GameState.player_places[GameState.local_player_id] = [Shuttle.PHOBOS, 0]
	GameState.phobos_finds_taken = {}

	var deep: PhobosDeep = _open(PhobosDeep.SCENE_PATH) as PhobosDeep
	var problem: String = ""
	if not deep.dusty or not "Dusty" in deep._hint.text:
		problem = "Entering Station deck 1 must start dusty and log 'Dusty' on HUD, got '%s'." % deep._hint.text
	# Leaving while dusty must NEVER be blocked.
	if problem == "":
		var seen: Array[String] = []
		deep.change_scene = func(path: String) -> void: seen.append(path)
		deep.walker.position = PhobosDepth.cell_to_world(PhobosDepth.HATCH_CELL)
		deep._on_hatch_up()
		if seen != [PhobosServiceTunnel.SCENE_PATH]:
			problem = "Leaving up the hatch while dusty must not be blocked: %s" % [seen]
		elif not PhobosServiceTunnel.arrive_at_deep_hatch:
			problem = "Leaving up the hatch must set PhobosServiceTunnel.arrive_at_deep_hatch."
	_drop(deep)

	# Re-enter and wipe dust -> logs "Dusty" wiped line.
	if problem == "":
		PhobosServiceTunnel.arrive_at_deep_hatch = false
		var deep2: PhobosDeep = _open(PhobosDeep.SCENE_PATH) as PhobosDeep
		deep2.walker.position = PhobosDepth.cell_to_world(PhobosDepth.WIPE_CELL)
		await deep2._on_wipe_stop()
		if deep2.dusty or not "Dusty" in deep2._hint.text:
			problem = "Wiping dust must clear dusty flag and log 'Dusty' wiped line, got '%s'." % deep2._hint.text
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
	for cmd: StringName in [&"enter_phobos_deep", &"take_phobos_find", &"wipe_phobos_dust"]:
		if not cmd in FarmCommands.ACTIONS or not cmd in FarmCommands.ON_A_MOON:
			return "%s must be in FarmCommands.ACTIONS and ON_A_MOON." % cmd
	if CoopSession.PROTOCOL != 46:
		return "CoopSession.PROTOCOL must be 46, got %d." % CoopSession.PROTOCOL
	return ""
