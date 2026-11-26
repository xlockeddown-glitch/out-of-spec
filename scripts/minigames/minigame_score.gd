class_name MinigameScore
extends RefCounted
## What a mini-game's score is worth, and when one is played
## (docs/design/quests_levels_story.md section 7). A score is a whole number
## from 0 to 100. A skip, and any try under the first grade, give exactly the
## plain result: a mini-game can only add (Q10).

## No game was played, or its score did not count.
const SKIPPED: int = -1
const MAX_SCORE: int = 100
## The field a scored command's answer gains: the score the host counted.
const RECORD_KEY: String = "zero_score"
## The Calibration unlock (data/skills.json) that opens the CAREFUL switch.
const CAREFUL_UNLOCK: String = "careful_bench"
const SKILL: String = "calibration"
## GameState.MANAGER_ID: the grace-night calibrations are not a player's.
const MANAGER: String = "Manager"
## This game's id, as a quest step's `minigame` names it (data/quests.json).
const SET_THE_ZERO: String = "set_the_zero"
## Mini-game 2 (section 7.1), and the skill that widens its green (section 7.3).
const WRING_THE_BLOCKS: String = "wring_the_blocks"
const WRING_SKILL: String = "earthworks"
## Mini-game 3 (section 7.1), and the skill that slows its wander (section 7.3).
const HOLD_THE_READING: String = "hold_the_reading"
const HOLD_SKILL: String = "uncertainty"
## The games played at the bench before ZERO / CALIBRATE. Which one an
## instrument gets is game_for(); a quest step may name either.
const BENCH_GAMES: Array[String] = [SET_THE_ZERO, HOLD_THE_READING]
## The standards that settle (section 7.1: "humidity generator, pressure
## controller"). A unit calibrated against one of these plays Hold the Reading
## in place of Set the Zero [ASSUMPTION: these two ids, and units only].
const SETTLING_STANDARDS: Array[String] = ["humidity_generator", "pressure_controller"]

## Section 7.2, best first: at `from` and over, the as-left residual is times
## `residual`. Under the last row a try is Standard, the same as a skip.
## `quest_bonus` is the quest grade's "bonus": that share of the quest's credits
## more [ASSUMPTION: the design gives no size; these are its paid-job bonus,
## 10 % and 20 %]. `giver_line`: the giver has a line for it.
const GRADES: Array[Dictionary] = [
	{ "from": 95, "name": "Reference", "residual": 0.4, "quest_bonus": 0.2, "giver_line": true },
	{ "from": 80, "name": "Fine", "residual": 0.6, "quest_bonus": 0.1, "giver_line": false },
	{ "from": 60, "name": "Good", "residual": 0.8, "quest_bonus": 0.0, "giver_line": false },
]
const STANDARD_GRADE: String = "Standard"


## What is left of the as-left residual at this score: 1.0 for a skip or a poor try.
static func residual_factor(score: int) -> float:
	for grade: Dictionary in GRADES:
		if score >= int(grade["from"]):
			return float(grade["residual"])
	return 1.0


## What is left of the operator's uncertainty term at this score (Hold the
## Reading): section 7.2, "by the same factors".
static func operator_factor(score: int) -> float:
	return residual_factor(score)


## The bench game for this instrument: Hold the Reading for a unit whose
## standard today is one that settles, else Set the Zero. A standard's own
## calibration keeps Set the Zero: the U of that calibration goes on the
## standard's in-house certificate, and a score never changes a standard's
## uncertainty [ASSUMPTION]. The host asks this too, so a guest never says
## which game it played.
static func game_for(farm: Node, instrument_id: String) -> String:
	var sensor: DriftingSensor = farm.get_sensor(instrument_id)
	if sensor != null and sensor.role != "standard" and sensor.calibrated_by in SETTLING_STANDARDS:
		return HOLD_THE_READING
	return SET_THE_ZERO


## The bench games this instrument can play by the data alone, with no farm:
## the game of the standard it starts on, and Hold the Reading if a standard
## that settles takes it over when bought (takes_over). Empty for an instrument
## the data does not have. Quest data is checked against this, so a step cannot
## name a game its instrument never plays.
static func games_in_data(instrument_id: String) -> Array[String]:
	var games: Array[String] = []
	var base: String = DriftingSensor.config_path(instrument_id)
	if DataManager.get_value(DriftingSensor.CONFIG_TABLE, base) == null:
		return games
	var unit: bool = str(DataManager.get_value(DriftingSensor.CONFIG_TABLE, base + "/role", "unit")) != "standard"
	var first: String = str(DataManager.get_value(DriftingSensor.CONFIG_TABLE, base + "/calibrated_by", ""))
	games.append(HOLD_THE_READING if unit and first in SETTLING_STANDARDS else SET_THE_ZERO)
	for standard: String in SETTLING_STANDARDS:
		var taken: Variant = DataManager.get_value(DriftingSensor.CONFIG_TABLE, "instruments/%s/takes_over" % standard, [])
		if unit and taken is Array and instrument_id in taken and not HOLD_THE_READING in games:
			games.append(HOLD_THE_READING)
	return games


## True where a step that names `step_game` is graded by a play of `played`:
## the same game, or both bench games (the instrument picks which is played;
## a unit a settling standard takes over changes game when that is bought).
static func grades_step(step_game: String, played: String) -> bool:
	return step_game != "" and (step_game == played or (step_game in BENCH_GAMES and played in BENCH_GAMES))


## True for a score that earned a grade over Standard. A skip and a poor try did not.
static func is_graded(score: int) -> bool:
	return score >= int(GRADES[-1]["from"])


## The share of a quest's credits a mini-game step played to this score adds
## (section 7.2, "Done, with a bonus"): 0.0 under Fine.
static func quest_bonus(score: int) -> float:
	for grade: Dictionary in GRADES:
		if score >= int(grade["from"]):
			return float(grade["quest_bonus"])
	return 0.0


## Whether the quest's giver has a line for this score (Reference).
static func earns_line(score: int) -> bool:
	for grade: Dictionary in GRADES:
		if score >= int(grade["from"]):
			return bool(grade["giver_line"])
	return false


static func grade_name(score: int) -> String:
	for grade: Dictionary in GRADES:
		if score >= int(grade["from"]):
			return str(grade["name"])
	return STANDARD_GRADE


## Shown when a score was sent and the host counted none.
const NOT_COUNTED_TEXT: String = "Score not counted (not a key moment)."


## "Zero score 97 of 100: REFERENCE, as-left residual 40 % of standard." For
## Hold the Reading: "Hold score 97 of 100: REFERENCE, your share of the
## uncertainty 60 % smaller."
static func result_text(score: int, game: String = SET_THE_ZERO) -> String:
	if score < 0:
		return ""
	var factor: float = residual_factor(score)
	var hold: bool = game == HOLD_THE_READING
	var gain: String = ", standard result"
	if factor < 1.0 and hold:
		gain = ", your share of the uncertainty %d %% smaller" % roundi((1.0 - factor) * 100.0)
	elif factor < 1.0:
		gain = ", as-left residual %d %% of standard" % roundi(factor * 100.0)
	return "%s score %d of %d: %s%s." % ["Hold" if hold else "Zero", score, MAX_SCORE, grade_name(score).to_upper(), gain]


## The kind of instrument: a robot's sensor ("laser@TR-1") is its sensor's kind.
static func instrument_type(instrument_id: String) -> String:
	return instrument_id.get_slice("@", 0)


## True until the lab has calibrated an instrument of this kind against a
## standard by a player's own hand. A robot's and the manager's do not count.
static func is_first_of_type(cal_log: Array, instrument_id: String) -> bool:
	var type: String = instrument_type(instrument_id)
	for record: Variant in cal_log:
		if not record is Dictionary or instrument_type(str(record.get("instrument_id", ""))) != type:
			continue
		var by_hand: bool = str(record.get("programmed_by", "")) == "" and str(record.get("performed_by", "")) != MANAGER
		if by_hand and str(record.get("standard_id", "")) != "":
			return false
	return true


## Whether a score from `player_id` (never "") may count for this instrument:
## is_due() with the switch on. The host asks this of a score that came with a
## command. It can't see a guest's switch, only the level the switch needs.
static func may_count(farm: Node, instrument_id: String, player_id: String) -> bool:
	return is_due(farm, instrument_id, player_id, true)


## Whether the game opens for this player (never "") at the bench: a key moment
## of section 7.4. With the CAREFUL unlock and `careful`, the player's own
## switch, any bench calibration is one, a standard's too. Without, only a
## unit's first calibration of its kind, or a unit's calibration while an open
## quest step carries this game for it (every try, until the step is done).
static func is_due(farm: Node, instrument_id: String, player_id: String, careful: bool) -> bool:
	var sensor: DriftingSensor = farm.get_sensor(instrument_id)
	if sensor == null:
		return false
	# An open quest step that carries this game for the instrument is a key
	# moment, on an old farm that has calibrated its kind before too. Not for a
	# standard: its game still needs CAREFUL, as before.
	if sensor.role != "standard":
		for game: String in BENCH_GAMES:
			if QuestEngine.has_minigame_step(farm, game, instrument_id, player_id):
				return true
	if careful and farm.has_skill_unlock(CAREFUL_UNLOCK, player_id):
		return true
	return sensor.role != "standard" and is_first_of_type(farm.cal_log, instrument_id)


## The host's cut of a score that came with a command: SKIPPED where no game
## could have been due, else held to 0 to MAX_SCORE. That is all the host can
## check. It cannot know the game was played, or how well: the score is the
## sender's word, for Hold the Reading as for Set the Zero. Among friends that
## is accepted [ASSUMPTION]; what a made-up score can gain is bounded by the
## grade table (the record's stated U and TUR, or the as-left residual, and a
## quest's bonus), never a verdict, an audit or XP.
static func allowed(farm: Node, instrument_id: String, player_id: String, score: int) -> int:
	if not may_count(farm, instrument_id, player_id):
		return SKIPPED
	return clampi(score, 0, MAX_SCORE)


## Sets the factor the instrument's next calibration takes: on its as-left
## residual for Set the Zero, on the operator's uncertainty term for Hold the
## Reading, never both. A skip sets 1.0.
static func arm(farm: Node, instrument_id: String, score: int) -> void:
	var sensor: DriftingSensor = farm.get_sensor(instrument_id)
	if sensor == null:
		return
	var hold: bool = game_for(farm, instrument_id) == HOLD_THE_READING
	sensor.next_residual_scale = 1.0 if hold else residual_factor(score)
	sensor.next_operator_scale = operator_factor(score) if hold else 1.0


static func disarm(farm: Node, instrument_id: String) -> void:
	var sensor: DriftingSensor = farm.get_sensor(instrument_id)
	if sensor != null:
		sensor.next_residual_scale = 1.0
		sensor.next_operator_scale = 1.0


## How much of the sweet spot's widening (section 7.3) this player's skill has,
## 0 to 1: the same front-loaded share as a skill's effects. Calibration for Set
## the Zero; WRING_SKILL for Wring the Blocks.
static func sweet_share(farm: Node, player_id: String, skill: String = SKILL) -> float:
	return maxf(farm.effect_share(farm.skill_level(skill, player_id)), farm.effect_floor(skill, player_id))


## "Wring score 97 of 100: REFERENCE." for a game with no residual to speak of.
static func grade_text(game_name: String, score: int) -> String:
	if score < 0:
		return ""
	return "%s score %d of %d: %s." % [game_name, score, MAX_SCORE, grade_name(score).to_upper()]
