extends Node
## Opens the farm when a guest's copy of it comes, and the title menu when the
## guest is out. Autoloaded as `CoopScenes`.

const ENDED: String = "The host closed the farm or the connection was lost."

var _note: String = ""
## On the way to the title menu.
var _leaving: bool = false


## A guest's report of its place is tried again this many times when the host
## gave no answer, 0.3 s apart [PLACEHOLDER].
const REPORT_TRIES: int = 5
const REPORT_WAIT_S: float = 0.3

## Only tests set others.
var session: Node
var farm: Node
## Only tests set these two: where this screen's scene is, and what opens the farm.
var scene_at: Callable = Callable()
var go_to_farm: Callable = Callable()


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
	# Guest: the host's 02:00 recall of this player (zones doc section 6.1).
	session.recalled.connect(_on_recalled)


## This screen's player is in the place `path` is (nothing is said for a menu).
## On the host it is set at once; a guest tells the host, which checks it.
func report_scene(path: String) -> void:
	await ZonePresence.report_scene(path, get_tree(), REPORT_TRIES, REPORT_WAIT_S)


## Guest: the host says the recall warns this player, or carries them out. The words
## and the cost are the host's; this screen only shows the warning and leaves the zone
## for the farm, where the host already has them in bed (the clock says so).
func _on_recalled(step: String) -> void:
	if step == TunnelRecall.WARN:
		if ZonePresence.in_zone(_scene_path()):
			farm.phone_message.emit(TunnelRecall.text("warn_text"))
	elif step == TunnelRecall.RESCUE:
		_carry_out_here()


## A swap in progress may be on its way into the zone, so it is waited for first.
func _carry_out_here() -> void:
	while not go_to_farm.is_valid() and SceneSwitcher.is_busy():
		await SceneSwitcher.scene_swapped
	if ZonePresence.in_zone(_scene_path()):
		if go_to_farm.is_valid():
			go_to_farm.call()
		else:
			SceneSwitcher.go_to(SceneSwitcher.FARM_SCENE)


func _scene_path() -> String:
	if scene_at.is_valid():
		return str(scene_at.call())
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	return scene.scene_file_path if scene != null else ""


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
