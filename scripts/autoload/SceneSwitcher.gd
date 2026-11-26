extends CanvasLayer
## Farm, tunnels and dome scene swaps with a short fade. Autoloaded as
## `SceneSwitcher`. Tab (action "swap_scene") goes to the dome and back.

signal scene_swapped(path: String)

const FARM_SCENE: String = "res://scenes/main_farm.tscn"
const TITLE_SCENE: String = "res://scenes/title_menu.tscn"
const DOME_SCENE: String = "res://scenes/dome_interior.tscn"
const TUNNELS_SCENE: String = "res://scenes/basalt_tunnels.tscn"
const FADE_SECONDS: float = 0.1  # each way; ~0.2 s total per the Week 2 board

## Where the dome's airlock leads: the farm or the tunnels, whichever was left.
var outside: String = FARM_SCENE

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
	if current != null and current.scene_file_path == TITLE_SCENE:
		return  # no farm is open yet
	if CoopWalkers.on_foot():
		return  # only the rover goes anywhere
	var on_dome: bool = current != null and current.scene_file_path == DOME_SCENE
	swap_to(exit_path() if on_dome else DOME_SCENE)


## Where the dome's airlock leads. The tunnels only while a rover is there for
## the player: one that was sent home, or let go, leaves the farm out the door.
func exit_path() -> String:
	if outside == TUNNELS_SCENE and GameState.rover_zone == "":
		outside = FARM_SCENE
	return outside


## Like swap_to, but after a swap in progress instead of not at all.
func go_to(path: String) -> void:
	while _busy:
		await scene_swapped
	swap_to(path)


## True while a swap is in progress (a second one is ignored).
func is_busy() -> bool:
	return _busy


func swap_to(path: String) -> void:
	if _busy:
		return
	_busy = true
	if path != TUNNELS_SCENE:
		# Anywhere but the tunnels, no screen is below them.
		ZoneDepth.set_local(0, {})
	else:
		# The tunnels show the depth the one rover is at.
		ZoneDepth.follow(GameState.rover_depth, GameState.world_seed, GameClock.get_day_index())
	_note_outside(path)
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


func _note_outside(path: String) -> void:
	if path == TUNNELS_SCENE:
		outside = TUNNELS_SCENE
	elif path != DOME_SCENE:
		outside = FARM_SCENE
