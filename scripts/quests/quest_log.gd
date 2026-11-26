class_name QuestLog
extends RefCounted
## What the QUESTS view lists (docs/design/quests_levels_story.md section 5.5,
## build step 7): a player's open quests, then the ones done.
##
## It reads the quests' data and what the farm keeps for them (quest_state, one
## player's entries of player_quest_state, the contract's run) and nothing else.
## A guest's copy of the farm has all of that from the host (FarmSync,
## quests_changed and credibility_changed), so a guest's list is the host's
## word: nothing here looks at a check, and the engine's update() is never run.

## The order of the list: by kind, then as the data file has them.
const KIND_ORDER: Array[String] = ["story", "lab", "personal", "daily"]
const OPEN: String = "open"
const DONE: String = "done"
## A step's `count_from` the view can show, and the key of `kept` it is read from.
const CONTRACT_RUN: String = "contract_run"
## How many done quests the view shows [PLACEHOLDER].
const DONE_SHOWN: int = 6


## { "open": rows, "done": rows } for one player. A row: id, kind, giver (as the
## phone names them), title, step (the first step not done, "" in a done row),
## have and need (need is 0 when the step has no count to show) and day (the
## day it was done, -1 in an open row).
##
## `farm_state` is quest_state, `own_state` the player's own entries and `kept`
## what the farm counts for a step with `count_from`: its name -> [have, need].
##
## No clock is read. The host takes a daily ask of another day out of the
## player's entries each morning, so the ask listed is the one accepted latest
## there: a guest whose clock runs a little behind or ahead of the host's
## around the morning still sees the ask the host says is today's.
##
## A quest is done by its entry's `done`, whatever steps the data has now: one
## finished before a step was added stays with the done. A quest the engine
## closed with nothing paid (is_closed) was never told to the player and is in
## neither list, the farm's or a player's own [ASSUMPTION].
static func build(quests: Array, farm_state: Dictionary, own_state: Dictionary, kept: Dictionary = {}) -> Dictionary:
	var open: Array[Dictionary] = []
	var done: Array[Dictionary] = []
	var ask_day: int = latest_ask_day(quests, own_state)
	for kind: String in KIND_ORDER:
		for quest: Variant in quests:
			if not quest is Dictionary or str(quest.get("kind", "")) != kind or not quest.get("steps") is Array:
				continue
			var own: bool = str(quest.get("scope", "")) == QuestEngine.SCOPE_PLAYER
			var entry: Variant = (own_state if own else farm_state).get(str(quest.get("id", "")))
			if not entry is Dictionary or not entry.get("steps_done") is Array:
				continue
			if kind == QuestEngine.KIND_DAILY and int(entry.get("accepted", -1)) != ask_day:
				continue
			var row: Dictionary = {
				"id": str(quest.get("id", "")), "kind": kind, "giver": QuestEngine.giver_name(quest),
				"title": str(quest.get("title", "")), "step": "", "have": 0, "need": 0, "day": int(entry.get("done", -1)),
			}
			if row["day"] >= 0:
				if not is_closed(quest, entry):
					done.append(row)
				continue
			var step: Dictionary = open_step(quest, entry)
			if step.is_empty():
				continue
			row["step"] = str(step.get("text", ""))
			var count: Array[int] = step_count(step, entry, kept)
			row["have"] = count[0]
			row["need"] = count[1]
			open.append(row)
	return { OPEN: open, DONE: done }


## The latest day a daily ask in `own_state` was accepted, or -1 with none.
static func latest_ask_day(quests: Array, own_state: Dictionary) -> int:
	var latest: int = -1
	for quest: Variant in quests:
		if not quest is Dictionary or str(quest.get("kind", "")) != QuestEngine.KIND_DAILY:
			continue
		var entry: Variant = own_state.get(str(quest.get("id", "")))
		if entry is Dictionary:
			latest = maxi(latest, int(entry.get("accepted", -1)))
	return latest


## True for a done entry the engine closed with nothing paid: only a quest with
## `closed_when` can be, and the engine writes such an entry in one go, done on
## the day it was made with no step ticked. A finished quest has a step ticked.
## [ASSUMPTION: a player's quest with `closed_when` that comes done from another
## farm on the day its entry is made here reads the same, and is hidden. No
## shipped player quest has `closed_when`.]
static func is_closed(quest: Dictionary, entry: Dictionary) -> bool:
	var closed_when: Variant = quest.get("closed_when")
	if not closed_when is Dictionary or closed_when.is_empty():
		return false
	var done: int = int(entry.get("done", -1))
	return done >= 0 and done == int(entry.get("accepted", -1)) and (entry["steps_done"] as Array).is_empty()


## The done rows the view shows: the `limit` done latest (the latest first, a
## tie in the list's order), and how many it leaves out.
static func latest_done(rows: Array, limit: int = DONE_SHOWN) -> Dictionary:
	var order: Array = range(rows.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var day_a: int = int(rows[a].get("day", -1))
		var day_b: int = int(rows[b].get("day", -1))
		return day_a > day_b if day_a != day_b else a < b)
	var shown: Array[Dictionary] = []
	for index: int in order.slice(0, maxi(limit, 0)):
		shown.append(rows[index])
	return { "rows": shown, "more": rows.size() - shown.size() }


## The first step of `quest` that `entry` has not done, or {}.
static func open_step(quest: Dictionary, entry: Dictionary) -> Dictionary:
	for step: Variant in quest["steps"]:
		if step is Dictionary and not str(step.get("id", "")) in entry["steps_done"]:
			return step
	return {}


## [have, need] of an open step, or [0, 0] when it has no count to show: only a
## counting step that needs more than one has, and a step with `count_from`.
## The count is the one the host last wrote in the entry (`shown`), which is
## what the phone was told.
static func step_count(step: Dictionary, entry: Dictionary, kept: Dictionary = {}) -> Array[int]:
	var from: Variant = kept.get(str(step.get("count_from", "")))
	if from is Array and from.size() == 2 and int(from[1]) > 0:
		return [clampi(int(from[0]), 0, int(from[1])), int(from[1])]
	var need: int = QuestEngine.step_need(step)
	if need < 2 or not str(step.get("check", "")) in QuestEngine.COUNTING:
		return [0, 0]
	var shown: Variant = entry.get("shown", {})
	var have: int = int(shown.get(str(step.get("id", "")), 0)) if shown is Dictionary else 0
	return [clampi(have, 0, need), need]


## The list of `player_id` on `farm` (a GameState, the host's or a guest's copy).
static func of(farm: Node, player_id: String) -> Dictionary:
	var own: Variant = farm.player_quest_state.get(player_id, {})
	return build(QuestEngine.quests(), farm.quest_state, own if own is Dictionary else {},
		{ CONTRACT_RUN: [farm.contract_run, farm.contract_run_needed()] })


## A row's first line: "LIN: The Thirsty Probe  (story)". A daily ask says "today".
static func title_text(row: Dictionary) -> String:
	var kind: String = str(row.get("kind", ""))
	return "%s: %s  (%s)" % [row.get("giver", ""), row.get("title", ""), "today" if kind == QuestEngine.KIND_DAILY else kind]


## An open row's second line: its step, and "2 of 3" when it counts.
static func step_text(row: Dictionary) -> String:
	if int(row.get("need", 0)) <= 0:
		return str(row.get("step", ""))
	return "%s  %s of %s" % [row.get("step", ""), SP811.integer(int(row["have"])), SP811.integer(int(row["need"]))]
