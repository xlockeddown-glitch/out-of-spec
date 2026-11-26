extends "res://tests/coop_net.gd"
## Co-op for quests (docs/design/quests_levels_story.md section 9, step 8): a
## guest's quest points, XP certificates and their own quests travel in their
## file, meet each host's copy without being paid twice, and reach guests with
## the farm. Fixture quests are put in DataManager's table for one test and taken
## out after; every GameState is freed and the clock and the guest flag put back.

const FILE: String = "user://test_coop_quests_player.json"
const KEY: String = "abcdef0123456789abcdef0123456789"
const FARM_Q: String = "farm_q"
const OWN_Q: String = "own_q"
const RICH: int = 50000

var _farms: Array[Node] = []
var _profiles: Array[Node] = []


## A session that is someone's guest, for a profile to ask.
class Away extends Node:
	var away: bool = true
	func is_guest() -> bool:
		return away


## Runs `body` with the two fixture quests in place of the shipped ones.
func _run(body: Callable) -> String:
	var saved_day: float = GameClock.elapsed_days
	var table: Dictionary = DataManager._records[&"quests"]
	var shipped: Dictionary = table["quests"]
	table["quests"] = {
		StringName(FARM_Q): _quest(FARM_Q, "farm", [_step("pay", "stat_at_least", { "stat": "credits", "at_least": RICH })],
			{ "quest_points": 2, "xp_certificate": 200 }),
		StringName(OWN_Q): _quest(OWN_Q, "player", [_step("till", "counter", { "counter": "till", "at_least": 3 }),
			_step("pay", "stat_at_least", { "stat": "credits", "at_least": RICH })], { "quest_points": 1, "credits": 100 }),
	}
	_clear()
	# A body that stops on a script error returns null, which must not pass.
	var out: Variant = body.call()
	for node: Node in _farms + _profiles:
		node.free()
	_farms.clear()
	_profiles.clear()
	table["quests"] = shipped
	FarmCommands.guest = false
	GameClock.elapsed_days = saved_day
	_clear()
	return _finish(out if out is String else "The test stopped early or did not return a String.")


func _quest(id: String, scope: String, steps: Array, rewards: Dictionary) -> Dictionary:
	return { "id": id, "kind": "story", "giver": "lin", "title": "Test " + id, "scope": scope, "gates": {}, "steps": steps, "rewards": rewards }


func _step(id: String, check: String, more: Dictionary) -> Dictionary:
	var step: Dictionary = { "id": id, "text": "Do %s." % id, "check": check }
	step.merge(more, true)
	return step


func _farm() -> Node:
	var gs: Node = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(77)
	gs.reset_credibility()
	gs.credits = 0
	_farms.append(gs)
	return gs


## A profile on FILE that believes it is a guest.
func _profile() -> Node:
	var profile: Node = ProfileScript.new()
	profile.path = FILE
	profile.session = Away.new()
	_profiles.append(profile.session)
	_profiles.append(profile)
	return profile


## The guest `id` of `farm` looks at the farm as it reached them, and keeps.
func _keep(profile: Node, farm: Node, id: String) -> String:
	var problem: String = farm.farm_dict_problem(farm.farm_to_dict())
	var view: Node = _farm()
	view.farm_from_dict(farm.farm_to_dict())
	view.local_player_id = id
	profile.farm = view
	profile.keep()
	return problem


func _join(farm: Node, record: Dictionary = {}) -> String:
	return farm.let_in_guest(KEY, {}, ["player_1"] as Array[String], record)


func _both(id: String) -> Array[String]:
	return ["player_1", id]


func _tills(farm: Node, id: String, count: int) -> void:
	farm.action_counts[id] = { "till": { "count": count, "xp": 0 } }


func _worth(farm: Node, id: String) -> Array:
	return farm.held_xp_certificates(id).values()


func _clear() -> void:
	for ending: String in ["", ".tmp", ".unreadable"]:
		if FileAccess.file_exists(FILE + ending):
			DirAccess.remove_absolute(FILE + ending)


func _put_file(text: String) -> void:
	var file: FileAccess = FileAccess.open(FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_two_hosts_and_coming_back_pay_once() -> String:
	return _run(func() -> String:
		var profile: Node = _profile()
		# Farm A pays the guest for a farm quest.
		var a: Node = _farm()
		var id_a: String = _join(a, profile.record())
		a.credits = RICH
		a.update_quests(_both(id_a))
		if a.quest_points.get(id_a) != { FARM_Q: 2 } or _worth(a, id_a) != [200]:
			return "Farm A pays its guest: %s, %s" % [a.quest_points, a.xp_certificates]
		var problem: String = _keep(profile, a, id_a)
		var first: Dictionary = profile.record()
		# Their own quest is offered there too; nothing of it is done.
		var offered: Dictionary = { OWN_Q: { "done": false, "steps": [], "counts": {} } }
		if problem != "" or first != { "quest_points": { FARM_Q: 2 }, "xp_certificates": { FARM_Q: 200 }, "xp_certificates_spent": [], "quests": offered }:
			return "The guest's file keeps what farm A paid: %s %s" % [problem, first]
		# Farm B has the same quest. They come with their points and certificate,
		# and finishing it there too pays neither again.
		var b: Node = _farm()
		var id_b: String = _join(b, first)
		if b.quest_points.get(id_b) != { FARM_Q: 2 } or _worth(b, id_b) != [200]:
			return "Farm B takes what they bring: %s, %s" % [b.quest_points, b.xp_certificates]
		b.credits = RICH
		b.update_quests(_both(id_b))
		_join(b, first)
		if QuestEngine.points_of(b, id_b) != 2 or _worth(b, id_b) != [200] or _worth(b, "player_1") != [200]:
			return "Farm B must not pay them twice: %s, %s" % [b.quest_points, b.xp_certificates]
		# Spent on B, it is spent everywhere.
		var spend: String = b.spend_xp_certificate(str(b.held_xp_certificates(id_b).keys()[0]), "calibration", id_b)
		problem = _keep(profile, b, id_b)
		var second: Dictionary = profile.record()
		if spend != "" or problem != "" or second["xp_certificates"] != {} or second["xp_certificates_spent"] != [FARM_Q] or second["quest_points"] != { FARM_Q: 2 }:
			return "The file knows it is spent: %s %s %s" % [spend, problem, second]
		var xp: Dictionary = a.player_skill_xp.get(id_a, {}).duplicate()
		var back: String = _join(a, second)
		a.update_quests(_both(id_a))
		if back != id_a or not _worth(a, id_a).is_empty() or not a.has_had_xp_certificate(FARM_Q, id_a) or a.player_skill_xp.get(id_a, {}) != xp:
			return "Back on farm A the certificate is gone and pays nothing: %s" % [a.xp_certificates]
		# An older copy of the file brings nothing back, and the file stays as it is.
		_join(a, first)
		_join(b, first)
		a.update_quests(_both(id_a))
		problem = _keep(profile, a, id_a)
		if not _worth(a, id_a).is_empty() or not _worth(b, id_b).is_empty() or QuestEngine.points_of(a, id_a) != 2 or profile.record() != second or problem != "":
			return "An old file must not give it back: %s, %s, %s %s" % [a.xp_certificates, b.xp_certificates, profile.record(), problem]
		if _worth(a, "player_1") != [200] or QuestEngine.points_of(a, "player_1") != 2:
			return "The host's own are untouched: %s" % [a.xp_certificates]
		return "")


func test_a_host_takes_only_what_its_quests_pay() -> String:
	return _run(func() -> String:
		var farm: Node = _farm()
		var record: Dictionary = { "quest_points": { FARM_Q: 99, OWN_Q: 1, "nope": 5 }, "xp_certificates": { FARM_Q: 99999, "nope": 10, OWN_Q: 50 },
			"xp_certificates_spent": ["nope", OWN_Q], "quests": { "nope": { "done": true, "steps": [], "counts": {} }, FARM_Q: { "done": true, "steps": [], "counts": {} } } }
		if not ProfileScript.is_record(record):
			return "The record itself is well formed."
		var id: String = _join(farm, record)
		if farm.quest_points.get(id) != { FARM_Q: 2, OWN_Q: 1 } or _worth(farm, id) != [200]:
			return "No more than the quest pays here: %s, %s" % [farm.quest_points, farm.xp_certificates]
		if farm.xp_certificates_spent.has(id) or farm.player_quest_state.has(id) or farm.xp_certificates_given != 1:
			return "Quests this farm has not, or that are not a player's own, are not taken: %s, %s" % [farm.xp_certificates_spent, farm.player_quest_state]
		# What a host did not check (a save, a test) is still read with care.
		var odd: Dictionary = { "quest_points": { FARM_Q: "9", 3: 1 }, "xp_certificates": [], "xp_certificates_spent": { FARM_Q: 1 }, "quests": { OWN_Q: 5 } }
		var other: Node = _farm()
		var odd_id: String = other.let_in_guest("1".repeat(32), {}, ["player_1"] as Array[String], odd)
		if other.quest_points.has(odd_id) or other.xp_certificates.has(odd_id) or other.xp_certificates_spent.has(odd_id) or other.player_quest_state.has(odd_id):
			return "A record that is not one changes nothing."
		# A guest the farm forgot gets theirs back from the file, not twice.
		farm.quest_points.erase(id)
		farm.xp_certificates.erase(id)
		_join(farm, { "quest_points": { FARM_Q: 2 }, "xp_certificates": { FARM_Q: 200 }, "xp_certificates_spent": [], "quests": {} })
		_join(farm, { "quest_points": { FARM_Q: 2 }, "xp_certificates": { FARM_Q: 200 }, "xp_certificates_spent": [], "quests": {} })
		if farm.quest_points.get(id) != { FARM_Q: 2 } or _worth(farm, id) != [200]:
			return "A forgotten guest brings theirs back once: %s, %s" % [farm.quest_points, farm.xp_certificates]
		return farm.farm_dict_problem(farm.farm_to_dict()))


func test_a_player_s_own_quest_travels() -> String:
	return _run(func() -> String:
		var profile: Node = _profile()
		var a: Node = _farm()
		var id_a: String = _join(a)
		a.update_quests(_both(id_a))
		_tills(a, id_a, 2)
		a.update_quests(_both(id_a))
		var there: Dictionary = QuestEngine.travelling(a, id_a)
		if there != { OWN_Q: { "done": false, "steps": [], "counts": { "till": 2 } } } or not a.player_quest_state.has("player_1"):
			return "Each player has the quest, and theirs counts their tilling: %s" % [a.player_quest_state]
		if QuestEngine.travelling(a, "player_1")[OWN_Q]["counts"] != {}:
			return "The host tilled nothing: %s" % [a.player_quest_state["player_1"]]
		var problem: String = _keep(profile, a, id_a)
		if problem != "" or profile.record()["quests"] != there:
			return "The file keeps how far they are: %s %s" % [problem, profile.record()]
		# On farm B it goes on from there: 2 brought and 1 tilled is 3.
		var b: Node = _farm()
		var id_b: String = _join(b, profile.record())
		_join(b, profile.record())
		b.update_quests(_both(id_b))
		if QuestEngine.travelling(b, id_b) != there:
			return "Farm B takes it up where it stands, once: %s" % [b.player_quest_state]
		_tills(b, id_b, 1)
		b.update_quests(_both(id_b))
		_join(b, profile.record())
		b.update_quests(_both(id_b))
		var entry: Dictionary = b.player_quest_state[id_b][OWN_Q]
		if entry["steps_done"] != ["till"] or entry["done"] >= 0 or entry["shown"]["till"] != 3:
			return "2 brought and 1 tilled finish the step: %s" % [entry]
		b.credits = RICH
		b.update_quests(_both(id_b))
		if b.credits != RICH + 100 or b.quest_points.get(id_b) != { FARM_Q: 2, OWN_Q: 1 } or b.quest_points.get("player_1") != { FARM_Q: 2 } or QuestEngine.is_done(b, OWN_Q, "player_1"):
			return "Farm B pays them alone, once: %d, %s" % [b.credits, b.quest_points]
		problem = _keep(profile, b, id_b)
		var done: Dictionary = profile.record()
		if problem != "" or done["quests"] != { OWN_Q: { "done": true, "steps": ["till", "pay"], "counts": { "till": 3 } } } or done["quest_points"] != { FARM_Q: 2, OWN_Q: 1 }:
			return "The file knows it is done: %s %s" % [problem, done]
		# Done on B is done on A, and A pays nothing for it.
		a.credits = RICH
		_join(a, done)
		a.update_quests(_both(id_a))
		_join(a, done)
		a.update_quests(_both(id_a))
		if not QuestEngine.is_done(a, OWN_Q, id_a) or a.credits != RICH or a.quest_points.get(id_a) != { FARM_Q: 2, OWN_Q: 1 }:
			return "Done elsewhere is done here and not paid again: %d, %s, %s" % [a.credits, a.quest_points, a.player_quest_state]
		# The file never goes back: farm A still says 2 for the count.
		_keep(profile, a, id_a)
		if profile.record() != done:
			return "The file keeps the most it has seen: %s" % [profile.record()]
		return a.farm_dict_problem(a.farm_to_dict()))


func test_counts_meet_by_the_higher_and_are_never_added() -> String:
	return _run(func() -> String:
		var farm: Node = _farm()
		var with: Callable = func(count: int) -> Dictionary:
			return { "quest_points": {}, "xp_certificates": {}, "xp_certificates_spent": [], "quests": { OWN_Q: { "done": false, "steps": [], "counts": { "till": count } } } }
		var id: String = _join(farm, with.call(1))
		for count: int in [1, 2, 1, 2, 2]:
			_join(farm, with.call(count))
			farm.update_quests(_both(id))
		var entry: Dictionary = farm.player_quest_state[id][OWN_Q]
		if entry["shown"] != { "till": 2 } or not entry["steps_done"].is_empty():
			return "Coming back often adds nothing: %s" % [entry]
		_tills(farm, id, 1)
		farm.update_quests(_both(id))
		if farm.player_quest_state[id][OWN_Q]["steps_done"] != ["till"]:
			return "One more here finishes it: %s" % [farm.player_quest_state[id][OWN_Q]]
		# A step done elsewhere is done here, and the next one opens.
		var other: Node = _farm()
		var record: Dictionary = with.call(3)
		record["quests"][OWN_Q]["steps"] = ["till", "no_such_step"]
		var other_id: String = _join(other, record)
		other.credits = RICH
		other.update_quests(_both(other_id))
		if other.player_quest_state[other_id][OWN_Q]["steps_done"] != ["till", "pay"] or other.credits != RICH + 100:
			return "The last step done here pays here: %s, %d" % [other.player_quest_state[other_id], other.credits]
		for bad: Dictionary in [{ id: { OWN_Q: {} } }, { "": {} }, { id: { OWN_Q: entry.duplicate(true).merged({ "carried": { "till": -1 } }, true) } }, { id: 5 }]:
			var data: Dictionary = farm.farm_to_dict()
			data["player_quest_state"] = bad
			if farm.farm_dict_problem(data) == "":
				return "A save with player_quest_state %s is refused." % [bad]
		for bad: Variant in [{ id: [1] }, { "": [] }, { id: "x" }]:
			var data: Dictionary = farm.farm_to_dict()
			data["xp_certificates_spent"] = bad
			if farm.farm_dict_problem(data) == "":
				return "A save with xp_certificates_spent %s is refused." % [bad]
		return "")


func test_an_old_guest_file_and_a_bad_one() -> String:
	return _run(func() -> String:
		var none: Dictionary = ProfileScript.no_record()
		if not ProfileScript.is_record(none) or ProfileScript.CURVE != 3:
			return "No record is a record, and the file's curve did not change."
		# A file from before the record loads with an empty one, XP and all.
		var old: String = '{"key":"%s","skills":{"calibration":60},"curve":3}' % KEY
		var got: Dictionary = ProfileScript._parse(old.to_utf8_buffer())
		if got != { "key": KEY, "skills": { "calibration": 60 } }.merged(none):
			return "An old guest file loads: %s" % [got]
		var full: String = '{"key":"%s","skills":{},"curve":3,"quest_points":{"q":2},"xp_certificates":{"q":200},"xp_certificates_spent":["r"],"quests":{"p":{"done":false,"steps":["s"],"counts":{"s":4}}}}' % KEY
		got = ProfileScript._parse(full.to_utf8_buffer())
		var want: Dictionary = { "quest_points": { "q": 2 }, "xp_certificates": { "q": 200 }, "xp_certificates_spent": ["r"], "quests": { "p": { "done": false, "steps": ["s"], "counts": { "s": 4 } } } }
		if got != { "key": KEY, "skills": {} }.merged(want) or not got["quest_points"]["q"] is int or not got["quests"]["p"]["counts"]["s"] is int:
			return "A file with a record loads with whole numbers: %s" % [got]
		var long: String = "x".repeat(SessionScript.MAX_TEXT + 1)
		for part: String in ['"quest_points":{"q":-1}', '"quest_points":{"q":1.5}', '"quest_points":[]', '"quest_points":{"q":"2"}', '"quest_points":{"":1}',
				'"quest_points":{"%s":1}' % long, '"quest_points":{"q":1e300}', '"xp_certificates":{"q":0}', '"xp_certificates":{"q":2000000000}',
				'"xp_certificates_spent":["q","q"]', '"xp_certificates_spent":[1]', '"xp_certificates_spent":{}', '"quests":[]', '"quests":{"p":1}',
				'"quests":{"p":{}}', '"quests":{"p":{"done":0,"steps":[],"counts":{}}}', '"quests":{"p":{"done":true,"steps":[1],"counts":{}}}',
				'"quests":{"p":{"done":true,"steps":[],"counts":{"s":-2}}}', '"quests":{"p":{"done":true,"steps":[]}}',
				'"quests":{"p":{"done":true,"steps":["a","b","c","d","e","f","g","h","i","j","k","l","m"],"counts":{}}}']:
			var text: String = '{"key":"%s","skills":{},"curve":3,%s}' % [KEY, part]
			if not ProfileScript._parse(text.to_utf8_buffer()).is_empty():
				return "Must not be read: %s" % part.left(80)
		var many: Dictionary = {}
		for i: int in ProfileScript.MOST_QUESTS + 1:
			many["q%d" % i] = 1
		if ProfileScript.is_record(none.merged({ "quest_points": many }, true)) or ProfileScript.is_record({}) or ProfileScript.is_record(none.merged({ "more": 1 })):
			return "Too many quests, or other keys, are not a record."
		# The old file on disk: read, then written with the record, key and XP kept.
		_put_file(old)
		var profile: Node = _profile()
		if profile.record() != none or profile.card() != { "key": KEY, "skills": { "calibration": 60 } }:
			return "The old file is read: %s" % [profile.card()]
		var farm: Node = _farm()
		farm.local_player_id = "player_2"
		farm.quest_points["player_2"] = { "q": 3 }
		farm.xp_certificates["player_2"] = { "q#1": 50, "q#2": 80, "r#3": 10 }
		farm.xp_certificates_spent["player_2"] = ["r"]
		profile.farm = farm
		profile.keep()
		var read: Node = ProfileScript.new()
		_profiles.append(read)
		read.path = FILE
		var kept: Dictionary = read.record()
		if kept != { "quest_points": { "q": 3 }, "xp_certificates": { "q": 80 }, "xp_certificates_spent": ["r"], "quests": {} } or read.card() != profile.card():
			return "The file is written with the record: %s" % [kept]
		if not '"curve": 3' in FileAccess.get_file_as_string(FILE) or FileAccess.file_exists(FILE + ".unreadable"):
			return "The file still says curve 3."
		# At home nothing is kept.
		profile.session.away = false
		farm.quest_points["player_2"] = { "q": 9 }
		profile.keep()
		if read.record() != kept:
			return "Their own farm's quests stay there."
		return "")


func test_the_record_goes_in_the_hello() -> String:
	return _run(func() -> String:
		var record: String = '"quest_points":{"%s":2},"xp_certificates":{"%s":200},"xp_certificates_spent":[],"quests":{"%s":{"done":false,"steps":[],"counts":{"till":2}}}' % [FARM_Q, FARM_Q, OWN_Q]
		_put_file('{"key":"%s","skills":{},"curve":3,%s}' % [KEY, record])
		var host: Node = _host()
		var farm: Node = host.commands.state
		for round: int in 2:
			var guest: Node = _session()
			guest.profile.path = FILE
			guest.join(LOCAL, host.port())
			_until(func() -> bool: return _got(guest, "joined") or _got(guest, "refused"))
			if not guest.is_guest() or farm.quest_points.get("player_2") != { FARM_Q: 2 } or _worth(farm, "player_2") != [200]:
				return "The host has what the guest's file says (join %d): %s, %s, %s" % [round, _log, farm.quest_points, farm.xp_certificates]
			if QuestEngine.travelling(farm, "player_2") != { OWN_Q: { "done": false, "steps": [], "counts": { "till": 2 } } }:
				return "And their own quest: %s" % [farm.player_quest_state]
			guest.leave()
			_until(func() -> bool: return host.players.size() == 1)
			_log.clear()
		# A record too big for a hello gives up quest progress, and nothing else.
		var big: Dictionary = ProfileScript.no_record().merged({ "quest_points": { FARM_Q: 2 }, "xp_certificates_spent": [FARM_Q] }, true)
		for i: int in ProfileScript.MOST_PROGRESS:
			var steps: Array = []
			for j: int in ProfileScript.MOST_STEPS:
				steps.append(("%d_" % j).rpad(SessionScript.MAX_TEXT, "x"))
			big["quests"][("%d_" % i).rpad(SessionScript.MAX_TEXT, "q")] = { "done": false, "steps": steps, "counts": {} }
		var card: Dictionary = { "key": KEY, "skills": {} }
		var small: Dictionary = ProfileScript.no_record().merged({ "quest_points": { FARM_Q: 2 } }, true)
		var sent: Dictionary = host.hello(card, big)[4]
		if not ProfileScript.is_record(big) or not ProfileScript.is_record(sent) or host.hello(card, small)[4] != small:
			return "A hello has the record."
		if sent["quest_points"] != { FARM_Q: 2 } or sent["xp_certificates_spent"] != [FARM_Q] or sent["quests"].is_empty() or sent["quests"].size() >= ProfileScript.MOST_PROGRESS:
			return "A record too big goes without some quest progress, and with its points and spent certificates: %d quests" % sent["quests"].size()
		if var_to_bytes(host.hello(card, big)).size() > SessionScript.MAX_HELLO_BYTES or SessionScript.PROTOCOL != 15:
			return "A hello fits, and the protocol says the hello changed."
		return "")


func test_quests_reach_a_guest_with_the_farm() -> String:
	return _run(func() -> String:
		var elapsed: float = GameClock.elapsed_days
		var speed: float = GameClock.seconds_per_day
		var paused: bool = GameClock.paused
		var open: bool = SaveGame.farm_open
		var host: Node = _farm()
		var id: String = _join(host)
		host.credits = RICH
		host.update_quests(_both(id))
		var guest: Node = _farm()
		guest.local_player_id = id
		var profile: Node = _profile()
		profile.start(profile.session, guest)
		FarmCommands.guest = true
		var problem: String = FarmSync.join(FarmSync.capture(host), guest)
		for field: String in ["quest_state", "quest_points", "player_quest_state", "xp_certificates", "xp_certificates_spent"]:
			if var_to_bytes(guest.get(field)) != var_to_bytes(host.get(field)):
				problem += " '%s' differs after joining." % field
		var counts: Dictionary = {}
		guest.quests_changed.connect(func() -> void: counts["quests"] = counts.get("quests", 0) + 1)
		guest.xp_certificates_changed.connect(func() -> void: counts["certificates"] = counts.get("certificates", 0) + 1)
		# One thing at a time, so each signal is known to show its own variables.
		FarmCommands.guest = false
		_tills(host, id, 2)
		host.update_quests(_both(id))
		FarmCommands.guest = true
		problem += FarmSync.update(FarmSync.capture(host), guest)
		if counts != { "quests": 1 } or guest.player_quest_state != host.player_quest_state:
			problem += " A player's own quest moving is shown as quests_changed: %s." % [counts]
		FarmCommands.guest = false
		var spend: String = host.spend_xp_certificate(str(host.held_xp_certificates(id).keys()[0]), "calibration", id)
		FarmCommands.guest = true
		problem += spend + FarmSync.update(FarmSync.capture(host), guest)
		if counts != { "quests": 1, "certificates": 1 } or guest.xp_certificates_spent != { id: [FARM_Q] } or guest.xp_certificates.has(id):
			problem += " A spent certificate is shown as xp_certificates_changed: %s." % [counts]
		# And the guest's file has it all, from those signals alone.
		var kept: Dictionary = profile.record()
		if kept != { "quest_points": { FARM_Q: 2 }, "xp_certificates": {}, "xp_certificates_spent": [FARM_Q], "quests": { OWN_Q: { "done": false, "steps": [], "counts": { "till": 2 } } } }:
			problem += " The guest's file follows the farm: %s." % [kept]
		GameClock.elapsed_days = elapsed
		GameClock.seconds_per_day = speed
		GameClock.paused = paused
		SaveGame.farm_open = open
		return problem)


func test_a_record_can_t_say_not_done_and_be_paid() -> String:
	return _run(func() -> String:
		var with: Callable = func(steps: Array, counts: Dictionary) -> Dictionary:
			return ProfileScript.no_record().merged({ "quests": { OWN_Q: { "done": false, "steps": steps, "counts": counts } } }, true)
		# Every step brought, by id or by a full count: done somewhere, so not paid here.
		for record: Dictionary in [with.call(["till", "pay"], {}), with.call(["pay"], { "till": 1000000 }), with.call(["pay", "till", "x"], { "till": 0 })]:
			var farm: Node = _farm()
			farm.credits = RICH
			var id: String = _join(farm, record)
			farm.update_quests(_both(id))
			farm.update_quests(_both(id))
			var entry: Dictionary = farm.player_quest_state.get(id, {}).get(OWN_Q, {})
			if int(entry.get("done", -1)) < 0 or farm.credits != RICH or farm.quest_points.get(id, {}).has(OWN_Q):
				return "A record with every step done is done and unpaid: %s -> %s, %d CR, %s" % [record["quests"], entry, farm.credits, farm.quest_points]
			if QuestEngine.travelling(farm, id)[OWN_Q]["done"] != true:
				return "And it travels on as done."
		# A count comes as no more than its step needs.
		var other: Node = _farm()
		var other_id: String = _join(other, with.call([], { "till": 1000000 }))
		var got: Dictionary = other.player_quest_state[other_id][OWN_Q]
		if got["shown"] != { "till": 3 } or got["carried"] != { "till": 3 } or int(got["done"]) >= 0:
			return "A huge count is the step's need and no more: %s" % [got]
		# The rest of it is still done here, and paid here.
		other.update_quests(_both(other_id))
		if other.credits != 0 or other.player_quest_state[other_id][OWN_Q]["steps_done"] != ["till"]:
			return "The last step is not done yet: %s" % [other.player_quest_state[other_id]]
		other.credits = RICH
		other.update_quests(_both(other_id))
		if other.credits != RICH + 100 or other.quest_points[other_id].get(OWN_Q) != 1:
			return "A quest whose last step is done here pays here: %d, %s" % [other.credits, other.quest_points]
		return "")


## Names as long as a name may be, each different, that JSON writes longer.
func _names(count: int, mark: String) -> Array:
	var out: Array = []
	for i: int in count:
		out.append(("%s%d" % [mark, i]).rpad(SessionScript.MAX_TEXT, '"'))
	return out


func test_a_record_too_big_keeps_points_and_certificates() -> String:
	return _run(func() -> String:
		# As much as a record may hold.
		var big: Dictionary = ProfileScript.no_record()
		for name: String in _names(ProfileScript.MOST_QUESTS, "p"):
			big["quest_points"][name] = ProfileScript.MOST_XP
		for name: String in _names(ProfileScript.MOST_QUESTS, "h"):
			big["xp_certificates"][name] = ProfileScript.MOST_XP
		big["xp_certificates_spent"] = _names(ProfileScript.MOST_QUESTS, "s")
		var steps: Array = _names(ProfileScript.MOST_STEPS, "t")
		var counts: Dictionary = {}
		for step: String in steps:
			counts[step] = ProfileScript.MOST_XP
		var ids: Array = _names(ProfileScript.MOST_PROGRESS, "q")
		for i: int in ids.size():
			# The first is the smallest one under way.
			big["quests"][ids[i]] = { "done": i % 2 == 1, "steps": steps.duplicate() if i > 0 else [], "counts": counts.duplicate() if i > 0 else {} }
		if not ProfileScript.is_record(big) or var_to_bytes(big).size() <= SessionScript.MAX_HELLO_BYTES:
			return "The biggest record is a record, and too big for a hello: %d" % var_to_bytes(big).size()
		var fit: Dictionary = ProfileScript.fitted(big)
		if not ProfileScript.is_record(fit) or var_to_bytes(fit).size() > ProfileScript.MAX_RECORD_BYTES:
			return "A fitted record is a record that fits: %d" % var_to_bytes(fit).size()
		for part: String in ["quest_points", "xp_certificates", "xp_certificates_spent"]:
			if fit[part] != big[part]:
				return "Fitting never drops %s." % part
		var under_way: int = 0
		for i: int in ids.size():
			var quest: Variant = fit["quests"].get(ids[i])
			if i % 2 == 1 and quest != { "done": true, "steps": [], "counts": {} }:
				return "A quest that is done stays done: %s" % [quest]
			if i % 2 == 0 and quest != null:
				under_way += 1
				if quest != big["quests"][ids[i]]:
					return "A quest under way is kept whole or not at all."
		if under_way == 0 or under_way == ids.size() / 2 or not fit["quests"].has(ids[0]):
			return "The biggest quests under way go first: %d kept" % under_way
		if big["quests"][ids[1]]["steps"].is_empty() or ProfileScript.fitted(fit) != fit:
			return "Fitting changes a copy, and only once."
		# It fits a hello, with as many skills as a card may have.
		var skills: Dictionary = {}
		for name: String in _names(ProfileScript.MOST_SKILLS, "k"):
			skills[name] = ProfileScript.MOST_XP
		var session: Node = SessionScript.new()
		_profiles.append(session)
		var card: Dictionary = { "key": KEY, "skills": skills }
		var hello: Array = session.hello(card, big)
		if not ProfileScript.are_skills(skills) or hello[4] != fit or var_to_bytes(hello).size() > SessionScript.MAX_HELLO_BYTES:
			return "A hello with the biggest record fits: %d" % var_to_bytes(hello).size()
		# And the file: written, not refused, and read back the same.
		var failed: Array = []
		var on_failed: Callable = func(message: String) -> void: failed.append(message)
		SaveGame.save_failed.connect(on_failed)
		var profile: Node = _profile()
		profile._write({ "key": KEY, "skills": skills }.merged(big))
		SaveGame.save_failed.disconnect(on_failed)
		var size: int = FileAccess.get_file_as_bytes(FILE).size()
		if not failed.is_empty() or size == 0 or size > ProfileScript.MAX_FILE_BYTES:
			return "The biggest record is written: %s, %d bytes" % [failed, size]
		if profile.record() != fit or profile.card() != card or FileAccess.file_exists(FILE + ".unreadable"):
			return "And read back with every point and certificate."
		return "")


func test_spent_certificates_are_never_crowded_out() -> String:
	return _run(func() -> String:
		# More than the 64 a file once had room for, and quest progress to the brim.
		var count: int = 100
		var farm: Node = _farm()
		farm.local_player_id = "player_2"
		var spent: Array = []
		var points: Dictionary = {}
		var held: Dictionary = {}
		for i: int in count:
			spent.append("spent_%d" % i)
			points["quest_%d" % i] = 1
			held["held_%d#%d" % [i, i + 1]] = 10
		farm.xp_certificates_spent["player_2"] = spent
		farm.quest_points["player_2"] = points
		farm.xp_certificates["player_2"] = held
		var own: Dictionary = {}
		for i: int in ProfileScript.MOST_PROGRESS + 5:
			own["own_%d" % i] = { "accepted": 0, "steps_done": [], "base": {}, "shown": {}, "players": ["player_2"], "done": -1, "carried": {} }
		farm.player_quest_state["player_2"] = own
		var profile: Node = _profile()
		profile.farm = farm
		profile.keep()
		var read: Node = ProfileScript.new()
		_profiles.append(read)
		read.path = FILE
		var kept: Dictionary = read.record()
		if kept["xp_certificates_spent"] != spent or kept["quest_points"] != points or kept["xp_certificates"].size() != count:
			return "Every spent certificate, point and held certificate is kept: %d, %d, %d" % [kept["xp_certificates_spent"].size(), kept["quest_points"].size(), kept["xp_certificates"].size()]
		if kept["quests"].size() != ProfileScript.MOST_PROGRESS or count <= 64:
			return "Quest progress has its own room: %d" % kept["quests"].size()
		# One spent later is kept, though quest progress is full.
		farm.xp_certificates["player_2"].erase("held_0#1")
		farm.xp_certificates_spent["player_2"] = ["held_0"]
		profile.keep()
		kept = read.record()
		if kept["xp_certificates"].has("held_0") or kept["xp_certificates_spent"] != spent + ["held_0"]:
			return "Spending drops the held one and forgets no other."
		return "")


## Not a fixture: the game's own quests must fit a guest's record.
func test_the_shipped_quests_fit_a_record() -> String:
	var all: Array[Dictionary] = QuestEngine.quests()
	var own: int = 0
	for quest: Dictionary in all:
		var id: String = str(quest.get("id", ""))
		if not ProfileScript._is_name(id):
			return "Quest id '%s' is not a name a record can keep." % id
		if str(quest.get("scope", "farm")) != "player":
			continue
		own += 1
		var steps: Array = quest.get("steps", [])
		if steps.size() > ProfileScript.MOST_STEPS:
			return "Quest '%s' has %d steps; a record keeps %d (CoopProfile.MOST_STEPS)." % [id, steps.size(), ProfileScript.MOST_STEPS]
		for step: Variant in steps:
			if not ProfileScript._is_name(step.get("id")):
				return "Quest '%s' has a step id a record can't keep." % id
	if all.is_empty() or all.size() > ProfileScript.MOST_QUESTS:
		return "data/quests.json has %d quests; a record keeps points and certificates for %d (CoopProfile.MOST_QUESTS)." % [all.size(), ProfileScript.MOST_QUESTS]
	if own > ProfileScript.MOST_PROGRESS:
		return "data/quests.json has %d player quests; a record keeps progress in %d (CoopProfile.MOST_PROGRESS)." % [own, ProfileScript.MOST_PROGRESS]
	return ""


## A stand-in for CoopSync.
class Sync extends Node:
	var here: bool = false
	func has_farm() -> bool:
		return here


func test_nothing_is_kept_before_the_host_s_farm_comes() -> String:
	return _run(func() -> String:
		var profile: Node = _profile()
		var before: Dictionary = profile.record()
		var sync: Node = Sync.new()
		_profiles.append(sync)
		profile.sync = sync
		# The player's own farm, under the id the host just gave them.
		var home: Node = _farm()
		home.local_player_id = "player_2"
		home.quest_points["player_2"] = { FARM_Q: 2 }
		home.xp_certificates_spent["player_2"] = [FARM_Q]
		profile.farm = home
		profile.keep()
		if profile.record() != before:
			return "Welcomed, but the farm here is still home: nothing is kept. %s" % [profile.record()]
		sync.here = true
		profile.keep()
		if profile.record()["quest_points"] != { FARM_Q: 2 }:
			return "Once the host's farm has come it is kept."
		return "")
