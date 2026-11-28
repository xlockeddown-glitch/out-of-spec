extends "res://tests/coop_net.gd"
## Co-op sessions over a peer that isn't ENet: CoopSession needs no more of a
## peer than MultiplayerPeer has.

const FakePeer: GDScript = preload("res://tests/fake_peer.gd")


class FakeSession extends "res://scripts/autoload/CoopSession.gd":
	var to: Node
	var id: int = 0

	func _make_host_peer(_listen_port: int, _bind_ip: String) -> Variant:
		return FakePeer.new()

	func _make_guest_peer(_address: String, _host_port: int) -> Variant:
		var peer: MultiplayerPeerExtension = FakePeer.new()
		peer.connect_to(to._peer, id)
		return peer


func _new_session() -> Node:
	return FakeSession.new()


func _guest(host: Node) -> Node:
	var session: Node = _session()
	session.to = host
	session.id = 100 + _sessions.size()
	session.join("a lobby")
	_until(func() -> bool: return _got(session, "joined") or _got(session, "refused"))
	return session


## A program that isn't the game.
func _raw_peer(host: Node, hello: bool) -> MultiplayerPeerExtension:
	var peer: MultiplayerPeerExtension = FakePeer.new()
	peer.connect_to(host._peer, 50 + _raw.size())
	peer.set_target_peer(1)
	_raw.append(peer)
	_until(func() -> bool: return not host._links.is_empty())
	if hello:
		peer.put_packet(_hello())
		_until(func() -> bool: return host.players.size() == 2)
	return peer


func _hello() -> PackedByteArray:
	return var_to_bytes([SessionScript.HELLO, SessionScript.PROTOCOL, "0".repeat(32), {}, ProfileScript.no_record()])


func _dropped(host: Node, peer: MultiplayerPeerExtension) -> bool:
	return _until(func() -> bool: return host._links.is_empty() and peer.status == MultiplayerPeer.CONNECTION_DISCONNECTED) and host.players == ["player_1"]


func test_joining_commands_and_leaving() -> String:
	var saved: float = GameClock.elapsed_days
	var host: Node = _host()
	var first: Node = _guest(host)
	var second: Node = _guest(host)
	_until(func() -> bool: return _got(first, "player_joined", "player_3"))
	if not _got(first, "joined", "player_2") or not _got(second, "joined", "player_3") or first.players != host.players or second.players != host.players:
		return _finish("Got %s" % [_log])
	if not first._peer is MultiplayerPeerExtension or not host._peer is MultiplayerPeerExtension:
		return _finish("This must not run over ENet")
	var got: Array = _request(second, &"calibrate_at_bench", [GameStateScript.HYGROMETER_ID])
	_until(func() -> bool: return not got.is_empty())
	GameClock.elapsed_days = saved
	if got.is_empty() or got[0].get("performed_by", "") != "player_3" or host.commands.state.cal_log.size() != 1:
		return _finish("A command must run as the sender, got %s" % [got])
	if not host.send_state({ "a": 1 }, "player_2") or not _until(func() -> bool: return _got(first, "state_received", { "a": 1 })):
		return _finish("A state must reach its guest")
	second.poll()
	if _got(second, "state_received"):
		return _finish("And no other")
	first.leave()
	if not _until(func() -> bool: return _got(host, "player_left", "player_2") and _got(second, "player_left", "player_2")) or first.commands.guest:
		return _finish("Everyone must hear who left")
	host.leave()
	return _finish("" if _until(func() -> bool: return _got(second, "lost")) and second.commands.guest else "The host leaving must be heard")


func test_refusals() -> String:
	var host: Node = _host()
	for i: int in 3:
		_guest(host)
	var extra: Node = _guest(host)
	if not _got(extra, "refused", SessionScript.REASONS["full"]) or extra.commands.guest or host.players.size() != 4:
		return _finish("A full farm must refuse, got %s" % [_log])
	_finish("")
	host = _host()
	host.protocol += 1
	var guest: Node = _guest(host)
	if not _got(guest, "refused", SessionScript.REASONS["version"]) or guest.commands.guest or host.players.size() != 1:
		return _finish("Another version must be refused, got %s" % [_log])
	return _finish("")


func test_a_cut_connection_is_noticed() -> String:
	var host: Node = _host()
	var guest: Node = _guest(host)
	var got: Array = _request(guest, &"start_lab_grow")
	guest._peer.cut(1)
	if not _until(func() -> bool: return _got(guest, "lost") and _got(host, "player_left", "player_2")):
		return _finish("Both ends must notice, got %s" % [_log])
	if got != ["The host gave no answer."] or not guest.commands.guest or host.players != ["player_1"] or not host._links.is_empty():
		return _finish("The guest must be answered and stay locked, got %s" % [got])
	return _finish("")


func test_a_forger_and_a_silent_connection_are_dropped() -> String:
	var host: Node = _host()
	var peer: MultiplayerPeerExtension = _raw_peer(host, true)
	if host.players.size() != 2:
		return _finish("The stranger never got in")
	peer.put_packet(var_to_bytes([SessionScript.STATE, {}]))
	if not _dropped(host, peer):
		return _finish("A forger must be dropped")
	host.join_timeout_ms = 50
	return _finish("" if _dropped(host, _raw_peer(host, false)) else "A silent connection must be dropped")


func test_sizes() -> String:
	var host: Node = _host()
	var peer: MultiplayerPeerExtension = _raw_peer(host, true)
	# Good but for its size: all the text a command may have.
	var big: Callable = func(letter: int) -> PackedByteArray:
		var arguments: Array = []
		for i: int in SessionScript.MAX_ARGUMENTS:
			arguments.append(String.chr(letter).repeat(SessionScript.MAX_TEXT))
		return var_to_bytes([SessionScript.COMMAND, 1, "none", arguments])
	peer.put_packet(big.call(0xe9))
	# WELCOME, then the answer.
	if not _until(func() -> bool: return peer.get_available_packet_count() == 2):
		return _finish("A big good command must be answered")
	if big.call(0x1f577).size() <= SessionScript.MAX_GUEST_BYTES:
		return _finish("Not too many bytes")
	peer.put_packet(big.call(0x1f577))
	if not _dropped(host, peer):
		return _finish("Too many bytes must end it")
	_finish("")
	host = _host()
	var guest: Node = _guest(host)
	if not host.send_state({ "big": "x".repeat(1024 * 1024) }) or not _until(func() -> bool: return _got(guest, "state_received")):
		return _finish("A big state must arrive")
	if host.send_state({ "huge": "x".repeat(SessionScript.MAX_HOST_BYTES) }):
		return _finish("A state has a size limit")
	host._peer.limit = 1000
	if host.send_state({ "big": "x".repeat(2000) }) or not host.send_state({}):
		return _finish("What the peer won't carry must be said to be unsent")
	host._peer.limit = 16 * 1024 * 1024
	host._put(guest.id, var_to_bytes([SessionScript.STATE, { "huge": "x".repeat(SessionScript.MAX_HOST_BYTES) }]))
	return _finish("" if _until(func() -> bool: return _got(guest, "lost")) else "A guest must leave a host that sends too much")


func test_an_unreliable_hello_is_dropped() -> String:
	var host: Node = _host()
	for mode: MultiplayerPeer.TransferMode in [MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED]:
		var bad: MultiplayerPeerExtension = _raw_peer(host, false)
		bad.transfer_mode = mode
		bad.put_packet(_hello())
		if not _dropped(host, bad):
			return _finish("Mode %d must be dropped" % mode)
	var peer: MultiplayerPeerExtension = _raw_peer(host, true)
	if host.players.size() != 2:
		return _finish("The same, reliably, must be let in")
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	peer.put_packet(var_to_bytes([SessionScript.COMMAND, 1, "add_credits", [1]]))
	return _finish("" if _dropped(host, peer) else "Nor may a command come unreliably")


func test_only_poses_are_sent_unreliably() -> String:
	var host: Node = _host()
	var guest: Node = _guest(host)
	guest._peer.sent_modes.clear()
	host._peer.sent_modes.clear()
	guest.walk([])
	guest.drive("rover_1", [])
	_request(guest, &"start_lab_grow")
	host.tell_walkers({})
	host.tell_rover("rover_1", "", [])
	host.send_state({})
	var late: int = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	var sure: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	if guest._peer.sent_modes != [late, late, sure] or host._peer.sent_modes != [late, late, sure]:
		return _finish("Got %s, %s" % [guest._peer.sent_modes, host._peer.sent_modes])
	return _finish("")


func test_a_short_list_of_ids_is_a_plain_argument() -> String:
	if not SessionScript.plain_arguments(["phobos", ["player_1", "player_2"]]):
		return "A shuttle party's ids must pass"
	if not SessionScript.plain_arguments([[]]):
		return "An empty list is plain (the command refuses it)"
	if SessionScript.plain_arguments([["a", "b", "c", "d", "e"]]):
		return "No more ids than players"
	if SessionScript.plain_arguments([[1]]) or SessionScript.plain_arguments([[["x"]]]) or SessionScript.plain_arguments([[{}]]):
		return "Only texts in a list"
	if SessionScript.plain_arguments([["x".repeat(SessionScript.MAX_TEXT + 1)]]):
		return "Each id is short"
	var typed: Array[String] = ["player_1"]
	if not SessionScript.plain_arguments([typed]):
		return "A list typed to texts is plain"
	var numbers: Array[int] = [1]
	if SessionScript.plain_arguments([numbers]):
		return "A list typed to anything else is not"
	if SessionScript.plain_arguments([{}]) or SessionScript.plain_arguments([NAN]):
		return "The old refusals stand"
	return ""


func test_a_guest_booking_with_ids_is_answered_not_dropped() -> String:
	var host: Node = _host()
	var peer: MultiplayerPeerExtension = _raw_peer(host, true)
	# Both the panel's plain copy and a typed list, as the wire carries them.
	var typed: Array[String] = ["player_2"]
	var plain: Array = []
	plain.assign(typed)
	if plain.is_typed():
		return _finish("The plain copy is untyped")
	peer.put_packet(var_to_bytes([SessionScript.COMMAND, 1, "none", ["phobos", plain]]))
	peer.put_packet(var_to_bytes([SessionScript.COMMAND, 2, "none", ["phobos", typed]]))
	# WELCOME, then the two answers.
	if not _until(func() -> bool: return peer.get_available_packet_count() == 3):
		return _finish("A command with a list of ids must be answered")
	return _finish("" if host._links.size() == 1 else "A list of ids must not end the link")
