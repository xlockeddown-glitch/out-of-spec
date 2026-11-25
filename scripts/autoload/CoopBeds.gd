extends Node
## Who is in bed, with friends in. The day ends when everyone is in bed, and
## waits just short of 06:00 for whoever is still up. Alone there is no bed: the
## day goes over at 06:00 on its own. Autoloaded as `CoopBeds`.

## On a guest, as the host last said.
var in_bed: Array[String] = []
## Only tests set others.
var session: Node
var clock: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start(CoopSession, GameClock)


func start(with_session: Node, with_clock: Node) -> void:
	session = with_session
	clock = with_clock
	session.player_joined.connect(_look.unbind(1))
	session.player_left.connect(_look.unbind(1))


func _process(_delta: float) -> void:
	_look()


## There is someone to wait for.
func together() -> bool:
	return session.players.size() > 1


## Host: "" or why not.
func go_to_bed(player_id: String) -> String:
	if not session.is_hosting() or not together() or not player_id in session.players:
		return "There is no one to wait for."
	if not player_id in in_bed:
		in_bed.append(player_id)
	_look()
	return ""


func get_up(player_id: String) -> void:
	in_bed.erase(player_id)


## Who the day waits for.
func still_up() -> Array[String]:
	var up: Array[String] = []
	for player_id: String in session.players:
		if not player_id in in_bed:
			up.append(player_id)
	return up


func _look() -> void:
	if not together():
		in_bed.clear()
	clock.morning_waits = session.is_hosting() and together()
	if not clock.morning_waits:
		return
	for player_id: String in in_bed.duplicate():
		if not player_id in session.players:
			in_bed.erase(player_id)
	if still_up().is_empty():
		in_bed.clear()
		clock.morning_waits = false
		clock.skip_to_next_morning()
		clock.morning_waits = true
