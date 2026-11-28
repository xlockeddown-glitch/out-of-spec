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
## and, only once a mini-game was played well for one of its steps:
##   scores      step id -> the score the host counted for the calibration that
##               did the step (60 to 100; a skip or a poor try keeps none)
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
## A step may carry "minigame" (section 7.4): while it is the open step of an
## accepted quest, the bench opens that game for the step's instrument
## (has_minigame_step, read by MinigameScore on the host and on a guest's copy).
## The step is still done by its check alone, so a skip does it too. A score
## that earned a grade is kept with the step (`scores`) and, when the quest is
## paid, gives the bonus of section 7.2.
##
## A farm's quest may carry "job" (section 6, S3): a job as the board's are,
## handed out by the quest and never on the board. On an offering look, while the
## quest is accepted and not done, the farm is asked to put it in active_jobs
## unless one of this quest's is there or in job_log (GameState.issue_quest_job).
## So a job that ran out or was dropped is back the next morning, as often as it
## takes, and no day is kept for it. Nothing new is saved: the job and its
## job_log row carry the quest's id (`quest`), and the `quest_job` check and a
## `count` of job_log rows read that. Handing out that job is the one thing the
## engine asks the farm to do; the rest of it only watches.
##
## A quest of kind "daily" is a daily ask (section 6, D2): a player's own, and
## one a day. On an offering look each player present who holds none of today's
## is given one, picked from the asks whose gates and offer hold for them by the
## farm's seed, the day and the player (daily_roll), so the pick is the same
## however often it is asked. Its entry is a player's own quest's, in
## player_quest_state, and `accepted` is its day: an entry of another day is
## taken out on the next look, done or not, with nothing paid and nothing lost,
## so the same ask can come again. A daily ask stays on its farm: it is not in
## what travels in a guest's file (travelling, take_brought), and neither is
## its certificate, which can be given as often as the ask is done.
##
## A player's own quest may pay "keepsake" (section 5.4): the id of one in the
## data's `keepsakes`. A keepsake is for show and gives no power. Nothing is
## saved for it: a player holds the keepsakes of their own quests that are done
## (keepsakes_of), so one comes with its quest in a guest's file and can't be
## held twice.
##
## A quest may pay "one_use": the id of one in the data's `one_use_rewards`
## (section 9, item 10). It is held (GameState.one_use_held, saved) until the
## action it is for uses it on its own: Bram's discount on the next standard he
## sells, a free refit of one lab area. A reward of "holder" player is given to
## each player the quest pays and is for a player's own quest; one of holder farm
## is the farm's and is for a farm quest. A daily ask pays none.
##
## Not built yet: accept and turn-in by the player (the quest log, build step 7;
## until then an offered quest is accepted at once and paid when its last step
## holds).

const TABLE: StringName = &"quests"
const SECTION: String = "quests"
const ENTRY_KEYS: Array[String] = ["accepted", "steps_done", "base", "shown", "players", "done"]
## An entry of a player's own quest.
const PLAYER_ENTRY_KEYS: Array[String] = ["accepted", "steps_done", "base", "shown", "players", "done", "carried"]
const SCOPE_FARM: String = "farm"
const SCOPE_PLAYER: String = "player"
## Optional flag on a finished farm lab quest earned at lab level 99.
const GOLD_BORDER: String = "gold_border"
## A daily ask's `kind`. See _update_dailies().
const KIND_DAILY: String = "daily"
## A counter step's `whose` when every player's doing counts, in a player's own
## quest too. For what is done to things the farm shares (the plot, the
## fissures): another player using them up moves the ask on, never out of reach.
const WHOSE_FARM: String = "farm"
## What `stat_at_least` may read.
const STATS: Array[String] = ["credits", "credibility", "crystal_ore", "stone", "optical_silk_spools", "clean_audit_streak"]
## What `flag` may read; `oirm_account` is has_oirm_account().
const FLAGS: Array[String] = ["tier1_unlocked", "traceable_lab", "relay_slotted", "audit_grace_used"]
## What `state_is` may read.
const STATES: Array[String] = ["contract_state"]
## The logs `count` may read, by the design's names.
const LOGS: Dictionary = { "cal_log": "cal_log", "job_log": "job_log", "audit_log": "audit_log", "certificates": "certificate_log", "oirm_trips": "oirm_trips" }
## Checks that count from the day the quest was accepted, unless `ever`.
const COUNTING: Array[String] = ["count", "counter"]
## The quest key that puts a quest on the farm notice board (NoticeBoard), and the
## step key that names an input action for the board to show the key of.
const BOARD_KEY: String = "board"
const PROMPT_KEY: String = "prompt"
## A `where` key with this in front matches rows whose value is NOT the one given.
const NOT_PREFIX: String = "not_"
## The checks check_value() knows: what a step's `check` may be, and with
## `always`, `day_at_least` and `day_at_most` (WHENS) what a `when` may be.
const CHECKS: Array[String] = ["stat_at_least", "flag", "band_at_least", "owns_standard", "lab_size", "count", "state_is", "level", "counter", "quest_job", "found_blocks", "plot_untilled", "fissures_open", "wheels_due", "beacons_placed", "relay_spool", "master_audit_passed", "silk_stock"]
## A `when` that is not a step check (offer_holds).
const WHENS: Array[String] = ["always", "day_at_least", "day_at_most"]
## A reward of skill XP is "xp_<skill id>".
const XP_PREFIX: String = "xp_"
## A reward of an XP certificate: the XP it is worth in the one skill its holder
## picks (section 4.4). Sized to the quest, never to the player.
const XP_CERTIFICATE: String = "xp_certificate"
## A `counter` that is not a source of data/skills.json: what Lin has bought in
## spec, of the crop `where.crop_id` names or of every crop.
const SOLD_IN_SPEC: String = "crops_sold_in_spec"
## A quest's key for the zone whose camp it opens for the farm (Camp, zones doc 6.2).
const CAMP: String = "camp"
## The mini-games a step may carry in `minigame`. A Set the Zero step is a
## `count` of `cal_log` rows whose `where` names one instrument: the one the game
## is for. A Wring the Blocks step is a `counter` of built stacks
## (GameState.BLOCK_STACK_COUNT): the game is the build itself. A Hold the
## Reading step has a Set the Zero step's shape; the bench plays the game the
## instrument has that day (MinigameScore.game_for), whichever of the two the
## step names, and that play grades the step. A Thread the Spool step is a
## `counter` of spools seated in the relay (the `slot_spool` source): the game
## is played as the spool goes in. A Torque to Spec step is a `counter` of
## Bram's wheel services (the `service_wheels` source): the game is played as
## the nuts are done.
const MINIGAMES: Array[String] = ["set_the_zero", "hold_the_reading", "wring_the_blocks", "thread_the_spool", "torque_to_spec"]
## A `counter` that is not a source of data/skills.json: the reference blocks the
## farm has dug up. As a counter it counts from when its step opened, so it is
## "find three more".
const BLOCKS_FOUND: String = "blocks_found"
## A `counter` that ends with this adds up every count whose name starts with
## what is before it: "check_with_block:*" is a check of any instrument.
const ANY_SUFFIX: String = "*"
## A reward that gives the farm the shuttle license (Shuttle). Farm quests only.
const SHUTTLE_LICENSE: String = "shuttle_license"
## A reward that opens the Colony Mine's gate for the farm (GameState.open_mine_gate). Farm quests only.
const MINE_GATE: String = "mine_gate"
## A reward that grants the farm the intrinsic silk standard (GameState.grant_intrinsic_standard). Farm quests only.
const INTRINSIC_STANDARD: String = "intrinsic_standard"
## A reward of a keepsake: its id in the data's KEEPSAKES. Cosmetic only.
const KEEPSAKE: String = "keepsake"
const KEEPSAKES: String = "keepsakes"
## A reward of a one-use reward: its id in the data's ONE_USE_REWARDS.
const ONE_USE: String = "one_use"
const ONE_USE_REWARDS: String = "one_use_rewards"
## The rewards that are the farm's and no discount: a free refit, a day of the lab sitter.
const FARM_ONLY_USES: Array[String] = ["free_lab_refit", "lab_sitter"]
## An entry's one key that is not always there: step id -> the score kept.
const SCORES: String = "scores"
## On a quest: its endings (section 8, S2), a list of { id, when and that check's
## fields, phone }. See ending_line().
const ENDINGS: String = "endings"
## On a mini-game step: what the giver says when the quest is paid and the game
## was played to the best grade. A path in dialogue_dispatches.json or the line.
const MINIGAME_LINE: String = "minigame_line"
## On a quest: a list of gates dictionaries of which one must hold ("credibility
## 20, or lab level 6"), beside `gates`, which must all hold. See any_gate_holds().
const ANY_GATE: String = "any_gate"
## On a farm's quest: the job it hands out, a job template as data/economy.json
## has them (id, customer, item, discipline, min_tier, pay, due_in_days,
## bench_minutes) and, if it likes, flat_cut_pct. See GameState.issue_quest_job.
const JOB: String = "job"
## What the giver says when the quest's job is handed out again: a path in
## dialogue_dispatches.json or the line itself.
const JOB_AGAIN_LINE: String = "job_again_line"
## What a quest's job must say in text.
const JOB_TEXTS: Array[String] = ["id", "customer", "item", "discipline"]


static func quests() -> Array[Dictionary]:
	return DataManager.get_records(TABLE, SECTION)


## Moves on and pays the farm's quests, and offers new ones if `offers`.
## `present` is who is on the farm now. True if anything changed. Host only: the
## caller sees to that. A quest whose data is wrong (data_problem) is left alone.
## `played` is a mini-game the command before this look was played with
## (played_game), or nothing.
static func update(farm: Node, present: Array[String], offers: bool = true, played: Dictionary = {}) -> bool:
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
			if is_daily(quest):
				continue
			if scope == SCOPE_FARM:
				if _update_one(farm, quest, farm.quest_state, present, offers, "", played):
					moved = true
			elif scope == SCOPE_PLAYER:
				for player: String in present:
					# Kept only once it holds something.
					var own: Dictionary = farm.player_quest_state.get(player, {})
					var alone: Array[String] = [player]
					if _update_one(farm, quest, own, alone, offers, player, played):
						farm.player_quest_state[player] = own
						moved = true
		if not moved:
			break
		changed = true
	# After the rest, so an ask is picked by the lab level this look ends with.
	if _update_dailies(farm, all, present, offers, played):
		changed = true
	return changed


## True if a `day_at_most` offer can never come now: the farm is past its day, or
## the quest in `unless_taken` is under way (in `farm_state`). The board hides such
## a quest when it is not taken.
static func offer_lapsed(offer: Dictionary, farm_state: Dictionary) -> bool:
	if str(offer.get("when", "")) != "day_at_most":
		return false
	var taken: String = str(offer.get("unless_taken", ""))
	return GameClock.get_day_index() > int(offer.get("day", 0)) or (taken != "" and farm_state.has(taken))


## The farm notice board's own look: takes up the starter jobs (quests with
## `board` set) that are offered and not yet taken, and nothing else, so a command
## never offers other quests. True if one was taken up. Host only.
static func offer_board(farm: Node, present: Array[String]) -> bool:
	var taken: bool = false
	for quest: Dictionary in quests():
		if str(quest.get(BOARD_KEY, "")) == NoticeBoard.FARM and data_problem(quest) == "" \
				and not farm.quest_state.has(str(quest["id"])):
			if _update_one(farm, quest, farm.quest_state, present, true, ""):
				taken = true
	return taken


# --- Daily asks (section 6, D2) -------------------------------------------------

static func is_daily(quest: Dictionary) -> bool:
	return str(quest.get("kind", "")) == KIND_DAILY


## Whether `quest_id` is one of this build's daily asks.
static func is_daily_id(quest_id: String) -> bool:
	return is_daily(DataManager.get_record(TABLE, quest_id, SECTION))


## The daily asks whose data is right.
static func daily_quests() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for quest: Dictionary in quests():
		if is_daily(quest) and data_problem(quest) == "":
			out.append(quest)
	return out


## Host: the daily asks of the players in `present`. An ask of another day is
## taken out, done or not: nothing is paid for it and nothing is lost. Today's
## is moved on and paid as any player's own quest is. With `offers`, a player who
## holds none of today's is given one (pick_daily). True if anything changed.
static func _update_dailies(farm: Node, all: Array[Dictionary], present: Array[String], offers: bool, played: Dictionary = {}) -> bool:
	var dailies: Array[Dictionary] = []
	for quest: Dictionary in all:
		if is_daily(quest):
			dailies.append(quest)
	if dailies.is_empty():
		return false
	var today: int = GameClock.get_day_index()
	var changed: bool = false
	for player: String in present:
		var own: Dictionary = farm.player_quest_state.get(player, {})
		var held: Dictionary = {}
		var moved: bool = false
		for quest: Dictionary in dailies:
			var id: String = str(quest["id"])
			if not own.has(id):
				continue
			if int((own[id] as Dictionary).get("accepted", -1)) != today:
				own.erase(id)
				moved = true
			elif held.is_empty():
				held = quest
		if held.is_empty() and offers:
			held = pick_daily(farm, dailies, player, today)
		var alone: Array[String] = [player]
		if not held.is_empty() and _update_one(farm, held, own, alone, offers, player, played):
			moved = true
		if moved:
			changed = true
			# Kept only while it holds something.
			if own.is_empty():
				farm.player_quest_state.erase(player)
			else:
				farm.player_quest_state[player] = own
	return changed


## Host: the look at one player's daily ask alone, with offers, for a guest who
## has just come in: they need not wait for the morning (GameState.let_in_guest).
static func update_daily_of(farm: Node, player_id: String) -> bool:
	var alone: Array[String] = [player_id]
	return _update_dailies(farm, daily_quests(), alone, true)


## The ask `player_id` is given on `day`: one of `dailies` whose gates and offer
## hold for them now, by daily_roll(). {} when none holds. The pick depends on
## which asks are open when it is made: a player who comes in later in the day
## (after a block is dug up, say) may roll among other asks than one who was
## there in the morning. An ask once given is held for its day and is not picked
## again, whatever opens or closes after.
static func pick_daily(farm: Node, dailies: Array[Dictionary], player_id: String, day: int) -> Dictionary:
	var alone: Array[String] = [player_id]
	var open: Array[Dictionary] = []
	for quest: Dictionary in dailies:
		if is_offered(farm, quest, alone, player_id):
			open.append(quest)
	if open.is_empty():
		return {}
	return open[daily_roll(int(farm.world_seed), day, player_id) % open.size()]


## A whole number from the farm's seed, the day and the player, the same on any
## machine and after any reload. Not GameState's generator: asking draws nothing.
static func daily_roll(world_seed: int, day: int, player_id: String) -> int:
	return ("%d:%d:%s" % [world_seed, day, player_id]).sha256_text().left(7).hex_to_int()


## The daily ask `player_id` holds today, as data/quests.json has it, or {}. It
## reads player_quest_state alone, so a guest's copy answers as the host does.
static func daily_ask(farm: Node, player_id: String) -> Dictionary:
	var own: Dictionary = farm.player_quest_state.get(player_id, {})
	for quest: Dictionary in daily_quests():
		var entry: Variant = own.get(str(quest["id"]))
		if entry is Dictionary and int(entry.get("accepted", -1)) == GameClock.get_day_index():
			return quest
	return {}


## Whether `player_id` has done today's ask.
static func daily_done(farm: Node, player_id: String) -> bool:
	var ask: Dictionary = daily_ask(farm, player_id)
	var own: Dictionary = farm.player_quest_state.get(player_id, {})
	return not ask.is_empty() and int((own[str(ask["id"])] as Dictionary).get("done", -1)) >= 0


## One quest in `state`: the farm's quest_state, or one player's own entries
## (`owner` is then that player, and `present` that player alone).
static func _update_one(farm: Node, quest: Dictionary, state: Dictionary, present: Array[String], offers: bool, owner: String, played: Dictionary = {}) -> bool:
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
	# A quest that carries a camp holds that zone's camp open for the farm while it is under
	# way: on taking it, and on a look at a loaded or merged one (open_camp is idempotent).
	if quest.has(CAMP) and farm.has_method("open_camp"):
		farm.open_camp(str(quest[CAMP]))
	var title: String = str(quest["title"])
	var steps: Array = quest["steps"]
	var done: Array = entry["steps_done"]
	var moved: bool = is_new
	# The quest's own job: handed out with the quest, and again on any offering
	# look that finds it gone with no row in job_log (it ran out, or was dropped).
	var issued: Dictionary = {}
	if offers and owner == "" and quest.has(JOB):
		issued = farm.issue_quest_job(id, quest[JOB])
		if not issued.is_empty():
			moved = true
			if not is_new:
				var again: String = phone_line(str(quest.get(JOB_AGAIN_LINE, "")))
				if again != "":
					farm.post_phone("%s: %s" % [giver_name(quest), again])
				farm.post_phone(farm.quest_job_text(issued))
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
			_keep_score(farm, entry, step, played, owner)
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
		if is_daily(quest):
			# An ask is the giver's own line, then what counts.
			farm.post_phone("%s: %sToday's ask: %s" % [giver_name(quest), "" if said == "" else said + " ", next])
		else:
			farm.post_phone("%s: New quest, %s. %s%s" % [giver_name(quest), title, "" if said == "" else said + " ", next])
		if not issued.is_empty():
			farm.post_phone(farm.quest_job_text(issued))
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
	if owner == "" and str(quest.get("kind", "")) == "lab" and str(quest.get("scope", SCOPE_FARM)) == SCOPE_FARM \
			and farm.lab_gate_open(Cosmetics.GATE_GOLD_BORDER):
		entry[GOLD_BORDER] = true
	# Before anything is paid: a reward must not change which ending it is.
	var line: String = phone_line(ending_line(farm, quest, present, owner))
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
	# The provisional way through a gate: most of the lab XP still missing to
	# the level of the row that names this quest, worked out after the lump.
	var lift: int = farm.provisional_lab_xp(str(quest.get("id", "")))
	if lift > 0:
		farm.post_phone("OIRM counts \"%s\" toward the lab level: %s lab XP." % [str(quest.get("title", "")), SP811.integer(lift)])
		farm.give_lab_xp(lift)
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
	if rewards.get(SHUTTLE_LICENSE, false) is bool and rewards.get(SHUTTLE_LICENSE, false):
		farm.grant_shuttle_license()
	if rewards.get(MINE_GATE, false) is bool and rewards.get(MINE_GATE, false) and farm.has_method("open_mine_gate"):
		farm.open_mine_gate()
	if rewards.get(INTRINSIC_STANDARD, false) is bool and rewards.get(INTRINSIC_STANDARD, false) and farm.has_method("grant_intrinsic_standard"):
		farm.grant_intrinsic_standard()
	# One each, held until its player spends it (GameState.spend_xp_certificate).
	# A player who holds or has spent this quest's certificate, here or on another
	# farm, is not given it again.
	var certificate: int = int(rewards.get(XP_CERTIFICATE, 0))
	var given: int = 0
	if certificate > 0:
		for player: String in players:
			# A daily ask's is given each time the ask is done.
			if (is_daily(quest) or not farm.has_had_xp_certificate(str(quest["id"]), player)) and farm.give_xp_certificate(player, str(quest["id"]), certificate) != "":
				given += 1
	if given > 0:
		farm.post_phone("XP CERTIFICATE: %s XP in a skill of your choice, for each player who took part. Open SKILLS to spend it." % SP811.integer(certificate))
	# One each for a reward of a player, one for the farm for the farm's: held
	# until the action it is for uses it (GameState.give_one_use).
	var one_use: String = str(rewards.get(ONE_USE, ""))
	if one_use != "":
		var holders: Array[String] = []
		if one_use_of_farm(one_use):
			holders.append(farm.FARM_HOLDER)
		else:
			holders.assign(players)
		var held: int = 0
		for holder: String in holders:
			if farm.give_one_use(one_use, holder):
				held += 1
		if held > 0 and one_use_held_line(one_use) != "":
			farm.post_phone(one_use_held_line(one_use))
	# Section 7.2: a mini-game step played to Fine or better adds to the quest's
	# credits. A skip or a poor try kept no score, and is paid as written.
	# The same share more of its skill XP [ASSUMPTION], so a quest that pays no
	# credits has a bonus too.
	var score: int = quest_score(quest, entry)
	var more: Array[String] = []
	var bonus: int = roundi(int(rewards.get("credits", 0)) * MinigameScore.quest_bonus(score))
	if bonus > 0:
		farm.add_credits(bonus)
		more.append("%s CR" % SP811.integer(bonus))
	for key: Variant in rewards:
		var skill: String = _reward_skill(str(key))
		var extra: int = roundi(int(rewards[key]) * MinigameScore.quest_bonus(score)) if skill != "" else 0
		if extra <= 0:
			continue
		var paid: Array[String] = players
		if farm.is_farm_skill(skill):
			paid = [str(farm.local_player_id)]
		for player: String in paid:
			farm.give_skill_xp(skill, extra, player)
		more.append("%s %s XP" % [SP811.integer(extra), str(DataManager.get_record(&"skills", skill, "skills").get("display_name", skill))])
	if not more.is_empty():
		farm.post_phone("QUEST BONUS: %s, played to %s. %s more." % [str(quest["title"]), MinigameScore.grade_name(score).to_upper(), ", ".join(more)])
	if line != "":
		farm.post_phone("%s: %s" % [giver_name(quest), line])
	# The best grade also has a line from the giver, one for each such step.
	if MinigameScore.earns_line(score):
		for step: Variant in quest["steps"]:
			var said: String = phone_line(str(step.get(MINIGAME_LINE, "")))
			if step.has("minigame") and said != "":
				farm.post_phone("%s: %s" % [giver_name(quest), said])


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
	if rewards.get(SHUTTLE_LICENSE, false) is bool and rewards.get(SHUTTLE_LICENSE, false):
		parts.append("the shuttle license")
	if rewards.get(MINE_GATE, false) is bool and rewards.get(MINE_GATE, false):
		parts.append("the key to the Mine's gate")
	if rewards.get(INTRINSIC_STANDARD, false) is bool and rewards.get(INTRINSIC_STANDARD, false):
		parts.append("the intrinsic silk standard")
	if keepsake_name(str(rewards.get(KEEPSAKE, ""))) != "":
		parts.append("a keepsake (%s)" % keepsake_name(str(rewards[KEEPSAKE])))
	if one_use_name(str(rewards.get(ONE_USE, ""))) != "":
		parts.append(one_use_name(str(rewards[ONE_USE])))
	return ", ".join(parts)


## A keepsake's name, or "" for none the data has.
static func keepsake_name(keepsake_id: String) -> String:
	if keepsake_id == "" or not DataManager.has_record(TABLE, keepsake_id, KEEPSAKES):
		return ""
	return str(DataManager.get_record(TABLE, keepsake_id, KEEPSAKES).get("display_name", keepsake_id))


## A keepsake's text, "" for one the data has none of.
static func keepsake_text(keepsake_id: String) -> String:
	if keepsake_name(keepsake_id) == "":
		return ""
	return str(DataManager.get_record(TABLE, keepsake_id, KEEPSAKES).get("text", ""))


## A one-use reward the data has (an id of `one_use_rewards`).
static func has_one_use(reward_id: String) -> bool:
	return reward_id != "" and DataManager.has_record(TABLE, reward_id, ONE_USE_REWARDS)


## Whether the reward is the farm's (held by the farm) and not a player's.
static func one_use_of_farm(reward_id: String) -> bool:
	return has_one_use(reward_id) and str(DataManager.get_record(TABLE, reward_id, ONE_USE_REWARDS).get("holder", "player")) == "farm"


## The percent a discount reward takes off, 0 for any other.
static func one_use_pct(reward_id: String) -> int:
	if not has_one_use(reward_id):
		return 0
	return int(DataManager.get_record(TABLE, reward_id, ONE_USE_REWARDS).get("pct", 0))


## "" or what is wrong with a one-use reward's own row: its holder is a player
## or the farm, a percent is 0 to 100, and the ones that are not a discount
## (the free refit, the lab sitter's day) carry none and are the farm's.
static func one_use_problem(reward_id: String) -> String:
	if not has_one_use(reward_id):
		return "no such reward."
	var row: Dictionary = DataManager.get_record(TABLE, reward_id, ONE_USE_REWARDS)
	if not str(row.get("holder", "player")) in ["player", "farm"]:
		return "its holder is not player or farm."
	var pct: int = int(row.get("pct", 0))
	if pct < 0 or pct > 100:
		return "its percent is not 0 to 100."
	if reward_id in FARM_ONLY_USES and (not one_use_of_farm(reward_id) or pct != 0):
		return "it is the farm's and takes no percent."
	return ""


## A one-use reward's name, or "" for none the data has.
static func one_use_name(reward_id: String) -> String:
	if not has_one_use(reward_id):
		return ""
	return str(DataManager.get_record(TABLE, reward_id, ONE_USE_REWARDS).get("display_name", reward_id))


## What the phone says when the reward is given, and when it is used.
static func one_use_held_line(reward_id: String) -> String:
	return _one_use_text(reward_id, "held_line")


static func one_use_used_line(reward_id: String) -> String:
	return _one_use_text(reward_id, "used_line")


static func _one_use_text(reward_id: String, key: String) -> String:
	if not has_one_use(reward_id):
		return ""
	return str(DataManager.get_record(TABLE, reward_id, ONE_USE_REWARDS).get(key, ""))


## The keepsakes a player holds: those of their own quests that are done, here
## or brought done from another farm. Ids, in the data's order. For show only.
static func keepsakes_of(farm: Node, player_id: String) -> Array[String]:
	var out: Array[String] = []
	for quest: Dictionary in quests():
		var keepsake: String = str((quest.get("rewards", {}) as Dictionary).get(KEEPSAKE, ""))
		if keepsake != "" and data_problem(quest) == "" and not keepsake in out and is_done(farm, str(quest["id"]), player_id):
			out.append(keepsake)
	return out


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


## What the giver says when the quest is paid, as a path or the words: the
## `phone` of the first of the quest's `endings` whose check holds, or the
## reward's own `phone` when it has no endings or none holds. _finish() asks
## before it pays, so the quest's own reward (its credits, its lab XP) is not
## in what an ending's check reads.
## An ending changes the words only; every ending pays the same. Which one it
## was is not kept: the line is on the phone, and nothing reads it later.
static func ending_line(farm: Node, quest: Dictionary, present: Array[String], owner: String = "") -> String:
	var endings: Variant = quest.get(ENDINGS, [])
	if endings is Array:
		for ending: Variant in endings:
			if ending is Dictionary and offer_holds(farm, ending, present, owner):
				return str(ending.get("phone", ""))
	var rewards: Dictionary = quest.get("rewards", {})
	return str(rewards.get("phone", ""))


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
		if str(step.get("check", "")) == "quest_job" and (not step.get("quest") is String or step["quest"] == ""):
			return "step '%s' looks for a quest's job and names no quest." % id
		if str(step.get("check", "")) == "relay_spool" and (not step.get("species") is String or step["species"] == ""):
			return "step '%s' checks the relay spool and names no species." % id
		if str(step.get("check", "")) == "silk_stock" and (not step.get("species") is String or step["species"] == ""):
			return "step '%s' checks silk stock and names no species." % id
		if step.has(MINIGAME_LINE) and not step.has("minigame"):
			return "step '%s' has a mini-game line and no mini-game." % id
		if step.has("minigame"):
			if not step["minigame"] is String or not step["minigame"] in MINIGAMES:
				return "step '%s' has a mini-game this build does not have." % id
			if step["minigame"] == MinigameScore.WRING_THE_BLOCKS:
				if not is_stack_step(step):
					return "step '%s' has Wring the Blocks and is not a counter of built stacks." % id
			elif step["minigame"] == MinigameScore.THREAD_THE_SPOOL:
				if not is_seat_step(step):
					return "step '%s' has Thread the Spool and is not a counter of seated spools." % id
			elif step["minigame"] == MinigameScore.TORQUE_TO_SPEC:
				if not is_service_step(step):
					return "step '%s' has Torque to Spec and is not a counter of wheel services." % id
			elif step_instrument(step) == "":
				return "step '%s' has a mini-game and is not a count of one instrument's cal_log rows." % id
			else:
				# The instrument picks the bench game (MinigameScore.game_for): a step
				# must name one its instrument plays, or it would never be offered.
				var plays: Array[String] = MinigameScore.games_in_data(step_instrument(step))
				if not plays.is_empty() and not step["minigame"] in plays:
					return "step '%s' names %s and its instrument plays %s." % [id, step["minigame"], " or ".join(plays)]
			if step.has(MINIGAME_LINE) and (not step[MINIGAME_LINE] is String or step[MINIGAME_LINE] == ""):
				return "step '%s' has a mini-game line that is not text." % id
	for step: Variant in steps:
		if str(step.get("check", "")) == "beacons_placed" and step_need(step) > LavaHub.SPOTS.size():
			return "step '%s' wants more beacons than there are spots." % str(step.get("id", ""))
	if quest.has(BOARD_KEY) and quest[BOARD_KEY] != NoticeBoard.FARM:
		return "its board is not one there is (farm)."
	if quest.has(BOARD_KEY) and (str(quest.get("scope", SCOPE_FARM)) != SCOPE_FARM or is_daily(quest)):
		return "a board quest must be a farm quest and not a daily ask."
	for step: Variant in steps:
		if step.has(PROMPT_KEY) and (not step[PROMPT_KEY] is String or not InputMap.has_action(StringName(step[PROMPT_KEY]))):
			return "step '%s' has a prompt that is not an input action." % str(step.get("id", ""))
	if quest.has(CAMP) and (not quest[CAMP] is String or not Camp.has_camp(quest[CAMP])):
		return "its camp is not a zone that has one."
	var lab_gate: Variant = (quest.get("gates", {}) as Dictionary).get("lab_gate") if quest.get("gates") is Dictionary else null
	if lab_gate != null:
		var known: bool = false
		for row: Dictionary in DataManager.get_records(&"skills", "lab_gates"):
			known = known or str(row.get("id", "")) == str(lab_gate)
		if not lab_gate is String or not known:
			return "its lab_gate is not a row of the lab's gates."
	if quest.has("zone") and (not quest["zone"] is String or not ZoneData.has_zone(StringName(quest["zone"]))):
		return "its zone is not one data/zones.json has."
	for key: String in ["gates", "offer", "closed_when", "rewards"]:
		if quest.has(key) and not quest[key] is Dictionary:
			return "'%s' is not a dictionary." % key
	if (quest.get("rewards", {}) as Dictionary).has(SHUTTLE_LICENSE):
		var license: Variant = (quest["rewards"] as Dictionary)[SHUTTLE_LICENSE]
		if typeof(license) != TYPE_BOOL or not license:
			return "its shuttle_license reward is not true."
		if str(quest.get("scope", SCOPE_FARM)) != SCOPE_FARM or is_daily(quest):
			return "the shuttle license is the farm's: a farm quest that is not a daily ask."
	if (quest.get("rewards", {}) as Dictionary).has(MINE_GATE):
		var gate_key: Variant = (quest["rewards"] as Dictionary)[MINE_GATE]
		if typeof(gate_key) != TYPE_BOOL or not gate_key:
			return "its mine_gate reward is not true."
		if str(quest.get("scope", SCOPE_FARM)) != SCOPE_FARM or is_daily(quest):
			return "the Mine's gate is the farm's: a farm quest that is not a daily ask."
	if (quest.get("rewards", {}) as Dictionary).has(INTRINSIC_STANDARD):
		var intrinsic_flag: Variant = (quest["rewards"] as Dictionary)[INTRINSIC_STANDARD]
		if typeof(intrinsic_flag) != TYPE_BOOL or not intrinsic_flag:
			return "its intrinsic_standard reward is not true."
		if str(quest.get("scope", SCOPE_FARM)) != SCOPE_FARM or is_daily(quest):
			return "the intrinsic silk standard is the farm's: a farm quest that is not a daily ask."
	var keepsake: Variant = (quest.get("rewards", {}) as Dictionary).get(KEEPSAKE)
	if keepsake != null:
		if not keepsake is String or not DataManager.has_record(TABLE, keepsake, KEEPSAKES):
			return "its keepsake is not one the data has."
		# Held by having done the quest: so only a player's own, done once, and
		# never one that can be closed with nothing paid.
		if str(quest.get("scope", SCOPE_FARM)) != SCOPE_PLAYER or is_daily(quest) or quest.has("closed_when"):
			return "a keepsake is for a player's own quest that is not a daily ask and has no closed_when."
	var one_use: Variant = (quest.get("rewards", {}) as Dictionary).get(ONE_USE)
	if one_use != null:
		if not one_use is String or not has_one_use(one_use):
			return "its one-use reward is not one the data has."
		if one_use_problem(one_use) != "":
			return "its one-use reward is wrong: %s" % one_use_problem(one_use)
		if is_daily(quest):
			return "a daily ask pays no one-use reward."
		if one_use_of_farm(one_use) != (str(quest.get("scope", SCOPE_FARM)) == SCOPE_FARM):
			return "a one-use reward of a player is for a player's own quest, and one of the farm's for a farm quest."
	if is_daily(quest):
		if str(quest.get("scope", SCOPE_FARM)) != SCOPE_PLAYER:
			return "a daily ask is not a player's own (scope player)."
		if int((quest.get("rewards", {}) as Dictionary).get("quest_points", 0)) != 0:
			return "a daily ask pays quest points."
	if quest.has(ANY_GATE):
		if not quest[ANY_GATE] is Array or (quest[ANY_GATE] as Array).is_empty():
			return "'any_gate' is not a list, or is empty."
		for gates: Variant in quest[ANY_GATE]:
			if not gates is Dictionary or (gates as Dictionary).is_empty():
				return "'any_gate' has an entry that is not a dictionary of gates."
	if quest.has(JOB):
		var job: Variant = quest[JOB]
		if not job is Dictionary or str(quest.get("scope", SCOPE_FARM)) != SCOPE_FARM:
			return "'job' is not a dictionary, or the quest is not the farm's."
		for key: String in JOB_TEXTS:
			if not job.get(key) is String or job[key] == "":
				return "'job' has no %s." % key
		for key: String in ["pay", "min_tier", "due_in_days", "bench_minutes", "flat_cut_pct"]:
			if job.has(key) and not (job[key] is int or job[key] is float):
				return "'job' has a %s that is not a number." % key
		for key: String in ["job_id", "due_day", "accepted_day", "at_bench", "quest", "min_band", "area"]:
			if job.has(key):
				return "'job' has '%s', which is not a quest job's to say." % key
	if quest.has(JOB_AGAIN_LINE) and (not quest.has(JOB) or not quest[JOB_AGAIN_LINE] is String or quest[JOB_AGAIN_LINE] == ""):
		return "'job_again_line' is not text, or the quest has no job."
	if quest.has(ENDINGS):
		if not quest[ENDINGS] is Array or (quest[ENDINGS] as Array).is_empty():
			return "'endings' is not a list, or is empty."
		var ending_ids: Array[String] = []
		for ending: Variant in quest[ENDINGS]:
			if not ending is Dictionary:
				return "an ending is not a dictionary."
			var ending_id: Variant = ending.get("id", "")
			if not ending_id is String or ending_id == "" or ending_id in ending_ids:
				return "an ending has no id, or two endings have the same id."
			ending_ids.append(ending_id)
			if not ending.get("when") is String or not ending.get("phone") is String or ending["phone"] == "":
				return "ending '%s' has no check (when) or no line (phone)." % ending_id
			if not when_known(ending["when"]):
				return "ending '%s' has a check (when) this build does not have." % ending_id
	return ""


# --- Offering -----------------------------------------------------------------

## Whether the quest's own gates and its offer hold.
static func is_offered(farm: Node, quest: Dictionary, present: Array[String], owner: String = "") -> bool:
	return gates_hold(farm, quest.get("gates", {}), present, owner) and any_gate_holds(farm, quest, present, owner) \
			and offer_holds(farm, quest.get("offer", {}), present, owner)


## `any_gate`: a list of gates dictionaries, and one of them must hold (each as
## gates_hold reads it, so all of that one's keys). A quest with none is open.
static func any_gate_holds(farm: Node, quest: Dictionary, present: Array[String], owner: String = "") -> bool:
	if not quest.has(ANY_GATE):
		return true
	var list: Variant = quest[ANY_GATE]
	if list is Array:
		for gates: Variant in list:
			if gates is Dictionary and gates_hold(farm, gates, present, owner):
				return true
	return false


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
			"lab_gate":
				# A lab gate row (data/skills.json lab_gates), as the lab level or a kept row opens it.
				if not farm.lab_gate_open(str(gate)):
					return false
			"band":
				if farm.credibility_band_index() < farm._band_index_named(str(gate)):
					return false
			"credibility":
				if int(farm.credibility) < int(gate):
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
			"found_blocks":
				# The farm's: blocks are shared, whoever dug them up.
				if (farm.found_blocks as Dictionary).size() < int(gate):
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


## Whether a `when` is one offer_holds() can read: always, a day, or a step check.
static func when_known(when: String) -> bool:
	return when in WHENS or when in CHECKS


## `offer`: always (or nothing), a day, or any step check that holds now.
static func offer_holds(farm: Node, offer: Dictionary, present: Array[String], owner: String = "") -> bool:
	var when: String = str(offer.get("when", "always"))
	if when == "always":
		return true
	if when == "day_at_least":
		return GameClock.get_day_index() >= int(offer.get("day", 0))
	# A young farm only, and not once the quest named in `unless_taken` is under way.
	if when == "day_at_most":
		return not offer_lapsed(offer, farm.quest_state)
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
			# `with_grow`: a grow under way counts as one size up (L4's first step).
			var growing: bool = bool(step.get("with_grow", false)) and str((farm.lab_build as Dictionary).get("kind", "")) == "grow"
			return int(farm.lab_size) + (1 if growing else 0)
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
			# The farm's, whoever dug them up: the blocks are shared.
			if str(step.get("counter", "")) == BLOCKS_FOUND:
				return (farm.found_blocks as Dictionary).size()
			# `whose` farm: every player's doing counts, in a player's own quest too.
			if owner != "" and str(step.get("whose", "")) != WHOSE_FARM:
				return _action_count(farm, str(step.get("counter", "")), owner)
			var total: int = 0
			for player: String in farm._known_players():
				total += _action_count(farm, str(step.get("counter", "")), player)
			return total
		"quest_job":
			return int(farm.has_quest_job(str(step.get("quest", ""))))
		"found_blocks":
			return (farm.found_blocks as Dictionary).size()
		"plot_untilled":
			return farm.untilled_cells()
		"fissures_open":
			return farm.open_fissures()
		"wheels_due":
			return int(farm.wheels_due())
		"beacons_placed":
			# The farm's, whoever set them down. Not a counting check: with only
			# three spots, one set down before the quest was offered must count.
			return (farm.beacons_placed as Array).size()
		"relay_spool":
			return int(farm.has_relay_spool(StringName(str(step.get("species", "")))))
		"master_audit_passed":
			return int(bool(farm.master_audit_passed))
		"silk_stock":
			return farm.whole_spools_of(StringName(str(step.get("species", ""))))
	return 0


## A player's count of `counter`, or with ANY_SUFFIX of every count that starts
## with what is before it.
static func _action_count(farm: Node, counter: String, player_id: String) -> int:
	if not counter.ends_with(ANY_SUFFIX):
		return farm.action_count(counter, player_id)
	var start: String = counter.trim_suffix(ANY_SUFFIX)
	var total: int = 0
	for source: Variant in (farm.action_counts as Dictionary).get(player_id, {}):
		if start != "" and str(source).begins_with(start):
			total += farm.action_count(str(source), player_id)
	return total


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
			# A key that starts with not_ wants the row's value to differ.
			var negated: bool = str(key).begins_with(NOT_PREFIX)
			var field: String = str(key).trim_prefix(NOT_PREFIX) if negated else str(key)
			if matches and _same((row as Dictionary).get(field), where[key]) == negated:
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


# --- Mini-game steps (section 7.4) ----------------------------------------------

## The instrument a step's mini-game is for: the one its `count` of cal_log rows
## names in `where`. "" for any other step.
static func step_instrument(step: Dictionary) -> String:
	var where: Variant = step.get("where")
	if str(step.get("check", "")) != "count" or str(step.get("log", "")) != "cal_log" or not where is Dictionary:
		return ""
	var instrument: Variant = where.get("instrument_id", "")
	return instrument if instrument is String else ""


## True for a step that counts built stacks of gauge blocks: the one kind of
## step Wring the Blocks may be carried by.
static func is_stack_step(step: Dictionary) -> bool:
	return str(step.get("check", "")) == "counter" and str(step.get("counter", "")) == "build_block_stack"


## True for a step that counts spools seated in the relay: the one kind of step
## Thread the Spool may be carried by.
static func is_seat_step(step: Dictionary) -> bool:
	return str(step.get("check", "")) == "counter" and str(step.get("counter", "")) == "slot_spool"


## True for a step that counts Bram's wheel services: the one kind of step
## Torque to Spec may be carried by.
static func is_service_step(step: Dictionary) -> bool:
	return str(step.get("check", "")) == "counter" and str(step.get("counter", "")) == "service_wheels"


## True where `step` is the kind a game with no instrument is carried by: a
## counter of built stacks for Wring the Blocks, of seated spools for Thread
## the Spool, of wheel services for Torque to Spec. False for a bench game.
static func is_bare_step(step: Dictionary, minigame: String) -> bool:
	match minigame:
		MinigameScore.WRING_THE_BLOCKS:
			return is_stack_step(step)
		MinigameScore.THREAD_THE_SPOOL:
			return is_seat_step(step)
		MinigameScore.TORQUE_TO_SPEC:
			return is_service_step(step)
	return false


## True while an accepted quest that is not done has an open step carrying
## `minigame` for this instrument: a key moment, however often the lab has
## calibrated that kind before (a standard's own calibration is left to
## MinigameScore). The farm's quests count for every player, and a
## player's own quests for that player. It only reads quest_state and
## player_quest_state, which a guest has as the host's copy, so it answers the
## same on a guest. In a quest done in order only the first step not done is open.
## Wring the Blocks, Thread the Spool and Torque to Spec have no instrument:
## their step is one that counts built stacks, seated spools or wheel services,
## and `instrument_id` is "" for them.
static func has_minigame_step(farm: Node, minigame: String, instrument_id: String, player_id: String) -> bool:
	var bare: bool = minigame in [MinigameScore.WRING_THE_BLOCKS, MinigameScore.THREAD_THE_SPOOL, MinigameScore.TORQUE_TO_SPEC]
	if instrument_id == "" and not bare:
		return false
	for quest: Dictionary in quests():
		if data_problem(quest) != "":
			continue
		var state: Dictionary = farm.quest_state
		if str(quest.get("scope", SCOPE_FARM)) == SCOPE_PLAYER:
			state = farm.player_quest_state.get(player_id, {})
		var entry: Variant = state.get(str(quest["id"]))
		if not entry is Dictionary or int(entry.get("done", -1)) >= 0:
			continue
		var in_order: bool = not bool(quest.get("any_order", false))
		for step: Variant in quest["steps"]:
			if str(step.get("id", "")) in entry.get("steps_done", []):
				continue
			if str(step.get("minigame", "")) == minigame and (is_bare_step(step, minigame) if bare else step_instrument(step) == instrument_id):
				return true
			if in_order:
				break
	return false


## What FarmCommands tells the look after a command a mini-game was played with:
## the game, the instrument, who played, and the score the host counted.
static func played_game(minigame: String, instrument_id: String, player_id: String, score: int) -> Dictionary:
	return { "minigame": minigame, "instrument_id": instrument_id, "player_id": player_id, "score": score }


## A step was done in the look after `played`: its score is kept if the game was
## this step's and it earned a grade. A skip, a poor try and a calibration with
## no game keep nothing, so their entry is the same as it always was. A
## player's own quest (`owner`) keeps only that player's score. The newest
## cal_log row must be the scored calibration itself: the player's own by hand,
## traceable, and a row the step counts, so a robot's or the manager's row that
## did the step is never given a player's grade. One calibration grades one
## quest: the first whose step it does (`played` is emptied once it is kept).
static func _keep_score(farm: Node, entry: Dictionary, step: Dictionary, played: Dictionary, owner: String) -> void:
	if played.is_empty() or not MinigameScore.grades_step(str(step.get("minigame", "")), str(played.get("minigame", ""))):
		return
	var player: String = str(played.get("player_id", ""))
	if owner != "" and owner != player:
		return
	var score: int = mini(int(played.get("score", MinigameScore.SKIPPED)), MinigameScore.MAX_SCORE)
	if not MinigameScore.is_graded(score):
		return
	if is_stack_step(step) or is_seat_step(step) or is_service_step(step):
		# Wring the Blocks: the build that did the step is the game itself, and
		# only a player's build is counted (GameState.build_block_stack). Thread
		# the Spool: the seat that did the step is the one the game was played for.
		# Torque to Spec: the same, for the wheel service.
		if not is_bare_step(step, str(played.get("minigame", ""))):
			return
		(entry.get_or_add(SCORES, {}) as Dictionary)[str(step.get("id", ""))] = score
		played.clear()
		return
	if step_instrument(step) == "" or step_instrument(step) != str(played.get("instrument_id", "")):
		return
	var log: Array = farm.cal_log
	var row: Variant = log[-1] if not log.is_empty() else null
	if not row is Dictionary or not bool(row.get("traceable", false)) or str(row.get("performed_by", "")) != player or str(row.get("programmed_by", "")) != "":
		return
	var where: Dictionary = step["where"]
	for key: Variant in where:
		var negated: bool = str(key).begins_with(NOT_PREFIX)
		var field: String = str(key).trim_prefix(NOT_PREFIX) if negated else str(key)
		if _same(row.get(field), where[key]) == negated:
			return
	var scores: Dictionary = entry.get_or_add(SCORES, {})
	scores[str(step.get("id", ""))] = score
	played.clear()


## The quest's score for its grade (section 7.2): the lowest kept among its
## mini-game steps, or MinigameScore.SKIPPED if any has none or it has no such step.
static func quest_score(quest: Dictionary, entry: Dictionary) -> int:
	var scores: Dictionary = entry.get(SCORES, {})
	var lowest: int = MinigameScore.SKIPPED
	for step: Variant in quest["steps"]:
		if not step.has("minigame"):
			continue
		var id: String = str(step.get("id", ""))
		if not scores.has(id):
			return MinigameScore.SKIPPED
		lowest = int(scores[id]) if lowest == MinigameScore.SKIPPED else mini(lowest, int(scores[id]))
	return lowest


# --- Saved state --------------------------------------------------------------

## "" or why a saved quest_state can't be loaded. A quest this build's data does
## not have is kept as it is and left alone, so its "done" is still there if the
## quest comes back.
static func state_problem(state: Dictionary, keys: Array[String] = ENTRY_KEYS, name: String = "quest_state") -> String:
	for id: Variant in state:
		var entry: Variant = state[id]
		# `scores` is there only once a mini-game step was played to a grade;
		# `gold_border` only on a farm lab quest finished at lab level 99.
		var extra_keys: int = int(entry is Dictionary and entry.has(SCORES)) + int(entry is Dictionary and entry.has(GOLD_BORDER))
		if not id is String or id == "" or typeof(entry) != TYPE_DICTIONARY or entry.size() != keys.size() + extra_keys or not entry.has_all(keys):
			return "'%s' has an entry that is not a quest's." % name
		if not entry["accepted"] is int or not entry["done"] is int or entry["accepted"] < 0 or entry["done"] < -1:
			return "'%s' has a day that is not a day." % name
		if not _all_text(entry["steps_done"]) or not _all_text(entry["players"]):
			return "'%s' has a list that is not of names." % name
		if not _text_to_counts(entry["base"]) or not _text_to_counts(entry["shown"]) or not _text_to_counts(entry.get("carried", {})):
			return "'%s' has a count that is not a whole number." % name
		if entry.has(GOLD_BORDER) and not entry[GOLD_BORDER] is bool:
			return "'%s' has a gold_border that is not a bool." % name
		if entry.has(SCORES):
			if not _text_to_counts(entry[SCORES]):
				return "'%s' has a score that is not a mini-game's." % name
			for score: Variant in (entry[SCORES] as Dictionary).values():
				if not MinigameScore.is_graded(score) or score > MinigameScore.MAX_SCORE:
					return "'%s' has a score that is not a mini-game's." % name
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

## The quests of scope "player" whose data is right, by id. Not the daily asks:
## they do not travel.
static func player_quests() -> Dictionary:
	var out: Dictionary = {}
	for quest: Dictionary in quests():
		if str(quest.get("scope", SCOPE_FARM)) == SCOPE_PLAYER and not is_daily(quest) and data_problem(quest) == "":
			out[str(quest["id"])] = quest
	return out


## What `player_id` has of their own quests here, as it travels in their file:
## quest id -> { done, steps (ids of the steps done), counts (step id -> the
## highest count reached) }.
static func travelling(farm: Node, player_id: String) -> Dictionary:
	var out: Dictionary = {}
	var own: Dictionary = farm.player_quest_state.get(player_id, {})
	for id: Variant in own:
		# A daily ask stays on its farm.
		if is_daily_id(str(id)):
			continue
		var entry: Dictionary = own[id]
		out[id] = { "done": int(entry["done"]) >= 0, "steps": (entry["steps_done"] as Array).duplicate(), "counts": (entry["shown"] as Dictionary).duplicate() }
	return out


## Host: `player_id` comes with `brought`, their own quests as travelling() gives
## them from other farms. A quest done anywhere is done here, and is not paid
## again. One under way is taken up where it stands: a step done anywhere is
## done, and a count is the higher of here and there, never the two added.
## Only this build's player quests are taken, and only their steps. True if
## anything changed. A quest that comes with every step done was finished
## somewhere, whatever its `done` says: it is done here and not paid, so a
## record can't claim a quest's pay from a farm that saw none of it. A count
## comes as no more than its step needs.
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
		if theirs.get("done") == true or _all_brought(quest, theirs):
			entry["done"] = GameClock.get_day_index()
			moved = true
		else:
			moved = _take_steps(farm, quest, entry, theirs, player_id, is_new)
		if moved:
			own[id] = entry
			farm.player_quest_state[player_id] = own
			changed = true
	return changed


## True if `theirs` has every step of `quest` done: by its id, or by a count
## that is full.
static func _all_brought(quest: Dictionary, theirs: Dictionary) -> bool:
	var their_steps: Variant = theirs.get("steps", [])
	var their_counts: Variant = theirs.get("counts", {})
	for step: Variant in quest["steps"]:
		var step_id: String = str(step.get("id", ""))
		if their_steps is Array and step_id in their_steps:
			continue
		var counted: bool = str(step.get("check", "")) in COUNTING and their_counts is Dictionary and their_counts.get(step_id, 0) is int
		if not counted or their_counts.get(step_id, 0) < step_need(step):
			return false
	return not (quest["steps"] as Array).is_empty()


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
			# Never more than the step needs, whatever the record says.
			there = mini(their_counts.get(step_id, 0), step_need(step))
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
