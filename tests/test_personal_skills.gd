extends RefCounted
## Every skill is a player's own (docs/design/quests_levels_story.md section 9,
## build order step 4): Robotics and Husbandry leave the farm, crop XP is
## Agronomy's, digging feeds Earthworks, and a save from before is converted
## once. The values are [PLACEHOLDER] in data/skills.json; the tests read them.
## Every GameState is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const ProfileScript: GDScript = preload("res://scripts/autoload/CoopProfile.gd")
const GUEST: String = "player_2"
const LATER: String = "player_3"
const EPS: float = 1.0e-9


func _run(body: Callable) -> String:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(gs)
	var problem: String = out if out is String else "The test stopped early or did not return a String."
	gs.free()
	return problem


func _xp(source: String) -> int:
	return roundi(float(DataManager.get_record(&"skills", source, "xp_sources").get("xp", 0)))


## The farm as a save with `curve` wrote it.
func _save_at(gs: GameStateScript, curve: int) -> Dictionary:
	var data: Dictionary = gs.farm_to_dict()
	data["skill_curve"] = curve
	return data


## Cells that can be dug, with a gauge block under them or without.
func _cells(gs: GameStateScript, with_block: bool) -> Array[Vector2i]:
	var none: Dictionary[Vector2i, int] = {}
	var out: Array[Vector2i] = []
	for x: int in range(-60, 60):
		for z: int in range(-60, 60):
			var cell := Vector2i(x, z)
			if Terrain.dig_problem(cell, none) == "" and ReferenceBlock.at(gs.world_seed, cell).is_empty() != with_block \
					and StonePieces.dig_beside_pad_problem(cell, none) == "":
				out.append(cell)
	return out


func test_no_skill_is_the_farm_s() -> String:
	return _run(_check_scopes)


func _check_scopes(gs: GameStateScript) -> String:
	for id: String in ["robotics", "husbandry", "agronomy", "earthworks", "field_ops", "calibration", "uncertainty"]:
		if not id in gs.skill_ids() or gs.is_farm_skill(id):
			return "%s must be a player's own skill." % id
	if GameStateScript.SKILL_CURVE != 4 or not 3 in GameStateScript.KNOWN_CURVES or not 2 in GameStateScript.KNOWN_CURVES:
		return "The save's marker is 4, and 2 and 3 still load."
	for effect: Dictionary in DataManager.get_records(&"skills", "effects"):
		if effect["skill"] == "earthworks":
			return "Earthworks has no effect yet."
	return "" if gs.skill_text("robotics").find("farm") < 0 else "No skill's line says it is the farm's."


func test_farm_xp_goes_to_each_player_once() -> String:
	return _run(_check_farm_xp)


func _check_farm_xp(gs: GameStateScript) -> String:
	var robotics: int = gs.xp_for_level(15) + 7
	var husbandry: int = gs.xp_for_level(20)
	gs.player_skill_xp = { "player_1": { "calibration": 100 }, GUEST: { "calibration": 60 } }
	# A guest the farm knows and holds nothing else for.
	gs.guest_ids = { "a".sha256_text(): GUEST, "b".sha256_text(): LATER }
	gs.next_player_number = 4
	gs.farm_skill_xp = { "robotics": robotics, "husbandry": husbandry }
	gs.skill_effect_floor = { "": { "husbandry": 0.5 }, GUEST: { "calibration": 0.25 } }
	var old: Dictionary = _save_at(gs, 3)
	if gs.farm_from_dict(old) != "" or gs.skill_curve != GameStateScript.SKILL_CURVE:
		return "A save from before must load: %s" % gs.farm_from_dict(old)
	for player: String in ["player_1", GUEST, LATER]:
		if gs.skill_xp("robotics", player) != robotics or gs.skill_xp("husbandry", player) != husbandry:
			return "%s has the farm's Robotics and Husbandry: %s" % [player, gs.player_skill_xp]
		if absf(gs.effect_floor("husbandry", player) - 0.5) > EPS or gs.effect_floor("robotics", player) != 0.0:
			return "%s keeps the share of the effect the farm had: %s" % [player, gs.skill_effect_floor]
		if not gs.has_skill_unlock("molt_on_phone", player) or gs.robot_job_gate("calibrate", player).find("Robotics") >= 0:
			return "%s keeps what the farm's levels opened." % player
	if not gs.farm_skill_xp.is_empty() or gs.skill_effect_floor.has("") or gs.skill_xp("calibration", GUEST) != 60 \
			or absf(gs.effect_floor("calibration", GUEST) - 0.25) > EPS:
		return "The farm holds none after, and nothing else changes: %s %s" % [gs.farm_skill_xp, gs.skill_effect_floor]
	if gs.skill_xp("robotics", "player_4") != 0:
		return "A player who comes later starts at level 1."
	# One player goes on; loading the new save gives nothing again.
	gs.player_skill_xp[GUEST]["robotics"] = robotics + 500
	gs.player_skill_xp["player_1"]["husbandry"] = 3
	var again: Dictionary = gs.farm_to_dict()
	if again.get("skill_curve") != GameStateScript.SKILL_CURVE or not (again.get("farm_skill_xp", {}) as Dictionary).is_empty():
		return "The save says the new curve and holds no farm XP."
	if gs.farm_from_dict(again) != "" or gs.skill_xp("robotics", GUEST) != robotics + 500 or gs.skill_xp("robotics") != robotics \
			or gs.skill_xp("husbandry") != 3:
		return "A converted save must not convert again: %s" % [gs.player_skill_xp]
	# A new save that somehow held farm XP is not a save from before.
	again["farm_skill_xp"] = { "robotics": 99999 }
	return "" if gs.farm_from_dict(again) == "" and gs.skill_xp("robotics") == robotics else "Only a save from before gives farm XP out."


func test_a_player_keeps_the_better_xp() -> String:
	return _run(_check_better)


func _check_better(gs: GameStateScript) -> String:
	gs.player_skill_xp = { "player_1": { "robotics": 900 }, GUEST: { "robotics": 10 } }
	gs.farm_skill_xp = { "robotics": 400 }
	if gs.farm_from_dict(_save_at(gs, 3)) != "":
		return "The save must load."
	return "" if gs.skill_xp("robotics") == 900 and gs.skill_xp("robotics", GUEST) == 400 else \
		"The farm's XP never lowers a player's: %s" % [gs.player_skill_xp]


func test_crop_xp_moves_by_the_count() -> String:
	return _run(_check_crop_move)


func _check_crop_move(gs: GameStateScript) -> String:
	var till: int = 40
	var crops: int = gs.xp_for_level(30)
	var share: float = gs.effect_share(gs._level_for_xp(till + crops))
	gs.player_skill_xp = { "player_1": { "field_ops": till + crops }, GUEST: { "field_ops": 30 }, LATER: { "field_ops": 500 } }
	gs.action_counts = {
		"player_1": { "plant_crop": { "count": 9, "xp": 45 }, "sell_crop": { "count": 2, "xp": crops - 45 }, "till": { "count": 8, "xp": till } },
		# More counted than Field Ops holds: only what is there can move.
		GUEST: { "harvest_in_spec": { "count": 4, "xp": 80 } },
		# No crop work: nothing moves.
		LATER: { "till": { "count": 100, "xp": 500 } },
	}
	var steering: float = gs.skill_factor("steering_usage")
	if steering >= 1.0:
		return "Field Ops at that level must cut the steering drift."
	var old: Dictionary = _save_at(gs, 3)
	if gs.farm_from_dict(old) != "":
		return "A save from before must load: %s" % gs.farm_from_dict(old)
	if gs.skill_xp("agronomy") != crops or gs.skill_xp("field_ops") != till:
		return "Crop XP leaves Field Ops for Agronomy; tilling's stays: %s" % [gs.player_skill_xp]
	if gs.skill_xp("agronomy", GUEST) != 30 or gs.skill_xp("field_ops", GUEST) != 0:
		return "No more moves than Field Ops held: %s" % [gs.player_skill_xp]
	if gs.skill_xp("agronomy", LATER) != 0 or gs.skill_xp("field_ops", LATER) != 500 or gs.skill_effect_floor.has(LATER):
		return "A player with no crop XP keeps Field Ops as it was: %s" % [gs.player_skill_xp]
	# Field Ops keeps what it did, though its level is lower now.
	if absf(gs.skill_factor("steering_usage") - steering) > EPS or absf(gs.effect_floor("field_ops") - share) > EPS:
		return "Field Ops keeps its effect: %s, was %s" % [gs.skill_factor("steering_usage"), steering]
	if gs.skill_level("agronomy") != 30 or gs.skill_factor("lin_price") <= 1.0:
		return "Agronomy has the level the crop XP is worth."
	# The count stays as it was, and a second load moves nothing.
	if gs.crop_xp() != crops or gs.action_xp("till") != till:
		return "The count is not changed by the move."
	var again: Dictionary = gs.farm_to_dict()
	var floors: Dictionary = gs.skill_effect_floor.duplicate(true)
	if gs.farm_from_dict(again) != "" or gs.skill_xp("agronomy") != crops or gs.skill_xp("field_ops") != till or gs.skill_effect_floor != floors:
		return "Crop XP must not move twice: %s" % [gs.player_skill_xp]
	return ""


func test_field_ops_stays_at_a_level_that_opened_something() -> String:
	return _run(_check_gate)


func _check_gate(gs: GameStateScript) -> String:
	# Nothing is gated on Field Ops today, so the floor is level 1.
	if gs._gate_reached("field_ops", 99) != 1:
		return "Field Ops opens something now: put it in test_crop_xp_moves_by_the_count."
	if gs._gate_reached("husbandry", 2) != 1 or gs._gate_reached("husbandry", 99) != 3:
		return "An unlock of data/skills.json is a level to stay at."
	if gs._gate_reached("robotics", 14) != 2 or gs._gate_reached("calibration", 99) != 10:
		return "A robot job's card is a level to stay at."
	return ""


func test_older_saves_run_every_stage() -> String:
	return _run(_check_stages)


func _check_stages(gs: GameStateScript) -> String:
	var factor: int = int(DataManager.get_number(&"skills", "old_curve/xp_factor", 0.0))
	# Curve 2: the lab level is given, then the farm's skills go to each player.
	gs.player_skill_xp = { "player_1": { "field_ops": 300 }, GUEST: {} }
	gs.farm_skill_xp = { "robotics": 700, "instrumentation": 200 }
	gs.action_counts = { "player_1": { "plant_crop": { "count": 20, "xp": 100 } } }
	if gs.farm_from_dict(_save_at(gs, 2)) != "":
		return "A curve 2 save must load."
	if gs.skill_xp("robotics", GUEST) != 700 or gs.skill_xp("agronomy") != 100 or gs.skill_xp("field_ops") != 200 \
			or gs.lab_xp < 200 or not gs.farm_skill_xp.is_empty():
		return "A curve 2 save gets the lab level and personal skills: %s %s" % [gs.player_skill_xp, gs.farm_skill_xp]
	# No marker: the 10-level curve first, then the rest.
	gs.player_skill_xp = { "player_1": { "calibration": 50 }, GUEST: {} }
	gs.farm_skill_xp = { "husbandry": 150 }
	gs.action_counts = {}
	gs.lab_xp = 0
	var old: Dictionary = gs.farm_to_dict()
	old.erase("skill_curve")
	old.erase("skill_effect_floor")
	if gs.farm_from_dict(old) != "":
		return "A save with no marker must load."
	if gs.skill_xp("husbandry") != 150 * factor or gs.skill_xp("husbandry", GUEST) != 150 * factor or not gs.farm_skill_xp.is_empty() \
			or gs.skill_curve != GameStateScript.SKILL_CURVE:
		return "A save with no marker is multiplied, then shared out: %s" % [gs.player_skill_xp]
	return "" if gs.effect_floor("husbandry", GUEST) > 0.0 and gs.effect_floor("husbandry", GUEST) == gs.effect_floor("husbandry") \
		else "Each player keeps the old Husbandry effect: %s" % [gs.skill_effect_floor]


func test_the_best_husbandry_sets_the_molt() -> String:
	return _run(_check_molt)


func _check_molt(gs: GameStateScript) -> String:
	if absf(gs.molt_days() - gs.PLAYTEST_MOLT_DAYS) > EPS:
		return "A new farm molts at the base time."
	gs.player_skill_xp[GUEST] = { "husbandry": gs.xp_for_level(60) }
	var guest: float = gs.skill_factor("molt_time", GUEST)
	if guest >= 1.0 or gs.skill_factor("molt_time") != 1.0 or absf(gs.molt_days() - gs.PLAYTEST_MOLT_DAYS * guest) > EPS:
		return "The best Husbandry on the farm sets the molt: %s" % gs.molt_days()
	gs.player_skill_xp["player_1"] = { "husbandry": gs.xp_for_level(99) }
	return "" if absf(gs.molt_days() - gs.PLAYTEST_MOLT_DAYS * gs.skill_factor("molt_time")) < EPS and gs.skill_factor("molt_time") < guest \
		else "The host's Husbandry counts when it is the best."


func test_robot_gates_read_the_acting_player() -> String:
	return _run(_check_gates)


func _check_gates(gs: GameStateScript) -> String:
	gs.player_skill_xp[GUEST] = { "robotics": gs.xp_for_level(15), "calibration": gs.xp_for_level(10) }
	if gs.robot_job_gate("calibrate") == "" or gs.robot_job_gate("calibrate", GUEST) != "":
		return "A job card's gate reads the Robotics of the player who asks."
	if gs.robot_job_gate("collect_spool") == "" or gs.robot_job_gate("collect_spool", GUEST) != "":
		return "COLLECT SPOOL needs the acting player's Robotics 2."
	if gs.robot_card_slots(GUEST) < gs.robot_card_slots() or gs.robot_card_slots() < 1:
		return "Card slots are by the acting player's Robotics."
	return ""


func test_digging_gives_earthworks_once_a_depth() -> String:
	return _run(_check_dig)


func _check_dig(gs: GameStateScript) -> String:
	var cells: Array[Vector2i] = _cells(gs, false)
	if cells.is_empty() or _xp("dig") <= 0:
		return "The test needs a cell with no block to dig, and dig must give XP."
	# One with ground all round that can be dug, to go two steps down.
	var none: Dictionary[Vector2i, int] = {}
	var at: Vector2i = cells[0]
	for candidate: Vector2i in cells:
		if Terrain.neighbors(candidate).all(func(n: Vector2i) -> bool: return Terrain.dig_problem(n, none) == ""):
			at = candidate
			break
	var cell := Vector3i(at.x, 0, at.y)
	if gs.dig(cell, GUEST) != "" or gs.skill_xp("earthworks", GUEST) != _xp("dig") or gs.skill_xp("earthworks") != 0 \
			or gs.action_count("dig", GUEST) != 1 or gs.dug_paid != gs.dug:
		return "The digger gets Earthworks XP: %s" % [gs.player_skill_xp]
	# Filled and dug again, by anyone: no XP. One step deeper than ever: XP.
	if gs.fill(cell, GUEST) != "" or gs.skill_xp("earthworks", GUEST) != _xp("dig") or gs.dug_paid.get(at, 0) != 1:
		return "Filling gives no XP and what was paid stays."
	if gs.dig(cell) != "" or gs.skill_xp("earthworks") != 0 or gs.action_count("dig") != 0:
		return "Digging a filled cell again gives no XP."
	for neighbor: Vector2i in Terrain.neighbors(at):
		gs.dug[neighbor] = 1
	if gs.dig(cell) != "" or gs.skill_xp("earthworks") != _xp("dig") or gs.dug_paid.get(at, 0) != 2:
		return "A step deeper than the cell has been gives XP."
	if gs.dig(Vector3i(at.x, 1, at.y)) == "" or gs.skill_xp("earthworks") != _xp("dig"):
		return "A dig that fails gives none."
	# It is saved, and a bad one is refused.
	var data: Dictionary = gs.farm_to_dict()
	gs.dug_paid.clear()
	if gs.farm_from_dict(data) != "" or gs.dug_paid.get(at, 0) != 2:
		return "What was paid is saved: %s" % [gs.dug_paid]
	for bad: Variant in [[], { at: 0 }, { at: Terrain.MAX_DIG_STEPS + 1 }, { "x": 1 }, { at: 1.5 }]:
		var broken: Dictionary = data.duplicate(true)
		broken["dug_paid"] = bad
		if gs.farm_from_dict(broken) == "":
			return "A bad dug_paid must be refused: %s" % [bad]
	# A save from before: its holes were dug for no XP, and filling them and
	# digging again gives none.
	data.erase("dug_paid")
	if gs.farm_from_dict(data) != "" or gs.dug_paid != gs.dug or gs.dug.get(at, 0) != 2 or gs.dug.size() < 2:
		return "An older save's holes are counted as paid: %s" % [gs.dug_paid]
	return ""


func test_a_block_dug_up_gives_earthworks() -> String:
	return _run(_check_block)


func _check_block(gs: GameStateScript) -> String:
	var cells: Array[Vector2i] = _cells(gs, true)
	if cells.is_empty() or _xp("find_block") <= 0:
		return "The test needs a cell with a block under it, and find_block must give XP."
	var cell := Vector3i(cells[0].x, 0, cells[0].y)
	if gs.dig(cell, GUEST) != "" or gs.skill_xp("earthworks", GUEST) != _xp("dig") + _xp("find_block") or gs.action_count("find_block", GUEST) != 1:
		return "The player who digs a block up gets XP for it: %s" % [gs.player_skill_xp]
	gs.fill(cell)
	gs.dig(cell, GUEST)
	return "" if gs.skill_xp("earthworks", GUEST) == _xp("dig") + _xp("find_block") else "A block is found once."


func test_tilling_gives_the_acting_player_agronomy() -> String:
	return _run(_check_till)


func _check_till(gs: GameStateScript) -> String:
	if not gs.till(Vector3i(1, 0, 1), GUEST) or gs.skill_xp("agronomy", GUEST) != _xp("till") or gs.skill_xp("agronomy") != 0 \
			or gs.skill_xp("field_ops", GUEST) != 0:
		return "Tilling gives the player who tilled Agronomy XP: %s" % [gs.player_skill_xp]
	return "" if gs.crop_xp(GUEST) == 0 else "Tilling is not crop XP, so a later move would leave it."


func test_agronomy_raises_what_lin_pays_the_seller() -> String:
	return _run(_check_price)


func _check_price(gs: GameStateScript) -> String:
	var effect: Dictionary = DataManager.get_record(&"skills", "lin_price", "effects")
	if effect.get("skill") != "agronomy" or float(effect.get("full", 0.0)) >= 0.0:
		return "lin_price is a gain from Agronomy."
	gs.player_skill_xp[GUEST] = { "agronomy": gs.xp_for_level(99) }
	var entry: Dictionary = { "crop_id": gs.current_seed(), "in_spec": true }
	var price: int = gs.crop_sale_price(entry)
	var most: int = roundi(price * (1.0 - float(effect["full"])))
	if gs.lin_pays(entry) != price or gs.lin_pays(entry, GUEST) != most or most <= price:
		return "Lin pays the base price at level 1 and the most at 99: %d, %d" % [gs.lin_pays(entry), gs.lin_pays(entry, GUEST)]
	gs.harvest_bin = [entry.duplicate(), entry.duplicate()]
	if gs.harvest_bin_value() != 2 * price or gs.harvest_bin_value(GUEST) != 2 * most:
		return "The bin is worth more to the better seller."
	var credits: int = gs.credits
	if gs.sell_harvest_to_lin(GUEST) != 2 * most or gs.credits != credits + 2 * most:
		return "The sale pays the seller's price into the shared wallet."
	# The XP is by the price without the gain.
	var rate: float = float(DataManager.get_record(&"skills", "sell_crop", "xp_sources")["xp"])
	return "" if gs.action_xp("sell_crop", GUEST) == roundi(2 * price * rate) else "Sale XP is by the base price: %d" % gs.action_xp("sell_crop", GUEST)


func test_a_guest_brings_and_takes_every_skill() -> String:
	return _run(_check_guest)


func _check_guest(gs: GameStateScript) -> String:
	var key: String = "1".repeat(32)
	var brought: Dictionary = { "robotics": 800, "husbandry": 300, "agronomy": 120, "earthworks": 40, "field_ops": 900 }
	var players: Array[String] = ["player_1"]
	gs.player_skill_xp["player_1"] = { "robotics": gs.xp_for_level(30) }
	var id: String = gs.let_in_guest(key, brought, players)
	if id == "" or gs.player_skill_xp[id] != brought:
		return "A guest brings all seven skills, and none of the host's Robotics: %s" % [gs.player_skill_xp]
	if not ProfileScript.are_skills(brought) or ProfileScript.CURVE != 3 or not 2 in ProfileScript.KNOWN_CURVES:
		return "The guest file holds the new skills and says curve 3; curve 2 is still read."
	# A file from before Agronomy is read as it is: its Field Ops stays whole.
	var before: Dictionary = ProfileScript._parse(('{"key":"%s","skills":{"field_ops":900,"calibration":10},"curve":2}' % key).to_utf8_buffer())
	if before != { "key": key, "skills": { "field_ops": 900, "calibration": 10 } }:
		return "A curve 2 guest file is read as it is: %s" % [before]
	var now: Dictionary = ProfileScript._parse(('{"key":"%s","skills":{"agronomy":5,"earthworks":6,"robotics":7,"husbandry":8},"curve":3}' % key).to_utf8_buffer())
	if now.get("skills") != { "agronomy": 5, "earthworks": 6, "robotics": 7, "husbandry": 8 }:
		return "A curve 3 guest file holds the new skills: %s" % [now]
	for curve: String in ["4", "5", "0", "3.5"]:
		if not ProfileScript._parse(('{"key":"%s","skills":{"agronomy":5},"curve":%s}' % [key, curve]).to_utf8_buffer()).is_empty():
			return "A guest file with curve %s is refused." % curve
	return ""
