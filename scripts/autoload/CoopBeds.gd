extends Node
## Who is in bed, with friends in. The day ends when everyone is in bed, and
## waits just short of 06:00 for whoever is still up. Alone, going to bed ends
## the day at once (and the day also goes over at 06:00 on its own). Autoloaded
## as `CoopBeds`.

## On a guest, as the host last said.
var in_bed: Array[String] = []
## A repeat solo request inside this many real milliseconds is ignored, so a
## double click does not sleep two days.
const SOLO_COOLDOWN_MS: int = 1000
var cooldown_ms: int = SOLO_COOLDOWN_MS
var _last_solo_msec: int = -1000000
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


## Someone has connected to the host and is still joining.
func joining() -> bool:
	return session.someone_joining()


## Why the local player can't go to bed where they are, or "".
func here_refusal() -> String:
	if not FarmCommands.guest and not SaveGame.farm_open:
		return "No farm is open."
	if clock.paused:
		return "The clock is paused."
	var scene: Node = session.get_tree().current_scene if session.is_inside_tree() else null
	return scene_refusal(scene.scene_file_path if scene != null else "")


## Beds are on the farm, and nowhere else (no scene counts as elsewhere).
static func scene_refusal(scene_path: String) -> String:
	if scene_path != SceneSwitcher.FARM_SCENE:
		return "Go to bed from the farm, not the dome, the tunnels or a menu."
	return ""


## Host or alone: "" or why not. Alone, the day ends at once; with friends in,
## it ends when the last one is in bed.
func go_to_bed(player_id: String) -> String:
	if session.is_guest():
		return "Only the host's farm can end the day."
	if not together():
		if not session.players.is_empty() and not player_id in session.players:
			return "That player is not on this farm."
		if joining():
			return "Someone is joining. Try again in a moment."
		if Time.get_ticks_msec() - _last_solo_msec < cooldown_ms:
			return "You already went to bed."
		_sleep_alone()
		return ""
	if not session.is_hosting() or not player_id in session.players:
		return "That player is not on this farm."
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


func _sleep_alone() -> void:
	_last_solo_msec = Time.get_ticks_msec()
	in_bed.clear()
	clock.morning_waits = false
	clock.skip_to_next_morning()


func _look() -> void:
	if not together():
		# The last friend left: if all who remain are in bed, the day ends.
		var all_in: bool = session.is_hosting() and not in_bed.is_empty() and still_up().is_empty()
		in_bed.clear()
		if all_in:
			_sleep_alone()
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
