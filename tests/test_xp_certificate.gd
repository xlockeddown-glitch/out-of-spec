extends RefCounted
## The XP certificate (docs/design/quests_levels_story.md section 4.4, build
## step 6): a quest gives one to each player who took part, its holder spends it
## on one skill of their own, and quest S1 (The Thirsty Probe) pays one.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const HOST: String = "player_1"
const GUEST: String = "player_2"
const S1: String = "thirsty_probe"
## The id of the first certificate S1 gives on a new farm.
const S1_CERT: String = "thirsty_probe#1"
## What S1's certificate is worth [PLACEHOLDER], as data/quests.json has it.
const S1_XP: int = 200


## Runs `body` on a new farm. `fixtures` replace the shipped quests if given.
func _run(body: Callable, fixtures: Array = []) -> String:
	var saved_day: float = GameClock.elapsed_days
	var saved_players: Array[String] = CoopSession.players.duplicate()
	var table: Dictionary = DataManager._records[&"quests"]
	var shipped: Dictionary = table["quests"]
	if not fixtures.is_empty():
		var mine: Dictionary = {}
		for quest: Dictionary in fixtures:
			mine[StringName(str(quest["id"]))] = quest
		table["quests"] = mine
	GameClock.elapsed_days = 0.0
	CoopSession.players.clear()
	var gs: GameStateScript = _farm()
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call(gs)
	gs.free()
	table["quests"] = shipped
	FarmCommands.guest = false
	CoopSession.players.assign(saved_players)
	GameClock.elapsed_days = saved_day
	return out if out is String else "The test stopped early or did not return a String."


func _farm() -> GameStateScript:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(77)
	gs.reset_credibility()
	return gs


## A quest done as soon as the farm has 100 CR, paying a certificate of `xp`.
func _quest(id: String, xp: int) -> Dictionary:
	return { "id": id, "kind": "story", "giver": "lin", "title": "Test " + id, "scope": "farm", "gates": {},
		"steps": [{ "id": "pay", "text": "Have 100 CR.", "check": "stat_at_least", "stat": "credits", "at_least": 100 }],
		"rewards": { "xp_certificate": xp } }


func _lines(gs: GameStateScript, part: String) -> int:
	var count: int = 0
	for line: String in gs.phone_log:
		if line.contains(part):
			count += 1
	return count


# --- Awarding -------------------------------------------------------------------

func test_each_player_who_took_part_is_given_one() -> String:
	return _run(_check_award, [_quest("lump", 200)])


func _check_award(gs: GameStateScript) -> String:
	gs.credits = 0
	var both: Array[String] = [HOST, GUEST]
	gs.update_quests(both)
	if not gs.xp_certificates.is_empty():
		return "Nothing is held before the quest is done."
	gs.credits = 100
	gs.update_quests(both)
	if gs.xp_certificates != { HOST: { "lump#1": 200 }, GUEST: { "lump#2": 200 } }:
		return "Each player who took part holds their own certificate: %s" % [gs.xp_certificates]
	if gs.held_xp_certificates() != { "lump#1": 200 } or gs.held_xp_certificates(GUEST) != { "lump#2": 200 }:
		return "A player's certificates can be asked for."
	if gs.player_skill_xp.has(HOST) or gs.player_skill_xp.has(GUEST):
		return "A held certificate is no XP yet: %s" % [gs.player_skill_xp]
	if _lines(gs, "Reward: an XP certificate (200 XP).") != 1 or _lines(gs, "XP CERTIFICATE: 200 XP in a skill of your choice") != 1:
		return "The phone says what was given and where to spend it: %s" % [gs.phone_log]
	# Another look, and a save and load: no second certificate.
	gs.update_quests(both)
	var again: GameStateScript = _farm()
	var problem: String = again.farm_from_dict(gs.farm_to_dict())
	again.update_quests(both)
	var same: bool = problem == "" and again.xp_certificates == gs.xp_certificates
	again.free()
	return "" if same and (gs.xp_certificates[HOST] as Dictionary).size() == 1 else "A quest's certificate is given once: %s" % problem


func test_an_id_is_never_used_again() -> String:
	return _run(_check_second)


func _check_second(gs: GameStateScript) -> String:
	if gs.give_xp_certificate(HOST, "lump", 50) != "lump#1" or gs.give_xp_certificate(HOST, "lump", 70) != "lump#2":
		return "A second certificate from one source has its own id."
	if gs.held_xp_certificates(HOST) != { "lump#1": 50, "lump#2": 70 }:
		return "Both are held: %s" % [gs.xp_certificates]
	# Spent, and given again from the same source: a new id, and the old one
	# stays dead, across a save too.
	if gs.spend_xp_certificate("lump#1", "calibration", HOST) != "" or gs.spend_xp_certificate("lump#2", "calibration", HOST) != "":
		return "Both can be spent."
	var copy: GameStateScript = _farm()
	var problem: String = copy.farm_from_dict(gs.farm_to_dict())
	var next: String = copy.give_xp_certificate(HOST, "lump", 50)
	var dead: bool = copy.spend_xp_certificate("lump#1", "calibration", HOST) != ""
	copy.free()
	if problem != "" or next != "lump#3" or not dead:
		return "A spent certificate's id is never given again: %s %s" % [next, problem]
	if gs.give_xp_certificate(HOST, "lump", 50) != "lump#3" or gs.give_xp_certificate(HOST, "lump", 70) != "lump#4":
		return "The farm counts every certificate it gives."
	gs.spend_xp_certificate("lump#3", "calibration", HOST)
	gs.xp_certificates[HOST].erase("lump#4")
	gs.xp_certificates[HOST]["lump#1"] = 50
	gs.xp_certificates[HOST]["lump#2"] = 70
	if GameStateScript.xp_certificate_number("lump#12") != 12 or GameStateScript.xp_certificate_source("a#b#12") != "a#b":
		return "An id is its source and its number."
	for bad: String in ["lump", "lump#", "#3", "lump#x", "lump#03", "lump#-1", "lump#0", ""]:
		if GameStateScript.xp_certificate_number(bad) != 0:
			return "An id with no number of its own has none: %s" % bad
	for bad: Array in [["", "lump", 50], [HOST, "", 50], [HOST, "lump", 0], [HOST, "lump", -5], [gs.MANAGER_ID, "lump", 50]]:
		if gs.give_xp_certificate(bad[0], bad[1], bad[2]) != "":
			return "No certificate for no player, no source or no XP: %s" % [bad]
	if XpCertificateUI.certificate_text("lump#2", 70) != "lump (70 XP)" or XpCertificateUI.confirm_text({ "name": "Calibration" }) != "Spend on Calibration?  CONFIRM":
		return "A certificate is named by its source: %s" % XpCertificateUI.certificate_text("lump#2", 70)
	return "" if gs.xp_certificates == { HOST: { "lump#1": 50, "lump#2": 70 } } and gs.xp_certificates_given == 4 else "A refused certificate leaves nothing behind and takes no number."


# --- Spending -------------------------------------------------------------------

func test_the_host_spends_one_on_a_skill() -> String:
	return _run(_check_host_spends)


func _check_host_spends(gs: GameStateScript) -> String:
	var commands: Node = CommandsScript.new()
	commands.state = gs
	gs.give_xp_certificate(HOST, "lump", 200)
	var changes: Array = []
	gs.xp_certificates_changed.connect(func() -> void: changes.append(1))
	# Spending is paperwork: a player in bed stays in bed.
	var were_in_bed: Array[String] = CoopBeds.in_bed.duplicate()
	CoopBeds.in_bed.assign([HOST])
	var answer: Variant = commands.execute(HOST, &"spend_xp_certificate", ["lump#1", "calibration"])
	var still_in_bed: bool = HOST in CoopBeds.in_bed
	commands.execute(HOST, &"set_rover_lights", [true])
	var up_after_work: bool = not HOST in CoopBeds.in_bed
	CoopBeds.in_bed.assign(were_in_bed)
	var out: String = ""
	if answer != "" or gs.skill_xp("calibration", HOST) != 200:
		out = "Spent, all its XP is in the skill picked: %s, %d XP" % [answer, gs.skill_xp("calibration", HOST)]
	elif not gs.xp_certificates.is_empty() or changes.size() != 1:
		out = "A spent certificate is gone, and the picker is told: %s" % [gs.xp_certificates]
	elif gs.action_counts.has(HOST):
		out = "A certificate's XP is not counted as an action."
	# No double spend.
	elif commands.execute(HOST, &"spend_xp_certificate", ["lump#1", "calibration"]) == "" or gs.skill_xp("calibration", HOST) != 200:
		out = "A certificate can't be spent twice."
	elif not still_in_bed or not up_after_work or not &"go_to_bed" in commands.NO_WAKE:
		out = "Spending a certificate gets no one up; other work does."
	commands.free()
	return out


func test_a_guest_spends_their_own() -> String:
	return _run(_check_guest_spends)


func _check_guest_spends(gs: GameStateScript) -> String:
	var commands: Node = CommandsScript.new()
	commands.state = gs
	CoopSession.players.assign([HOST, GUEST])
	gs.give_xp_certificate(HOST, "hosts", 200)
	gs.give_xp_certificate(GUEST, "guests", 120)
	var out: String = ""
	# Not the host's, not one that isn't there, and not on a wrong skill.
	for bad: Array in [["hosts#1", "calibration"], ["nothing", "calibration"], ["", "calibration"],
			["guests#2", "no_such_skill"], ["guests#2", ""], ["guests#2", "lab"]]:
		if commands.execute(GUEST, &"spend_xp_certificate", bad) == "":
			out = "Refused: another's certificate, a bad id, a skill that is not one's own: %s" % [bad]
	for skill: String in gs.skill_ids():
		if gs.is_farm_skill(skill) and commands.execute(GUEST, &"spend_xp_certificate", ["guests#2", skill]) == "":
			out = "A skill the farm shares can't take a player's certificate: %s" % skill
	if out == "" and (commands.execute(GUEST, &"spend_xp_certificate", ["guests#2"]) == "" or commands.execute(GUEST, &"spend_xp_certificate", [7, "calibration"]) == ""):
		out = "A command with the wrong arguments is refused."
	if out == "" and (gs.xp_certificates != { HOST: { "hosts#1": 200 }, GUEST: { "guests#2": 120 } } or gs.player_skill_xp.has(GUEST)):
		out = "A refused spend changes nothing: %s" % [gs.xp_certificates]
	if out == "" and (commands.execute(GUEST, &"spend_xp_certificate", ["guests#2", "agronomy"]) != ""
			or gs.skill_xp("agronomy", GUEST) != 120 or gs.skill_xp("agronomy", HOST) != 0):
		out = "A guest spends their own on their own skill: %d XP" % gs.skill_xp("agronomy", GUEST)
	if out == "" and gs.xp_certificates != { HOST: { "hosts#1": 200 } }:
		out = "Only the guest's certificate is gone: %s" % [gs.xp_certificates]
	if out == "" and commands.execute(GUEST, &"spend_xp_certificate", ["guests#2", "agronomy"]) == "":
		out = "A guest can't spend theirs twice."
	# Someone on foot may still spend one.
	if out == "" and not &"spend_xp_certificate" in CoopWalkers.ON_FOOT:
		out = "A certificate can be spent on foot."
	commands.free()
	return out


func test_a_skill_at_the_top_level_takes_none() -> String:
	return _run(_check_top)


func _check_top(gs: GameStateScript) -> String:
	gs.give_skill_xp("calibration", gs.xp_for_level(gs.max_skill_level()), HOST)
	gs.give_xp_certificate(HOST, "lump", 200)
	if gs.spend_xp_certificate("lump#1", "calibration", HOST) == "" or gs.held_xp_certificates(HOST) != { "lump#1": 200 }:
		return "A skill at the top level takes no certificate, and it is kept."
	var rows: Array[Dictionary] = XpCertificateUI.choices(gs, "lump#1", HOST)
	if rows[0]["skill"] != "calibration" or rows[0]["problem"] == "" or not XpCertificateUI.choice_text(rows[0]).ends_with("top level"):
		return "The picker shows the top level as closed: %s" % [rows[0]]
	return "" if gs.spend_xp_certificate("lump#1", "agronomy", HOST) == "" else "It can still go to another skill."


# --- The picker's numbers ---------------------------------------------------------

func test_the_picker_shows_the_level_reached() -> String:
	return _run(_check_picker)


func _check_picker(gs: GameStateScript) -> String:
	gs.give_xp_certificate(HOST, "lump", 200)
	# 200 XP on the 10 % curve from 50 XP: levels cost 50, 55, 60 (165), then 66.
	if gs.level_with_xp("calibration", 200, HOST) != 4 or gs.level_with_xp("calibration", 0, HOST) != 1 or gs.level_with_xp("calibration", -9, HOST) != 1:
		return "200 XP takes level 1 to level 4: %d" % gs.level_with_xp("calibration", 200, HOST)
	# The same XP lifts a high level a little: at level 50 it is not one level.
	gs.give_skill_xp("agronomy", gs.xp_for_level(50), HOST)
	if gs.skill_level("agronomy", HOST) != 50 or gs.level_with_xp("agronomy", 200, HOST) != 50:
		return "200 XP is less than a level at level 50: %d" % gs.level_with_xp("agronomy", 200, HOST)
	var rows: Array[Dictionary] = XpCertificateUI.choices(gs, "lump#1", HOST)
	var personal: Array[String] = []
	for skill: String in gs.skill_ids():
		if not gs.is_farm_skill(skill):
			personal.append(skill)
	if rows.size() != personal.size() or rows.is_empty():
		return "The picker lists each skill of the player's own: %d" % rows.size()
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		if row["skill"] != personal[i] or row["xp"] != 200 or row["problem"] != "" or row["level"] != gs.skill_level(personal[i], HOST):
			return "A row has the skill, its level and the XP: %s" % [row]
		# What the picker shows is what spending gives.
		var copy: GameStateScript = _farm()
		var problem: String = copy.farm_from_dict(gs.farm_to_dict())
		copy.spend_xp_certificate("lump#1", personal[i], HOST)
		var reached: int = copy.skill_level(personal[i], HOST)
		copy.free()
		if problem != "" or reached != row["level_after"]:
			return "%s: the picker said level %d and spending gave %d. %s" % [personal[i], row["level_after"], reached, problem]
	if XpCertificateUI.choice_text(rows[0]) != "Calibration: level 1, to level 4":
		return "A row reads plainly: %s" % XpCertificateUI.choice_text(rows[0])
	if not XpCertificateUI.choices(gs, "nothing", HOST).is_empty() or not XpCertificateUI.choices(gs, "lump#1", GUEST).is_empty():
		return "No rows for a certificate the player does not hold."
	return ""


# --- Saves ------------------------------------------------------------------------

func test_certificates_are_saved_and_checked() -> String:
	return _run(_check_save)


func _check_save(gs: GameStateScript) -> String:
	gs.give_xp_certificate(HOST, "lump", 200)
	gs.give_xp_certificate(GUEST, "lump", 200)
	gs.give_xp_certificate(GUEST, "other", 75)
	gs.crops_sold_in_spec = { "dust_turnip": 3 }
	var saved: Dictionary = gs.farm_to_dict()
	var copy: GameStateScript = _farm()
	var changes: Array = []
	copy.xp_certificates_changed.connect(func() -> void: changes.append(1))
	var problem: String = copy.farm_from_dict(saved)
	var same: bool = copy.xp_certificates == { HOST: { "lump#1": 200 }, GUEST: { "lump#2": 200, "other#3": 75 } } and copy.xp_certificates_given == 3 \
			and copy.crops_sold_in_spec == { "dust_turnip": 3 }
	# A save from before certificates holds none.
	var old: Dictionary = saved.duplicate(true)
	old.erase("xp_certificates")
	old.erase("xp_certificates_given")
	old.erase("crops_sold_in_spec")
	var old_problem: String = copy.farm_from_dict(old)
	var none: bool = copy.xp_certificates.is_empty() and copy.xp_certificates_given == 0 and copy.crops_sold_in_spec.is_empty()
	copy.free()
	if problem != "" or not same or changes.is_empty():
		return "Certificates and the sold count are saved and loaded, and the picker is told: %s" % problem
	if old_problem != "" or not none:
		return "An old save loads with no certificate held: %s" % old_problem
	if SaveGame.VERSION != 1:
		return "The save version stays 1."
	for bad: Variant in [[], "x", { HOST: [] }, { HOST: 5 }, { "": { "lump#1": 5 } }, { 3: { "lump#1": 5 } }, { HOST: { "": 5 } },
			{ HOST: { 2: 5 } }, { HOST: { "lump#1": 0 } }, { HOST: { "lump#1": -5 } }, { HOST: { "lump#1": 1.5 } }, { HOST: { "lump#1": "5" } },
			{ HOST: { "lump#1": NAN } }, { HOST: { "lump#1": gs.MOST_SKILL_XP + 1 } },
			# An id with no number, a number the farm has not reached, one number twice.
			{ HOST: { "lump": 5 } }, { HOST: { "lump#0": 5 } }, { HOST: { "lump#4": 5 } }, { HOST: { "lump#x": 5 } },
			{ HOST: { "lump#1": 5 }, GUEST: { "other#1": 5 } }]:
		var broken: Dictionary = saved.duplicate(true)
		broken["xp_certificates"] = bad
		if gs.farm_dict_problem(broken) == "":
			return "A save with bad certificates is refused: %s" % [bad]
	for bad: Variant in [-1, 2, 1.5, "3", null, []]:
		var broken: Dictionary = saved.duplicate(true)
		broken["xp_certificates_given"] = bad
		if gs.farm_dict_problem(broken) == "":
			return "A save with a bad count of certificates given is refused: %s" % [bad]
	for bad: Variant in [[], { "dust_turnip": -1 }, { "dust_turnip": 1.5 }, { "": 1 }, { 4: 1 }, { "dust_turnip": "1" }]:
		var broken: Dictionary = saved.duplicate(true)
		broken["crops_sold_in_spec"] = bad
		if gs.farm_dict_problem(broken) == "":
			return "A save with a bad sold count is refused: %s" % [bad]
	return "" if gs.farm_dict_problem(saved) == "" else "A good save passes: %s" % gs.farm_dict_problem(saved)


func test_a_forgotten_guest_holds_none() -> String:
	return _run(_check_forgotten)


func _check_forgotten(gs: GameStateScript) -> String:
	gs.guest_ids["hash"] = GUEST
	gs.give_xp_certificate(HOST, "lump", 200)
	gs.give_xp_certificate(GUEST, "lump", 200)
	var here: Array[String] = [HOST]
	gs._forget_a_guest(here)
	return "" if gs.xp_certificates == { HOST: { "lump#1": 200 } } else "A forgotten guest's certificates go: %s" % [gs.xp_certificates]


# --- S1, The Thirsty Probe ----------------------------------------------------------

func test_s1_is_offered_on_day_2_and_pays_once() -> String:
	return _run(_check_s1)


func _sell(gs: GameStateScript, crop_id: String, in_spec: bool) -> void:
	gs.harvest_bin.append({ "crop_id": crop_id, "in_spec": in_spec })
	gs.sell_harvest_to_lin(HOST)


func _check_s1(gs: GameStateScript) -> String:
	var quest: Dictionary = DataManager.get_record(&"quests", S1, "quests")
	var rewards: Dictionary = quest.get("rewards", {})
	if quest.is_empty() or int(rewards.get("credits", 0)) != 150 or int(rewards.get("quest_points", 0)) != 1 \
			or int(rewards.get("xp_certificate", 0)) != S1_XP or quest.get("kind") != "story" or quest.get("giver") != "lin" \
			or not (quest.get("gates", {}) as Dictionary).is_empty():
		return "S1 ships as the design has it: %s" % [quest]
	# Day 1: not yet. A turnip sold now is before the quest and does not count.
	gs.update_quests()
	_sell(gs, "dust_turnip", true)
	if gs.quest_state.has(S1) or gs.crops_sold_in_spec != { "dust_turnip": 1 }:
		return "S1 is not offered on day 1: %s" % [gs.quest_state.keys()]
	GameClock.elapsed_days = 1.0
	if GameClock.get_day_index() != 2:
		return "The test's clock is not on day 2."
	gs.update_quests()
	var entry: Dictionary = gs.quest_state.get(S1, {})
	# The kit is founding stock, so its step is done as the quest is accepted.
	if entry.is_empty() or entry["steps_done"] != ["kit"] or int(entry["done"]) >= 0:
		return "S1 is offered the morning of day 2, the kit already owned: %s" % [entry]
	if _lines(gs, "LIN: New quest, The Thirsty Probe. Your irrigation thinks the bed is at 40 %. Your turnip disagrees. I trust the turnip. Calibrate the soil probe against the gravimetric kit.") != 1:
		return "Lin offers it in her own words: %s" % [gs.phone_log]
	# A turnip sold before the probe is calibrated is not the quest's crate: the
	# sale counts from when the calibration step is done.
	_sell(gs, "dust_turnip", true)
	gs.update_quests()
	if entry["steps_done"] != ["kit"] or int(entry["done"]) >= 0:
		return "A turnip sold before the calibration does no step: %s" % [entry]
	var record: Dictionary = gs.calibrate("soil_probe", HOST)
	if not record.get("traceable", false):
		return "The test's calibration is not traceable: %s" % [record]
	gs.update_quests()
	if entry["steps_done"] != ["kit", "cal"] or int(entry["done"]) >= 0 or int(entry["base"]["sell"]) != 2:
		return "A traceable soil probe calibration does the second step, and the early sale does not finish S1: %s" % [entry]
	# Another look, and a save and a load: the early sale still does not count.
	gs.update_quests()
	var early: GameStateScript = _farm()
	var early_problem: String = early.farm_from_dict(gs.farm_to_dict())
	early.update_quests()
	var waits: bool = early_problem == "" and not QuestEngine.is_done(early, S1)
	early.free()
	if not waits or int(entry["done"]) >= 0:
		return "S1 waits for a sale made after the calibration: %s" % early_problem
	# Off-spec turnip and another crop don't count.
	_sell(gs, "dust_turnip", false)
	var crops: Array[String] = []
	for crop: Dictionary in DataManager.get_records(&"crops", "crops"):
		if str(crop["id"]) != "dust_turnip":
			crops.append(str(crop["id"]))
	if not crops.is_empty():
		_sell(gs, crops[0], true)
	gs.update_quests()
	if int(entry["done"]) >= 0 or int(gs.crops_sold_in_spec["dust_turnip"]) != 2:
		return "Off-spec turnip or another crop does not finish S1."
	var credits: int = gs.credits
	gs.harvest_bin.append({ "crop_id": "dust_turnip", "in_spec": true })
	var sale: int = gs.sell_harvest_to_lin(HOST)
	gs.update_quests()
	if int(entry["done"]) < 0 or gs.credits != credits + sale + 150:
		return "In-spec dust turnip sold to Lin finishes S1 and pays 150 CR: %d" % (gs.credits - credits - sale)
	if gs.quest_points != { HOST: { S1: 1 } } or gs.xp_certificates != { HOST: { S1_CERT: S1_XP } }:
		return "S1 pays a quest point and an XP certificate: %s %s" % [gs.quest_points, gs.xp_certificates]
	if _lines(gs, "QUEST DONE: The Thirsty Probe. Reward: 150 CR, 1 quest point, an XP certificate (200 XP).") != 1 \
			or _lines(gs, "LIN: Your probe is lying to you. Was. Better.") != 1:
		return "The phone says what S1 paid, and Lin's line: %s" % [gs.phone_log]
	if XpCertificateUI.certificate_text(S1_CERT, S1_XP) != "The Thirsty Probe (200 XP)":
		return "The certificate is named for its quest: %s" % XpCertificateUI.certificate_text(S1_CERT, S1_XP)
	# Paid once: more turnip, another morning, a save and a load.
	_sell(gs, "dust_turnip", true)
	gs.update_quests()
	GameClock.elapsed_days = 2.0
	gs.update_quests()
	var again: GameStateScript = _farm()
	var problem: String = again.farm_from_dict(gs.farm_to_dict())
	again.update_quests()
	var once: bool = problem == "" and again.xp_certificates == { HOST: { S1_CERT: S1_XP } } and again.quest_point_total(HOST) == 1
	again.free()
	if not once or _lines(gs, "QUEST DONE: The Thirsty Probe.") != 1 or gs.xp_certificates != { HOST: { S1_CERT: S1_XP } }:
		return "S1 pays once: %s" % problem
	# And the certificate is spent like any other.
	if gs.spend_xp_certificate(S1_CERT, "agronomy", HOST) != "" or not gs.xp_certificates.is_empty():
		return "S1's certificate can be spent."
	return ""


## Two steps: have 100 CR, then 2 in-spec crops sold to Lin.
func _two_steps(id: String, extra: Dictionary = {}, sell_extra: Dictionary = {}) -> Dictionary:
	var sell: Dictionary = { "id": "sell", "text": "Sell 2.", "check": "counter", "counter": "crops_sold_in_spec", "at_least": 2 }
	sell.merge(sell_extra)
	var quest: Dictionary = { "id": id, "kind": "story", "giver": "lin", "title": "Test " + id, "scope": "farm", "gates": {},
		"steps": [{ "id": "pay", "text": "Have 100 CR.", "check": "stat_at_least", "stat": "credits", "at_least": 100 }, sell],
		"rewards": {} }
	quest.merge(extra)
	return quest


func test_a_later_step_counts_from_when_it_opened() -> String:
	return _run(_check_bases, [_two_steps("ordered"), _two_steps("ever", {}, { "ever": true }), _two_steps("loose", { "any_order": true })])


func _check_bases(gs: GameStateScript) -> String:
	gs.credits = 0
	gs.crops_sold_in_spec = { "dust_turnip": 1 }
	gs.update_quests()
	# Two sold while the first step is still open.
	gs.crops_sold_in_spec = { "dust_turnip": 3 }
	gs.update_quests(none(), false)
	if QuestEngine.is_done(gs, "ordered") or gs.quest_state["ordered"]["steps_done"] != [] or gs.quest_state["loose"]["steps_done"] != ["sell"]:
		return "In order, a later step is not looked at early; in any order it is: %s" % [gs.quest_state]
	gs.credits = 100
	gs.update_quests(none(), false)
	if QuestEngine.is_done(gs, "ordered") or int(gs.quest_state["ordered"]["base"]["sell"]) != 3:
		return "In order, what was sold before the step opened is not counted: %s" % [gs.quest_state["ordered"]]
	if not QuestEngine.is_done(gs, "ever") or int(gs.quest_state["ever"]["base"]["sell"]) != 1 or not QuestEngine.is_done(gs, "loose"):
		return "An `ever` step counts everything, and any_order counts from the day accepted: %s" % [gs.quest_state]
	# Looking again does not move the base; one more sale is 1 of 2, a second finishes.
	gs.update_quests(none(), false)
	gs.crops_sold_in_spec = { "dust_turnip": 4 }
	gs.update_quests(none(), false)
	if QuestEngine.is_done(gs, "ordered") or int(gs.quest_state["ordered"]["base"]["sell"]) != 3 or int(gs.quest_state["ordered"]["shown"]["sell"]) != 1:
		return "The base is taken once, when the step opens: %s" % [gs.quest_state["ordered"]]
	gs.crops_sold_in_spec = { "dust_turnip": 5 }
	gs.update_quests(none(), false)
	return "" if QuestEngine.is_done(gs, "ordered") else "Two sold after the step opened finish it."


func none() -> Array[String]:
	var out: Array[String] = []
	return out


func test_the_sold_counter_reads_one_crop_or_all() -> String:
	return _run(_check_counter)


func _check_counter(gs: GameStateScript) -> String:
	gs.crops_sold_in_spec = { "dust_turnip": 2, "glass_wheat": 5 }
	var present: Array[String] = [HOST]
	var one: Dictionary = { "check": "counter", "counter": "crops_sold_in_spec", "where": { "crop_id": "dust_turnip" } }
	var all: Dictionary = { "check": "counter", "counter": "crops_sold_in_spec" }
	var other: Dictionary = { "check": "counter", "counter": "crops_sold_in_spec", "where": { "crop_id": "nothing" } }
	if QuestEngine.check_value(gs, one, present) != 2 or QuestEngine.check_value(gs, all, present) != 7 or QuestEngine.check_value(gs, other, present) != 0:
		return "The counter reads one crop, or every crop: %d %d" % [QuestEngine.check_value(gs, one, present), QuestEngine.check_value(gs, all, present)]
	return ""


# --- The view ---------------------------------------------------------------------

func _buttons(under: Node) -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in under.get_children():
		if child is Button:
			out.append(child)
	return out


func test_the_skills_view_opens_the_picker_and_a_second_click_spends() -> String:
	var kept: Dictionary = SaveGame.snapshot()
	var me: String = GameState.local_player_id
	GameState.xp_certificates = { me: { "lump#1": 200 } }
	GameState.xp_certificates_given = 1
	var view: SkillsUI = SkillsUI.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	view.open()
	var out: String = _check_view(view, me)
	view.free()
	var back: String = SaveGame.restore(kept)
	return out if out != "" else back


## The picker's row button with this name, or null.
func _row(picker: XpCertificateUI, row: String) -> Button:
	for button: Button in _buttons(picker._rows):
		if str(button.get_meta(&"row", "")) == row:
			return button
	return null


func _focus(view: Control) -> Control:
	return view.get_viewport().gui_get_focus_owner()


func _check_view(view: SkillsUI, me: String) -> String:
	var before: int = GameState.skill_xp("calibration", me)
	var level: int = GameState.skill_level("calibration", me)
	var said: int = GameState.level_with_xp("calibration", 200, me)
	var picker: XpCertificateUI = view._picker
	var open: Array[Button] = _buttons(view._rows)
	if open.size() != 1 or open[0].text != "SPEND AN XP CERTIFICATE  (1 held)" or open[0].focus_mode != Control.FOCUS_ALL:
		return "The skills view has a button while a certificate is held."
	open[0].pressed.emit()
	var rows: Array[Button] = _buttons(picker._rows)
	if not picker.visible or rows.is_empty() or rows[0].text != "Calibration: level %d, to level %d" % [level, said]:
		return "The picker lists the skills with the level each would reach."
	# Under the open picker, nothing of the skills view takes focus.
	open = _buttons(view._rows)
	if open.size() != 1 or open[0].focus_mode != Control.FOCUS_NONE or view._close_button.focus_mode != Control.FOCUS_NONE \
			or _focus(view) != picker._close_button:
		return "While the picker is open the buttons under it take no focus."
	# The first click only asks.
	rows[0].pressed.emit()
	rows = _buttons(picker._rows)
	if GameState.skill_xp("calibration", me) != before or GameState.held_xp_certificates(me).size() != 1:
		return "The first click on a skill spends nothing."
	if rows[0].text != "Spend on Calibration?  CONFIRM" or rows[1].text.begins_with("Spend on") or _focus(view) != rows[0]:
		return "The first click asks: %s" % rows[0].text
	# BACK (and Esc, which calls the same) takes the question back and stays.
	picker._close_button.pressed.emit()
	rows = _buttons(picker._rows)
	if not picker.visible or rows[0].text != "Calibration: level %d, to level %d" % [level, said] or GameState.skill_xp("calibration", me) != before:
		return "BACK takes the question back and spends nothing."
	# Asking of one skill and then another moves the question.
	rows[0].pressed.emit()
	_buttons(picker._rows)[1].pressed.emit()
	rows = _buttons(picker._rows)
	if rows[0].text.begins_with("Spend on") or not rows[1].text.begins_with("Spend on") or GameState.held_xp_certificates(me).size() != 1:
		return "A click on another skill asks of that one, and spends nothing."
	rows[0].pressed.emit()
	rows = _buttons(picker._rows)
	rows[0].pressed.emit()
	if GameState.skill_xp("calibration", me) != before + 200 or GameState.skill_level("calibration", me) != said or not GameState.xp_certificates.is_empty():
		return "The second click spends the certificate on that skill: %d XP" % (GameState.skill_xp("calibration", me) - before)
	if picker._note.text != "Spent." or not _buttons(picker._rows).is_empty():
		return "The picker says it is spent, with nothing left to press: %s" % picker._note.text
	# A guest's copy of the farm can still list it for a moment: it is not
	# shown again, so it can't be clicked again.
	picker._spent.assign(["lump#1"])
	GameState.xp_certificates = { me: { "lump#1": 200 } }
	GameState.xp_certificates_changed.emit()
	if not picker.spendable().is_empty() or not _buttons(picker._rows).is_empty() or picker._spent != ["lump#1"]:
		return "A spent certificate is not listed again from a stale copy."
	# Once the farm no longer lists it, it is forgotten here.
	GameState.xp_certificates = {}
	GameState.xp_certificates_changed.emit()
	if not picker._spent.is_empty():
		return "A spent certificate the farm no longer lists is forgotten."
	# Another farm (a save loaded, a host joined) may hold the same id: it shows.
	picker._spent.assign(["lump#1"])
	GameState.farm_loaded.emit()
	GameState.xp_certificates = { me: { "lump#1": 200 } }
	GameState.xp_certificates_changed.emit()
	if not picker._spent.is_empty() or picker.spendable() != { "lump#1": 200 } or _buttons(picker._rows).is_empty():
		return "A certificate of another farm is not hidden by one spent on the last."
	# The rows are built again while one has focus: focus stays on that row.
	var agronomy: Button = _row(picker, "skill agronomy")
	agronomy.grab_focus()
	GameState.xp_certificates_changed.emit()
	if _focus(view) == agronomy or _focus(view) != _row(picker, "skill agronomy") or agronomy.get_parent() != null:
		return "Focus stays on the same row when the rows are built again."
	# A second certificate: its pick row has focus, then it is gone, so BACK has it.
	GameState.xp_certificates = { me: { "lump#1": 200, "lump#2": 50 } }
	GameState.xp_certificates_changed.emit()
	_row(picker, "certificate lump#2").grab_focus()
	GameState.xp_certificates = { me: { "lump#1": 200 } }
	GameState.xp_certificates_changed.emit()
	if _row(picker, "certificate lump#2") != null or _focus(view) != picker._close_button:
		return "Focus goes to BACK when its row is gone."
	# Focus elsewhere is left where it is.
	GameState.xp_certificates_changed.emit()
	if _focus(view) != picker._close_button:
		return "Focus on BACK stays on BACK."
	GameState.xp_certificates = {}
	GameState.xp_certificates_changed.emit()
	# BACK closes the picker and hands focus to the skills view's CLOSE.
	picker._close_button.pressed.emit()
	if picker.visible or view._close_button.focus_mode != Control.FOCUS_ALL or _focus(view) != view._close_button:
		return "BACK closes the picker and focus goes back to the skills view."
	if not _buttons(view._rows).is_empty():
		return "With none left to spend, the skills view has no button."
	# Another certificate: Esc steps back from the question, then out, then closes.
	GameState.xp_certificates = { me: { "lump#2": 50 } }
	GameState.xp_certificates_changed.emit()
	open = _buttons(view._rows)
	if open.size() != 1:
		return "A new certificate brings the button back."
	open[0].pressed.emit()
	_buttons(picker._rows)[0].pressed.emit()
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	view._unhandled_input(esc)
	if not picker.visible or _buttons(picker._rows)[0].text.begins_with("Spend on"):
		return "Esc takes the question back first."
	view._unhandled_input(esc)
	if picker.visible or not view.visible or _focus(view) != view._close_button:
		return "Esc then closes the picker, and focus is on the skills view."
	view._unhandled_input(esc)
	if view.visible or GameState.held_xp_certificates(me) != { "lump#2": 50 }:
		return "Esc then closes the skills view, with nothing spent."
	return ""
