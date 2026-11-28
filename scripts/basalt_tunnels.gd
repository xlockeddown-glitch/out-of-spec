extends Node
## Composition root for the basalt tunnels. Wires rover / GameState <-> HUD,
## like the farm's. Holds no gameplay rules of its own.

## Phone-log lines replayed into the HUD when the tunnels load.
const LOG_REPLAY_LINES: int = 6
## With the rover in the other scene, these only say where it is.
const ROVER_KEYS: Array[StringName] = [
	&"rover_forward", &"rover_reverse", &"rover_till", &"rover_zero_steering", &"rover_dig", &"rover_fill", &"rover_lights"]

var _had_los: bool = true
var _last_band: int = DriftingSensor.Band.IN_BAND
## This player asked to move the rover; the host said yes.
var _moving: bool = false
var _move_granted: bool = false
@onready var _cup := CatchCupUI.new()
## The cup can reach the Cobalt Sentinel.
var _in_reach: bool = false
var _told_reach: bool = false
## What _hub_near calls a way down, a lift station and a find below.
const HATCH: String = "hatch"
const LIFT: String = "lift"
const FIND: String = "find"
## The camp at the hub, once a quest has opened it (Camp).
const CAMP: String = "camp"

## The rack, the board or a beacon spot the rover is by (LavaHub.nearest), or {}.
var _hub_near: Dictionary = {}
var _told_hub: String = ""
## This player took a beacon from the rack and has not set it down [PLACEHOLDER:
## it is not kept if they leave the tunnels].
var _holding_beacon: bool = false
var _props: LavaHubProps
## This player is below, in one of the depths (ZoneDepth), not in the hub.
var _below: bool = false
## The depth and the day this scene was built for. The rover's depth, or the day,
## changing means the scene is built again.
var _built_depth: int = 0
var _built_day: int = 0
var _depth_props: ZoneDepthProps
## Today's vents below (ZoneHazards), the one the rover is in (told once while it is
## hot), and the one it was last told was near.
var _vents: Array = []
var _in_vent: String = ""
var _near_vent: String = ""

@onready var _rover: RoverController = %Rover
@onready var _hud: FieldPhoneHUD = %FieldPhoneHUD
@onready var _exit_pad: ParkingPad = %ExitPad


func _ready() -> void:
	_rover.uplink_changed.connect(_on_uplink_changed)
	_rover.drift_changed.connect(_on_drift_changed)
	_rover.steering_zeroed.connect(_on_steering_zeroed)
	_rover.till_rejected.connect(_on_till_rejected)
	_rover.dig_rejected.connect(_on_dig_rejected)
	_rover.fill_rejected.connect(_on_fill_rejected)
	_exit_pad.rover_entered.connect(_on_rover_entered_exit)
	if ZoneDepth.arrive_pending:
		_rover.global_transform = ZoneDepth.arrive_at
		ZoneDepth.arrive_pending = false
	_build_zone()
	_hud.set_lights(GameState.rover_lights)
	GameState.rover_lights_changed.connect(_show_lights)
	var pause := PauseUI.new()
	_hud.get_parent().add_child(pause)
	_hud.get_parent().move_child(pause, 0)
	_hud.zero_steering_pressed.connect(_on_zero_pressed)
	_hud.slot_spool_pressed.connect(_on_slot_spool_pressed)
	_hud.enter_dome_pressed.connect(_go_to_dome)
	_hud.accept_job_pressed.connect(_try_accept_job)
	# Bound methods so the autoloads drop them when this scene is freed.
	GameState.silk_changed.connect(_on_silk_changed)
	GameState.relay_changed.connect(_on_relay_changed)
	GameState.phone_message.connect(_hud.push_log)
	GameState.skill_leveled.connect(_on_skill_leveled)
	SaveGame.save_failed.connect(_hud.push_log)
	GameState.rover_place_changed.connect(_on_rover_place_changed)
	GameState.credits_changed.connect(_hud.set_credits)
	GameState.ore_changed.connect(_hud.set_ore)
	GameState.credibility_changed.connect(_on_credibility_changed)
	GameState.lab_xp_changed.connect(_on_lab_xp_changed)
	GameState.jobs_changed.connect(_refresh_jobs_hud)
	GameState.upgrades_changed.connect(_refresh_jobs_hud)
	GameState.oirm_changed.connect(_refresh_jobs_hud)

	for line: String in GameState.phone_log.slice(-LOG_REPLAY_LINES):
		_hud.push_log(line)
	_hud.configure(_rover.satellite_relay.relay_name, _rover.steering.mpe, _rover.steering.acceptance_ratio)
	_last_band = _rover.get_drift_band()
	_rover.broadcast_state()
	_refresh_relay_hud()
	_hud.set_credits(GameState.credits)
	_hud.set_ore(GameState.crystal_ore)
	_on_credibility_changed(0)
	_hud.get_parent().add_child(SkillsUI.new())
	_hud.get_parent().add_child(ToolRollUI.new())
	_hud.get_parent().add_child(PickerUI.new())
	_hud.get_parent().add_child(ControlsGuideUI.new())
	_hud.get_parent().add_child(QuestsUI.new())
	_hud.get_parent().add_child(CoopUI.new())
	_hud.get_parent().add_child(ActionsMenuUI.new(ActionsMenuUI.PANEL_ACTIONS))
	_hud.get_parent().add_child(_cup)
	_cup.closed.connect(_on_cup_closed)
	if _rover.away_text() == "":
		_hud.push_log("LIGHTS: press " + Controls.prompt(&"rover_lights") + " to turn them low or on.")
	_say_if_away()


## Builds this scene's depth and props. The Lava Tubes' are here; the Flooded Aquifer's
## scene (FloodedAquifer) builds its own.
func _build_zone() -> void:
	_below = ZoneDepth.local_depth > 0 and not ZoneDepth.local_layout.is_empty()
	_built_depth = ZoneDepth.local_depth if _below else 0
	_built_day = GameClock.get_day_index()
	GameClock.day_started.connect(_on_new_day)
	_depth_props = ZoneDepthProps.new()
	_rover.get_parent().add_child(_depth_props)
	if _below:
		# The depth has its own finds, and none of the hub's rack, board or beacons.
		_depth_props.build_finds(ZoneDepth.local_layout, _taken_today())
		_vents = ZoneHazards.vents_for(GameState.world_seed, ZoneDepth.ZONE, _built_depth, _built_day)
		_depth_props.build_vents(_vents)
		_depth_props.build_rockfall(ZoneDepth.local_layout)
		if ZoneDepth.has_way_down(_built_depth):
			_depth_props.build_hatch(_built_depth)
		GameState.finds_changed.connect(_on_finds_changed)
		var wild: Node = get_node_or_null("WorldView/WorldViewport/World/WildSentinel")
		if wild != null:
			wild.queue_free()
	else:
		_depth_props.build_hatch()
		_props = LavaHubProps.new()
		_rover.get_parent().add_child(_props)
		if Camp.has_camp(_zone_id()):
			_rover.get_parent().add_child(CampProps.new(_zone_id()))
		GameState.beacons_changed.connect(_on_beacons_changed)
	# The lift station: at the hub, and at the depth that has one. Broken until repaired.
	if ZoneDepth.is_lift_depth(_built_depth) or _built_depth == 0:
		_depth_props.build_lift(_built_depth, GameState.is_lift_repaired(ZoneDepth.ZONE, _lift_depth()))
		GameState.lifts_changed.connect(_on_lifts_changed)


## The zone this scene shows (ZoneDepth.ZONE): the Flooded Aquifer's scene says its own.
func _zone_id() -> String:
	return ZoneDepth.ZONE


func _process(_delta: float) -> void:
	_resync_depth()
	_hud.set_clock(GameClock.format_now())
	_hud.set_molt(GameState.molt_text() if GameState.has_skill_unlock("molt_on_phone") else "")
	var reach: bool = _can_catch()
	var rover_free: bool = _rover.away_text() == ""
	# A held beacon and an empty spot in reach: the spot wins over the Sentinel's
	# catch, so the prompt and E agree on one target.
	var spot_wins: bool = reach and rover_free and _holding_beacon \
			and not LavaHub.nearest(_rover.global_position, GameState.beacons_placed, true).is_empty()
	var catching: bool = reach and not spot_wins
	if catching and not _told_reach:
		_told_reach = true
		_hud.push_log("SENTINEL: in reach. Press " + Controls.prompt(&"interact") + " for the catch cup.")
	if not catching and _cup.visible:
		_cup.hide()
	_in_reach = catching
	if not catching:
		_told_reach = false
	# One target for the prompt and for E: the Sentinel's catch comes first, unless
	# a held beacon has an empty spot in reach.
	if _below:
		_hub_near = _nearest_find() if rover_free else {}
	else:
		_hub_near = LavaHub.nearest(_rover.global_position, GameState.beacons_placed, spot_wins) if rover_free and not catching else {}
	if _hub_near.is_empty() and rover_free and not catching:
		_hub_near = _station_near()
	if _hub_near.is_empty() and rover_free and not catching and not _below:
		_hub_near = _camp_near()
	_tell_hub()
	if _below:
		_watch_vents(rover_free)


## Lights the vents by the clock, tells of one the rover comes near, and, the first time
## the rover is in a hot one, tells the host (its heat command; the host decides).
func _watch_vents(rover_free: bool) -> void:
	var now: float = GameClock.elapsed_days
	_depth_props.show_heat(now)
	var cell: Vector2i = ZoneHazards.cell_of(_rover.global_position) if rover_free else Vector2i(-1, -1)
	var here: Dictionary = ZoneHazards.vent_at(_vents, cell)
	var near_text: String = ""
	var in_text: String = ""
	for vent: Dictionary in _vents:
		var there: Vector3 = TunnelRock.at(vent["cell"])
		if rover_free and Vector2(there.x - _rover.global_position.x, there.z - _rover.global_position.z).length() <= ZoneDepth.REACH_M:
			near_text = str(vent["id"])
	if not here.is_empty() and ZoneHazards.is_hot(here, now):
		in_text = str(here["id"])
	if near_text != _near_vent:
		_near_vent = near_text
		if near_text != "":
			_hud.push_log(ZoneHazards.hint(ZoneHazards.vent_in(_vents, near_text), now))
	if in_text != "" and (SceneSwitcher.is_busy() or _moving or not (CoopRovers.driver(GameState.TUNNEL_ROVER) in ["", GameState.local_player_id])):
		in_text = ""  # swapping scenes, or somebody else drives: not this screen's to tell
	if in_text != _in_vent:
		_in_vent = in_text
		if in_text != "":
			_enter_vent(in_text)


func _enter_vent(vent_id: String) -> void:
	var problem: String = await FarmCommands.request(&"enter_vent", [vent_id, _built_day])
	if not is_inside_tree():
		return
	if problem == "Still waiting for the host.":
		_in_vent = ""  # another command was in flight: ask again next frame
		return
	if problem != "":
		_hud.push_log("VENT: " + problem)  # on success the host's phone line says it


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and SceneSwitcher.is_busy():
		get_viewport().set_input_as_handled()
		return  # a swap is under way; a second one would be dropped
	var away: bool = _rover.away_text() != ""
	if away and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		SceneSwitcher.swap_to(SceneSwitcher.FARM_SCENE)
	elif away and not event is InputEventJoypadMotion and ROVER_KEYS.any(func(key: StringName) -> bool: return event.is_action_pressed(key)):
		get_viewport().set_input_as_handled()
		_say_if_away()
	elif event.is_action_pressed(&"interact") and _exit_pad.rover_inside:
		get_viewport().set_input_as_handled()
		if _below:
			_go_up()
		else:
			_leave_tunnels()
	elif event.is_action_pressed(&"interact") and _in_reach:
		get_viewport().set_input_as_handled()
		_cup.open()
	elif event.is_action_pressed(&"interact") and not _hub_near.is_empty():
		get_viewport().set_input_as_handled()
		_use_hub(_hub_near)
	elif event.is_action_pressed(&"rover_lights"):
		get_viewport().set_input_as_handled()
		_toggle_lights()
	elif event.is_action_pressed(&"rover_dig"):
		get_viewport().set_input_as_handled()
		_rover.queue_command(RoverController.Command.DIG)
	elif event.is_action_pressed(&"rover_fill"):
		get_viewport().set_input_as_handled()
		_rover.queue_command(RoverController.Command.FILL)


func _on_rover_entered_exit() -> void:
	_hud.push_log("WAY UP: press " + Controls.prompt(&"interact") + " to go up." if _below else ("WAY HOME: press " + Controls.prompt(&"interact") + " to go back to the dome." if not GameState.rover_lent else "TUNNEL MOUTH: press " + Controls.prompt(&"interact") + " to leave."))


## Says what E does when the rover first comes by the rack, the board or a spot.
func _tell_hub() -> void:
	var key: String = "%s:%s" % [_hub_near.get("kind", ""), _hub_near.get("id", "")] if not _hub_near.is_empty() else ""
	if key == _told_hub:
		return
	_told_hub = key
	match _hub_near.get("kind", ""):
		LavaHub.RACK:
			_hud.push_log("BEACON RACK: press " + Controls.prompt(&"interact") + " to take a beacon.")
		LavaHub.BOARD:
			_hud.push_log("NOTICE BOARD: press " + Controls.prompt(&"interact") + " to read it.")
		LavaHub.SPOT:
			_hud.push_log("BEACON SPOT: press " + Controls.prompt(&"interact") + " to set a beacon down.")
		HATCH:
			var shut: String = GameState.lava_deep_problem() if ZoneDepth.is_deep(_built_depth + 1) else ""
			_hud.push_log("WAY DOWN: press " + Controls.prompt(&"interact") + " to go down." if shut == "" else "WAY DOWN: " + shut)
		LIFT:
			_hud.push_log(_lift_prompt())
		FIND:
			_hud.push_log("FIND: press " + Controls.prompt(&"interact") + " to take it.")
		CAMP:
			if CoopBeds.in_bed.has(GameState.local_player_id):
				_hud.push_log("CAMP: you are asleep. Press %s to get up." % Controls.prompt(&"interact"))
			elif GameState.camp_supplies > 0:
				_hud.push_log("CAMP: press %s to sleep the night here (%d of supplies held)." % [Controls.prompt(&"interact"), GameState.camp_supplies])
			else:
				_hud.push_log("CAMP: press %s to buy a night's supplies (%d credits)." % [Controls.prompt(&"interact"), Camp.SUPPLY_COST_CREDITS])


func _use_hub(target: Dictionary) -> void:
	match target["kind"]:
		LavaHub.RACK:
			_use_rack()
		LavaHub.BOARD:
			for line: String in LavaHub.board_lines(QuestEngine.quests(), GameState.quest_state,
					GameState.player_quest_state.get(GameState.local_player_id, {}), GameState.beacons_placed.size()):
				_hud.push_log(line)
		LavaHub.SPOT:
			_use_spot(str(target["id"]))
		HATCH:
			_go_down()
		LIFT:
			_use_lift()
		FIND:
			_use_find(str(target["id"]))
		CAMP:
			_use_camp()


## Orin speaks on the phone: he is not here in person [PLACEHOLDER].
func _orin(line_id: String) -> void:
	_hud.push_log("ORIN: " + QuestEngine.phone_line("npcs/orin/hub/" + line_id))


func _use_rack() -> void:
	if _holding_beacon:
		_orin("rack_holding")
	elif GameState.beacons_placed.size() >= LavaHub.SPOTS.size():
		_orin("rack_empty")
	elif LavaHub.job_problem(GameState.quest_state) != "":
		_orin("rack_no_job")
	else:
		_holding_beacon = true
		_orin("rack_take")


func _use_spot(spot_id: String) -> void:
	if not _holding_beacon:
		_orin("spot_needs_beacon")
		return
	var problem: String = await FarmCommands.request(&"place_beacon", [spot_id])
	if not is_inside_tree():
		return
	if problem != "":
		_hud.push_log("BEACON SPOT: " + problem)
		return
	_holding_beacon = false
	_orin("spot_placed")


## A beacon was set down here, or a host's copy says so: show it.
func _on_beacons_changed() -> void:
	_props.show_placed(GameState.beacons_placed)


## The ids taken below today (ZoneDepth).
func _taken_today() -> Array:
	return ZoneDepth.taken_today(GameState.finds_taken, ZoneDepth.ZONE, GameClock.get_day_index())


## A find was taken, here or by a friend: show what is left.
func _on_finds_changed() -> void:
	_depth_props.show_taken(_taken_today())


## The nearest find not taken within reach of the rover: { "kind": FIND, "id" }, or {}.
func _nearest_find() -> Dictionary:
	var taken: Array = _taken_today()
	var best: float = ZoneDepth.REACH_M
	var found: Dictionary = {}
	for find: Dictionary in ZoneDepth.local_layout.get("finds", []):
		if str(find["id"]) in taken:
			continue
		var there: Vector3 = TunnelRock.at(find["cell"])
		var away: float = Vector2(there.x - _rover.global_position.x, there.z - _rover.global_position.z).length()
		if away <= best:
			best = away
			found = { "kind": FIND, "id": str(find["id"]) }
	return found


func _use_find(find_id: String) -> void:
	# The day the finds on this screen were drawn from: the host refuses another.
	var problem: String = await FarmCommands.request(&"take_find", [find_id, int(ZoneDepth.local_layout.get("day", 0))])
	if not is_inside_tree():
		return
	if problem != "":
		_hud.push_log("FIND: " + problem)
		return
	var find: Dictionary = ZoneDepth.find_in(ZoneDepth.local_layout, find_id)
	_hud.push_log("FIND: " + ZoneDepth.reward_text(str(find.get("kind", "")), _built_depth))


## The depth whose lift this screen shows: the hub's (0) goes to the deepest repaired
## one; below, the depth's own.
func _lift_depth() -> int:
	return GameState.repaired_lift_depth(ZoneDepth.ZONE) if _built_depth == 0 else _built_depth


## The way down or the lift the rover is by (below: only if the depth has one), or {}.
func _station_near() -> Dictionary:
	var at: Vector3 = _rover.global_position
	if ZoneDepth.has_way_down(_built_depth) and ZoneDepth.near_descent(at, _built_depth):
		return { "kind": HATCH, "id": "" }
	if (_built_depth == 0 or ZoneDepth.is_lift_depth(_built_depth)) and ZoneDepth.near_lift(at, _built_depth):
		return { "kind": LIFT, "id": "repaired" if GameState.is_lift_repaired(ZoneDepth.ZONE, _lift_depth()) else "broken" }
	return {}


## The open camp the rover is by, or {}. Its id is the supplies held, so the prompt is
## told again when a night's supplies are bought.
func _camp_near() -> Dictionary:
	var zone: String = _zone_id()
	if Camp.has_camp(zone) and GameState.camps_open.has(zone) and Camp.near(zone, _rover.global_position):
		return { "kind": CAMP, "id": str(GameState.camp_supplies) }
	return {}


## E at the camp: sleep the night if the farm holds supplies, else buy a night's (host-run).
func _use_camp() -> void:
	var asleep: bool = CoopBeds.in_bed.has(GameState.local_player_id)
	var buying: bool = GameState.camp_supplies < 1 and not asleep
	var problem: String = ""
	if asleep:
		problem = await FarmCommands.request(&"get_up", [])
	elif buying:
		problem = await FarmCommands.request(&"buy_camp_supplies", [])
	else:
		problem = await FarmCommands.request(&"go_to_bed", [])
	if not is_inside_tree():
		return
	if asleep and problem == "":
		_hud.push_log("CAMP: you get up.")
	elif problem != "":
		_hud.push_log("CAMP: " + problem)
	elif buying:
		_hud.push_log("CAMP: the farm bought a night's supplies for %d credits." % Camp.SUPPLY_COST_CREDITS)
	else:
		_hud.push_log("CAMP: you turn in for the night.")


func _lift_prompt() -> String:
	var repaired: bool = GameState.is_lift_repaired(ZoneDepth.ZONE, _lift_depth())
	if repaired:
		var shut: String = GameState.lava_deep_problem() if _built_depth == 0 and ZoneDepth.is_deep(_lift_depth()) else ""
		if shut != "":
			return "LIFT: " + shut
		return "LIFT: press " + Controls.prompt(&"interact") + " to ride it %s." % ("up to the hub" if _built_depth > 0 else "down to depth %d" % _lift_depth())
	if _built_depth > 0:
		return "LIFT: broken. Press " + Controls.prompt(&"interact") + " to repair it. %s" % ZoneDepth.repair_cost_text(_built_depth)
	return "LIFT: broken. It is repaired from its far end, at depth %d." % ZoneDepth.LIFT_EVERY


## E at a lift: repair it where it is broken (below), or ride it. The host decides.
func _use_lift() -> void:
	if _built_depth > 0 and not GameState.is_lift_repaired(ZoneDepth.ZONE, _built_depth):
		var problem: String = await FarmCommands.request(&"repair_lift", [])
		if not is_inside_tree():
			return
		if problem != "":
			_hud.push_log("LIFT: " + problem)
		return  # the phone says it was repaired; lifts_changed redraws the lift
	_ride_lift()


## The lift was repaired, here or by a friend: draw it so.
func _on_lifts_changed() -> void:
	_depth_props.build_lift(_built_depth, GameState.is_lift_repaired(ZoneDepth.ZONE, _lift_depth()))
	_told_hub = ""  # the prompt changed
	_hud.set_credibility(GameState.credibility_text(), GameState.contract_phone_text(), GameState.lab_phone_text())  # the deepest depth


## Down a hatch: the host takes the one rover down (to the start below, with its
## driver). Nothing here changes until the host says yes; then every screen in the
## tunnels builds the depth from the rover's (_on_rover_place_changed).
func _go_down() -> void:
	_change_depth(_built_depth + 1)


## Up again: the host brings the rover out by the hatch above, or in the hub.
func _go_up() -> void:
	_change_depth(_built_depth - 1)


func _change_depth(target: int) -> void:
	if _moving or SceneSwitcher.is_busy():
		return
	_moving = true
	var problem: String = await FarmCommands.request(&"change_depth", [target])
	_finish_move(problem, "WAY DOWN: " if target > _built_depth else "WAY UP: ")


## The lift's ride, asked of the host the same way.
func _ride_lift() -> void:
	if _moving or SceneSwitcher.is_busy():
		return
	_moving = true
	var target: int = 0 if _built_depth > 0 else _lift_depth()  # where this screen means to go
	var problem: String = await FarmCommands.request(&"use_lift", [target])
	_finish_move(problem, "LIFT: ")


## The host's answer to a move of the rover between depths.
func _finish_move(problem: String, prefix: String) -> void:
	if not is_inside_tree():
		return
	if problem != "":
		_moving = false
		_hud.push_log(prefix + problem)
		return
	# A guest's copy of the farm may come after the host's yes.
	_on_rover_place_changed()
	if not SceneSwitcher.is_busy():
		_moving = false  # no rebuild or swap began (the rover is at this depth already)


## The rover's depth is not the one this scene was built for: it is built again, with
## the rover put where the new depth starts it (the same on every screen).
func _rebuild_for_depth() -> void:
	if SceneSwitcher.is_busy():
		return
	_moving = true
	if GameState.rover_depth != _built_depth:
		# The old rover node reports its pose as it leaves; make it the new one, and
		# have the next scene's rover start there too. (A new day on the same depth
		# keeps the rover where it is.)
		_rover.global_transform = _rover_pose_for_rebuild()
		ZoneDepth.arrive_at = _rover.global_transform
		ZoneDepth.arrive_pending = true
	SceneSwitcher.swap_to(SceneSwitcher.scene_for_zone(_zone_id()))


## Where the rebuilt scene's rover starts: where the rover is, if that is inside
## this depth's rock. A guest has the host's told pose, or else (a depth change clears
## it) the pose the host's snapshot parked; the host has its parked one,
## which counts only if the rover has a pose at all, and it lies inside this depth's
## rock (so a trip through the airlock that raced a console re-park does not put the
## rover by the hatch while it is at the hub start; a depth change parks a pose of
## its own, so the hatch is for when none is valid); else where a depth starts it.
func _rover_pose_for_rebuild() -> Transform3D:
	var known: Variant = CoopRovers.told_pose(GameState.TUNNEL_ROVER) if FarmCommands.guest else null
	if known == null and GameState.rover_transforms.has(GameState.TUNNEL_ROVER):
		known = GameState.parked_rover_transform(GameState.TUNNEL_ROVER)
	return ZoneDepth.rebuild_pose(known, GameState.rover_depth, GameState.world_seed, GameClock.get_day_index(), _zone_id())


## Not left to a signal, which a busy swap can swallow and a later snapshot with the
## same depth does not send again: if this scene is not the rover's depth, or the day
## its finds were drawn for, it is built again. Each frame, and when a swap is done.
func _resync_depth() -> void:
	if SceneSwitcher.is_busy() or GameState.rover_zone != _zone_id() or _rover.away_text() != "":
		return
	if ZoneDepth.needs_rebuild(_built_depth, _built_day, GameState.rover_depth, GameClock.get_day_index()):
		_rebuild_for_depth()


## 06:00: the floor below is another one. A screen below builds it again, so its
## finds are today's (the host has put the rover on it).
func _on_new_day(_day: int) -> void:
	_resync_depth()


func _can_catch() -> bool:
	return (_rover.away_text() == "" and _rover.is_stopped() and not GameState.rover_lights
		and GameState.sentinel_in_reach(_rover.global_position))


func _show_lights() -> void:
	_hud.set_lights(GameState.rover_lights)


func _toggle_lights() -> void:
	var on: bool = not GameState.rover_lights
	var problem: String = await FarmCommands.request(&"set_rover_lights", [on])
	if is_inside_tree():
		_hud.push_log("LIGHTS: " + (problem if problem != "" else "on." if on else "low."))


func _on_cup_closed(reading_pct: float) -> void:
	var problem: String = await FarmCommands.request(&"catch_sentinel", [reading_pct])
	if is_inside_tree() and problem != "":
		_hud.push_log("CATCH CUP: " + problem)


func _on_uplink_changed(has_los: bool, quality: float, lag_s: float) -> void:
	if _rover.away_text() != "":
		_hud.set_rover_away()
		return
	_hud.set_uplink(has_los, quality, lag_s)
	if _had_los != has_los:
		_hud.push_log("SYS: LOS %s" % ("restored" if has_los else "lost; uplink lag rising"))
	_had_los = has_los


func _on_drift_changed(drift_deg: float, band: int) -> void:
	_hud.set_drift(drift_deg, band)
	if band == DriftingSensor.Band.OUT_OF_TOLERANCE and _last_band != band:
		_hud.push_log("SYS: steering exceeds MPE ±%.2f°" % _rover.steering.mpe)
	_last_band = band


func _on_zero_pressed() -> void:
	if _rover.away_text() != "":
		_say_if_away()
		return
	_rover.queue_command(RoverController.Command.ZERO_STEERING)
	_hud.push_log("> ZERO STEERING sent (%d ms lag)" % roundi(_rover.get_current_lag() * 1000.0))


func _on_steering_zeroed(record: Dictionary) -> void:
	if record.get("refused", false):
		_hud.push_log("ZERO STEERING FAILED: %s" % record["reason"])
		return
	var schedule: String = ("No standard: not a calibration, still due day %d" % record.get("due_day", 0)
		if not record.get("traceable", true)
		else "Next due day %d (%d d)" % [record.get("due_day", 0), record.get("interval_days", 0)])
	_hud.push_log("As-found %s°  As-left %s°  %s" % [
		SP811.signed(record.get("as_found", 0.0)), SP811.signed(record.get("as_left", 0.0)), schedule])


func _on_slot_spool_pressed() -> void:
	var replaced: bool = GameState.relay_slotted
	if await FarmCommands.request(&"slot_spool_into_relay") and is_inside_tree():
		if FarmCommands.guest:
			_hud.push_log("Silk spool installed.")
			return
		_hud.push_log("%s installed%s. Uplink lag × %s." % [
			"Damaged silk spool" if GameState.slotted_spool_damaged else "Optical silk spool",
			", the old one taken out" if replaced else "", SP811.number(GameState.get_relay_lag_multiplier(), 2)])


func _on_silk_changed(_spools: int) -> void:
	_refresh_relay_hud()


func _on_relay_changed(_slotted: bool) -> void:
	_refresh_relay_hud()
	_rover.broadcast_state()


func _refresh_relay_hud() -> void:
	_hud.set_relay(GameState.relay_slotted, GameState.slotted_spool_damaged, GameState.spool_count_text(), GameState.can_slot_spool())


func _on_till_rejected(reason: String) -> void:
	_hud.push_log("TILL FAILED: %s" % reason)


func _on_dig_rejected(reason: String) -> void:
	_hud.push_log("DIG FAILED: %s" % reason + (" The tunnel floor is solid basalt." if reason == RoverController.ROCK_REFUSAL else ""))


func _on_fill_rejected(reason: String) -> void:
	_hud.push_log("FILL FAILED: %s" % reason)


## A new lab level can open the way down or the hub lift: the prompt is read again.
func _on_lab_xp_changed() -> void:
	_told_hub = ""
	_on_credibility_changed(0)


func _on_credibility_changed(_points: int) -> void:
	_hud.set_credibility(GameState.credibility_text(), GameState.contract_phone_text(), GameState.lab_phone_text())
	_refresh_jobs_hud()


func _on_skill_leveled(player_id: String, skill_id: String, _level: int) -> void:
	if player_id == "" or player_id == GameState.local_player_id:
		_hud.push_log("SKILL UP: %s. %s shows skills." % [GameState.skill_text(skill_id), Controls.prompt(&"open_skills")])


func _refresh_jobs_hud() -> void:
	var active: PackedStringArray = []
	for job: Dictionary in GameState.active_jobs:
		active.append(GameState.active_job_text(job))
	var offers: Array[Dictionary] = []
	for job: Dictionary in GameState.job_board:
		var problem: String = GameState.job_accept_problem(job)
		offers.append({ "text": GameState.job_offer_text(job) + (" (%s)" % problem if problem != "" else ""),
			"disabled": problem != "", "tooltip": problem })
	_hud.show_jobs(active, offers, GameState.job_board_note())


func _try_accept_job(index: int) -> void:
	var problem: String = await FarmCommands.request(&"accept_job", [index])
	if is_inside_tree() and problem != "":
		_hud.push_log("JOB NOT ACCEPTED: " + problem)


func _go_to_dome() -> void:
	SceneSwitcher.swap_to(SceneSwitcher.DOME_SCENE)


## Says where the rover is if it is not here.
func _say_if_away() -> void:
	if _rover.away_text() != "":
		_hud.push_log(_rover.away_text())


## Takes the rover out and goes with it.
func _leave_tunnels() -> void:
	if _moving:
		return
	_moving = true
	if not GameState.rover_lent:
		# A field rover, from the dome's console: the way home is the dome, where
		# the console is. The farm's rover never left home.
		var left: String = await FarmCommands.request(&"leave_zone")
		if not is_inside_tree():
			return
		if left != "":
			_moving = false
			_hud.push_log("TUNNEL MOUTH: " + left)
			return
		SceneSwitcher.outside = SceneSwitcher.FARM_SCENE
		SceneSwitcher.go_to(SceneSwitcher.DOME_SCENE)
		return
	var problem: String = await FarmCommands.request(&"move_rover", [false])
	if not is_inside_tree():
		return
	if problem != "":
		_moving = false
		_hud.push_log("TUNNEL MOUTH: " + problem)
		return
	_move_granted = true
	_on_rover_place_changed()


## A guest's copy of the farm may come after the host's yes.
func _on_rover_place_changed() -> void:
	if GameState.rover_zone == _zone_id() and GameState.rover_depth != _built_depth and _rover.away_text() == "":
		_rebuild_for_depth()
	elif _move_granted and _rover.away_text() != "":
		_move_granted = false
		SceneSwitcher.go_to(SceneSwitcher.FARM_SCENE)
	elif not _moving:
		_say_if_away()
