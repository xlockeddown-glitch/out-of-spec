extends CanvasLayer
## Farm <-> dome scene swaps with a short fade. Autoloaded as `SceneSwitcher`.
## Tab (action "swap_scene") toggles from anywhere.

signal scene_swapped(path: String)

const FARM_SCENE: String = "res://scenes/main_farm.tscn"
const DOME_SCENE: String = "res://scenes/dome_interior.tscn"
const FADE_SECONDS: float = 0.1  # each way; ~0.2 s total per the Week 2 board

var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"swap_scene"):
		get_viewport().set_input_as_handled()
		toggle_farm_dome()


func toggle_farm_dome() -> void:
	var current: Node = get_tree().current_scene
	var on_dome: bool = current != null and current.scene_file_path == DOME_SCENE
	swap_to(FARM_SCENE if on_dome else DOME_SCENE)


func swap_to(path: String) -> void:
	if _busy:
		return
	_busy = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
	await tween.finished
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneSwitcher: could not load %s (error %d)." % [path, err])
	# change_scene_to_file swaps at the end of the frame; wait for it.
	await get_tree().process_frame
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
	await tween.finished
	_busy = false
	scene_swapped.emit(path)
