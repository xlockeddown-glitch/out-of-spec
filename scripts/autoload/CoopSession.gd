extends Node
## Co-op over the internet: one player hosts, friends join by IP address.
## Autoloaded as `CoopSession`. Nothing is opened until host() or join().
##
## It sends its own messages, [kind, ...] as plain data, straight through the
## peer. There are no RPCs, so nothing in the game can be called from outside
## except FarmCommands' actions. Nobody at the other end is trusted.

## Host and guests: someone else is in, or out.
signal player_joined(player_id: String)
signal player_left(player_id: String)
## Guest: the host let us in as `player_id`.
signal joined(player_id: String)
## Guest: we never got in.
signal refused(reason: String)
## Guest: we were in and the connection ended. The copy of the farm stays locked
## until leave().
signal lost
## Guest: what the host gave send_state(). Plain data, but unchecked otherwise.
signal state_received(data: Dictionary)

## Raise it whenever two versions could disagree about the farm or the messages.
const PROTOCOL: int = 1
const DEFAULT_PORT: int = 24711
const MAX_PLAYERS: int = 4

enum { HELLO, COMMAND, WELCOME, REFUSED, JOINED, LEFT, ANSWER, STATE }

const REASONS: Dictionary = {
	"full": "The farm is full.",
	"version": "The host has another version of the game.",
}
const NO_HOST: String = "The host did not answer."

## Connections beyond the players, so a full farm can still say so.
const SPARE_CONNECTIONS: int = 4
const MAX_GUEST_BYTES: int = 2048
const MAX_HOST_BYTES: int = 4 * 1024 * 1024
const MAX_ARGUMENTS: int = 8
const MAX_TEXT: int = 64
const MAX_DEPTH: int = 32
## What a list may say it holds. TYPE_NIL is a list that doesn't say.
const LIST_TYPES: Array[int] = [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR3I,
	TYPE_DICTIONARY, TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY]
## A guest's messages: this many at once, then this many each second.
const BURST: int = 20
const RATE: float = 10.0

var players: Array[String] = []
var protocol: int = PROTOCOL
## A connection gets this long to be let in, and a command to be answered.
var join_timeout_ms: int = 10000
var answer_timeout_ms: int = 10000
## Only tests set another.
var commands: Node

var _peer: ENetMultiplayerPeer
var _hosting: bool = false
## Guest: let in, and not cut off since.
var _accepted: bool = false
var _hello_sent: bool = false
var _join_by: int = 0
## Guest: who this player was before joining, until leave().
var _own_id: String = ""
## Host: peer -> { player ("" until let in), join_by, tokens, at, gone (hung up) }.
var _links: Dictionary = {}
## Host: [peer, came or went], in order, noted while polling.
var _events: Array = []
## Guest: request number -> Ask.
var _asks: Dictionary = {}
var _last_number: int = 0


class Ask extends RefCounted:
	signal answered(answer: Variant)
	var answer_by: int = 0


func _ready() -> void:
	# A paused game must still answer.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _process(_delta: float) -> void:
	poll()


func _exit_tree() -> void:
	leave()


## Opens the farm to guests. Returns "" or why not.
func host(listen_port: int = DEFAULT_PORT, bind_ip: String = "*") -> String:
	var problem: String = _start_problem()
	if problem != "":
		return problem
	# Godot would report a bad address, then listen on all of them.
	if bind_ip != "*" and not bind_ip.is_valid_ip_address():
		return "'%s' is not an address." % bind_ip
	if listen_port < 0 or listen_port > 65535:
		return "%d is not a port." % listen_port
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_ip)
	if peer.create_server(listen_port, MAX_PLAYERS - 1 + SPARE_CONNECTIONS) != OK:
		return "Could not open port %d." % listen_port
	peer.peer_connected.connect(func(id: int) -> void: _events.append([id, true]))
	peer.peer_disconnected.connect(_peer_gone)
	_open(peer)
	_hosting = true
	players = [_local_id()]
	return ""


## Asks to join the host at `address`. Returns "" or why not; then joined or
## refused follows. From the title menu: a guest has no farm of its own open,
## so nothing autosaves the host's farm over it.
func join(address: String, host_port: int = DEFAULT_PORT) -> String:
	var problem: String = _start_problem()
	if problem != "":
		return problem
	if SaveGame.farm_open:
		return "Close your own farm first."
	if not address.is_valid_ip_address():
		return "That is not an IP address."
	if host_port < 1 or host_port > 65535:
		return "That is not a port."
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, host_port) != OK:
		return "Could not connect."
	_open(peer)
	_hello_sent = false
	_join_by = Time.get_ticks_msec() + join_timeout_ms
	return ""


## Ends hosting, joining or being a guest. A guest's copy of the farm is then
## unlocked, so whoever calls this must leave that farm too.
func leave() -> void:
	_close()
	if _own_id != "":
		_farm_commands().guest = false
		_farm_commands()._farm().local_player_id = _own_id
		_own_id = ""


func is_hosting() -> bool:
	return _hosting


## The port hosted on, or 0.
func port() -> int:
	return _peer.host.get_local_port() if _hosting else 0


## Host: sends `data`, for a later syncing layer, to one guest or ("") to all.
## It arrives in order with answers. False if it can't be sent.
func send_state(data: Dictionary, player_id: String = "") -> bool:
	if not _hosting or not is_plain([STATE, data]):
		return false
	var message: PackedByteArray = var_to_bytes([STATE, data])
	if message.size() > MAX_HOST_BYTES:
		return false
	var sent: bool = false
	for id: int in _links:
		var to: String = _links[id]["player"]
		if to != "" and not _links[id].get("gone", false) and player_id in ["", to]:
			sent = _put(id, message) or sent
	return sent


## Only these kinds of data: nothing that is, holds or calls an object.
static func is_plain(value: Variant, depth: int = 0) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_VECTOR3I, TYPE_PACKED_BYTE_ARRAY:
			return true
		TYPE_STRING, TYPE_STRING_NAME:
			# Godot drops a byte order mark when it reads text.
			return not str(value).begins_with("﻿")
		TYPE_ARRAY:
			if depth >= MAX_DEPTH or not value.get_typed_builtin() in LIST_TYPES:
				return false
			for item: Variant in value:
				if not is_plain(item, depth + 1):
					return false
		TYPE_DICTIONARY:
			if depth >= MAX_DEPTH or not value.get_typed_key_builtin() in LIST_TYPES or not value.get_typed_value_builtin() in LIST_TYPES:
				return false
			for key: Variant in value:
				if not is_plain(key, depth + 1) or not is_plain(value[key], depth + 1):
					return false
		_:
			return false
	return true


## Reads and acts on what has come in. Each frame while open.
func poll() -> void:
	if _peer == null:
		return
	_peer.poll()
	if _hosting:
		_poll_host()
	else:
		_poll_guest()


func _peer_gone(id: int) -> void:
	_events.append([id, false])
	if _links.has(id):
		_links[id]["gone"] = true


func _poll_host() -> void:
	var now: int = Time.get_ticks_msec()
	while not _events.is_empty():
		var event: Array = _events.pop_front()
		var id: int = event[0]
		_drop(id, true)
		if _peer == null:
			return
		if event[1]:
			# The other end picks its peer id. One Godot wouldn't pick is never let in.
			_links[id] = { "player": "", "join_by": now + (join_timeout_ms if id > 1 else -1), "tokens": float(BURST), "at": now }
	for id: int in _links.keys():
		if _links.has(id) and _links[id]["player"] == "" and now > _links[id]["join_by"]:
			_drop(id)
	while _peer != null and _peer.get_available_packet_count() > 0:
		var from: int = _peer.get_packet_peer()
		var packet: PackedByteArray = _peer.get_packet()
		if _links.has(from) and not _host_read(from, packet, now):
			_drop(from)


## False if the peer must go.
func _host_read(from: int, packet: PackedByteArray, now: int) -> bool:
	var link: Dictionary = _links[from]
	link["tokens"] = minf(BURST, link["tokens"] + (now - link["at"]) * RATE / 1000.0) - 1.0
	link["at"] = now
	if link["tokens"] < 0.0 or packet.size() > MAX_GUEST_BYTES:
		return false
	var message: Array = _unpack(packet)
	if link["player"] == "":
		if not _is_shape(message, [HELLO, TYPE_INT]):
			return false
		_let_in(from, message[1])
		return true
	if not _is_shape(message, [COMMAND, TYPE_INT, TYPE_STRING, TYPE_ARRAY]):
		return false
	var action: String = message[2]
	var arguments: Array = message[3]
	if action.length() > MAX_TEXT or arguments.size() > MAX_ARGUMENTS or arguments.is_typed():
		return false
	for argument: Variant in arguments:
		if not typeof(argument) in [TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR3I]:
			return false
		if (argument is String or argument is StringName) and str(argument).length() > MAX_TEXT:
			return false
	var answer: Variant = _farm_commands().execute(link["player"], StringName(action), arguments)
	# What the command set off may have ended the session.
	if _links.has(from):
		_send(from, [ANSWER, message[1], answer if is_plain([answer]) else null])
	return true


func _let_in(id: int, version: int) -> void:
	var reason: String = ""
	if version != protocol:
		reason = "version"
	elif players.size() >= MAX_PLAYERS:
		reason = "full"
	if reason != "":
		# The guest hangs up, or is dropped when its time is up.
		_send(id, [REFUSED, reason])
		return
	var player_id: String = ""
	var farm: Node = _farm_commands()._farm()
	while player_id == "" or player_id in players:
		player_id = "player_%d" % farm.next_player_number
		farm.next_player_number += 1
	_send(id, [WELCOME, player_id, players])
	_tell_guests([JOINED, player_id])
	_links[id]["player"] = player_id
	players.append(player_id)
	player_joined.emit(player_id)


## Host: forgets a peer, and hangs up unless it already has.
func _drop(id: int, gone: bool = false) -> void:
	if not _links.has(id):
		return
	var player_id: String = _links[id]["player"]
	_links.erase(id)
	if not gone:
		_peer.disconnect_peer(id, true)
	if player_id != "":
		players.erase(player_id)
		_tell_guests([LEFT, player_id])
		player_left.emit(player_id)


func _tell_guests(message: Array) -> void:
	for id: int in _links:
		if _links[id]["player"] != "" and not _links[id].get("gone", false):
			_send(id, message)


func _poll_guest() -> void:
	var now: int = Time.get_ticks_msec()
	# Anything read now came after we stopped waiting.
	if not _accepted and now > _join_by:
		_end(NO_HOST)
		return
	_expire(now)
	while _peer != null and _peer.get_available_packet_count() > 0:
		if not _guest_read(_peer.get_packet()):
			_end(NO_HOST)
	if _peer == null:
		return
	var status: MultiplayerPeer.ConnectionStatus = _peer.get_connection_status()
	if status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_end(NO_HOST)
		return
	if not _hello_sent and status == MultiplayerPeer.CONNECTION_CONNECTED:
		_hello_sent = true
		_send(1, [HELLO, protocol])


func _expire(now: int) -> void:
	for number: int in _asks.keys():
		if _asks.has(number) and now > _asks[number].answer_by:
			_answer(number, null)


## False if the host makes no sense.
func _guest_read(packet: PackedByteArray) -> bool:
	if packet.size() > MAX_HOST_BYTES:
		return false
	var message: Array = _unpack(packet)
	if not _accepted:
		if _is_shape(message, [REFUSED, TYPE_STRING]):
			_end(REASONS.get(message[1], NO_HOST))
			return true
		if not _is_shape(message, [WELCOME, TYPE_STRING, TYPE_ARRAY]) or not _is_player_id(message[1]):
			return false
		var others: Array = message[2]
		if others.size() >= MAX_PLAYERS or not others.all(_is_player_id) or message[1] in others:
			return false
		_accepted = true
		players.assign(others)
		players.append(message[1])
		_own_id = _local_id()
		_farm_commands()._farm().local_player_id = message[1]
		_farm_commands().remote = _ask
		_farm_commands().guest = true
		joined.emit(message[1])
		return true
	if _is_shape(message, [ANSWER, TYPE_INT, TYPE_MAX]):
		_answer(message[1], message[2])
	elif _is_shape(message, [STATE, TYPE_DICTIONARY]):
		state_received.emit(message[1])
	elif _is_shape(message, [JOINED, TYPE_STRING]) and _is_player_id(message[1]) and players.size() < MAX_PLAYERS and not message[1] in players:
		players.append(message[1])
		player_joined.emit(message[1])
	elif _is_shape(message, [LEFT, TYPE_STRING]) and message[1] in players and message[1] != _local_id():
		players.erase(message[1])
		player_left.emit(message[1])
	else:
		return false
	return true


## FarmCommands' way to the host. Null when no answer comes.
func _ask(action: StringName, arguments: Array) -> Variant:
	_last_number += 1
	if not _send(1, [COMMAND, _last_number, String(action), arguments]):
		return null
	var ask := Ask.new()
	ask.answer_by = Time.get_ticks_msec() + answer_timeout_ms
	_asks[_last_number] = ask
	return await ask.answered


## A number nobody waits for any more is ignored.
func _answer(number: int, answer: Variant) -> void:
	if _asks.has(number):
		var ask: Ask = _asks[number]
		_asks.erase(number)
		ask.answered.emit(answer)


## Guest: it is over, and the host or the connection ended it.
func _end(reason: String) -> void:
	var was_in: bool = _accepted
	_close()
	if was_in:
		lost.emit()
	else:
		refused.emit(reason)


func _start_problem() -> String:
	return "Leave the co-op farm first." if _peer != null or _own_id != "" else ""


func _open(peer: ENetMultiplayerPeer) -> void:
	_peer = peer
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	set_process(true)


## Hangs up. A guest stays a guest, now with no way to the host.
func _close() -> void:
	set_process(false)
	if _peer != null:
		_peer.close()
		_peer = null
	_hosting = false
	_accepted = false
	_links.clear()
	_events.clear()
	players.clear()
	if _own_id != "":
		_farm_commands().remote = Callable()
	for number: int in _asks.keys():
		_answer(number, null)


func _send(to: int, message: Array) -> bool:
	return _put(to, var_to_bytes(message))


func _put(to: int, bytes: PackedByteArray) -> bool:
	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	_peer.set_target_peer(to)
	return _peer.put_packet(bytes) == OK


func _unpack(packet: PackedByteArray) -> Array:
	# Godot reports an error for bytes it can't read, so it gets only good ones.
	if _end_of(packet, 0) != packet.size():
		return []
	var message: Variant = bytes_to_var(packet)
	return message if message is Array and is_plain(message) else []


## Where the value at `at` ends, or -1 if it isn't a whole value is_plain() allows,
## as var_to_bytes() writes it. A header is a type and its flags; text and bytes
## have a length and fill whole words; a list has a count.
static func _end_of(bytes: PackedByteArray, at: int, depth: int = 0) -> int:
	if at < 0 or at + 4 > bytes.size():
		return -1
	var header: int = bytes.decode_u32(at)
	var type: int = header & 0xff
	var flags: int = header >> 16
	at += 4
	if header & 0xff00 != 0 or (flags != 0 and not type in [TYPE_INT, TYPE_FLOAT, TYPE_ARRAY, TYPE_DICTIONARY]):
		return -1
	match type:
		TYPE_NIL:
			return at
		TYPE_BOOL:
			return at + 4 if at + 4 <= bytes.size() and bytes.decode_u32(at) <= 1 else -1
		TYPE_INT, TYPE_FLOAT:
			at += 8 if flags == 1 else 4
			return at if flags <= 1 and at <= bytes.size() else -1
		TYPE_VECTOR3I:
			return at + 12 if at + 12 <= bytes.size() else -1
		TYPE_STRING, TYPE_STRING_NAME, TYPE_PACKED_BYTE_ARRAY:
			if at + 4 > bytes.size():
				return -1
			var length: int = bytes.decode_u32(at)
			at += 4
			var end: int = at + length + (4 - length % 4) % 4
			if end > bytes.size() or (type != TYPE_PACKED_BYTE_ARRAY and not _is_text(bytes, at, at + length)):
				return -1
			return end
		TYPE_ARRAY, TYPE_DICTIONARY:
			return _end_of_list(bytes, at, type, flags, depth)
	return -1


## Two bits of `flags` for a list's items, or for a dictionary's keys and then its
## values: 1 is a built-in type, named next and kept to; a script or class isn't
## allowed.
static func _end_of_list(bytes: PackedByteArray, at: int, type: int, flags: int, depth: int) -> int:
	var kinds: Array = [flags & 3] if type == TYPE_ARRAY else [flags & 3, flags >> 2 & 3]
	if depth >= MAX_DEPTH or flags >> (2 * kinds.size()) != 0:
		return -1
	var types: PackedInt32Array = []
	for kind: int in kinds:
		if kind > 1 or (kind == 1 and at + 4 > bytes.size()):
			return -1
		types.append(bytes.decode_u32(at) if kind == 1 else TYPE_NIL)
		at += 4 * kind
		if kind == 1 and (types[-1] == TYPE_NIL or not types[-1] in LIST_TYPES):
			return -1
	if at + 4 > bytes.size() or bytes.decode_u32(at) > bytes.size():
		return -1
	var count: int = bytes.decode_u32(at) * types.size()
	at += 4
	for i: int in count:
		var want: int = types[i % types.size()]
		if at + 4 > bytes.size() or (want != TYPE_NIL and bytes.decode_u32(at) & 0xff != want):
			return -1
		at = _end_of(bytes, at, depth + 1)
		if at < 0:
			return -1
	return at


## UTF-8, with no NUL and no byte order mark.
static func _is_text(bytes: PackedByteArray, at: int, end: int) -> bool:
	if end - at >= 3 and bytes[at] == 0xef and bytes[at + 1] == 0xbb and bytes[at + 2] == 0xbf:
		return false
	while at < end:
		var lead: int = bytes[at]
		var more: int = 0 if lead < 0x80 else 1 if lead >= 0xc2 and lead < 0xe0 else 2 if lead >= 0xe0 and lead < 0xf0 else 3 if lead >= 0xf0 and lead < 0xf5 else -1
		if lead == 0 or more < 0 or at + more >= end:
			return false
		var code: int = lead if more == 0 else lead & (0x3f >> more)
		for i: int in range(1, more + 1):
			if bytes[at + i] & 0xc0 != 0x80:
				return false
			code = code << 6 | bytes[at + i] & 0x3f
		# Too long a spelling, a half of a pair, or past the last character.
		if code < [0, 0x80, 0x800, 0x10000][more] or (code >= 0xd800 and code < 0xe000) or code > 0x10ffff:
			return false
		at += more + 1
	return true


## `shape` is the kind, then the type of each part (TYPE_MAX: any).
func _is_shape(message: Array, shape: Array) -> bool:
	if message.size() != shape.size() or typeof(message[0]) != TYPE_INT or message[0] != shape[0]:
		return false
	for i: int in range(1, shape.size()):
		if shape[i] != TYPE_MAX and typeof(message[i]) != shape[i]:
			return false
	return true


func _is_player_id(value: Variant) -> bool:
	return value is String and value != "" and value.length() <= MAX_TEXT


func _local_id() -> String:
	return _farm_commands()._farm().local_player_id


func _farm_commands() -> Node:
	return commands if commands != null else FarmCommands
