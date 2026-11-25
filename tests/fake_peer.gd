extends MultiplayerPeerExtension
## A connection to another of these in the same process, with no network: a host
## (id 1), or a guest of one. Only what CoopSession needs. What is sent arrives
## when the other end polls.

var id: int = 1
var status: MultiplayerPeer.ConnectionStatus = CONNECTION_CONNECTED
## Bytes it will carry at once, as a transport may have a limit.
var limit: int = 16 * 1024 * 1024
## [from, mode, bytes], in order: not here until polled, then here.
var coming: Array = []
var here: Array = []
## The mode of each packet this end sent.
var sent_modes: Array = []
var _ends: Dictionary = {}
var _news: Array = []
var _target: int = 0
var _mode: MultiplayerPeer.TransferMode = TRANSFER_MODE_RELIABLE


func connect_to(host: MultiplayerPeerExtension, own_id: int) -> void:
	id = own_id
	status = CONNECTION_CONNECTING
	_ends[1] = host
	host._ends[id] = self
	_news.append([1, true])
	host._news.append([id, true])


## The connection to `other` is gone, as both ends learn when they poll.
func cut(other: int) -> void:
	if not _ends.has(other):
		return
	var end: MultiplayerPeerExtension = _ends[other]
	_ends.erase(other)
	end._ends.erase(id)
	_news.append([other, false])
	end._news.append([id, false])


func _poll() -> void:
	here.append_array(coming)
	coming.clear()
	while not _news.is_empty():
		var news: Array = _news.pop_front()
		if news[1]:
			status = CONNECTION_CONNECTED
			peer_connected.emit(news[0])
		else:
			if id != 1:
				status = CONNECTION_DISCONNECTED
			peer_disconnected.emit(news[0])


func _put_packet_script(bytes: PackedByteArray) -> Error:
	if bytes.size() > limit:
		return ERR_OUT_OF_MEMORY
	if not _ends.has(_target):
		return ERR_INVALID_PARAMETER
	sent_modes.append(_mode)
	_ends[_target].coming.append([id, _mode, bytes])
	return OK


func _get_packet_script() -> PackedByteArray:
	return here.pop_front()[2]


func _get_available_packet_count() -> int:
	return here.size()


func _get_packet_peer() -> int:
	return here[0][0]


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return here[0][1]


func _set_target_peer(to: int) -> void:
	_target = to


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return status


func _get_unique_id() -> int:
	return id


## The other end is told; this one asked, so it is not.
func _disconnect_peer(other: int, _force: bool) -> void:
	cut(other)
	_news = _news.filter(func(news: Array) -> bool: return news != [other, false])


func _close() -> void:
	for other: int in _ends.keys():
		_disconnect_peer(other, true)
	status = CONNECTION_DISCONNECTED
	coming.clear()
	here.clear()
