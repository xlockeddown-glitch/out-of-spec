extends RefCounted
## Guest picker offer (feat/picker-guest-offer): a guest whose player id has no entry in
## the host's synced player_loadouts is offered PickerUI once after the first farm snapshot
## arrives; a guest who already has a loadout, a host, and solo play are unaffected.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const TitleScript: GDScript = preload("res://scripts/ui/title_menu.gd")


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _snapshot() -> Dictionary:
	return {
		"farm": GameState.farm_to_dict(),
		"local": GameState.local_player_id,
		"places": GameState.player_places.duplicate(true),
		"guest": FarmCommands.guest,
		"players": CoopSession.players.duplicate(),
		"own_id": CoopSession._own_id,
		"elapsed": GameClock.elapsed_days,
		"speed": GameClock.seconds_per_day,
		"paused": GameClock.paused,
		"in_bed": CoopBeds.in_bed.duplicate(),
		"farm_open": SaveGame.farm_open,
		"blocked": RoverController.input_blocked,
		"offer": PickerUI.offer_next,
		"note": CoopScenes._note,
	}


func _restore(snap: Dictionary) -> void:
	CoopSession.leave()
	GameState.farm_from_dict(snap["farm"])
	GameState.local_player_id = snap["local"]
	GameState.player_places = snap["places"]
	FarmCommands.guest = snap["guest"]
	CoopSession.players = snap["players"]
	CoopSession._own_id = snap["own_id"]
	GameClock.elapsed_days = snap["elapsed"]
	GameClock.seconds_per_day = snap["speed"]
	GameClock.paused = snap["paused"]
	CoopBeds.in_bed = snap["in_bed"]
	SaveGame.farm_open = snap["farm_open"]
	RoverController.input_blocked = snap["blocked"]
	PickerUI.offer_next = snap["offer"]
	CoopScenes._note = snap["note"]


func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _host_state() -> Node:
	var state: Node = GameStateScript.new()
	state.build_registry()
	return state


func _title() -> Control:
	var title: Control = TitleScript.new()
	_root().add_child(title)
	return title


func _picker() -> PickerUI:
	var picker := PickerUI.new()
	_root().add_child(picker)
	return picker


func test_a_guest_with_no_loadout_is_offered_the_picker_after_snapshot() -> String:
	var snap: Dictionary = _snapshot()
	var host: Node = _host_state()
	host.set_loadout("Host", Loadout.encode({ Loadout.HEAD: &"sun_brim_hat" }), "player_1")
	var bytes: PackedByteArray = FarmSync.capture(host)
	host.free()
	var title: Control = _title()
	var wired: bool = CoopSync.farm_ready.is_connected(title._on_farm_ready)
	# Guest is welcomed, but the farm snapshot has not arrived yet.
	FarmCommands.guest = true
	GameState.local_player_id = "player_2"
	title._on_joined()
	var before_snapshot: bool = PickerUI.offer_next
	# Host snapshot arrives and is applied; CoopSync.farm_ready notifies the title menu.
	var join_problem: String = FarmSync.join(bytes, GameState)
	title._on_farm_ready()
	var offered: bool = PickerUI.offer_next
	_free(title)
	var picker: PickerUI = _picker()
	var consumed: bool = not PickerUI.offer_next
	await _root().get_tree().process_frame
	var opened: bool = picker.visible
	picker.close()
	_free(picker)
	_restore(snap)
	if not wired:
		return "The title menu must listen to CoopSync.farm_ready"
	if before_snapshot:
		return "The picker must not be offered before the host snapshot arrives"
	if join_problem != "":
		return "FarmSync.join failed: %s" % join_problem
	if not offered or not consumed or not opened:
		return "A guest with no loadout must be offered the picker once (offered=%s, consumed=%s, opened=%s)" % [offered, consumed, opened]
	return ""


func test_a_guest_with_a_saved_loadout_is_not_offered_the_picker() -> String:
	var snap: Dictionary = _snapshot()
	var host: Node = _host_state()
	host.set_loadout("Quill", Loadout.encode({ Loadout.WHEELS: &"wide_crawler_tracks" }), "player_2")
	var bytes: PackedByteArray = FarmSync.capture(host)
	host.free()
	var title: Control = _title()
	FarmCommands.guest = true
	GameState.local_player_id = "player_2"
	var join_problem: String = FarmSync.join(bytes, GameState)
	title._on_farm_ready()
	var offered: bool = PickerUI.offer_next
	_free(title)
	var picker: PickerUI = _picker()
	await _root().get_tree().process_frame
	var opened: bool = picker.visible
	_free(picker)
	_restore(snap)
	if join_problem != "":
		return "FarmSync.join failed: %s" % join_problem
	if offered or opened:
		return "A guest with a saved loadout on the host must not be offered the picker"
	return ""


func test_host_and_solo_paths_are_unchanged() -> String:
	var snap: Dictionary = _snapshot()
	GameState.player_loadouts = {}
	GameState.local_player_id = "player_1"
	FarmCommands.guest = false
	# Solo: should_offer_for_guest is false and a plain picker stays closed.
	var solo_check: bool = PickerUI.should_offer_for_guest()
	var title: Control = _title()
	title._on_farm_ready()
	var solo_offered: bool = PickerUI.offer_next
	# Host: hosting with another player in the session is still not a guest.
	CoopSession.players = ["player_1", "player_2"] as Array[String]
	var host_check: bool = PickerUI.should_offer_for_guest()
	title._on_farm_ready()
	var host_offered: bool = PickerUI.offer_next
	_free(title)
	var quiet_picker: PickerUI = _picker()
	await _root().get_tree().process_frame
	var quiet: bool = not quiet_picker.visible
	_free(quiet_picker)
	# New-farm path still works via offer_next.
	PickerUI.offer_next = true
	var new_farm_picker: PickerUI = _picker()
	await _root().get_tree().process_frame
	var new_farm_opened: bool = new_farm_picker.visible
	new_farm_picker.close()
	_free(new_farm_picker)
	_restore(snap)
	if solo_check or solo_offered or host_check or host_offered or not quiet:
		return "Solo and host must not trigger the guest offer"
	return "" if new_farm_opened else "The new-farm offer path must remain unchanged"


func test_guest_offer_is_made_once_and_not_repeated_on_reconnect_with_loadout() -> String:
	var snap: Dictionary = _snapshot()
	var host: Node = _host_state()
	var first_bytes: PackedByteArray = FarmSync.capture(host)
	var title_first: Control = _title()
	FarmCommands.guest = true
	GameState.local_player_id = "player_2"
	var first_problem: String = FarmSync.join(first_bytes, GameState)
	title_first._on_farm_ready()
	_free(title_first)
	# First picker (farm scene) opens and consumes the offer.
	var first_picker: PickerUI = _picker()
	await _root().get_tree().process_frame
	var first_opened: bool = first_picker.visible
	first_picker.close()
	_free(first_picker)
	# Second picker on the same join (e.g. entering the dome) stays quiet.
	await _root().get_tree().process_frame
	var second_picker: PickerUI = _picker()
	await _root().get_tree().process_frame
	var second_quiet: bool = not second_picker.visible
	_free(second_picker)
	# Guest saves a loadout on the host, leaves to the title menu, and reconnects.
	host.set_loadout("Quill", Loadout.encode({ Loadout.POWER: &"folding_solar_array" }), "player_2")
	var reconnect_bytes: PackedByteArray = FarmSync.capture(host)
	host.free()
	var title_again: Control = _title()
	FarmCommands.guest = true
	GameState.local_player_id = "player_2"
	var second_problem: String = FarmSync.join(reconnect_bytes, GameState)
	title_again._on_farm_ready()
	var reconnect_offered: bool = PickerUI.offer_next
	_free(title_again)
	var third_picker: PickerUI = _picker()
	await _root().get_tree().process_frame
	var third_quiet: bool = not third_picker.visible
	_free(third_picker)
	_restore(snap)
	if first_problem != "" or second_problem != "":
		return "FarmSync.join failed: '%s' / '%s'" % [first_problem, second_problem]
	if not first_opened or not second_quiet:
		return "The guest offer must open once per join and not reopen on later scenes"
	if reconnect_offered or not third_quiet:
		return "Reconnecting after saving a loadout must not offer the picker again"
	return ""


func test_title_menu_clears_a_stale_offer() -> String:
	var snap: Dictionary = _snapshot()
	PickerUI.offer_next = true
	var title: Control = _title()
	var cleared: bool = not PickerUI.offer_next
	_free(title)
	_restore(snap)
	return "" if cleared else "Returning to the title menu must clear any leftover picker offer"
