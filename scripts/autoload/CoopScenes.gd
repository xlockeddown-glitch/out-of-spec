extends Node
## Opens the farm when a guest's copy of it comes, and the title menu when the
## guest is out. Autoloaded as `CoopScenes`.

const ENDED: String = "The host closed the farm or the connection was lost."

var _note: String = ""
## On the way to the title menu.
var _leaving: bool = false


## A guest's report of its place is tried this many times while an earlier
## command is still waiting for its answer [PLACEHOLDER].
const REPORT_TRIES: int = 5
const REPORT_WAIT_S: float = 0.3

## Only tests set others.
var session: Node
var farm: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	CoopSync.farm_ready.connect(func() -> void: SceneSwitcher.go_to(SceneSwitcher.FARM_SCENE))
	CoopSync.stopped.connect(func(text: String) -> void: _note = text)
	CoopSession.lost.connect(_on_lost)
	SceneSwitcher.scene_swapped.connect(report_scene)
	start(CoopSession, GameState)


func start(with_session: Node, with_farm: Node) -> void:
	session = with_session
	farm = with_farm
	# The host forgets a player who leaves or drops (zones doc section 12.3).
	session.player_left.connect(farm.forget_place)


## This screen's player is in the place `path` is (nothing is said for a menu).
## On the host it is set at once; a guest tells the host, which checks it.
func report_scene(path: String) -> void:
	await ZonePresence.report_scene(path, get_tree(), REPORT_TRIES, REPORT_WAIT_S)


func _on_lost() -> void:
	if _note == "" and not _leaving:
		_note = ENDED
	leave_farm()


## Guest: out of the host's farm. The title menu ends the session, so the copy
## stays locked until its scene is gone.
func leave_farm() -> void:
	if _leaving:
		return
	_leaving = true
	SceneSwitcher.go_to(SceneSwitcher.TITLE_SCENE)


## Why the last farm was left, once; "" when the player chose to.
func take_note() -> String:
	var note: String = _note
	_note = ""
	_leaving = false
	return note
