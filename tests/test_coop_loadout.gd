extends "res://tests/coop_net.gd"
## The picker over a real connection (this machine only): a guest asks the host to change
## its own loadout, the host checks it, and everyone's copy of the farm gets it.

const SyncScript: GDScript = preload("res://scripts/autoload/CoopSync.gd")

var _syncs: Array[Node] = []
var _events: Array = []


func _sync(session: Node) -> Node:
	var sync: Node = SyncScript.new()
	sync.start(session, session.commands.state)
	sync.farm_ready.connect(func() -> void: _events.append("ready"))
	_syncs.append(sync)
	return sync


## Runs `body(host, first, second)` with a host and two guests that have the farm.
func _play(body: Callable) -> String:
	var elapsed: float = GameClock.elapsed_days
	var speed: float = GameClock.seconds_per_day
	var paused: bool = GameClock.paused
	var open: bool = SaveGame.farm_open
	_events.clear()
	GameClock.elapsed_days = 2.25
	var host: Node = _host()
	_sync(host)
	FarmCommands.guest = true
	var first: Node = _session()
	_sync(first)
	first.join(LOCAL, host.port())
	var second: Node = _session()
	_sync(second)
	second.join(LOCAL, host.port())
	var problem: String = "Both guests must get the farm, got %s" % [_events]
	if _until(func() -> bool: return _events.count("ready") == 2):
		problem = body.call(host, first, second)
	problem = _finish(problem)
	for sync: Node in _syncs:
		sync.free()
	_syncs.clear()
	FarmCommands.guest = false
	GameClock.elapsed_days = elapsed
	GameClock.seconds_per_day = speed
	GameClock.paused = paused
	SaveGame.farm_open = open
	return problem


func test_a_guest_changes_its_own_loadout_and_everyone_sees_it() -> String:
	return _play(func(host: Node, first: Node, second: Node) -> String:
		var choice: String = Loadout.encode({ Loadout.HEAD: &"sun_brim_hat", Loadout.POWER: &"twin_cell_battery_pack",
			Loadout.WHEELS: &"wide_crawler_tracks" })
		var answer: Array = _request(first, &"set_loadout", ["Quill", choice])
		_until(func() -> bool: return not answer.is_empty())
		var mine: String = first.commands.state.local_player_id
		if answer != [""] or mine == "player_1":
			return "The host must take it, got %s for %s" % [answer, mine]
		# The host sends the farm to everyone once a second (the tick runs in the game itself).
		var seen: Callable = func() -> bool:
			_syncs[0].tick(Time.get_ticks_msec())
			return second.commands.state.loadout_of(mine)["name"] == "Quill"
		if not _until(seen):
			return "The other guest must get the new loadout"
		var parts: Dictionary = second.commands.state.loadout_of(mine)["parts"]
		if Loadout.encode(parts) != choice or host.commands.state.loadout_of(mine)["name"] != "Quill":
			return "Every copy must have the same loadout, got %s" % [parts]
		if host.commands.state.loadout_of("player_1")["name"] != "":
			return "The host's own must be as it was"
		return "")


## What a guest's session sends when it skips FarmCommands.request (which refuses a wrong
## argument count itself): the raw command, as a forger would send it.
func _forged(session: Node, arguments: Array) -> Array:
	var got: Array = []
	var ask: Callable = func() -> void: got.append(await session._ask(&"set_loadout", arguments))
	ask.call()
	return got


func test_a_guest_cannot_change_another_player_s_loadout() -> String:
	return _play(func(host: Node, first: Node, _second: Node) -> String:
		var choice: String = "1,1,1,1,1,1"
		var state: Node = host.commands.state
		# Named as the host, in a third argument: the host's own check refuses the count.
		var named: Array = _forged(first, ["Fake", choice, "player_1"])
		_until(func() -> bool: return not named.is_empty())
		if named.is_empty() or named[0] == "" or not named[0] is String:
			return "The host must refuse a command that names a player, got %s" % [named]
		if not state.player_loadouts.is_empty():
			return "A refused command must change nothing, got %s" % [state.player_loadouts]
		# The right shape: stored under the connection's player, never the host's.
		var plain: Array = _forged(first, ["Mine", choice])
		_until(func() -> bool: return not plain.is_empty())
		var sender: String = first.commands.state.local_player_id
		if plain != [""] or sender == "player_1":
			return "The host must take the plain command from %s, got %s" % [sender, plain]
		if state.loadout_of("player_1")["name"] != "" or state.loadout_of("player_1")["parts"] != Loadout.default_parts():
			return "The host's own loadout must not change, got %s" % [state.player_loadouts]
		if not state.player_loadouts.has(sender) or state.player_loadouts.size() != 1 or state.loadout_of(sender)["name"] != "Mine":
			return "It must be stored under the sender (%s), got %s" % [sender, state.player_loadouts]
		return "")


func test_the_host_refuses_what_is_not_a_loadout() -> String:
	return _play(func(host: Node, first: Node, _second: Node) -> String:
		var bad: Array = ["", "1,2,3", "9,9,9,9,9,9", "a,b,c,d,e,f", "0,0,0,0,0,0,0", "-1,0,0,0,0,0"]
		for choice: String in bad:
			var answer: Array = _request(first, &"set_loadout", ["Quill", choice])
			_until(func() -> bool: return not answer.is_empty())
			if answer.is_empty() or answer[0] == "":
				return "'%s' must be refused, got %s" % [choice, answer]
		# A name over the limit but within a message: the name rule refuses it.
		var long_name: Array = _request(first, &"set_loadout", ["N".repeat(40), "0,0,0,0,0,0"])
		_until(func() -> bool: return not long_name.is_empty())
		if long_name.is_empty() or long_name[0] == "" or not str(long_name[0]).contains("characters"):
			return "A name over the limit must be refused by the name rule, got %s" % [long_name]
		# One over a message's text limit: the transport drops the guest, who is told nothing.
		var huge_name: Array = _request(first, &"set_loadout", ["N".repeat(200), "0,0,0,0,0,0"])
		_until(func() -> bool: return not huge_name.is_empty())
		if huge_name.is_empty() or huge_name[0] == "":
			return "A message over the text limit must not be taken, got %s" % [huge_name]
		return "" if host.commands.state.player_loadouts.is_empty() else "Nothing must be stored, got %s" % [host.commands.state.player_loadouts])
