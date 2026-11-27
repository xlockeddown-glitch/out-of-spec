extends RefCounted
## The character and tractor picker (feat/picker): the parts table, what each part does to
## driving, the save, the looks on the walker and the rover, and the screen itself.
## The co-op side is in test_coop_loadout.gd.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _snapshot() -> Dictionary:
	return {
		"loadouts": GameState.player_loadouts.duplicate(true),
		"local": GameState.local_player_id,
		"blocked": RoverController.input_blocked,
		"offer": PickerUI.offer_next,
	}


func _restore(snap: Dictionary) -> void:
	GameState.player_loadouts = snap["loadouts"]
	GameState.local_player_id = snap["local"]
	RoverController.input_blocked = snap["blocked"]
	PickerUI.offer_next = snap["offer"]


func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _picker() -> PickerUI:
	var picker := PickerUI.new()
	_root().add_child(picker)
	return picker


func _state() -> Node:
	var state: Node = GameStateScript.new()
	state.build_registry()
	return state


func test_six_slots_of_four_parts_and_the_first_is_the_default() -> String:
	if Loadout.SLOTS.size() != 6:
		return "Six slots, got %d" % Loadout.SLOTS.size()
	var defaults: Dictionary = Loadout.default_parts()
	for slot: StringName in Loadout.SLOTS:
		var parts: Array = Loadout.parts_of(slot)
		var seen: Array = []
		if parts.size() != 4:
			return "%s must have 4 parts, got %d" % [slot, parts.size()]
		for entry: Dictionary in parts:
			if str(entry["id"]) != str(entry["id"]).to_snake_case() or str(entry["name"]) == "" or entry["id"] in seen:
				return "%s has a bad or repeated part %s" % [slot, entry["id"]]
			seen.append(entry["id"])
			if slot in [Loadout.POWER, Loadout.WHEELS] and entry != parts[0] and str(entry["trade_off"]) == "":
				return "%s needs a trade-off line" % entry["id"]
		if defaults[slot] != parts[0]["id"] or not (parts[0]["look"] as Array).is_empty():
			return "The first part of %s is the default and adds no look" % slot
	return ""


func test_the_part_names_are_ryan_s() -> String:
	var wanted: Dictionary = {
		Loadout.HEAD: ["Survey Helmet", "Mechanic Cap & Goggles", "Sun-Brim Hat", "Canyon Respirator Hood"],
		Loadout.UPPER: ["Frontier Flight Suit", "Calibration Lab Coat", "Mechanic Coverall", "Botanist Field Vest"],
		Loadout.LOWER: ["Standard Field Boots", "Mechanic Workpants", "Thermal Basalt Greaves", "Botanist Waders"],
		Loadout.CHASSIS: ["Standard Utility Cab", "Open Roll-Cage Surveyor", "Tunnel Armor Hull", "Flatbed Cargo Frame"],
		Loadout.POWER: ["Thermal Diesel Block", "Twin-Cell Battery Pack", "Folding Solar Array", "Silk-Coil Harmonic Cell"],
		Loadout.WHEELS: ["Standard Ag Tires", "Wide Crawler Tracks", "Rock-Climber Wheels", "Six-Wheel Survey Bogie"],
	}
	for slot: StringName in wanted:
		var names: Array = Loadout.parts_of(slot).map(func(entry: Dictionary) -> String: return entry["name"])
		if names != wanted[slot]:
			return "%s has %s" % [slot, names]
	return ""


func test_the_default_parts_drive_exactly_as_today() -> String:
	var factors: Dictionary = Loadout.drive(Loadout.default_parts())
	for key: StringName in Loadout.DRIVE_KEYS:
		if factors[key] != 1.0:
			return "%s must be exactly 1, got %s" % [key, factors[key]]
	# Nothing, an unknown part and a damaged table are the defaults as well.
	for odd: Variant in [{}, "x", null, { Loadout.WHEELS: "no_such_wheel", Loadout.POWER: 7 }]:
		for key: StringName in Loadout.DRIVE_KEYS:
			if Loadout.drive(odd)[key] != 1.0:
				return "%s must give the defaults" % [odd]
	return ""


func test_each_wheel_and_power_part_gives_something_and_takes_something() -> String:
	for slot: StringName in [Loadout.POWER, Loadout.WHEELS]:
		for entry: Dictionary in Loadout.parts_of(slot).slice(1):
			var up: bool = false
			var down: bool = false
			for key: StringName in entry["drive"]:
				if not key in Loadout.DRIVE_KEYS:
					return "%s has the unknown multiplier %s" % [entry["id"], key]
				up = up or entry["drive"][key] > 1.0
				down = down or entry["drive"][key] < 1.0
			if not (up and down):
				return "%s needs at least one + and one −" % entry["id"]
	for slot: StringName in [Loadout.HEAD, Loadout.UPPER, Loadout.LOWER, Loadout.CHASSIS]:
		for entry: Dictionary in Loadout.parts_of(slot):
			if not (entry["drive"] as Dictionary).is_empty():
				return "%s is a look only" % entry["id"]
	return ""


func test_no_pair_of_parts_outruns_what_the_host_accepts() -> String:
	var worst: float = 0.0
	var rover := RoverController.new()
	var base: float = rover.max_speed_mps
	rover.free()
	for power: Dictionary in Loadout.parts_of(Loadout.POWER):
		for wheels: Dictionary in Loadout.parts_of(Loadout.WHEELS):
			var parts: Dictionary = { Loadout.POWER: power["id"], Loadout.WHEELS: wheels["id"] }
			worst = maxf(worst, Loadout.drive(parts)[&"speed"])
	if worst > Loadout.MAX_SPEED_FACTOR or base * worst > CoopRovers.REACH_MPS:
		return "The best top speed is %s times, over what the host lets a rover do" % worst
	return ""


func test_an_unknown_id_or_a_bad_choice_is_the_default() -> String:
	var cleaned: Dictionary = Loadout.clean({ Loadout.HEAD: "no_such_hat", Loadout.POWER: &"twin_cell_battery_pack",
		Loadout.WHEELS: 5, &"not_a_slot": "x" })
	var want: Dictionary = Loadout.default_parts()
	want[Loadout.POWER] = &"twin_cell_battery_pack"
	if cleaned != want:
		return "Got %s" % [cleaned]
	if Loadout.clean("nonsense") != Loadout.default_parts() or Loadout.clean(null) != Loadout.default_parts():
		return "Not a table: the defaults"
	for bad: String in ["", "1", "1,2,3,4,5", "0,0,0,0,0,0,0", "4,0,0,0,0,0", "-1,0,0,0,0,0", "a,0,0,0,0,0"]:
		if not Loadout.decode(bad).is_empty():
			return "'%s' is not a loadout" % bad
	var round_trip: Dictionary = Loadout.decode(Loadout.encode(want))
	return "" if round_trip == want else "Encoded and back: %s" % [round_trip]


func test_a_name_is_trimmed_and_kept_short() -> String:
	var long_name: String = "N".repeat(Loadout.MAX_NAME + 9)
	if Loadout.clean_name(long_name).length() != Loadout.MAX_NAME:
		return "A name is at most %d letters" % Loadout.MAX_NAME
	if Loadout.clean_name("  Quill  ") != "Quill" or Loadout.clean_name(5) != "":
		return "Spaces off, and only text is a name"
	return "" if Loadout.shown_name("") == Loadout.UNNAMED and Loadout.shown_name("Quill") == "Quill" else "The unnamed show %s" % Loadout.UNNAMED


func test_set_loadout_stores_asks_nothing_twice_and_refuses_the_bad() -> String:
	var state: Node = _state()
	var heard: Array = []
	state.loadouts_changed.connect(func() -> void: heard.append(1))
	var choice: String = Loadout.encode({ Loadout.CHASSIS: &"tunnel_armor_hull" })
	var problems: Array = [state.set_loadout("Quill", choice, "player_2"), state.set_loadout("Quill", choice, "player_2"),
		state.set_loadout("Quill", "nonsense", "player_2")]
	var got: Dictionary = state.loadout_of("player_2")
	var own: Dictionary = state.loadout_of()
	state.free()
	if problems[0] != "" or problems[1] != "" or problems[2] == "":
		return "Got %s" % [problems]
	if heard.size() != 1:
		return "Only a change is a change, got %d signals" % heard.size()
	if got["name"] != "Quill" or got["parts"][Loadout.CHASSIS] != &"tunnel_armor_hull":
		return "Got %s" % [got]
	return "" if own["parts"] == Loadout.default_parts() and own["name"] == "" else "A player nobody asked about has the defaults"


func test_the_loadout_is_saved_with_the_farm() -> String:
	var source: Node = _state()
	source.set_loadout("Quill", Loadout.encode({ Loadout.WHEELS: &"rock_climber_wheels" }), "player_2")
	source.set_loadout("Hob", Loadout.encode({ Loadout.POWER: &"folding_solar_array" }))
	var data: Dictionary = bytes_to_var(var_to_bytes(source.farm_to_dict()))
	var target: Node = _state()
	var problem: String = target.farm_dict_problem(data)
	if problem == "":
		problem = target.farm_from_dict(data)
	var same: bool = target.player_loadouts == source.player_loadouts and target.loadout_of("player_2")["name"] == "Quill"
	var mine: Dictionary = target.loadout_of()
	source.free()
	target.free()
	if problem != "":
		return problem
	return "" if same and mine["name"] == "Hob" else "The loadouts must come back as they were"


func test_an_old_save_gives_the_defaults() -> String:
	var source: Node = _state()
	var data: Dictionary = source.farm_to_dict()
	data.erase("player_loadouts")
	var target: Node = _state()
	target.set_loadout("Stale", "1,1,1,1,1,1")
	var problem: String = target.farm_from_dict(data)
	var got: Dictionary = target.loadout_of()
	source.free()
	target.free()
	if problem != "":
		return "An old save must load, got '%s'" % problem
	return "" if got["name"] == "" and got["parts"] == Loadout.default_parts() else "Got %s" % [got]


func test_a_saved_part_the_game_does_not_know_loads_as_the_default() -> String:
	var source: Node = _state()
	var data: Dictionary = source.farm_to_dict()
	data["player_loadouts"] = { "player_1": { "name": "Quill", "parts": { "head": "no_such_hat", "wheels": "wide_crawler_tracks" } } }
	var target: Node = _state()
	var problem: String = target.farm_dict_problem(data)
	if problem == "":
		problem = target.farm_from_dict(data)
	var got: Dictionary = target.loadout_of("player_1")
	# A table that is not a table is refused whole, as the farm's other data is.
	data["player_loadouts"] = { "player_1": "no" }
	var refused: String = target.farm_dict_problem(data)
	data["player_loadouts"] = { "player_1": { "name": "N".repeat(99), "parts": {} } }
	var too_long: String = target.farm_dict_problem(data)
	source.free()
	target.free()
	if problem != "":
		return "An unknown part is not a damaged save, got '%s'" % problem
	if got["parts"][Loadout.HEAD] != &"survey_helmet" or got["parts"][Loadout.WHEELS] != &"wide_crawler_tracks" or got["name"] != "Quill":
		return "The unknown part must be the default and the rest kept, got %s" % [got]
	return "" if refused != "" and too_long != "" else "A bad entry must be refused"


func test_the_walker_wears_what_it_is_given() -> String:
	var model := WalkerModel.new()
	var bare: int = _count_meshes(model)
	model.set_loadout(Loadout.default_parts())
	var still_bare: int = _count_meshes(model)
	var dressed: Dictionary = Loadout.default_parts()
	dressed[Loadout.HEAD] = &"sun_brim_hat"
	dressed[Loadout.UPPER] = &"botanist_field_vest"
	dressed[Loadout.LOWER] = &"thermal_basalt_greaves"
	model.set_loadout(dressed)
	var worn: int = _count_meshes(model)
	model.set_loadout(dressed)
	var again: int = _count_meshes(model)
	model.set_loadout(Loadout.default_parts())
	var back: int = _count_meshes(model)
	model.free()
	if bare != still_bare or back != bare:
		return "The defaults add nothing: %d, %d, %d" % [bare, still_bare, back]
	if worn <= bare or again != worn:
		return "Parts add boxes, once: %d, %d, %d" % [bare, worn, again]
	return ""


func _count_meshes(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _count_meshes(child)
	return count


func test_the_rover_takes_the_owner_s_parts_and_the_defaults_change_nothing() -> String:
	var snap: Dictionary = _snapshot()
	GameState.player_loadouts = {}
	var rover := RoverController.new()
	_root().add_child(rover)
	rover._refresh_loadout()
	var plain: Dictionary = rover.drive_factors().duplicate()
	var plain_look: Node = rover.get_node_or_null("LoadoutLook")
	GameState.set_loadout("", Loadout.encode({ Loadout.POWER: &"folding_solar_array", Loadout.WHEELS: &"wide_crawler_tracks",
		Loadout.CHASSIS: &"flatbed_cargo_frame" }))
	rover._refresh_loadout()
	var worn: Dictionary = rover.drive_factors().duplicate()
	var look: Node = rover.get_node_or_null("LoadoutLook")
	if look == null:
		look = rover.find_child("LoadoutLook", true, false)
	var boxes: int = look.get_child_count() if look != null else 0
	GameState.player_loadouts = {}
	rover._refresh_loadout()
	var gone: Node = rover.find_child("LoadoutLook", true, false)
	_free(rover)
	_restore(snap)
	for key: StringName in Loadout.DRIVE_KEYS:
		if plain[key] != 1.0:
			return "The defaults must be exactly 1, %s is %s" % [key, plain[key]]
	if plain_look != null or gone != null:
		return "The default parts draw nothing"
	if not is_equal_approx(worn[&"speed"], 1.1 * 0.85) or boxes == 0:
		return "The fitted parts must change the drive (%s) and show (%d boxes)" % [worn, boxes]
	return ""


func test_p_opens_the_picker_and_blocks_the_rover_until_it_closes() -> String:
	var snap: Dictionary = _snapshot()
	RoverController.input_blocked = false
	var picker: PickerUI = _picker()
	picker._unhandled_input(_key(KEY_P))
	var opened: bool = picker.visible
	var blocked: bool = RoverController.input_blocked
	var modal: bool = picker.is_in_group(QuestsUI.MODAL_GROUP)
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	picker._unhandled_input(escape)
	var closed: bool = not picker.visible
	var freed: bool = not RoverController.input_blocked
	_free(picker)
	_restore(snap)
	if not opened or not blocked or not modal:
		return "P opens it, as a modal panel, with the rover blocked"
	return "" if closed and freed else "Esc must close it and give the rover back its controls"


func test_a_picker_torn_down_open_gives_the_rover_its_controls_back() -> String:
	var snap: Dictionary = _snapshot()
	RoverController.input_blocked = false
	var picker: PickerUI = _picker()
	picker.open()
	_free(picker)
	var freed: bool = not RoverController.input_blocked
	_restore(snap)
	return "" if freed else "The rover must not stay blocked"


func test_the_picker_cycles_names_and_applies() -> String:
	var snap: Dictionary = _snapshot()
	GameState.player_loadouts = {}
	var picker: PickerUI = _picker()
	picker.open()
	var start: String = picker._part_labels[Loadout.WHEELS].text
	picker._next_buttons[Loadout.WHEELS].pressed.emit()
	var second: String = picker._part_labels[Loadout.WHEELS].text
	var trade: String = picker._trade_labels[Loadout.WHEELS].text
	picker._prev_buttons[Loadout.WHEELS].pressed.emit()
	picker._prev_buttons[Loadout.WHEELS].pressed.emit()
	var wrapped: String = picker._part_labels[Loadout.WHEELS].text
	for i: int in 2:
		picker._next_buttons[Loadout.WHEELS].pressed.emit()
	var head_trade: String = picker._trade_labels[Loadout.HEAD].text
	picker._next_buttons[Loadout.HEAD].pressed.emit()
	picker._next_buttons[Loadout.POWER].pressed.emit()
	picker.set_chosen_name("Quill")
	picker._apply_button.pressed.emit()
	var got: Dictionary = GameState.loadout_of(GameState.local_player_id)
	var shut: bool = not picker.visible
	_free(picker)
	_restore(snap)
	if start != "Standard Ag Tires" or second != "Wide Crawler Tracks" or wrapped != "Six-Wheel Survey Bogie":
		return "Cycling goes round: %s, %s, %s" % [start, second, wrapped]
	if not trade.contains("+") or not trade.contains("−") or head_trade != PickerUI.NO_TRADE_OFF:
		return "Wheels say what they give and take; a hat is a look only: '%s', '%s'" % [trade, head_trade]
	if got["name"] != "Quill" or got["parts"][Loadout.HEAD] != &"mechanic_cap_goggles" \
			or got["parts"][Loadout.POWER] != &"twin_cell_battery_pack" or got["parts"][Loadout.WHEELS] != &"wide_crawler_tracks":
		return "Apply must set the loadout, got %s" % [got]
	return "" if shut else "Applying closes the picker"


func test_closing_without_applying_changes_nothing() -> String:
	var snap: Dictionary = _snapshot()
	GameState.player_loadouts = {}
	var picker: PickerUI = _picker()
	picker.open()
	picker._next_buttons[Loadout.CHASSIS].pressed.emit()
	picker.set_chosen_name("Nope")
	picker.close()
	var got: Dictionary = GameState.loadout_of(GameState.local_player_id)
	picker.open()
	var reopened: Dictionary = picker.chosen()
	var name_back: String = picker.chosen_name()
	_free(picker)
	_restore(snap)
	if got["name"] != "" or got["parts"] != Loadout.default_parts() or reopened != Loadout.default_parts() or name_back != "":
		return "Closing throws the choices away"
	return ""


func test_the_name_field_holds_no_more_than_the_limit() -> String:
	var picker: PickerUI = _picker()
	var limit: int = picker._name_field.max_length
	_free(picker)
	return "" if limit == Loadout.MAX_NAME else "The field holds %d" % limit


func test_the_pad_can_work_the_picker() -> String:
	var snap: Dictionary = _snapshot()
	var picker: PickerUI = _picker()
	picker.open()
	var first: Control = picker.get_viewport().gui_get_focus_owner()
	var ok_focus: bool = first == picker._next_buttons[Loadout.SLOTS[0]]
	# Every control a pad has to reach can take the focus.
	var unreachable: PackedStringArray = []
	var controls: Array[Control] = [picker._apply_button, picker._close_button, picker._name_field]
	for slot: StringName in Loadout.SLOTS:
		controls.append_array([picker._prev_buttons[slot], picker._next_buttons[slot]])
	for control: Control in controls:
		if control.focus_mode != Control.FOCUS_ALL:
			unreachable.append(control.name)
	# A press of A (ui_accept) on a focused arrow cycles it, as a click does.
	var before: String = picker._part_labels[Loadout.SLOTS[0]].text
	(first as Button).pressed.emit()
	var after: String = picker._part_labels[Loadout.SLOTS[0]].text
	var pad_close := InputEventJoypadButton.new()
	pad_close.button_index = JOY_BUTTON_X
	pad_close.pressed = true
	var pad_swallowed: bool = true
	picker._unhandled_input(pad_close)
	if not picker.visible:
		pad_swallowed = false
	picker.close()
	var returned: bool = picker.get_viewport().gui_get_focus_owner() == null or not picker.is_ancestor_of(picker.get_viewport().gui_get_focus_owner())
	_free(picker)
	_restore(snap)
	if not ok_focus or not unreachable.is_empty():
		return "A pad must land on the first arrow and reach all: %s" % [unreachable]
	if before == after:
		return "A press on an arrow must cycle the part"
	return "" if returned and pad_swallowed else "Pad presses must not leak to the farm, and closing gives the focus up"


func test_a_new_farm_offers_the_picker_once() -> String:
	var snap: Dictionary = _snapshot()
	PickerUI.offer_next = true
	var first: PickerUI = _picker()
	var consumed: bool = not PickerUI.offer_next
	_free(first)
	var second: PickerUI = _picker()
	var quiet: bool = not second.visible
	_free(second)
	_restore(snap)
	return "" if consumed and quiet else "The offer is made once"


func test_the_actions_menu_and_the_controls_guide_list_the_picker() -> String:
	var in_menu: bool = ActionsMenuUI.ENTRIES.any(func(entry: Dictionary) -> bool: return entry["action"] == &"open_picker")
	var on_panels: bool = &"open_picker" in ActionsMenuUI.PANEL_ACTIONS
	var in_guide: bool = false
	for group: Dictionary in ControlsGuideUI.GROUPS:
		for line: Dictionary in group["lines"]:
			in_guide = in_guide or line.get("action") == &"open_picker"
	return "" if in_menu and on_panels and in_guide else "The pad's menu (every scene) and the guide list it"
