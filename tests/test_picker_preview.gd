extends RefCounted
## Live 3D turntable and combined drive-stat preview inside PickerUI
## (feat/picker-preview). Local-only UI; frees every node it creates.


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


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


func _picker() -> PickerUI:
	var picker := PickerUI.new()
	_root().add_child(picker)
	return picker


func test_preview_shows_defaults_on_open() -> String:
	var snap: Dictionary = _snapshot()
	GameState.player_loadouts.erase(GameState.local_player_id)
	var picker: PickerUI = _picker()
	picker.open()
	var preview := picker.find_child("PickerPreview", true, false) as PickerPreview
	var problem: String = ""
	if preview == null:
		problem = "PickerUI is missing PickerPreview."
	elif preview.walker_model() == null:
		problem = "PickerPreview has no WalkerModel."
	elif preview.tractor_look_count() != 0:
		problem = "Default tractor should add 0 extra look meshes, got %d." % preview.tractor_look_count()
	else:
		for key: StringName in Loadout.DRIVE_KEYS:
			if preview.stat_text(key) != PickerPreview.BASE_TEXT:
				problem = "Default %s should read %s, got '%s'." % [key, PickerPreview.BASE_TEXT, preview.stat_text(key)]
				break
			if preview.stat_color(key) != ScopeTheme.INK_MUTED:
				problem = "Default %s should use ScopeTheme.INK_MUTED." % key
				break
	_free(picker)
	_restore(snap)
	return problem


func test_cycling_parts_updates_3d_preview_and_combined_drive_stats() -> String:
	var snap: Dictionary = _snapshot()
	GameState.player_loadouts.erase(GameState.local_player_id)
	var picker: PickerUI = _picker()
	picker.open()
	var preview := picker.find_child("PickerPreview", true, false) as PickerPreview
	var problem: String = ""
	if preview == null:
		problem = "PickerUI is missing PickerPreview."
	else:
		# Cycle head, chassis, power (Twin-Cell Battery Pack: +20 % accel, -5 % speed),
		# and wheels (Wide Crawler Tracks: +25 % wade, -15 % speed, -20 % turn).
		picker.cycle(Loadout.HEAD, 1)
		picker.cycle(Loadout.CHASSIS, 1)
		picker.cycle(Loadout.POWER, 1)
		picker.cycle(Loadout.WHEELS, 1)
		var walker_parts: Dictionary = preview.walker_model().loadout()
		if walker_parts[Loadout.HEAD] != &"mechanic_cap_goggles":
			problem = "Preview walker did not take head part: %s" % walker_parts[Loadout.HEAD]
		elif preview.tractor_look_count() == 0:
			problem = "Preview tractor should show look meshes for non-default parts."
		elif preview.stat_text(&"accel") != "+20 %":
			problem = "Expected '+20 %%' accel, got '%s'." % preview.stat_text(&"accel")
		elif preview.stat_color(&"accel") != ScopeTheme.TEAL:
			problem = "Improved stat must use ScopeTheme.TEAL."
		elif preview.stat_text(&"wade") != "+25 %":
			problem = "Expected '+25 %%' wade, got '%s'." % preview.stat_text(&"wade")
		elif preview.stat_text(&"turn") != SP811.MINUS + "20 %":
			problem = "Expected SP 811 minus '20 %%' turn, got '%s'." % preview.stat_text(&"turn")
		elif preview.stat_color(&"turn") != ScopeTheme.AMBER:
			problem = "Traded-down stat must use ScopeTheme.AMBER."
		elif preview.stat_text(&"speed") != SP811.MINUS + "19 %":
			# Combined speed: 0.95 * 0.85 = 0.8075 -> -19.25 % -> -19 %.
			problem = "Expected combined speed '%s19 %%', got '%s'." % [SP811.MINUS, preview.stat_text(&"speed")]
		elif preview.stat_text(&"brake") != PickerPreview.BASE_TEXT:
			problem = "Unchanged brake should stay Base, got '%s'." % preview.stat_text(&"brake")
	_free(picker)
	_restore(snap)
	return problem
