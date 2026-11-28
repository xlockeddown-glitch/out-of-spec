extends RefCounted
## The Colony Mine's two quests, Old Props and The Colonist's Set, and the colonist's case
## find on depth 1 (docs/design/zones.md §10.1, §10.3, §13 step 14). Every GameState,
## clock, session, guest flag and ZoneDepth field is restored, and every node is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const ProfileScript: GDScript = preload("res://scripts/autoload/CoopProfile.gd")

const HOST: String = "player_1"
const GUEST_KEY: String = "abcdef0123456789abcdef0123456789"
const SEED: int = 424242
const ZONE: String = "colony_mine"
const GATE_KEY: String = "the_gate_key"
const OLD_PROPS: String = "old_props"
const COLONISTS_SET: String = "colonists_set"
const KEEPSAKE: String = "colonists_case"
const SITTER: String = "lab_sitter"
const SKILL: String = "earthworks"

var _nodes: Array[Node] = []


func _run(body: Callable, quest_ids: Array = []) -> String:
	var saved_day: float = GameClock.elapsed_days
	var saved_players: Array[String] = CoopSession.players.duplicate()
	var saved_guest: bool = FarmCommands.guest
	var table: Dictionary = DataManager._records[&"quests"]
	var shipped: Dictionary = table["quests"]
	if not quest_ids.is_empty():
		var subset: Dictionary = {}
		for id: Variant in quest_ids:
			var found: Dictionary = _shipped(str(id))
			if not found.is_empty():
				subset[StringName(str(id))] = found.duplicate(true)
		table["quests"] = subset
	GameClock.elapsed_days = 0.0
	CoopSession.players.clear()
	FarmCommands.guest = false
	var commands: Node = CommandsScript.new()
	commands.state = _farm()
	_nodes.append(commands)
	var out: Variant = body.call(commands)
	for node: Node in _nodes:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
	_nodes.clear()
	table["quests"] = shipped
	FarmCommands.guest = saved_guest
	CoopSession.players.assign(saved_players)
	GameClock.elapsed_days = saved_day
	return out if out is String else "The test stopped early or did not return a String."


func _farm(seed_value: int = SEED) -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(seed_value)
	gs.reset_credibility()
	gs.local_player_id = HOST
	_nodes.append(gs)
	return gs


func _shipped(id: String) -> Dictionary:
	for quest: Dictionary in QuestEngine.quests():
		if str(quest.get("id", "")) == id:
			return quest
	return {}


func _morning(gs: GameStateScript, day: int, present: Array[String] = []) -> void:
	GameClock.elapsed_days = float(day - 1)
	if present.is_empty():
		gs.update_quests()
	else:
		gs.update_quests(present)


func _rover_at(gs: GameStateScript, depth: int, at: Vector3, who: String = HOST) -> void:
	gs.rover_zone = ZONE
	gs.rover_lent = true
	gs.rover_depth = depth
	gs.rover_transforms[gs.TUNNEL_ROVER] = Transform3D(Basis.IDENTITY, at)
	gs.player_places[who] = [ZONE, depth]


func _lines(gs: GameStateScript, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


func _case_in(layout_data: Dictionary) -> Dictionary:
	for find: Dictionary in layout_data.get("finds", []):
		if str(find.get("kind", "")) == MineDepth.CASE:
			return find
	return {}


func _case_days(seed_value: int, needed: int, start_day: int = 1) -> Array[int]:
	var out: Array[int] = []
	for day: int in range(start_day, start_day + 120):
		var data: Dictionary = MineDepth.layout(seed_value, 1, day)
		if not _case_in(data).is_empty():
			out.append(day)
			if out.size() >= needed:
				break
	return out


func _blocked_case_day(seed_value: int) -> int:
	for day: int in range(1, 120):
		var data: Dictionary = MineDepth.layout(seed_value, 1, day)
		var found: Dictionary = _case_in(data)
		if not found.is_empty() and MineDepth.blocked_problem(data, str(found["id"])) != "":
			return day
	return -1


func _mark_gate_key_done(gs: GameStateScript, day: int = 1) -> void:
	gs.quest_state[GATE_KEY] = {
		"accepted": day,
		"steps_done": ["prove"],
		"base": {},
		"shown": {},
		"players": [HOST],
		"done": day,
	}
	gs.open_mine_gate()


func _has_collision(node: Node) -> bool:
	if node is CollisionObject3D:
		return true
	for child: Node in node.get_children():
		if _has_collision(child):
			return true
	return false


func _count_type(node: Node, class_text: String) -> int:
	var total: int = 1 if node.get_class() == class_text else 0
	for child: Node in node.get_children():
		total += _count_type(child, class_text)
	return total


# --- Shipped data & repo checks -----------------------------------------------------

func test_both_quests_keepsake_and_dialogue_load_and_validate() -> String:
	if CoopSession.PROTOCOL != 46:
		return "Mine quests add no command or synced field; PROTOCOL must be 46 (got %d)." % CoopSession.PROTOCOL
	var old_q: Dictionary = _shipped(OLD_PROPS)
	var set_q: Dictionary = _shipped(COLONISTS_SET)
	if old_q.is_empty() or set_q.is_empty():
		return "Both old_props and colonists_set must ship in data/quests.json."
	for quest: Dictionary in QuestEngine.quests():
		var why: String = QuestEngine.data_problem(quest)
		if why != "":
			return "%s failed data_problem: %s" % [quest.get("id", "?"), why]
		for path_key: String in ["offer_line"]:
			var p: String = str(quest.get(path_key, ""))
			if p.contains("/") and QuestEngine.phone_line(p) == p:
				return "%s %s did not resolve: %s" % [quest["id"], path_key, p]
		var done_path: String = str((quest.get("rewards", {}) as Dictionary).get("phone", ""))
		if done_path.contains("/") and QuestEngine.phone_line(done_path) == done_path:
			return "%s rewards.phone did not resolve: %s" % [quest["id"], done_path]

	if old_q["kind"] != "lab" or old_q["giver"] != "bram" or old_q["scope"] != "farm" or old_q["zone"] != ZONE:
		return "old_props metadata mismatch: %s" % [old_q]
	var old_gates: Dictionary = old_q["gates"]
	if int(old_gates.get("lab_level", 0)) != 12 or str(old_gates.get("quest_done", "")) != GATE_KEY:
		return "old_props must gate on lab level 12 and the_gate_key done: %s" % [old_gates]
	var old_steps: Array = old_q["steps"]
	if old_steps.size() != 1 or old_steps[0]["check"] != "counter" or old_steps[0]["counter"] != "shore_room" \
			or old_steps[0].get("whose", "") != "farm" or int(old_steps[0].get("at_least", 0)) != 2:
		return "old_props step must count two farm shorings (no lift step yet): %s" % [old_steps]
	var old_rewards: Dictionary = old_q["rewards"]
	if int(old_rewards.get("lab_xp", 0)) != 300 or str(old_rewards.get("one_use", "")) != SITTER:
		return "old_props must pay 300 lab_xp and lab_sitter: %s" % [old_rewards]

	if set_q["kind"] != "personal" or set_q["giver"] != "bram" or set_q["scope"] != "player" or set_q["zone"] != ZONE:
		return "colonists_set metadata mismatch: %s" % [set_q]
	if set_q["any_gate"] != [{ "skill": { "id": SKILL, "level": 5.0 } }, { "quest_done": GATE_KEY }]:
		return "colonists_set any_gate must be Earthworks 5 or the_gate_key done: %s" % [set_q["any_gate"]]
	var set_steps: Array = set_q["steps"]
	if set_steps.size() != 1 or set_steps[0]["check"] != "counter" or set_steps[0]["counter"] != "open_colonist_case" \
			or set_steps[0].has("whose") or int(set_steps[0].get("at_least", 0)) != 3:
		return "colonists_set step must count 3 per-player cases: %s" % [set_steps]
	var set_rewards: Dictionary = set_q["rewards"]
	if int(set_rewards.get("xp_earthworks", 0)) != 150 or str(set_rewards.get("keepsake", "")) != KEEPSAKE:
		return "colonists_set must pay 150 xp_earthworks and colonists_case keepsake: %s" % [set_rewards]
	if QuestEngine.keepsake_name(KEEPSAKE) == "" or QuestEngine.keepsake_text(KEEPSAKE) == "":
		return "colonists_case keepsake must have a display_name and text."
	return ""


# --- Gates --------------------------------------------------------------------------

func test_old_props_is_offered_only_once_lab_is_twelve_and_the_gate_key_is_done() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		gs.lab_xp = gs.xp_for_level(11)
		_morning(gs, 2)
		if gs.quest_state.has(OLD_PROPS):
			return "Offered at lab 11 without the Gate Key."
		gs.lab_xp = gs.xp_for_level(12)
		_morning(gs, 3)
		if gs.quest_state.has(OLD_PROPS):
			return "Offered at lab 12 before the Gate Key is done."
		var only_key: GameStateScript = _farm()
		only_key.lab_xp = only_key.xp_for_level(11)
		_mark_gate_key_done(only_key, 1)
		_morning(only_key, 2)
		if only_key.quest_state.has(OLD_PROPS):
			return "Offered with the Gate Key done while still at lab 11."
		_mark_gate_key_done(gs, 3)
		_morning(gs, 4)
		if not gs.quest_state.has(OLD_PROPS) or QuestEngine.is_done(gs, OLD_PROPS):
			return "Not offered once lab is 12 and the Gate Key is done: %s" % [gs.quest_state]
		var offer_words: String = QuestEngine.phone_line(str(_shipped(OLD_PROPS)["offer_line"]))
		if _lines(gs, offer_words) != 1:
			return "Bram's offer line was not posted once: %s" % [gs.phone_log]
		return "", [GATE_KEY, OLD_PROPS])


func test_colonists_set_is_offered_at_earthworks_five_or_once_the_gate_key_is_done() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		var guest_id: String = gs.let_in_guest(GUEST_KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		var both: Array[String] = [HOST, guest_id]
		CoopSession.players.assign(both)
		gs.player_skill_xp[HOST] = { SKILL: gs.xp_for_level(5) - 1 }
		_morning(gs, 2, both)
		if not gs.player_quest_state.is_empty():
			return "Offered at Earthworks 4 before the Gate Key is done: %s" % [gs.player_quest_state]
		gs.player_skill_xp[HOST] = { SKILL: gs.xp_for_level(5) }
		_morning(gs, 3, both)
		var host_own: Dictionary = gs.player_quest_state.get(HOST, {})
		var guest_own: Dictionary = gs.player_quest_state.get(guest_id, {})
		if not host_own.has(COLONISTS_SET) or guest_own.has(COLONISTS_SET):
			return "Earthworks 5 must open colonists_set for that player alone: %s" % [gs.player_quest_state]
		_mark_gate_key_done(gs, 3)
		_morning(gs, 4, both)
		guest_own = gs.player_quest_state.get(guest_id, {})
		if not guest_own.has(COLONISTS_SET):
			return "Finishing the Gate Key must open colonists_set for a player below Earthworks 5."
		return "", [GATE_KEY, COLONISTS_SET])


# --- Old Props: shoring & rewards ---------------------------------------------------

func test_shoring_counts_for_old_props_refusals_do_not_and_finishing_pays_rewards() -> String:
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		var guest_id: String = gs.let_in_guest(GUEST_KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		var both: Array[String] = [HOST, guest_id]
		CoopSession.players.assign(both)
		gs.lab_xp = gs.xp_for_level(12)
		_mark_gate_key_done(gs, 1)
		var day: int = 4
		_morning(gs, day, both)
		if not gs.quest_state.has(OLD_PROPS):
			return "Setup: Old Props was not offered."

		var data: Dictionary = MineDepth.layout(SEED, 1, day)
		var fall: Dictionary = data["rockfalls"][0]
		var fall_id: String = str(fall["id"])
		var fall_pos: Vector3 = MineDepth.rockfall_position(fall)
		_rover_at(gs, 1, fall_pos, HOST)

		# Refusals: no props, stale day, unknown rockfall, too far, wrong depth.
		commands.execute(HOST, &"shore_room", [fall_id, day])
		gs.mine_props = 3
		commands.execute(HOST, &"shore_room", [fall_id, day - 1])
		commands.execute(HOST, &"shore_room", ["r9", day])
		_rover_at(gs, 1, fall_pos + Vector3(25.0, 0.0, 0.0), HOST)
		commands.execute(HOST, &"shore_room", [fall_id, day])
		_rover_at(gs, 0, fall_pos, HOST)
		commands.execute(HOST, &"shore_room", [fall_id, day])
		if gs.action_count(gs.SHORE_COUNT, HOST) != 0 or not (gs.quest_state[OLD_PROPS]["steps_done"] as Array).is_empty():
			return "Refused shorings must not count: count %d, state %s" % [gs.action_count(gs.SHORE_COUNT, HOST), gs.quest_state[OLD_PROPS]]

		# First shoring by host; repeated attempt on the same shored room is refused.
		_rover_at(gs, 1, fall_pos, HOST)
		var first_shore: Variant = commands.execute(HOST, &"shore_room", [fall_id, day])
		var repeat_shore: Variant = commands.execute(HOST, &"shore_room", [fall_id, day])
		if first_shore != "" or repeat_shore == "" or gs.action_count(gs.SHORE_COUNT, HOST) != 1:
			return "First shoring must count once and repeat must refuse: '%s', '%s', count %d" % [first_shore, repeat_shore, gs.action_count(gs.SHORE_COUNT, HOST)]
		if QuestEngine.is_done(gs, OLD_PROPS) or _lines(gs, "QUEST Old Props: 1 of 2.") != 1:
			return "One shoring is 1 of 2: %s" % [gs.phone_log]

		# Second shoring on the next day by the guest: farm-wide counter finishes Old Props.
		var next_day: int = day + 1
		GameClock.elapsed_days = float(next_day - 1)
		var next_data: Dictionary = MineDepth.layout(SEED, 1, next_day)
		var next_fall: Dictionary = next_data["rockfalls"][0]
		_rover_at(gs, 1, MineDepth.rockfall_position(next_fall), guest_id)
		var lab_before: int = gs.lab_xp
		var second_shore: Variant = commands.execute(guest_id, &"shore_room", [str(next_fall["id"]), next_day])
		if second_shore != "" or not QuestEngine.is_done(gs, OLD_PROPS):
			return "Second shoring by a friend must finish Old Props: '%s', %s" % [second_shore, gs.quest_state[OLD_PROPS]]
		if gs.lab_xp != lab_before + 300 or gs.one_use_count(SITTER) != 1:
			return "Old Props must pay 300 lab XP and 1 lab_sitter day: +%d XP, %d sitter" % [gs.lab_xp - lab_before, gs.one_use_count(SITTER)]
		var done_words: String = QuestEngine.phone_line(str(_shipped(OLD_PROPS)["rewards"]["phone"]))
		if _lines(gs, "QUEST DONE: Old Props.") != 1 or _lines(gs, done_words) != 1 or _lines(gs, "Dana Pike will mind the lab") != 1:
			return "Finishing must post QUEST DONE, sitter held line, and Bram's line: %s" % [gs.phone_log]
		return "", [GATE_KEY, OLD_PROPS])


# --- Colonist's case: layout & rockfall blocking ------------------------------------

func test_case_is_fixed_per_seed_and_day_in_a_side_room_and_blocked_by_rockfall() -> String:
	var with_case: int = 0
	var without_case: int = 0
	for day: int in range(1, 61):
		var a: Dictionary = MineDepth.layout(SEED, 1, day)
		var b: Dictionary = MineDepth.layout(SEED, 1, day)
		if var_to_str(a["finds"]) != var_to_str(b["finds"]):
			return "Day %d layout finds differed across calls." % day
		var cases: Array = []
		for find: Dictionary in a["finds"]:
			if str(find["kind"]) == MineDepth.CASE:
				cases.append(find)
		if cases.size() > 1:
			return "Day %d spawned %d cases (at most 1 allowed)." % [day, cases.size()]
		if cases.is_empty():
			without_case += 1
		else:
			with_case += 1
			var c: Dictionary = cases[0]
			if int(c["room"]) < 0 or int(c["room"]) >= MineDepth.ROOMS.size():
				return "Day %d placed a case outside the side rooms: %s" % [day, c]
			var seen: Array[Vector2i] = ZoneDepth.reachable(a["grid"], ZoneDepth.START_CELL)
			if not (c["cell"] as Vector2i) in seen:
				return "Day %d placed an unreachable case: %s" % [day, c]
	if with_case < 10 or without_case < 10:
		return "Cases must appear on only some days (got %d with, %d without over 60 days)." % [with_case, without_case]

	var blocked_day: int = _blocked_case_day(SEED)
	if blocked_day < 0:
		return "Expected at least one day where a rockfall blocks the case."
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		GameClock.elapsed_days = float(blocked_day - 1)
		var data: Dictionary = MineDepth.layout(SEED, 1, blocked_day)
		var case_find: Dictionary = _case_in(data)
		var case_id: String = str(case_find["id"])
		var case_pos: Vector3 = TunnelRock.at_in(data["grid"], case_find["cell"])
		_rover_at(gs, 1, case_pos, HOST)
		var refused: String = gs.take_find(case_id, blocked_day, HOST)
		if refused == "" or not refused.contains("rockfall"):
			return "A case in a buried room must be refused for the rockfall: '%s'" % refused
		if not gs.found_blocks.is_empty() or gs.action_count(gs.CASE_COUNT, HOST) != 0:
			return "A refused case must add no block and no count."
		var fall_id: String = MineDepth.ROCKFALL_IDS[int(case_find["room"])]
		gs.rooms_shored = ZoneDepth.with_taken(gs.rooms_shored, ZONE, blocked_day, fall_id)
		var ok: String = gs.take_find(case_id, blocked_day, HOST)
		if ok != "" or gs.found_blocks.size() != 1 or gs.action_count(gs.CASE_COUNT, HOST) != 1:
			return "Once shored, the case must open and give one block: '%s'" % ok
		return "", [])


# --- Taking a case: deterministic unfound block & fallback --------------------------

func test_taking_a_case_adds_the_same_unfound_block_and_counts_blocks_found() -> String:
	var days: Array[int] = _case_days(SEED, 2)
	if days.size() < 2:
		return "Need two case days for determinism check."
	return _run(func(commands: Node) -> String:
		var all_cells: Array[Vector2i] = MineDepth.block_cells(SEED)
		if all_cells.size() < 5:
			return "Expected buried blocks on seed %d." % SEED
		# Pre-populate two blocks in different insertion orders on two farms with the same seed.
		var a: GameStateScript = commands.state
		var b: GameStateScript = _farm(SEED)
		a._find_block_at(all_cells[0], HOST)
		a._find_block_at(all_cells[2], HOST)
		b._find_block_at(all_cells[2], HOST)
		b._find_block_at(all_cells[0], HOST)

		# Open missing_blocks's counter check value before and after, plus blocks_changed & XP.
		var step: Dictionary = { "id": "find", "check": "counter", "counter": QuestEngine.BLOCKS_FOUND }
		var before_count: int = QuestEngine.check_value(a, step, [HOST] as Array[String])
		var before_xp: int = a.skill_xp(SKILL, HOST)
		var signals: Array[int] = [0]
		a.blocks_changed.connect(func() -> void: signals[0] += 1)

		# Farm A takes a case on days[0]; Farm B takes a case on days[1].
		GameClock.elapsed_days = float(days[0] - 1)
		var layout_a: Dictionary = MineDepth.layout(SEED, 1, days[0], MineDepth.ROCKFALL_IDS)
		gs_clear_shored(a, days[0])
		var case_a: Dictionary = _case_in(layout_a)
		_rover_at(a, 1, TunnelRock.at_in(layout_a["grid"], case_a["cell"]), HOST)
		var reply_a: String = a.take_find(str(case_a["id"]), days[0], HOST)

		GameClock.elapsed_days = float(days[1] - 1)
		var layout_b: Dictionary = MineDepth.layout(SEED, 1, days[1], MineDepth.ROCKFALL_IDS)
		gs_clear_shored(b, days[1])
		var case_b: Dictionary = _case_in(layout_b)
		_rover_at(b, 1, TunnelRock.at_in(layout_b["grid"], case_b["cell"]), HOST)
		var reply_b: String = b.take_find(str(case_b["id"]), days[1], HOST)

		if reply_a != "" or reply_b != "":
			return "Case with unfound blocks left must succeed with empty reply: '%s', '%s'" % [reply_a, reply_b]
		if a.found_blocks.size() != 3 or b.found_blocks.size() != 3:
			return "Each case must add exactly one block: %d, %d" % [a.found_blocks.size(), b.found_blocks.size()]
		if not a.found_blocks.has(all_cells[1]) or not b.found_blocks.has(all_cells[1]):
			return "Same seed and found set must pick the exact same unfound block (%s): %s vs %s" % [all_cells[1], a.found_blocks.keys(), b.found_blocks.keys()]
		if signals[0] != 1:
			return "blocks_changed must emit once when a case gives a block (got %d)." % signals[0]
		if QuestEngine.check_value(a, step, [HOST] as Array[String]) != before_count + 1:
			return "blocks_found counter must grow by 1."
		if a.skill_xp(SKILL, HOST) <= before_xp or a.action_count("find_block", HOST) != 3:
			return "Taking a case must reuse the dig block path (find_block XP and count)."
		if a.farm_dict_problem(a.farm_to_dict()) != "":
			return "Saved farm with a Mine-found block must validate: %s" % a.farm_dict_problem(a.farm_to_dict())
		return "", [])


func gs_clear_shored(gs: GameStateScript, day: int) -> void:
	for id: String in MineDepth.ROCKFALL_IDS:
		gs.rooms_shored = ZoneDepth.with_taken(gs.rooms_shored, ZONE, day, id)


func test_with_every_block_found_a_case_pays_fallback_credits_and_still_counts() -> String:
	var days: Array[int] = _case_days(SEED, 1)
	if days.is_empty():
		return "Need one case day."
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		for cell: Vector2i in MineDepth.block_cells(SEED):
			gs.found_blocks[cell] = true
		var total_blocks: int = gs.found_blocks.size()
		var day: int = days[0]
		GameClock.elapsed_days = float(day - 1)
		gs_clear_shored(gs, day)
		var data: Dictionary = MineDepth.layout(SEED, 1, day, MineDepth.ROCKFALL_IDS)
		var case_find: Dictionary = _case_in(data)
		_rover_at(gs, 1, TunnelRock.at_in(data["grid"], case_find["cell"]), HOST)

		var signals: Array[int] = [0]
		gs.blocks_changed.connect(func() -> void: signals[0] += 1)
		var credits_before: int = gs.credits
		var reply: Variant = commands.execute(HOST, &"take_find", [str(case_find["id"]), day])
		if reply != MineDepth.case_fallback_reply() or not str(reply).contains("credits"):
			return "Fallback reply must explain that every block is found and name credits: '%s'" % [reply]
		if gs.credits != credits_before + MineDepth.CASE_FALLBACK_CREDITS:
			return "Fallback case must pay %d credits (got +%d)." % [MineDepth.CASE_FALLBACK_CREDITS, gs.credits - credits_before]
		if gs.found_blocks.size() != total_blocks or signals[0] != 0:
			return "Fallback case must not add a block or emit blocks_changed."
		if gs.action_count(gs.CASE_COUNT, HOST) != 1:
			return "Fallback case must still increment open_colonist_case."
		var second: Variant = commands.execute(HOST, &"take_find", [str(case_find["id"]), day])
		if second == "" or second == MineDepth.case_fallback_reply() or gs.credits != credits_before + MineDepth.CASE_FALLBACK_CREDITS:
			return "Taking the same fallback case twice must be refused: '%s'" % [second]
		return "", [])


# --- The Colonist's Set: per-player completion & keepsake ---------------------------

func test_three_cases_finish_colonists_set_for_taker_only_and_pay_keepsake() -> String:
	var days: Array[int] = _case_days(SEED, 4, 2)
	if days.size() < 4:
		return "Need four case days."
	return _run(func(commands: Node) -> String:
		var gs: GameStateScript = commands.state
		var guest_id: String = gs.let_in_guest(GUEST_KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
		var both: Array[String] = [HOST, guest_id]
		CoopSession.players.assign(both)
		_mark_gate_key_done(gs, 1)
		_morning(gs, 2, both)
		if not (gs.player_quest_state.get(HOST, {}) as Dictionary).has(COLONISTS_SET) \
				or not (gs.player_quest_state.get(guest_id, {}) as Dictionary).has(COLONISTS_SET):
			return "Both players must hold colonists_set."

		# Guest takes 1 case on days[0]: does not advance host's count.
		GameClock.elapsed_days = float(days[0] - 1)
		gs_clear_shored(gs, days[0])
		var d0: Dictionary = MineDepth.layout(SEED, 1, days[0], MineDepth.ROCKFALL_IDS)
		var c0: Dictionary = _case_in(d0)
		_rover_at(gs, 1, TunnelRock.at_in(d0["grid"], c0["cell"]), guest_id)
		if commands.execute(guest_id, &"take_find", [str(c0["id"]), days[0]]) != "":
			return "Guest failed to open first case."
		if gs.action_count(gs.CASE_COUNT, guest_id) != 1 or gs.action_count(gs.CASE_COUNT, HOST) != 0:
			return "Guest's case counted for the wrong player."

		# Host takes 2 normal cases (days[1], days[2]), then 1 fallback case (days[3]).
		for i: int in [1, 2]:
			var d_i: int = days[i]
			GameClock.elapsed_days = float(d_i - 1)
			gs_clear_shored(gs, d_i)
			var lay: Dictionary = MineDepth.layout(SEED, 1, d_i, MineDepth.ROCKFALL_IDS)
			var cf: Dictionary = _case_in(lay)
			_rover_at(gs, 1, TunnelRock.at_in(lay["grid"], cf["cell"]), HOST)
			if commands.execute(HOST, &"take_find", [str(cf["id"]), d_i]) != "":
				return "Host failed to open case %d." % i
		if QuestEngine.is_done(gs, COLONISTS_SET, HOST) or QuestEngine.is_done(gs, COLONISTS_SET, guest_id):
			return "Two cases must not finish colonists_set yet."

		for cell: Vector2i in MineDepth.block_cells(SEED):
			gs.found_blocks[cell] = true
		var xp_before_finish: int = gs.skill_xp(SKILL, HOST)
		var guest_xp_before: int = gs.skill_xp(SKILL, guest_id)
		var last_day: int = days[3]
		GameClock.elapsed_days = float(last_day - 1)
		gs_clear_shored(gs, last_day)
		var last_lay: Dictionary = MineDepth.layout(SEED, 1, last_day, MineDepth.ROCKFALL_IDS)
		var last_cf: Dictionary = _case_in(last_lay)
		_rover_at(gs, 1, TunnelRock.at_in(last_lay["grid"], last_cf["cell"]), HOST)
		var last_reply: Variant = commands.execute(HOST, &"take_find", [str(last_cf["id"]), last_day])
		if last_reply != MineDepth.case_fallback_reply():
			return "Expected fallback reply on third case, got '%s'." % [last_reply]

		if not QuestEngine.is_done(gs, COLONISTS_SET, HOST) or QuestEngine.is_done(gs, COLONISTS_SET, guest_id):
			return "Three cases must finish colonists_set for the taker only."
		if gs.skill_xp(SKILL, HOST) != xp_before_finish + 150 or gs.skill_xp(SKILL, guest_id) != guest_xp_before:
			return "Taker alone must gain 150 Earthworks XP (+%d host, +%d guest)." % [gs.skill_xp(SKILL, HOST) - xp_before_finish, gs.skill_xp(SKILL, guest_id) - guest_xp_before]
		if QuestEngine.keepsakes_of(gs, HOST) != [KEEPSAKE] or not QuestEngine.keepsakes_of(gs, guest_id).is_empty():
			return "Taker alone must hold colonists_case keepsake: host %s, guest %s" % [QuestEngine.keepsakes_of(gs, HOST), QuestEngine.keepsakes_of(gs, guest_id)]
		var done_words: String = QuestEngine.phone_line(str(_shipped(COLONISTS_SET)["rewards"]["phone"]))
		if _lines(gs, "QUEST DONE: The Colonist's Set.") != 1 or _lines(gs, done_words) != 1:
			return "Phone must record QUEST DONE and Bram's done line: %s" % [gs.phone_log]

		var saved: Dictionary = bytes_to_var(var_to_bytes(gs.farm_to_dict()))
		var reloaded: GameStateScript = _farm(SEED)
		if reloaded.farm_dict_problem(saved) != "" or reloaded.farm_from_dict(saved) != "":
			return "Saved farm with finished colonists_set failed to load: %s" % reloaded.farm_dict_problem(saved)
		if QuestEngine.keepsakes_of(reloaded, HOST) != [KEEPSAKE] or QuestEngine.is_done(reloaded, COLONISTS_SET, guest_id):
			return "Reloaded farm lost keepsake or guest quest separation."
		return "", [GATE_KEY, COLONISTS_SET])


# --- Scene prop & notice board ------------------------------------------------------

func test_colony_mine_scene_draws_case_without_colliders_and_lists_mine_quests() -> String:
	var days: Array[int] = _case_days(SEED, 1)
	if days.is_empty():
		return "Need one case day."
	var day: int = days[0]
	var saved_day: float = GameClock.elapsed_days
	var saved_state: Dictionary = {
		"rover_zone": GameState.rover_zone,
		"rover_depth": GameState.rover_depth,
		"rover_lent": GameState.rover_lent,
		"world_seed": GameState.world_seed,
		"rooms_shored": GameState.rooms_shored.duplicate(true),
		"finds_taken": GameState.finds_taken.duplicate(true),
		"local_zone": ZoneDepth.local_zone,
		"local_depth": ZoneDepth.local_depth,
		"local_layout": ZoneDepth.local_layout.duplicate(true),
		"arrive_pending": ZoneDepth.arrive_pending,
	}
	GameClock.elapsed_days = float(day - 1)
	GameState.world_seed = SEED
	GameState.rover_zone = ZONE
	GameState.rover_depth = 1
	GameState.rover_lent = true
	GameState.finds_taken = {}
	GameState.rooms_shored = {}

	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var packed: PackedScene = load("res://scenes/colony_mine.tscn") as PackedScene
	var scene: ColonyMine = packed.instantiate() as ColonyMine
	root.add_child(scene)

	var problem: String = ""
	var case_find: Dictionary = _case_in(ZoneDepth.local_layout)
	var case_id: String = str(case_find.get("id", ""))
	var case_node: Node3D = scene._depth_props.find_node(case_id)
	if case_node == null or not case_node.visible:
		problem = "ColonyMine depth 1 did not build a visible node for case %s." % case_id
	elif _count_type(case_node, "MeshInstance3D") < 6 or case_node.get_node_or_null("CaseLatch") == null or _count_type(case_node, "Label3D") != 1:
		problem = "Case node must draw crate meshes, CaseLatch, and a label."
	elif _has_collision(case_node):
		problem = "Colonist's case visual prop must have zero colliders."
	else:
		GameState.finds_taken = ZoneDepth.with_taken(GameState.finds_taken, ZONE, day, case_id)
		GameState.finds_changed.emit()
		if case_node.visible:
			problem = "Taken colonist's case stayed visible after finds_changed."

	root.remove_child(scene)
	scene.free()

	if problem == "":
		var board_lines: Array[String] = MineDepth.board_lines(QuestEngine.quests(), {}, {})
		var joined: String = "\n".join(board_lines)
		if not joined.contains("The Gate Key") or not joined.contains("Old Props") or not joined.contains("The Colonist's Set"):
			problem = "Mine notice board must list all three Mine quests: %s" % [board_lines]

	GameState.rover_zone = str(saved_state["rover_zone"])
	GameState.rover_depth = int(saved_state["rover_depth"])
	GameState.rover_lent = bool(saved_state["rover_lent"])
	GameState.world_seed = int(saved_state["world_seed"])
	GameState.rooms_shored = (saved_state["rooms_shored"] as Dictionary).duplicate(true)
	GameState.finds_taken = (saved_state["finds_taken"] as Dictionary).duplicate(true)
	ZoneDepth.local_zone = str(saved_state["local_zone"])
	ZoneDepth.local_depth = int(saved_state["local_depth"])
	ZoneDepth.local_layout = (saved_state["local_layout"] as Dictionary).duplicate(true)
	ZoneDepth.arrive_pending = bool(saved_state["arrive_pending"])
	GameClock.elapsed_days = saved_day
	return problem
