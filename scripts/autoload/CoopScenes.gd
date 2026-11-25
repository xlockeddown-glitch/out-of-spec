extends Node
## Opens the farm when a guest's copy of it comes, and the title menu when the
## guest is out. Autoloaded as `CoopScenes`.

const ENDED: String = "The host closed the farm or the connection was lost."

var _note: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	CoopSync.farm_ready.connect(func() -> void: SceneSwitcher.go_to(SceneSwitcher.FARM_SCENE))
	CoopSync.stopped.connect(func(text: String) -> void: _note = text)
	CoopSession.lost.connect(_on_lost)


func _on_lost() -> void:
	if _note == "":
		_note = ENDED
	leave_farm()


## Guest: out of the host's farm. The title menu ends the session, so the copy
## stays locked until its scene is gone.
func leave_farm() -> void:
	SceneSwitcher.go_to(SceneSwitcher.TITLE_SCENE)


## Why the last farm was left, once; "" when the player chose to.
func take_note() -> String:
	var note: String = _note
	_note = ""
	return note
