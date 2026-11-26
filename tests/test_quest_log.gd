extends RefCounted
## The quest log (build order step 7 of docs/design/quests_levels_story.md): what
## the QUESTS view lists for a player, from the quests' data and what the farm
## keeps for them. GameClock, SaveGame.farm_open and the guest flag are put back;
## every node is freed.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const ProfileScript: GDScript = preload("res://scripts/autoload/CoopProfile.gd")
const KEY: String = "abcdef0123456789abcdef0123456789"
const HOST: String = "player_1"
const DAY: int = 4


func _quest(id: String, kind: String, scope: String, steps: Array, giver: String = "lin") -> Dictionary:
	return { "id": id, "kind": kind, "giver": giver, "title": "Title of %s" % id, "scope": scope, "gates": {},
		"offer": { "when": "always" }, "steps": steps, "rewards": {} }


func _step(id: String, check: String = "flag", more: Dictionary = {}) -> Dictionary:
	return { "id": id, "text": "Do %s." % id, "check": check }.merged(more)


func _entry(steps_done: Array = [], done: int = -1, shown: Dictionary = {}, accepted: int = 1) -> Dictionary:
	return { "accepted": accepted, "steps_done": steps_done, "base": {}, "shown": shown, "players": [], "done": done }


func _ids(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> String: return row["id"])


func test_open_quests_are_listed_with_giver_title_and_next_step() -> String:
	var quests: Array = [
		_quest("lab_q", "lab", "farm", [_step("a"), _step("b")], "orin"),
		_quest("story_q", "story", "farm", [_step("a"), _step("b"), _step("c")]),
		_quest("own_q", "personal", "player", [_step("dig", "counter", { "counter": "dig", "at_least": 3 })], "orin"),
		_quest("not_offered", "story", "farm", [_step("a")]),
	]
	var farm_state: Dictionary = { "lab_q": _entry(), "story_q": _entry(["a"]), "own_q": _entry(["dig"], 2), "gone_from_data": _entry() }
	var own_state: Dictionary = { "own_q": _entry([], -1, { "dig": 2 }) }
	var lists: Dictionary = QuestLog.build(quests, farm_state, own_state)
	var open: Array = lists[QuestLog.OPEN]
	# Story first, then lab, then the player's own: by kind, not by the file.
	if _ids(open) != ["story_q", "lab_q", "own_q"] or not (lists[QuestLog.DONE] as Array).is_empty():
		return "Got %s" % [lists]
	if open[0] != { "id": "story_q", "kind": "story", "giver": "LIN", "title": "Title of story_q", "step": "Do b.", "have": 0, "need": 0, "day": -1 }:
		return "The row is the giver, the title and the first step not done: %s" % [open[0]]
	if QuestLog.title_text(open[0]) != "LIN: Title of story_q  (story)" or QuestLog.step_text(open[0]) != "Do b.":
		return "Got '%s' and '%s'" % [QuestLog.title_text(open[0]), QuestLog.step_text(open[0])]
	# A player's own quest is read from their own entries, never the farm's.
	if open[2]["have"] != 2 or open[2]["need"] != 3 or QuestLog.step_text(open[2]) != "Do dig.  2 of 3":
		return "A counting step says how far it is: %s" % [open[2]]
	return ""


func test_done_quests_are_listed_apart() -> String:
	var closed_q: Dictionary = _quest("closed_q", "lab", "farm", [_step("a")])
	closed_q["closed_when"] = { "check": "flag" }
	var quests: Array = [
		_quest("done_q", "lab", "farm", [_step("a")]),
		closed_q,
		_quest("open_q", "lab", "farm", [_step("a")]),
		_quest("brought_q", "personal", "player", [_step("a"), _step("b")]),
	]
	var farm_state: Dictionary = { "done_q": _entry(["a"], 3), "closed_q": _entry([], 1), "open_q": _entry() }
	# Done on another farm: done here with no step ticked (QuestEngine.take_brought).
	var own_state: Dictionary = { "brought_q": _entry([], 2) }
	var lists: Dictionary = QuestLog.build(quests, farm_state, own_state)
	if _ids(lists[QuestLog.OPEN]) != ["open_q"] or _ids(lists[QuestLog.DONE]) != ["done_q", "brought_q"]:
		return "A closed quest is in neither list; one done elsewhere is done: %s" % [lists]
	var row: Dictionary = (lists[QuestLog.DONE] as Array)[0]
	return "" if row["step"] == "" and row["need"] == 0 else "A done row has no step: %s" % [row]


func test_only_the_latest_ask_is_listed() -> String:
	var quests: Array = [
		_quest("ask_a", "daily", "player", [_step("till", "counter", { "counter": "till", "at_least": 6 })], "orin"),
		_quest("ask_b", "daily", "player", [_step("mine", "counter", { "counter": "mine_fissure", "at_least": 2 })], "bram"),
	]
	var own_state: Dictionary = { "ask_a": _entry([], -1, { "till": 4 }, DAY), "ask_b": _entry(["mine"], DAY - 1, {}, DAY - 1) }
	var lists: Dictionary = QuestLog.build(quests, {}, own_state)
	var open: Array = lists[QuestLog.OPEN]
	if _ids(open) != ["ask_a"] or not (lists[QuestLog.DONE] as Array).is_empty():
		return "The older ask is gone, done or not: %s" % [lists]
	if QuestLog.title_text(open[0]) != "ORIN: Title of ask_a  (today)" or QuestLog.step_text(open[0]) != "Do till.  4 of 6":
		return "Got '%s' and '%s'" % [QuestLog.title_text(open[0]), QuestLog.step_text(open[0])]
	own_state["ask_a"] = _entry(["till"], DAY, { "till": 6 }, DAY)
	lists = QuestLog.build(quests, {}, own_state)
	return "" if _ids(lists[QuestLog.DONE]) == ["ask_a"] and (lists[QuestLog.OPEN] as Array).is_empty() else "The ask of today, done, is with the done: %s" % [lists]


## A guest's clock may run behind or ahead of the host's: the ask listed is the
## latest in the player's own entries, whatever day the guest thinks it is.
func test_the_ask_does_not_depend_on_the_clock() -> String:
	var quests: Array = [_quest("ask_a", "daily", "player", [_step("a")]), _quest("ask_b", "daily", "player", [_step("a")])]
	var own_state: Dictionary = { "ask_a": _entry([], -1, {}, 7), "ask_b": _entry([], -1, {}, 8) }
	var elapsed: float = GameClock.elapsed_days
	for day: int in [6, 7, 8, 9]:
		GameClock.elapsed_days = float(day)
		if _ids(QuestLog.build(quests, {}, own_state)[QuestLog.OPEN]) != ["ask_b"]:
			GameClock.elapsed_days = elapsed
			return "On day %d the latest ask is listed." % day
	GameClock.elapsed_days = elapsed
	own_state.erase("ask_b")
	return "" if _ids(QuestLog.build(quests, {}, own_state)[QuestLog.OPEN]) == ["ask_a"] else "With one ask, it is the one."


## Closed with nothing paid is in neither list, a player's own quest as well as
## the farm's; a player's quest done with a step ticked is done.
func test_a_player_quest_closed_with_nothing_paid_is_not_done() -> String:
	var shut: Dictionary = _quest("shut", "personal", "player", [_step("a")])
	shut["closed_when"] = { "check": "flag" }
	var paid: Dictionary = _quest("paid", "personal", "player", [_step("a")])
	paid["closed_when"] = { "check": "flag" }
	var lists: Dictionary = QuestLog.build([shut, paid], {}, { "shut": _entry([], 3, {}, 3), "paid": _entry(["a"], 3, {}, 3) })
	if not (lists[QuestLog.OPEN] as Array).is_empty() or _ids(lists[QuestLog.DONE]) != ["paid"]:
		return "Got %s" % [lists]
	return ""


## Done is the entry's word: a step added to the data later does not undo it.
func test_a_finished_quest_stays_done_when_a_step_is_added() -> String:
	var quest: Dictionary = _quest("q", "lab", "farm", [_step("a"), _step("b")])
	var lists: Dictionary = QuestLog.build([quest], { "q": _entry(["a"], 3) }, {})
	return "" if _ids(lists[QuestLog.DONE]) == ["q"] and (lists[QuestLog.OPEN] as Array).is_empty() else "Got %s" % [lists]


func test_the_done_list_is_the_latest_few() -> String:
	var quests: Array = []
	var farm_state: Dictionary = {}
	for index: int in 9:
		var id: String = "q%d" % index
		quests.append(_quest(id, "lab", "farm", [_step("a")]))
		farm_state[id] = _entry(["a"], index)
	var done: Array = QuestLog.build(quests, farm_state, {})[QuestLog.DONE]
	var latest: Dictionary = QuestLog.latest_done(done)
	if _ids(latest["rows"]) != ["q8", "q7", "q6", "q5", "q4", "q3"] or latest["more"] != 3:
		return "Got %s" % [latest]
	latest = QuestLog.latest_done(done.slice(0, 2))
	return "" if latest["rows"].size() == 2 and latest["more"] == 0 else "Few done: %s" % [latest]


func test_a_step_counts_only_when_it_has_a_count() -> String:
	var entry: Dictionary = _entry([], -1, { "many": 9, "one": 1 })
	var many: Dictionary = _step("many", "count", { "log": "cal_log", "at_least": 5 })
	if QuestLog.step_count(many, entry) != [5, 5] or QuestLog.step_count(many, _entry()) != [0, 5]:
		return "A count is never over what the step needs, and 0 before the host wrote one."
	if QuestLog.step_count(_step("one", "counter", { "counter": "till" }), entry) != [0, 0]:
		return "A step that needs one says no count."
	if QuestLog.step_count(_step("level", "level", { "skill": "lab", "at_least": 12 }), entry) != [0, 0]:
		return "A level is not a count the entry keeps."
	var run: Dictionary = _step("run", "state_is", { "count_from": "contract_run" })
	if QuestLog.step_count(run, entry, { "contract_run": [3, 5] }) != [3, 5] or QuestLog.step_count(run, entry, { "contract_run": [7, 5] }) != [5, 5]:
		return "The run of the contract is the count of the farm."
	if QuestLog.step_count(run, entry) != [0, 0] or QuestLog.step_count(run, entry, { "contract_run": [1, 0] }) != [0, 0]:
		return "With no such count kept, none is said."
	return ""


func test_odd_state_is_left_out() -> String:
	var quests: Array = [_quest("q", "lab", "farm", [_step("a")]), "not a quest", { "id": "bare", "kind": "lab" },
		_quest("odd_kind", "seasonal", "farm", [_step("a")]), _quest("all_ticked", "lab", "farm", [_step("a")])]
	var farm_state: Dictionary = { "q": "not an entry", "bare": _entry(), "odd_kind": _entry(), "all_ticked": _entry(["a"]) }
	var lists: Dictionary = QuestLog.build(quests, farm_state, {})
	return "" if (lists[QuestLog.OPEN] as Array).is_empty() and (lists[QuestLog.DONE] as Array).is_empty() else "Got %s" % [lists]


## Every shipped quest, accepted and then done, makes a whole row: the data has
## the words the view needs.
func test_every_shipped_quest_has_its_words() -> String:
	var quests: Array[Dictionary] = QuestEngine.quests()
	var farm_state: Dictionary = {}
	for quest: Dictionary in quests:
		farm_state[str(quest["id"])] = _entry([], -1, {})
	var open: Array = QuestLog.build(quests, farm_state, farm_state)[QuestLog.OPEN]
	if open.size() != quests.size() or quests.is_empty():
		return "%d of %d shipped quests are listed" % [open.size(), quests.size()]
	for row: Dictionary in open:
		if row["title"] == "" or row["giver"] == "" or str(row["step"]).length() < 8 or not row["kind"] in QuestLog.KIND_ORDER:
			return "A row lacks words: %s" % [row]
	for quest: Dictionary in quests:
		var ids: Array = (quest["steps"] as Array).map(func(step: Dictionary) -> String: return step["id"])
		farm_state[str(quest["id"])] = _entry(ids, DAY, {}, DAY)
	var lists: Dictionary = QuestLog.build(quests, farm_state, farm_state)
	return "" if (lists[QuestLog.DONE] as Array).size() == quests.size() and (lists[QuestLog.OPEN] as Array).is_empty() else "Done, all are with the done."


## A guest's list is read from the farm as the host sent it: the guest's own
## quest and the farm's, each as far as the host says, with no engine run there.
func test_a_guest_reads_their_own_list_from_the_farm_of_the_host() -> String:
	var elapsed: float = GameClock.elapsed_days
	var speed: float = GameClock.seconds_per_day
	var paused: bool = GameClock.paused
	var open: bool = SaveGame.farm_open
	var table: Dictionary = DataManager._records[&"quests"]
	var shipped: Dictionary = table["quests"]
	table["quests"] = {
		&"farm_q": _quest("farm_q", "story", "farm", [_step("kit", "owns_standard", { "standard_id": "gravimetric_kit" }), _step("rich", "stat_at_least", { "stat": "credits", "at_least": 1000000 })]),
		&"own_q": _quest("own_q", "personal", "player", [_step("till", "counter", { "counter": "till", "at_least": 3 })], "orin"),
	}
	var host: Node = _farm()
	var guest: Node = _farm()
	var out: Variant = _guest_body(host, guest)
	host.free()
	guest.free()
	table["quests"] = shipped
	FarmCommands.guest = false
	GameClock.elapsed_days = elapsed
	GameClock.seconds_per_day = speed
	GameClock.paused = paused
	SaveGame.farm_open = open
	return out if out is String else "The test stopped early or did not return a String."


func _farm() -> Node:
	var gs: Node = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(77)
	gs.reset_credibility()
	gs.credits = 0
	return gs


func _guest_body(host: Node, guest: Node) -> String:
	var id: String = host.let_in_guest(KEY, {}, [HOST] as Array[String], ProfileScript.no_record())
	var both: Array[String] = [HOST, id]
	host.update_quests(both)
	host.owned_standards["gravimetric_kit"] = {}
	host.action_counts[id] = { "till": { "count": 2, "xp": 0 } }
	host.update_quests(both, false)
	var hers: Dictionary = QuestLog.of(host, id)
	var rows: Array = hers[QuestLog.OPEN]
	if _ids(rows) != ["farm_q", "own_q"] or rows[0]["step"] != "Do rich." or QuestLog.step_text(rows[1]) != "Do till.  2 of 3":
		return "On the host, the guest's list: %s" % [hers]
	if QuestLog.step_text((QuestLog.of(host, HOST)[QuestLog.OPEN] as Array)[1]) != "Do till.  0 of 3":
		return "The host's own quest is the host's."
	guest.local_player_id = id
	FarmCommands.guest = true
	var problem: String = FarmSync.join(FarmSync.capture(host), guest)
	if problem != "":
		return problem
	# The guest's copy holds no kit a check could read wrongly: the list is the entries' word.
	guest.owned_standards.clear()
	guest.action_counts.clear()
	guest.update_quests(both)
	if QuestLog.of(guest, id) != hers:
		return "The guest's list is the host's word: %s" % [QuestLog.of(guest, id)]
	FarmCommands.guest = false
	host.action_counts[id] = { "till": { "count": 3, "xp": 0 } }
	host.update_quests(both, false)
	FarmCommands.guest = true
	problem = FarmSync.update(FarmSync.capture(host), guest)
	var now: Dictionary = QuestLog.of(guest, id)
	if problem != "" or _ids(now[QuestLog.OPEN]) != ["farm_q"] or _ids(now[QuestLog.DONE]) != ["own_q"]:
		return "A quest done on the host is done on the guest's list: %s %s" % [problem, now]
	return ""
