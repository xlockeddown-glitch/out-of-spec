extends RefCounted
## For the co-op suites: sessions over connections on this machine, real or (with fake_peer.gd) in memory.

const SessionScript: GDScript = preload("res://scripts/autoload/CoopSession.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const ProfileScript: GDScript = preload("res://scripts/autoload/CoopProfile.gd")
const LOCAL: String = "127.0.0.1"

var _sessions: Array[Node] = []
var _raw: Array[MultiplayerPeer] = []
var _log: Array = []


func _new_session() -> Node:
	return SessionScript.new()


func _session() -> Node:
	var session: Node = _new_session()
	session.commands = CommandsScript.new()
	session.commands.state = GameStateScript.new()
	session.commands.state.build_registry()
	session.profile = ProfileScript.new()
	session.profile.path = ""
	for what: String in ["joined", "refused", "player_joined", "player_left", "state_received"]:
		session.connect(what, _note.bind(session.get_instance_id(), what))
	session.connect("lost", _note.bind(null, session.get_instance_id(), "lost"))
	_sessions.append(session)
	return session


func _note(value: Variant, session_id: int, what: String) -> void:
	_log.append([session_id, what, value])


func _got(session: Node, what: String, value: Variant = null) -> bool:
	for entry: Array in _log:
		if entry[0] == session.get_instance_id() and entry[1] == what and (value == null or entry[2] == value):
			return true
	return false


func _host() -> Node:
	var session: Node = _session()
	session.host(0, LOCAL)
	return session


func _guest(host: Node) -> Node:
	var session: Node = _session()
	session.join(LOCAL, host.port())
	_until(func() -> bool: return _got(session, "joined") or _got(session, "refused"))
	return session


## A program that isn't the game.
func _stranger(host: Node, hello: bool) -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(LOCAL, host.port())
	_raw.append(peer)
	_until(func() -> bool: return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and not host._links.is_empty())
	if hello:
		peer.put_packet(var_to_bytes([SessionScript.HELLO, SessionScript.PROTOCOL, "0".repeat(32), {}, ProfileScript.no_record()]))
		_until(func() -> bool: return host.players.size() == 2)
	return peer


func _until(done: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		for session: Node in _sessions:
			session.poll()
		for peer: MultiplayerPeer in _raw:
			if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
				peer.poll()
		if done.call():
			return true
		OS.delay_msec(1)
	return false


## Puts the request's answer in the array returned, when it comes.
func _request(session: Node, action: StringName, arguments: Array = []) -> Array:
	var got: Array = []
	var ask: Callable = func() -> void: got.append(await session.commands.request(action, arguments))
	ask.call()
	return got


func _finish(problem: String) -> String:
	for peer: MultiplayerPeer in _raw:
		peer.close()
	for session: Node in _sessions:
		session.leave()
		session.profile.free()
		session.commands.state.free()
		session.commands.free()
		session.free()
	_sessions.clear()
	_raw.clear()
	_log.clear()
	return problem
