class_name QuestEngine
extends RefCounted
## The quests of data/quests.json (docs/design/quests_levels_story.md section 5).
##
## It only watches: every check reads what the farm (a GameState) already keeps,
## and nothing here calibrates, sells or buys. The farm holds the state
## (quest_state, player_quest_state, quest_points) and calls update() on the
## host; a guest's copy is the host's and never runs this. With the data file
## empty the game under it is the same.
##
## A farm's entry in quest_state, by quest id:
##   accepted    the day it was accepted
##   steps_done  ids of the steps that are done
##   base        step id -> what a counting check read when its step opened: on
##               that day, or, in a quest done in order, when the step before
##               it was done
##   shown       step id -> the highest count a counting step has reached; the
##               phone is told when it grows, and it never goes back
##   players     who was on the farm when any step was done (they took part)
##   done        the day it was finished and paid, or -1
##
## A quest of scope "player" is each player's own (section 5.4): its entry is in
## player_quest_state, by player id then quest id, and has one key more:
##   carried     step id -> what the player had counted on other farms when they
##               came (take_brought); added to what they count here
## It is offered to, counted for and paid to that player alone: a gate on a level
## or on points reads theirs, a `counter` step counts their actions, and the
## skill XP, quest points and certificate are theirs. Credits go to the shared
## wallet and lab XP to the lab, as a farm quest's do. A guest's entries travel
## in the guest's own file (CoopProfile).
##
## Quests are offered only on an offering look (each morning, and when a farm is
## started or opened), so an offer never lands on top of what a command said.
## Steps are ticked and a finished quest is paid on every look.
##
## Not built yet: accept and turn-in by the player (the quest log, build step 7;
## until then an offered quest is accepted at once and paid when its last step
## holds), mini-game steps (step 11: a step may carry "minigame", which nothing
## reads yet) and item rewards (step 10).

const TABLE: StringName = &"quests"
const SECTION: String = "quests"
const ENTRY_KEYS: Array[String] = ["accepted", "steps_done", "base", "shown", "players", "done"]
## An entry of a player's own quest.
const PLAYER_ENTRY_KEYS: Array[String] = ["accepted", "steps_done", "base", "shown", "players", "done", "carried"]
const SCOPE_FARM: String = "farm"
const SCOPE_PLAYER: String = "player"
## What `stat_at_least` may read.
const STATS: Array[String] = ["credits", "credibility", "crystal_ore", "stone", "optical_silk_spools", "clean_audit_streak"]
## What `flag` may read; `oirm_account` is has_oirm_account().
const FLAGS: Array[String] = ["tier1_unlocked", "traceable_lab", "relay_slotted", "audit_grace_used"]
## What `state_is` may read.
const STATES: Array[String] = ["contract_state"]
## The logs `count` may read, by the design's names.
const LOGS: Dictionary = { "cal_log": "cal_log", "job_log": "job_log", "audit_log": "audit_log", "certificates": "certificate_log" }
## Checks that count from the day the quest was accepted, unless `ever`.
const COUNTING: Array[String] = ["count", "counter"]
## A reward of skill XP is "xp_<skill id>".
const XP_PREFIX: String = "xp_"
## A reward of an XP certificate: the XP it is worth in the one skill its holder
## picks (section 4.4). Sized to the quest, never to the player.
const XP_CERTIFICATE: String = "xp_certificate"
## A `counter` that is not a source of data/skills.json: what Lin has bought in
## spec, of the crop `where.crop_id` names or of every crop.
const SOLD_IN_SPEC: String = "crops_sold_in_spec"


static func quests() -> Array[Dictionary]:
	return DataManager.get_records(TABLE, SECTION)


## Moves on and pays the farm's quests, and offers new ones if `offers`.
## `present` is who is on the farm now. True if anything changed. Host only: the
## caller sees to that. A quest whose data is wrong (data_problem) is left alone.
static func update(farm: Node, present: Array[String], offers: bool = true) -> bool:
	var changed: bool = false
	var all: Array[Dictionary] = []
	for quest: Dictionary in quests():
		if data_problem(quest) == "":
			all.append(quest)
	# A quest finished here can open one listed before it, so go round again.
	for _round: int in all.size() + 1:
		var moved: bool = false
		for quest: Dictionary in all:
			var scope: String = str(quest.get("scope", SCOPE_FARM))
			if scope == SCOPE_FARM:
				if _update_one(farm, quest, farm.quest_state, present, offers, ""):
					moved = true
			elif scope == SCOPE_PLAYER:
				for player: String in present:
					# Kept only once it holds something.
					var own: Dictionary = farm.player_quest_state.get(player, {})
					var alone: Array[String] = [player]
					if _update_one(farm, quest, own, alone, offers, player):
						farm.player_quest_state[player] = own
						moved = true
		if not moved:
			break
		changed = true
	return changed


## One quest in `state`: the farm's quest_state, or one player's own entries
## (`owner` is then that player, and `present` that player alone).
static func _update_one(farm: Node, quest: Dictionary, state: Dictionary, present: Array[String], offers: bool, owner: String) -> bool:
	var id: String = str(quest["id"])
	var is_new: bool = not state.has(id)
	if is_new:
		if not offers:
			return false
		if not is_offered(farm, quest, present, owner):
			# What it waits for can no longer come: closed, and nothing is paid.
			if _closed(farm, quest, present, owner):
				var closed: Dictionary = _accepted(farm, quest, present, owner)
				closed["done"] = closed["accepted"]
				state[id] = closed
				return true
			return false
		state[id] = _accepted(farm, quest, present, owner)
	var entry: Dictionary = state[id]
	if int(entry["done"]) >= 0:
		return false
	var title: String = str(quest["title"])
	var steps: Array = quest["steps"]
	var done: Array = entry["steps_done"]
	var moved: bool = is_new
	var finished: Array[String] = []
	var in_order: bool = not bool(quest.get("any_order", false))
	# The step before this one was done in this look.
	var opened: bool = false
	for step: Variant in steps:
		var step_id: String = str(step.get("id", ""))
		if step_id in done:
			continue
		var counts: bool = str(step.get("check", "")) in COUNTING
		# In order, a step counts from when it opened: what was done while an
		# earlier step was still open is not this step's.
		if opened and in_order and counts and not bool(step.get("ever", false)):
			entry["base"][step_id] = check_value(farm, step, present, owner)
		opened = false
		var have: int = step_count(farm, step, entry, present, owner)
		var need: int = step_need(step)
		var grew: bool = counts and have > int(entry["shown"].get(step_id, 0))
		if grew:
			entry["shown"][step_id] = have
			moved = true
		if have >= need:
			done.append(step_id)
			finished.append(str(step.get("text", "")))
			for player: String in present:
				if not player in entry["players"]:
					(entry["players"] as Array).append(player)
			moved = true
			opened = true
			continue
		# A count that grew is told once; a contract's run has its own line.
		if need > 1 and grew:
			farm.post_phone("QUEST %s: %d of %d. %s" % [title, have, need, str(step.get("text", ""))])
		if in_order:
			break
	if done.size() >= steps.size():
		_finish(farm, quest, entry, present, owner)
		return true
	var next: String = current_step_text(quest, entry)
	if is_new:
		# `offer_line`: what the giver says with the offer, a path or the words.
		var said: String = phone_line(str(quest.get("offer_line", "")))
		farm.post_phone("%s: New quest, %s. %s%s" % [giver_name(quest), title, "" if said == "" else said + " ", next])
	elif not finished.is_empty():
		farm.post_phone("QUEST %s: step done. Next: %s" % [title, next])
	return moved


static func _accepted(farm: Node, quest: Dictionary, present: Array[String], owner: String = "") -> Dictionary:
	var base: Dictionary = {}
	for step: Variant in quest["steps"]:
		if str(step.get("check", "")) in COUNTING:
			base[str(step.get("id", ""))] = check_value(farm, step, present, owner)
	var entry: Dictionary = { "accepted": GameClock.get_day_index(), "steps_done": [], "base": base, "shown": {}, "players": [], "done": -1 }
	if owner != "":
		entry["carried"] = {}
	return entry


## Marks it done and pays it, once: update() never comes back to a done quest.
## A player's own quest (`owner`) pays that player.
static func _finish(farm: Node, quest: Dictionary, entry: Dictionary, present: Array[String], owner: String = "") -> void:
	entry["done"] = GameClock.get_day_index()
	var reward: String = reward_text(quest)
	farm.post_phone("QUEST DONE: %s.%s" % [str(quest["title"]), "" if reward == "" else " Reward: %s." % reward])
	var rewards: Dictionary = quest.get("rewards", {})
	# Those who took part and are still known here: a guest the farm has
	# forgotten is not given a place again.
	var known: Array[String] = farm._known_players()
	var players: Array[String] = []
	for player: Variant in entry["players"]:
		if player in known or player in present:
			players.append(str(player))
	if owner != "":
		players = [owner]
	if int(rewards.get("credits", 0)) > 0:
		farm.add_credits(int(rewards["credits"]))
	# The amount written on the quest, in any lab (section 3.2.1).
	farm.give_lab_xp(int(rewards.get("lab_xp", 0)))
	for key: Variant in rewards:
		var skill: String = _reward_skill(str(key))
		if skill == "":
			continue
		# A skill the whole farm shares is paid once, not once for each player.
		if farm.is_farm_skill(skill):
			farm.give_skill_xp(skill, int(rewards[key]), farm.local_player_id)
			continue
		for player: String in players:
			farm.give_skill_xp(skill, int(rewards[key]), player)
	# By quest id, so no player can hold one quest's points twice: not here, and
	# not with the points they brought from another farm (GameState.let_in_guest).
	if int(rewards.get("quest_points", 0)) > 0:
		for player: String in players:
			var points: Dictionary = farm.quest_points.get_or_add(player, {})
			points[str(quest["id"])] = maxi(int(rewards["quest_points"]), int(points.get(str(quest["id"]), 0)))
	# One each, held until its player spends it (GameState.spend_xp_certificate).
	# A player who holds or has spent this quest's certificate, here or on another
	# farm, is not given it again.
	var certificate: int = int(rewards.get(XP_CERTIFICATE, 0))
	var given: int = 0
	if certificate > 0:
		for player: String in players:
			if not farm.has_had_xp_certificate(str(quest["id"]), player) and farm.give_xp_certificate(player, str(quest["id"]), certificate) != "":
				given += 1
	if given > 0:
		farm.post_phone("XP CERTIFICATE: %s XP in a skill of your choice, for each player who took part. Open SKILLS (K) to spend it." % SP811.integer(certificate))
	var line: String = phone_line(str(rewards.get("phone", "")))
	if line != "":
		farm.post_phone("%s: %s" % [giver_name(quest), line])


## "250 lab XP, 1 quest point": what the quest pays, for the phone.
static func reward_text(quest: Dictionary) -> String:
	var rewards: Dictionary = quest.get("rewards", {})
	var parts: Array[String] = []
	if int(rewards.get("credits", 0)) > 0:
		parts.append("%s CR" % SP811.integer(int(rewards["credits"])))
	if int(rewards.get("lab_xp", 0)) > 0:
		parts.append("%s lab XP" % SP811.integer(int(rewards["lab_xp"])))
	for key: Variant in rewards:
		var skill: String = _reward_skill(str(key))
		if skill != "" and int(rewards[key]) > 0:
			var name: String = str(DataManager.get_record(&"skills", skill, "skills").get("display_name", skill))
			parts.append("%s %s XP" % [SP811.integer(int(rewards[key])), name])
	var points: int = int(rewards.get("quest_points", 0))
	if points > 0:
		parts.append("%s quest %s" % [SP811.integer(points), "point" if points == 1 else "points"])
	if int(rewards.get(XP_CERTIFICATE, 0)) > 0:
		parts.append("an XP certificate (%s XP)" % SP811.integer(int(rewards[XP_CERTIFICATE])))
	return ", ".join(parts)


## The skill a reward key names, or "" (the certificate names none).
static func _reward_skill(key: String) -> String:
	if not key.begins_with(XP_PREFIX):
		return ""
	var skill: String = key.trim_prefix(XP_PREFIX)
	return skill if DataManager.has_record(&"skills", skill, "skills") else ""


## A reward's line: the text at a path in dialogue_dispatches.json, or the
## reward's own words when it is no path there.
static func phone_line(reward: String) -> String:
	if reward == "":
		return ""
	var found: Variant = DataManager.get_value(&"dialogue_dispatches", reward)
	return found if found is String else reward


## The giver as the phone's other lines name them: "VANCE", "OIRM".
static func giver_name(quest: Dictionary) -> String:
	return str(quest.get("giver", "quest")).to_upper()


## "" or what is wrong with a quest as the data file has it. update() leaves
## such a quest alone, and tests/test_quests.gd holds the shipped file to this.
static func data_problem(quest: Dictionary) -> String:
	var steps: Variant = quest.get("steps")
	if not steps is Array or (steps as Array).is_empty():
		return "it has no steps."
	var ids: Array[String] = []
	for step: Variant in steps:
		if not step is Dictionary:
			return "a step is not a dictionary."
		var id: Variant = step.get("id", "")
		if not id is String or id == "" or id in ids:
			return "a step has no id, or two steps have the same id."
		ids.append(id)
	for key: String in ["gates", "offer", "closed_when", "rewards"]:
		if quest.has(key) and not quest[key] is Dictionary:
			return "'%s' is not a dictionary." % key
	return ""


# --- Offering -----------------------------------------------------------------

## Whether the quest's own gates and its offer hold.
static func is_offered(farm: Node, quest: Dictionary, present: Array[String], owner: String = "") -> bool:
	return gates_hold(farm, quest.get("gates", {}), present, owner) and offer_holds(farm, quest.get("offer", {}), present, owner)


## All of a quest's gates (section 5.2). For a gate on a player's own level or
## points, the highest among the players on the farm counts (section 5.6). A gate
## this build can't read is shut. For a player's own quest (`owner`), `present`
## is that player alone and `quest_done` also reads their own quests.
static func gates_hold(farm: Node, gates: Dictionary, present: Array[String], owner: String = "") -> bool:
	for key: Variant in gates:
		var gate: Variant = gates[key]
		match str(key):
			"lab_level":
				if farm.lab_level() < int(gate):
					return false
			"band":
				if farm.credibility_band_index() < farm._band_index_named(str(gate)):
					return false
			"skill":
				if not gate is Dictionary or _best_level(farm, str(gate.get("id", "")), present) < int(gate.get("level", 1)):
					return false
			"total_level":
				if _best_level(farm, "total", present) < int(gate):
					return false
			"quest_points":
				if best_quest_points(farm, present) < int(gate):
					return false
			"quest_done":
				for id: Variant in (gate if gate is Array else [gate]):
					if not is_done(farm, str(id), owner):
						return false
			_:
				return false
	return true


## `closed_when` (a step check): true when it holds for a quest that was never
## offered. The quest is then marked done with nothing paid, so nothing gated on
## it is stuck behind an offer that can't come.
static func _closed(farm: Node, quest: Dictionary, present: Array[String], owner: String = "") -> bool:
	var closed: Dictionary = quest.get("closed_when", {})
	if closed.is_empty():
		return false
	var as_step: Dictionary = closed.duplicate()
	as_step["check"] = str(closed.get("when", ""))
	return check_value(farm, as_step, present, owner) >= step_need(as_step)


## `offer`: always (or nothing), a day, or any step check that holds now.
static func offer_holds(farm: Node, offer: Dictionary, present: Array[String], owner: String = "") -> bool:
	var when: String = str(offer.get("when", "always"))
	if when == "always":
		return true
	if when == "day_at_least":
		return GameClock.get_day_index() >= int(offer.get("day", 0))
	var as_step: Dictionary = offer.duplicate()
	as_step["check"] = when
	return check_value(farm, as_step, present, owner) >= step_need(as_step)


## Whether the farm's quest is done or, with `owner`, that player's own.
static func is_done(farm: Node, quest_id: String, owner: String = "") -> bool:
	if int((farm.quest_state.get(quest_id, {}) as Dictionary).get("done", -1)) >= 0:
		return true
	if owner == "":
		return false
	var own: Dictionary = farm.player_quest_state.get(owner, {})
	return int((own.get(quest_id, {}) as Dictionary).get("done", -1)) >= 0


## A player's quest points on this farm.
static func points_of(farm: Node, player_id: String) -> int:
	var total: int = 0
	for points: Variant in (farm.quest_points.get(player_id, {}) as Dictionary).values():
		total += int(points)
	return total


static func best_quest_points(farm: Node, present: Array[String]) -> int:
	var best: int = 0
	for player: String in present:
		best = maxi(best, points_of(farm, player))
	return best


## A player's levels added up (section 4.3).
static func total_level(farm: Node, player_id: String) -> int:
	var total: int = 0
	for skill: String in farm.skill_ids():
		total += farm.skill_level(skill, player_id)
	return total


## The lab's level, or the best of those present in a skill or in total.
static func _best_level(farm: Node, skill: String, present: Array[String]) -> int:
	if skill == "lab":
		return farm.lab_level()
	var best: int = 0
	for player: String in present:
		best = maxi(best, total_level(farm, player) if skill == "total" else farm.skill_level(skill, player))
	return best


# --- Steps --------------------------------------------------------------------

## What a step needs: `at_least`, or 1.
static func step_need(step: Dictionary) -> int:
	return maxi(int(step.get("at_least", 1)), 1)


## What a step has: its check's reading, less what it read when the step opened
## (`base`) for a counting check that is not `ever`. A count never goes
## back: the highest it has reached is kept (a forgotten guest's actions leave
## the farm's counters). A player's own quest adds what they brought (`carried`).
static func step_count(farm: Node, step: Dictionary, entry: Dictionary, present: Array[String], owner: String = "") -> int:
	var value: int = check_value(farm, step, present, owner)
	if not str(step.get("check", "")) in COUNTING:
		return maxi(value, 0)
	var id: String = str(step.get("id", ""))
	if not bool(step.get("ever", false)):
		value -= int((entry.get("base", {}) as Dictionary).get(id, 0))
		value += int((entry.get("carried", {}) as Dictionary).get(id, 0))
	return maxi(value, int((entry.get("shown", {}) as Dictionary).get(id, 0)))


## The first step not done, as the phone says it: its text, with "3 of 5" when it
## counts. "" when every step is done.
static func current_step_text(quest: Dictionary, entry: Dictionary) -> String:
	for step: Variant in quest["steps"]:
		if not str(step.get("id", "")) in entry["steps_done"]:
			return str(step.get("text", ""))
	return ""


## [have, need] for the quest log (build step 7). A step with `count_from` shows
## a count the farm keeps for it: the contract's run, of the run it needs.
static func step_progress(farm: Node, step: Dictionary, entry: Dictionary, present: Array[String], owner: String = "") -> Array[int]:
	if str(step.get("count_from", "")) == "contract_run":
		var needed: int = farm.contract_run_needed()
		return [needed if step_count(farm, step, entry, present, owner) >= step_need(step) else mini(farm.contract_run, needed), needed]
	return [mini(step_count(farm, step, entry, present, owner), step_need(step)), step_need(step)]


## One check's reading (section 5.3): a count or a level for the checks that have
## one, else 1 when it holds and 0 when not. A check this build does not know
## (a mini-game) reads 0, so its step waits. With `owner` (a player's own quest)
## a `counter` reads that player's actions alone; what the farm keeps as a whole
## (its logs, stats and what Lin bought) reads the same for every player.
static func check_value(farm: Node, step: Dictionary, present: Array[String], owner: String = "") -> int:
	match str(step.get("check", "")):
		"stat_at_least":
			var stat: String = str(step.get("stat", ""))
			return int(farm.get(stat)) if stat in STATS else 0
		"flag":
			var flag: String = str(step.get("flag", ""))
			if flag == "oirm_account":
				return int(farm.has_oirm_account())
			return int(bool(farm.get(flag))) if flag in FLAGS else 0
		"band_at_least":
			return int(farm.credibility_band_index() >= farm._band_index_named(str(step.get("band", ""))))
		"owns_standard":
			return int((farm.owned_standards as Dictionary).has(str(step.get("standard_id", ""))))
		"lab_size":
			return int(farm.lab_size)
		"count":
			return _count_rows(farm, str(step.get("log", "")), step.get("where", {}))
		"state_is":
			var state: String = str(step.get("state", ""))
			var wanted: Variant = step.get("is", "")
			if not state in STATES:
				return 0
			return int(str(farm.get(state)) in (wanted if wanted is Array else [wanted]))
		"level":
			return _best_level(farm, str(step.get("skill", "")), present)
		"counter":
			if str(step.get("counter", "")) == SOLD_IN_SPEC:
				return _sold_in_spec(farm, step.get("where", {}))
			if owner != "":
				return farm.action_count(str(step.get("counter", "")), owner)
			var total: int = 0
			for player: String in farm._known_players():
				total += farm.action_count(str(step.get("counter", "")), player)
			return total
	return 0


static func _sold_in_spec(farm: Node, where: Variant) -> int:
	var sold: Dictionary = farm.crops_sold_in_spec
	if where is Dictionary and where.has("crop_id"):
		return int(sold.get(str(where["crop_id"]), 0))
	var total: int = 0
	for count: Variant in sold.values():
		total += int(count)
	return total


static func _count_rows(farm: Node, log_name: String, where: Variant) -> int:
	if not LOGS.has(log_name) or not where is Dictionary:
		return 0
	var count: int = 0
	for row: Variant in farm.get(LOGS[log_name]):
		var matches: bool = row is Dictionary
		for key: Variant in where:
			if matches and not _same((row as Dictionary).get(key), where[key]):
				matches = false
		if matches:
			count += 1
	return count


## JSON's numbers are floats and the logs hold whole numbers and names.
static func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if (a is String or a is StringName) and (b is String or b is StringName):
		return str(a) == str(b)
	return typeof(a) == typeof(b) and a == b


# --- Saved state --------------------------------------------------------------

## "" or why a saved quest_state can't be loaded. A quest this build's data does
## not have is kept as it is and left alone, so its "done" is still there if the
## quest comes back.
static func state_problem(state: Dictionary, keys: Array[String] = ENTRY_KEYS, name: String = "quest_state") -> String:
	for id: Variant in state:
		var entry: Variant = state[id]
		if not id is String or id == "" or typeof(entry) != TYPE_DICTIONARY or entry.size() != keys.size() or not entry.has_all(keys):
			return "'%s' has an entry that is not a quest's." % name
		if not entry["accepted"] is int or not entry["done"] is int or entry["accepted"] < 0 or entry["done"] < -1:
			return "'%s' has a day that is not a day." % name
		if not _all_text(entry["steps_done"]) or not _all_text(entry["players"]):
			return "'%s' has a list that is not of names." % name
		if not _text_to_counts(entry["base"]) or not _text_to_counts(entry["shown"]) or not _text_to_counts(entry.get("carried", {})):
			return "'%s' has a count that is not a whole number." % name
	return ""


## "" or why a saved player_quest_state can't be loaded: player id -> quest id ->
## an entry with PLAYER_ENTRY_KEYS.
static func player_state_problem(states: Dictionary) -> String:
	for player: Variant in states:
		if not player is String or player == "" or typeof(states[player]) != TYPE_DICTIONARY:
			return "'player_quest_state' has an entry that is not a player's quests."
		var problem: String = state_problem(states[player], PLAYER_ENTRY_KEYS, "player_quest_state")
		if problem != "":
			return problem
	return ""


# --- A guest's own record (build step 8) ----------------------------------------

## The quests of scope "player" whose data is right, by id.
static func player_quests() -> Dictionary:
	var out: Dictionary = {}
	for quest: Dictionary in quests():
		if str(quest.get("scope", SCOPE_FARM)) == SCOPE_PLAYER and data_problem(quest) == "":
			out[str(quest["id"])] = quest
	return out


## What `player_id` has of their own quests here, as it travels in their file:
## quest id -> { done, steps (ids of the steps done), counts (step id -> the
## highest count reached) }.
static func travelling(farm: Node, player_id: String) -> Dictionary:
	var out: Dictionary = {}
	var own: Dictionary = farm.player_quest_state.get(player_id, {})
	for id: Variant in own:
		var entry: Dictionary = own[id]
		out[id] = { "done": int(entry["done"]) >= 0, "steps": (entry["steps_done"] as Array).duplicate(), "counts": (entry["shown"] as Dictionary).duplicate() }
	return out


## Host: `player_id` comes with `brought`, their own quests as travelling() gives
## them from other farms. A quest done anywhere is done here, and is not paid
## again. One under way is taken up where it stands: a step done anywhere is
## done, and a count is the higher of here and there, never the two added.
## Only this build's player quests are taken, and only their steps. True if
## anything changed. The next update() pays a quest whose last step came with it.
static func take_brought(farm: Node, player_id: String, brought: Dictionary) -> bool:
	var changed: bool = false
	var alone: Array[String] = [player_id]
	var known: Dictionary = player_quests()
	for id: Variant in brought:
		var theirs: Variant = brought[id]
		if not known.has(id) or not theirs is Dictionary:
			continue
		var quest: Dictionary = known[id]
		var own: Dictionary = farm.player_quest_state.get(player_id, {})
		var is_new: bool = not own.has(id)
		var entry: Dictionary = _accepted(farm, quest, alone, player_id) if is_new else own[id]
		if int(entry["done"]) >= 0:
			continue
		var moved: bool = false
		if theirs.get("done") == true:
			entry["done"] = GameClock.get_day_index()
			moved = true
		else:
			moved = _take_steps(farm, quest, entry, theirs, player_id, is_new)
		if moved:
			own[id] = entry
			farm.player_quest_state[player_id] = own
			changed = true
	return changed


## True if the entry took anything from `theirs`.
static func _take_steps(farm: Node, quest: Dictionary, entry: Dictionary, theirs: Dictionary, player_id: String, is_new: bool) -> bool:
	var moved: bool = false
	var alone: Array[String] = [player_id]
	var done: Array = entry["steps_done"]
	var in_order: bool = not bool(quest.get("any_order", false))
	var was_open: String = _open_step(quest, entry)
	var their_steps: Variant = theirs.get("steps", [])
	var their_counts: Variant = theirs.get("counts", {})
	for step: Variant in quest["steps"]:
		var step_id: String = str(step.get("id", ""))
		if their_steps is Array and step_id in their_steps and not step_id in done:
			done.append(step_id)
			moved = true
	for step: Variant in quest["steps"]:
		var step_id: String = str(step.get("id", ""))
		if step_id in done or not str(step.get("check", "")) in COUNTING or bool(step.get("ever", false)):
			continue
		# A step that opens with what they brought counts here from now.
		if in_order and not is_new and step_id == _open_step(quest, entry) and step_id != was_open:
			entry["base"][step_id] = check_value(farm, step, alone, player_id)
		var there: int = 0
		if their_counts is Dictionary and their_counts.get(step_id, 0) is int:
			there = their_counts.get(step_id, 0)
		var here: int = step_count(farm, step, entry, alone, player_id)
		if there > here:
			entry["carried"][step_id] = int(entry["carried"].get(step_id, 0)) + there - here
			entry["shown"][step_id] = there
			moved = true
	if moved and not player_id in entry["players"]:
		(entry["players"] as Array).append(player_id)
	return moved


## The id of the first step not done, or "".
static func _open_step(quest: Dictionary, entry: Dictionary) -> String:
	for step: Variant in quest["steps"]:
		if not str(step.get("id", "")) in entry["steps_done"]:
			return str(step.get("id", ""))
	return ""


## "" or why saved quest_points can't be loaded: player id -> quest id -> points.
static func points_problem(points: Dictionary) -> String:
	for player: Variant in points:
		if not player is String or player == "" or not _text_to_counts(points[player]):
			return "'quest_points' has an entry that is not a player's points."
	return ""


static func _all_text(list: Variant) -> bool:
	if not list is Array:
		return false
	for item: Variant in list:
		if not item is String or item == "" or (list as Array).count(item) > 1:
			return false
	return true


static func _text_to_counts(counts: Variant) -> bool:
	if not counts is Dictionary:
		return false
	for key: Variant in counts:
		if not key is String or key == "" or not counts[key] is int or counts[key] < 0:
			return false
	return true
