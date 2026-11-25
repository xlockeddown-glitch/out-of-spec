extends "res://tests/coop_net.gd"
## A guest sees the host's farm: a real connection, on this machine only.

const SyncScript: GDScript = preload("res://scripts/autoload/CoopSync.gd")

var _syncs: Array[Node] = []
var _events: Array = []


func _sync(session: Node) -> Node:
	var sync: Node = SyncScript.new()
	sync.start(session, session.commands.state)
	sync.farm_ready.connect(func() -> void: _events.append("ready"))
	sync.stopped.connect(func(text: String) -> void: _events.append(text))
	_syncs.append(sync)
	return sync


## Runs `body` with a host and a guest that joined it, then puts the clock back.
## FarmCommands says guest: host and guest share this process.
func _play_together(body: Callable) -> String:
	var elapsed: float = GameClock.elapsed_days
	var speed: float = GameClock.seconds_per_day
	var paused: bool = GameClock.paused
	var open: bool = SaveGame.farm_open
	_events.clear()
	GameClock.elapsed_days = 2.25
	var host: Node = _host()
	var host_sync: Node = _sync(host)
	host.commands.state.credits = 777
	host.commands.state.set_world_seed(99)
	FarmCommands.guest = true
	var guest: Node = _session()
	var guest_sync: Node = _sync(guest)
	guest.join(LOCAL, host.port())
	var problem: String = "The farm must come after joining, got %s" % [_events]
	if _until(func() -> bool: return _events.has("ready")):
		problem = body.call(host, guest, host_sync, guest_sync)
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


func test_joining_brings_the_whole_farm() -> String:
	return _play_together(func(host: Node, guest: Node, _host_sync: Node, _guest_sync: Node) -> String:
		var mine: Dictionary = guest.commands.state.farm_to_dict()
		var theirs: Dictionary = host.commands.state.farm_to_dict()
		if var_to_bytes(mine) != var_to_bytes(theirs):
			return "The guest's copy must be the host's farm"
		return "" if _events == ["ready"] else "Got %s" % [_events])


func test_a_command_s_change_comes_before_its_answer() -> String:
	return _play_together(func(host: Node, guest: Node, _host_sync: Node, _guest_sync: Node) -> String:
		var cell := Vector3i(0, 0, 0)
		var seen: Array = []
		var ask: Callable = func() -> void:
			await guest.commands.request(&"till", [cell])
			seen.append(guest.commands.state.tilled_cells.has(cell))
		ask.call()
		_until(func() -> bool: return not seen.is_empty())
		if not host.commands.state.tilled_cells.has(cell):
			return "The host must till"
		return "" if seen == [true] else "The guest's copy must have it when the answer comes, got %s" % [seen])


func test_the_host_s_changes_and_clock_come_in_time() -> String:
	return _play_together(func(host: Node, guest: Node, host_sync: Node, _guest_sync: Node) -> String:
		host.commands.state.credits = 555
		host_sync.tick(1000000)
		if not _until(func() -> bool: return guest.commands.state.credits == 555):
			return "A change must reach the guest"
		host.commands.state.credits = 444
		GameClock.paused = true
		GameClock.elapsed_days = 2.5
		var got: int = _log.size()
		host_sync.tick(1000000 + SyncScript.CLOCK_MS - 1)
		host_sync.tick(1000000 + SyncScript.CLOCK_MS)
		_until(func() -> bool: return _log.size() > got)
		if _log.size() != got + 1 or not _log[-1][2].has("clock"):
			return "Only the clock must come between farms, got %s" % [_log.slice(got)]
		host_sync.tick(1000000 + SyncScript.FARM_MS)
		return "" if _until(func() -> bool: return guest.commands.state.credits == 444) else "The next farm must come a second later")


func test_a_bad_farm_ends_the_connection() -> String:
	for bad: Dictionary in [{}, { "clock": 1 }, { "too_big": true }, { "farm": PackedByteArray(), "size": 3 }, { "clock": {} }, { "farm": PackedByteArray([1]), "size": 0 },
			{ "farm": PackedByteArray([1]), "size": FarmSync.MAX_BYTES + 1 }, { "farm": PackedByteArray([1]), "size": 1.0 },
			{ "farm": PackedByteArray([1, 2, 3]).compress(FileAccess.COMPRESSION_ZSTD), "size": 3 },
			{ "farm": PackedByteArray([1, 2, 3]), "size": 3, "more": 1 }]:
		var problem: String = _play_together(func(host: Node, guest: Node, _host_sync: Node, _guest_sync: Node) -> String:
			host.send_state(bad)
			if not _until(func() -> bool: return _got(guest, "lost")):
				return "%s must end the connection" % [bad]
			if guest.commands.state.credits != 777 or _events.size() != 2:
				return "%s must change nothing and say why, got %s" % [bad, _events]
			return "")
		if problem != "":
			return problem
	return ""


func test_alone_nothing_is_sent() -> String:
	var host: Node = _host()
	var sync: Node = _sync(host)
	var captures: Array = []
	var note: Callable = func() -> void: captures.append(1)
	SaveGame.saving.connect(note)
	sync.tick(1000000)
	SaveGame.saving.disconnect(note)
	_syncs.clear()
	sync.free()
	return _finish("" if captures.is_empty() else "A host with no guests must not gather its farm")
