extends RefCounted
## In-world quest board marker (feat/quest-marker): shows over the farm notice
## board when QuestSeen reports any unseen open quest, hides once seen, and uses
## ScopeTheme colours only. Local-only UI.

const SEEN_PATH: String = "user://test_quest_board_marker_seen.cfg"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _farm_quest_ids(count: int) -> Array[String]:
	var ids: Array[String] = []
	for quest: Dictionary in QuestEngine.quests():
		if str(quest.get("scope", "")) == "farm" and str(quest.get("kind", "")) in ["story", "lab"]:
			ids.append(str(quest["id"]))
			if ids.size() >= count:
				break
	return ids


func _snapshot() -> Dictionary:
	return {
		"quest_state": GameState.quest_state.duplicate(true),
		"player_quest_state": GameState.player_quest_state.duplicate(true),
		"seen_path": QuestSeen.path,
	}


func _restore(snap: Dictionary) -> void:
	GameState.quest_state = snap["quest_state"]
	GameState.player_quest_state = snap["player_quest_state"]
	DirAccess.remove_absolute(SEEN_PATH)
	QuestSeen.path = snap["seen_path"]
	QuestSeen.reset()


func _clean_seen() -> void:
	QuestSeen.path = SEEN_PATH
	DirAccess.remove_absolute(SEEN_PATH)
	QuestSeen.reset()


func _open_entry() -> Dictionary:
	return { "accepted": 1, "steps_done": [], "base": {}, "shown": {}, "players": [], "done": -1 }


func test_marker_hides_when_there_are_no_open_quests() -> String:
	var snap: Dictionary = _snapshot()
	_clean_seen()
	GameState.quest_state = {}
	GameState.player_quest_state = {}
	var marker := QuestBoardMarker.new()
	_root().add_child(marker)
	var shown: bool = marker.visible
	_free(marker)
	_restore(snap)
	return "" if not shown else "Marker should hide when there are no open quests."


func test_marker_shows_with_unseen_quests_and_hides_when_seen() -> String:
	var snap: Dictionary = _snapshot()
	_clean_seen()
	var ids: Array[String] = _farm_quest_ids(1)
	if ids.is_empty():
		_restore(snap)
		return "No farm story/lab quests found in QuestEngine."
	GameState.quest_state = { ids[0]: _open_entry() }
	GameState.player_quest_state = {}
	var marker := QuestBoardMarker.new()
	_root().add_child(marker)
	var shown_before: bool = marker.visible
	var open_rows: Array = QuestLog.of(GameState, GameState.local_player_id).get(QuestLog.OPEN, [])
	QuestSeen.mark_seen(open_rows)
	var shown_after: bool = marker.visible
	_free(marker)
	_restore(snap)
	if not shown_before:
		return "Marker should show when an open quest is unseen."
	return "" if not shown_after else "Marker should hide once open quests are marked seen."


func test_marker_hides_after_quests_ui_closes_and_returns_on_new_quest() -> String:
	var snap: Dictionary = _snapshot()
	_clean_seen()
	var ids: Array[String] = _farm_quest_ids(2)
	if ids.size() < 2:
		_restore(snap)
		return "Need at least two farm story/lab quests."
	GameState.quest_state = { ids[0]: _open_entry() }
	GameState.player_quest_state = {}
	var marker := QuestBoardMarker.new()
	var ui := QuestsUI.new()
	_root().add_child(marker)
	_root().add_child(ui)
	var before_open: bool = marker.visible
	ui.open()
	ui.close()
	var after_close: bool = marker.visible
	GameState.quest_state[ids[1]] = _open_entry()
	GameState.quests_changed.emit()
	var after_second: bool = marker.visible
	_free(ui)
	_free(marker)
	_restore(snap)
	if not before_open:
		return "Marker should show before the quest board is opened."
	if after_close:
		return "Marker should hide after QuestsUI closes and marks quests seen."
	return "" if after_second else "Marker should show again when another unseen quest arrives."


func test_marker_uses_scope_theme_colours_only() -> String:
	var marker := QuestBoardMarker.new()
	_root().add_child(marker)
	var backing := marker.get_node_or_null("Pivot/Emblem/Backing") as MeshInstance3D
	var stem := marker.get_node_or_null("Pivot/Emblem/Stem") as MeshInstance3D
	var dot := marker.get_node_or_null("Pivot/Emblem/Dot") as MeshInstance3D
	var label := marker.get_node_or_null("Pivot/NewLabel") as Label3D
	var problem: String = ""
	if backing == null or stem == null or dot == null or label == null:
		problem = "Marker is missing one or more expected visual child nodes."
	else:
		var back_mat := backing.material_override as StandardMaterial3D
		var stem_mat := stem.material_override as StandardMaterial3D
		var dot_mat := dot.material_override as StandardMaterial3D
		if back_mat == null or back_mat.albedo_color != ScopeTheme.SHADOW:
			problem = "Backing material must use ScopeTheme.SHADOW."
		elif stem_mat == null or stem_mat.albedo_color != ScopeTheme.AMBER or stem_mat.emission != ScopeTheme.AMBER:
			problem = "Stem material must use ScopeTheme.AMBER."
		elif dot_mat == null or dot_mat.albedo_color != ScopeTheme.AMBER or dot_mat.emission != ScopeTheme.AMBER:
			problem = "Dot material must use ScopeTheme.AMBER."
		elif label.modulate != ScopeTheme.AMBER or label.outline_modulate != ScopeTheme.SHADOW:
			problem = "Label3D must use ScopeTheme.AMBER and ScopeTheme.SHADOW."
	_free(marker)
	return problem
