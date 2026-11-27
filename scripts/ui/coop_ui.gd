class_name CoopUI
extends Control
## Co-op on the farm and in the dome: a line saying who is in, and a panel to
## host, stop hosting or leave. F7 opens and closes the panel.

const TEAL: Color = Color("38E1C6")
const TEXT: Color = Color(0.85, 0.95, 0.88)
const STRIP_TOP: float = 8.0
const PANEL_WIDTH: float = 820.0

var _strip: Label
var _panel: Control
var _about: Label
var _action: Button
var _bed: Button
var _close_button: Button
var _addresses: PackedStringArray = []
var _problem: String = ""
## What the bed button last said, shown as its own line.
var _bed_note: String = ""


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip = PlanBoardUI._label("", TEAL, 18)
	_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_strip.offset_top = STRIP_TOP
	_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var box := PanelContainer.new()
	box.custom_minimum_size.x = PANEL_WIDTH
	box.add_theme_stylebox_override(&"panel", PlanBoardUI._panel_style())
	center.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	box.add_child(column)
	column.add_child(PlanBoardUI._label("CO-OP", TEAL, 30))
	_about = PlanBoardUI._label("", TEXT, 20)
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_about)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override(&"separation", 12)
	column.add_child(buttons)
	_bed = PlanBoardUI._button("")
	_bed.pressed.connect(_on_bed)
	buttons.add_child(_bed)
	_action = PlanBoardUI._button("")
	_action.pressed.connect(_on_action)
	buttons.add_child(_action)
	_close_button = PlanBoardUI._button("CLOSE  (F7 or Esc)")
	_close_button.pressed.connect(_panel.hide)
	buttons.add_child(_close_button)
	_panel.hide()


## The rover this screen is with: in the tunnels, the one below (a console's field rover too).
func _rover_here() -> String:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.scene_file_path == SceneSwitcher.TUNNELS_SCENE:
		return GameState.TUNNEL_ROVER
	return GameState.rover_here()


func _process(_delta: float) -> void:
	_strip.text = strip_text(CoopSession.players, GameState.local_player_id, CoopSession.is_hosting(), CoopSync.is_too_big(), CoopBeds.in_bed, CoopRovers.driver(_rover_here()))
	if _panel.visible:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var toggled: bool = event.is_action_pressed(&"open_coop")
	if not _panel.visible:
		if toggled:
			get_viewport().set_input_as_handled()
			open()
		return
	if toggled or event.is_action_pressed(&"ui_cancel"):
		_panel.hide()
	# As in SkillsUI: no key press reaches the farm behind the panel.
	if key != null or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func open() -> void:
	_problem = ""
	_bed_note = ""
	_addresses = local_addresses()
	_refresh()
	_panel.show()
	_close_button.grab_focus()


func _refresh() -> void:
	var who: String = players_text(CoopSession.players, GameState.local_player_id, GameState.player_places, true)
	if FarmCommands.guest:
		_action.text = "LEAVE THIS FARM"
		_about.text = "You are on a friend's farm. It is saved on the host's PC, not on this one.\n\n" + who
	elif CoopSession.is_hosting():
		_action.text = "STOP HOSTING"
		_about.text = host_text(CoopSession.port(), _addresses) + "\n\n" + who
	else:
		_action.text = "HOST THIS FARM"
		_about.text = _problem if _problem != "" else "Hosting lets friends join this farm while you play. Anyone who knows your address can join, so share it only with friends."
	_bed.visible = true
	_bed.text = "GET UP" if GameState.local_player_id in CoopBeds.in_bed else "GO TO BED"
	var here: String = CoopBeds.here_refusal()
	_bed.disabled = here != "" and not GameState.local_player_id in CoopBeds.in_bed
	if FarmCommands.guest or CoopBeds.together():
		_about.text += "\n\nThe day ends when everyone is in bed, and waits at 06:00 for anyone still up."
	else:
		_about.text += "\n\nGO TO BED ends the day."
	if _bed.disabled:
		_about.text += " " + here
	if _bed_note != "":
		_about.text += "\n\n" + _bed_note
	# A farm run on its own, not from the title menu, is nobody's to share.
	_action.disabled = not FarmCommands.guest and not SaveGame.farm_open


func _on_bed() -> void:
	if GameState.local_player_id in CoopBeds.in_bed:
		_bed_note = str(await FarmCommands.request(&"get_up"))
	else:
		_bed_note = str(await FarmCommands.request(&"go_to_bed"))
	if _panel.visible:
		_refresh()


func _on_action() -> void:
	_problem = ""
	if FarmCommands.guest:
		_panel.hide()
		CoopScenes.leave_farm()
		return
	if CoopSession.is_hosting():
		CoopSession.leave()
	else:
		_problem = CoopSession.host()
	_refresh()


static func player_name(player_id: String) -> String:
	return player_id.replace("_", " ").to_upper()


## The line at the top of the screen; "" when playing alone.
static func strip_text(players: Array[String], own_id: String, hosting: bool, too_big: bool, in_bed: Array[String] = [], driver: String = "") -> String:
	if players.is_empty():
		return ""
	if hosting and too_big:
		return "CO-OP  THE FARM IS TOO BIG TO SHARE, SO FRIENDS CAN'T STAY"
	if players.size() == 1:
		return "CO-OP  WAITING FOR FRIENDS  (F7)"
	if not in_bed.is_empty():
		var up: PackedStringArray = []
		for player_id: String in players:
			if not player_id in in_bed:
				up.append(player_name(player_id))
		return "CO-OP  %d OF %d IN BED, STILL UP: %s  (F7)" % [players.size() - up.size(), players.size(), ", ".join(up)]
	var driving: String = ", %s IS DRIVING" % player_name(driver) if driver in players and driver != own_id else ""
	return "CO-OP  %d PLAYERS, YOU ARE %s%s  (F7)" % [players.size(), player_name(own_id), driving]


## The host is first. With `show_places`, each line also says where that player is
## (`places`: player -> [place, depth], GameState.player_places), in the same
## capitals; a player not in it is on the farm.
static func players_text(players: Array[String], own_id: String, places: Dictionary = {}, show_places: bool = false) -> String:
	var lines: PackedStringArray = []
	for index: int in players.size():
		var line: String = player_name(players[index])
		if index == 0:
			line += "  HOST"
		if players[index] == own_id:
			line += "  YOU"
		if show_places:
			var at: Array = places.get(players[index], [ZonePresence.DEFAULT_PLACE, 0])
			line += "  " + ZonePresence.label(str(at[0]), int(at[1])).to_upper()
		lines.append(line)
	return "\n".join(lines)


static func host_text(port: int, addresses: PackedStringArray) -> String:
	var here: String = "Friends on your network join %s." % " or ".join(addresses)
	if addresses.is_empty():
		here = "This PC is on no network that friends could join."
	return "Hosting on UDP port %d. %s Over the internet they join your public address, and your router must forward that port to this PC." % [port, here]


## This PC's addresses on its own networks.
static func local_addresses() -> PackedStringArray:
	var found: PackedStringArray = []
	for address: String in IP.get_local_addresses():
		if not ":" in address and not address.begins_with("127.") and not address.begins_with("169.254."):
			found.append(address)
	return found
