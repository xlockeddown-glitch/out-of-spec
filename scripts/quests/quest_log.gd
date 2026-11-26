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


## { "open": rows, "done": rows } for one player. A row: id, kind, giver (as the
## phone names them), title, step (the first step not done, "" in a done row),
## have and need (need is 0 when the step has no count to show).
##
## `farm_state` is quest_state, `own_state` the player's own entries, `day` today
## (a daily ask of another day is not listed) and `kept` what the farm counts
## for a step with `count_from`: its name -> [have, need].
##
## A farm's quest that is done with steps left was closed with nothing paid
## (the engine's closed_when) and was never told to the player: it is left out
## [ASSUMPTION]. A player's own quest done with steps left was done on another
## farm, and is listed as done.
static func build(quests: Array, farm_state: Dictionary, own_state: Dictionary, day: int, kept: Dictionary = {}) -> Dictionary:
	var open: Array[Dictionary] = []
	var done: Array[Dictionary] = []
	for kind: String in KIND_ORDER:
		for quest: Variant in quests:
			if not quest is Dictionary or str(quest.get("kind", "")) != kind or not quest.get("steps") is Array:
				continue
			var own: bool = str(quest.get("scope", "")) == QuestEngine.SCOPE_PLAYER
			var entry: Variant = (own_state if own else farm_state).get(str(quest.get("id", "")))
			if not entry is Dictionary or not entry.get("steps_done") is Array:
				continue
			if kind == QuestEngine.KIND_DAILY and int(entry.get("accepted", -1)) != day:
				continue
			var row: Dictionary = {
				"id": str(quest.get("id", "")), "kind": kind, "giver": QuestEngine.giver_name(quest),
				"title": str(quest.get("title", "")), "step": "", "have": 0, "need": 0,
			}
			if int(entry.get("done", -1)) >= 0:
				if own or (entry["steps_done"] as Array).size() >= (quest["steps"] as Array).size():
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
	return build(QuestEngine.quests(), farm.quest_state, own if own is Dictionary else {}, GameClock.get_day_index(),
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
