extends Node
## Keeps each guest's copy of the farm up to date. Autoloaded as `CoopSync`.
##
## The host sends a guest the whole farm when it joins, after each change it asks
## for and then each second, and the clock in between. A guest shows what comes.

## Guest: the whole farm is here. Its scene must open now.
signal farm_ready
## Guest: the host's farm can't be shown, so the connection was ended. `text` is
## for the player. CoopSession.lost follows.
signal stopped(text: String)
## Host: the farm is too big to send, so guests are told and leave.
signal too_big

## The farm is sent this often, and the clock this often [PLACEHOLDER].
const FARM_MS: int = 1000
const CLOCK_MS: int = 300
## A big farm is sent less often: this many bytes a second to each guest, apart
## from the farm each guest's command brings [PLACEHOLDER].
const BYTES_PER_SECOND: int = 64 * 1024

## Only tests set others.
var session: Node
var farm: Node

## Guest: the whole farm has come.
var _has_farm: bool = false
var _was_too_big: bool = false
var _farm_at: int = 0
var _clock_at: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start(CoopSession, GameState)


func start(with_session: Node, with_farm: Node) -> void:
	session = with_session
	farm = with_farm
	session.player_joined.connect(_on_player_joined)
	session.command_done.connect(send_farm)
	session.joined.connect(_on_joined.unbind(1))
	session.state_received.connect(_on_state_received)


func _process(_delta: float) -> void:
	tick(Time.get_ticks_msec())


## Host: sends what is due.
func tick(now: int) -> void:
	if not session.is_hosting():
		_was_too_big = false
		return
	if session.players.size() < 2:
		return
	if now >= _farm_at:
		@warning_ignore("integer_division")
		_farm_at = now + maxi(FARM_MS, send_farm() * 1000 / BYTES_PER_SECOND)
		_clock_at = now + CLOCK_MS
	elif now >= _clock_at:
		_clock_at = now + CLOCK_MS
		session.send_state({ "clock": FarmSync.clock() })


## Host: sends the farm to one guest or ("") to all. Returns its size as sent, or
## 0. Not from inside a GameState or GameClock signal (see FarmSync.capture).
func send_farm(player_id: String = "") -> int:
	if not session.is_hosting():
		return 0
	var bytes: PackedByteArray = FarmSync.capture(farm)
	if bytes.is_empty():
		session.send_state({ "too_big": true }, player_id)
		if not _was_too_big:
			_was_too_big = true
			too_big.emit()
		return 0
	_was_too_big = false
	var packed: PackedByteArray = bytes.compress(FileAccess.COMPRESSION_ZSTD)
	return packed.size() if session.send_state({ "farm": packed, "size": bytes.size() }, player_id) else 0


## Host: the farm was too big to send when it was last tried.
func is_too_big() -> bool:
	return _was_too_big


## Emitted on guests too, who send nothing.
func _on_player_joined(player_id: String) -> void:
	send_farm(player_id)


func _on_joined() -> void:
	_has_farm = false


## Guest: true once the host's whole farm has come. Until then the farm here is
## still the guest's own.
func has_farm() -> bool:
	return _has_farm


func _on_state_received(data: Dictionary) -> void:
	var problem: String = _take(data)
	if problem != "":
		stopped.emit(problem)
		session.hang_up()


func _take(data: Dictionary) -> String:
	if data.size() == 1 and data.get("clock") is Dictionary:
		# Before the farm there is nothing to show the time of.
		return FarmSync.follow_clock(data["clock"], farm) if _has_farm else ""
	if data.size() == 1 and data.get("too_big") is bool:
		return "The host's farm is too big to share."
	if data.size() != 2 or not data.get("farm") is PackedByteArray or not data.get("size") is int:
		return "The host sent something this game can't read."
	var size: int = data["size"]
	if size <= 0 or (data["farm"] as PackedByteArray).is_empty() or size > FarmSync.MAX_BYTES:
		return "The host's farm has a bad size (%d bytes)." % size
	# Never more than `size`, whatever the bytes would unpack to.
	var bytes: PackedByteArray = (data["farm"] as PackedByteArray).decompress(size, FileAccess.COMPRESSION_ZSTD)
	if _has_farm:
		return FarmSync.update(bytes, farm)
	var problem: String = FarmSync.join(bytes, farm)
	if problem == "":
		_has_farm = true
		farm_ready.emit()
	return problem
