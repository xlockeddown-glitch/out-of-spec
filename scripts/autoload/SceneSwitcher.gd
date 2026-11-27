extends CanvasLayer
## Farm, tunnels and dome scene swaps with a short fade. Autoloaded as
## `SceneSwitcher`. Tab (action "swap_scene") goes to the dome and back.

signal scene_swapped(path: String)

const FARM_SCENE: String = "res://scenes/main_farm.tscn"
const TITLE_SCENE: String = "res://scenes/title_menu.tscn"
const DOME_SCENE: String = "res://scenes/dome_interior.tscn"
const TUNNELS_SCENE: String = "res://scenes/basalt_tunnels.tscn"
const AQUIFER_SCENE: String = "res://scenes/flooded_aquifer.tscn"
const PHOBOS_SCENE: String = "res://scenes/phobos_hub.tscn"
const DEIMOS_SCENE: String = "res://scenes/deimos_hub.tscn"
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
	GameState.shuttle_trips_changed.connect(reconcile_trip)
	scene_swapped.connect(func(_path: String) -> void: reconcile_trip())


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
	if current != null and current.scene_file_path in [PHOBOS_SCENE, DEIMOS_SCENE]:
		return  # the way home from a moon is the hub's return shuttle
	var on_dome: bool = current != null and current.scene_file_path == DOME_SCENE
	swap_to(exit_path() if on_dome else DOME_SCENE)


## Where the dome's airlock leads. The tunnels only while a rover is there for
## the player: one that was sent home, or let go, leaves the farm out the door.
func exit_path() -> String:
	if is_zone_scene(outside) and (GameState.rover_zone == "" or TunnelRecall.closed(GameClock.elapsed_days)):
		outside = FARM_SCENE
	elif is_zone_scene(outside):
		outside = scene_for_zone(GameState.rover_zone)
	return outside


## True if `path` is the hub scene of a zone the farm's rover goes into (the Lava
## Tubes' tunnels, the Flooded Aquifer): one that shows a depth below it.
static func is_zone_scene(path: String) -> bool:
	return path == TUNNELS_SCENE or path == AQUIFER_SCENE


## The hub scene of the zone the rover is in: the Aquifer's, else the tunnels'.
static func scene_for_zone(zone: String) -> String:
	return AQUIFER_SCENE if zone == AquiferDepth.ZONE else TUNNELS_SCENE


## True if `scene_path` is the dome and a console request is out: nothing leaves the
## dome until it is answered, whatever the way (Tab, the airlock, the phone).
func trip_holds_dome(scene_path: String) -> bool:
	return FastTravel.pending and scene_path == DOME_SCENE


## The dome stays while a console trip waits on the host; the title menu is always reachable
## (STOP HOSTING, quitting), so a stuck wait cannot hold the player in the dome.
func swap_blocked(path: String, scene_path: String) -> bool:
	return path != TITLE_SCENE and trip_holds_dome(scene_path)


## A guest's screen follows the host's word on its trip (the synced shuttle_trips), not
## the answer to its booking, which can be lost: on a trip but still at the farm or the
## dome, it goes to the moon's hub. The other way (a hub with no trip) is the hub's own
## doing, which asks the host first. Returns the scene it set out for, or "".
func reconcile_trip() -> String:
	if not FarmCommands.guest:
		return ""
	var current: Node = get_tree().current_scene
	var to: String = Shuttle.hub_to_join(GameState.shuttle_trips.get(GameState.local_player_id), current.scene_file_path if current != null else "")
	if to != "":
		go_to(to)
	return to


## Like swap_to, but after a swap in progress instead of not at all; nothing if that swap
## (or an earlier go_to) already brought this screen to `path`, so two asks load it once.
func go_to(path: String) -> void:
	while _busy:
		await scene_swapped
	var current: Node = get_tree().current_scene
	if current != null and current.scene_file_path == path:
		return
	swap_to(path)


## True while a swap is in progress (a second one is ignored).
func is_busy() -> bool:
	return _busy


func swap_to(path: String) -> void:
	if _busy:
		return
	var current: Node = get_tree().current_scene
	if swap_blocked(path, current.scene_file_path if current != null else ""):
		return  # a console trip the host may have agreed to has not got its answer: the dome stays
	_busy = true
	if path == TITLE_SCENE:
		FastTravel.pending = false  # leaving the farm: no answer is waited for
	if not is_zone_scene(path):
		# Anywhere but a zone, no screen is below it.
		ZoneDepth.set_local(0, {})
	else:
		# A zone shows the depth the one rover is at.
		ZoneDepth.follow(GameState.rover_depth, GameState.world_seed, GameClock.get_day_index(), AquiferDepth.ZONE if path == AQUIFER_SCENE else ZoneDepth.ZONE)
	_note_outside(path)
	note_arrival(path)
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


## The player is in a zone from the moment the swap into it is committed, not when
## its scene has loaded: nothing the host decides in the fade (a console arrival, a
## rescue) may treat them as still at home. The host sets it directly; a guest tells
## the host now, as the console path does (the report after the swap says it again,
## and a place the host already has is not sent twice). Any other place is reported
## when the swap is done.
func note_arrival(path: String) -> void:
	var at: Array = ZonePresence.for_scene(path)
	if at.is_empty() or at[0] in [ZonePresence.FARM, ZonePresence.DOME]:
		return
	if FarmCommands.guest:
		CoopScenes.report_scene(path)
	else:
		GameState.player_places[GameState.local_player_id] = at


func _note_outside(path: String) -> void:
	if is_zone_scene(path):
		outside = path
	elif path != DOME_SCENE:
		outside = FARM_SCENE
