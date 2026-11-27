extends RefCounted
## UI restyle part 2 (feat/ui-restyle-2): pause, title, skills and XP
## certificate screens use ScopeTheme and keep their buttons and named nodes.

const TitleScene: PackedScene = preload("res://scenes/title_menu.tscn")


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _find_panel(root: Node, variation: StringName) -> PanelContainer:
	for child: Node in root.get_children():
		if child is PanelContainer and (child as PanelContainer).theme_type_variation == variation:
			return child as PanelContainer
		var found: PanelContainer = _find_panel(child, variation)
		if found != null:
			return found
	return null


func _button_texts(parent: Node) -> Array[String]:
	var out: Array[String] = []
	for child: Node in parent.get_children():
		if child is Button:
			out.append((child as Button).text)
	return out


func test_pause_ui_uses_scope_theme_and_keeps_its_buttons() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var pause := PauseUI.new()
	_root().add_child(pause)
	var problem: String = ""
	var shell: PanelContainer = _find_panel(pause, ScopeTheme.SHELL)
	var header: PanelContainer = _find_panel(pause, ScopeTheme.HEADER)
	var glass: PanelContainer = _find_panel(pause, ScopeTheme.GLASS)
	if pause.theme != ScopeTheme.theme():
		problem = "PauseUI must carry ScopeTheme."
	elif shell == null or header == null or glass == null:
		problem = "PauseUI needs shell, header and glass panels."
	elif (shell.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color != ScopeTheme.ENAMEL:
		problem = "PauseUI shell must use ScopeTheme enamel."
	elif (pause._resume_button.get_theme_stylebox(&"normal") as StyleBoxFlat).bg_color != ScopeTheme.ENAMEL_INSET:
		problem = "PauseUI buttons must use ScopeTheme button style."
	elif pause._title == null or pause._text == null or pause._note == null:
		problem = "PauseUI labels must still exist."
	elif not pause._resume_button.text.begins_with("RESUME") or pause._quit_button.text != "SAVE AND QUIT":
		problem = "PauseUI buttons changed: %s | %s" % [pause._resume_button.text, pause._quit_button.text]
	elif pause._resume_button.get_node_or_null("PadGlyph") == null:
		problem = "PauseUI resume button needs its pad glyph."
	_free(pause)
	tree.paused = false
	RoverController.input_blocked = false
	return problem


func test_title_menu_uses_scope_theme_and_keeps_its_buttons() -> String:
	var saved_paused: bool = GameClock.paused
	var saved_speed: float = GameClock.seconds_per_day
	var saved_note: String = CoopScenes._note
	var title: Control = TitleScene.instantiate() as Control
	_root().add_child(title)
	var problem: String = ""
	var shell: PanelContainer = _find_panel(title, ScopeTheme.SHELL)
	var header: PanelContainer = _find_panel(title, ScopeTheme.HEADER)
	var glass: PanelContainer = _find_panel(title, ScopeTheme.GLASS)
	var main_texts: Array[String] = _button_texts(title._main_buttons)
	var confirm_texts: Array[String] = _button_texts(title._confirm_buttons)
	var join_texts: Array[String] = _button_texts(title._join_buttons)
	if title.theme != ScopeTheme.theme():
		problem = "TitleMenu must carry ScopeTheme."
	elif shell == null or header == null or glass == null:
		problem = "TitleMenu needs shell, header and glass panels."
	elif (shell.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color != ScopeTheme.ENAMEL:
		problem = "TitleMenu shell must use ScopeTheme enamel."
	elif (title._address.get_theme_stylebox(&"normal") as StyleBoxFlat).bg_color != ScopeTheme.GLASS_DEEP:
		problem = "TitleMenu address field must use ScopeTheme LineEdit style."
	elif (title._join_button.get_theme_stylebox(&"normal") as StyleBoxFlat).bg_color != ScopeTheme.ENAMEL_INSET:
		problem = "TitleMenu buttons must use ScopeTheme button style."
	elif not ("NEW FARM" in main_texts and "JOIN A FRIEND" in main_texts and "QUIT" in main_texts):
		problem = "TitleMenu main buttons changed: %s" % [main_texts]
	elif confirm_texts != ["START A NEW FARM", "BACK"]:
		problem = "TitleMenu confirm buttons changed: %s" % [confirm_texts]
	elif join_texts != ["JOIN", "BACK"] or title._address == null or title._note == null:
		problem = "TitleMenu join controls changed: %s" % [join_texts]
	_free(title)
	GameClock.paused = saved_paused
	GameClock.seconds_per_day = saved_speed
	CoopScenes._note = saved_note
	return problem


func test_skills_ui_uses_scope_theme_and_keeps_its_rows_and_buttons() -> String:
	var kept: Dictionary = SaveGame.snapshot()
	var me: String = GameState.local_player_id
	GameState.xp_certificates = { me: { "lump#1": 200 } }
	GameState.xp_certificates_given = 1
	var view := SkillsUI.new()
	_root().add_child(view)
	view.open()
	var problem: String = ""
	var shell: PanelContainer = _find_panel(view, ScopeTheme.SHELL)
	var header: PanelContainer = _find_panel(view, ScopeTheme.HEADER)
	var glass: PanelContainer = _find_panel(view, ScopeTheme.GLASS)
	var cards: int = 0
	for child: Node in view._rows.get_children():
		if child is PanelContainer and (child as PanelContainer).theme_type_variation == ScopeTheme.CARD:
			cards += 1
	var row_buttons: Array[String] = _button_texts(view._rows)
	if view.theme != ScopeTheme.theme():
		problem = "SkillsUI must carry ScopeTheme."
	elif shell == null or header == null or glass == null:
		problem = "SkillsUI needs shell, header and glass panels."
	elif (shell.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color != ScopeTheme.ENAMEL:
		problem = "SkillsUI shell must use ScopeTheme enamel."
	elif (view._close_button.get_theme_stylebox(&"normal") as StyleBoxFlat).bg_color != ScopeTheme.ENAMEL_INSET:
		problem = "SkillsUI close button must use ScopeTheme button style."
	elif cards != 1 + GameState.skill_ids().size():
		problem = "SkillsUI must show a card for the lab and each skill: %d" % cards
	elif row_buttons != ["SPEND AN XP CERTIFICATE  (1 held)"]:
		problem = "SkillsUI spend button changed: %s" % [row_buttons]
	elif not view._close_button.text.begins_with("CLOSE") or view._close_button.get_node_or_null("PadGlyph") == null:
		problem = "SkillsUI close button or pad glyph missing."
	elif view._picker == null:
		problem = "SkillsUI must still own its XpCertificateUI picker."
	_free(view)
	var back: String = SaveGame.restore(kept)
	return problem if problem != "" else back


func test_xp_certificate_ui_uses_scope_theme_and_keeps_its_rows_and_buttons() -> String:
	var kept: Dictionary = SaveGame.snapshot()
	var me: String = GameState.local_player_id
	GameState.xp_certificates = { me: { "lump#1": 200 } }
	GameState.xp_certificates_given = 1
	var picker := XpCertificateUI.new()
	_root().add_child(picker)
	picker.open()
	var problem: String = ""
	var shell: PanelContainer = _find_panel(picker, ScopeTheme.SHELL)
	var header: PanelContainer = _find_panel(picker, ScopeTheme.HEADER)
	var glass: PanelContainer = _find_panel(picker, ScopeTheme.GLASS)
	var row_buttons: Array[String] = _button_texts(picker._rows)
	if picker.theme != ScopeTheme.theme():
		problem = "XpCertificateUI must carry ScopeTheme."
	elif shell == null or header == null or glass == null:
		problem = "XpCertificateUI needs shell, header and glass panels."
	elif (shell.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color != ScopeTheme.ENAMEL:
		problem = "XpCertificateUI shell must use ScopeTheme enamel."
	elif (picker._close_button.get_theme_stylebox(&"normal") as StyleBoxFlat).bg_color != ScopeTheme.ENAMEL_INSET:
		problem = "XpCertificateUI back button must use ScopeTheme button style."
	elif row_buttons.size() != XpCertificateUI.choices(GameState, "lump#1", me).size():
		problem = "XpCertificateUI must list one button per personal skill: %d" % row_buttons.size()
	elif not picker._close_button.text.begins_with("BACK") or picker._close_button.get_node_or_null("PadGlyph") == null:
		problem = "XpCertificateUI back button or pad glyph missing."
	elif picker._note == null:
		problem = "XpCertificateUI note label missing."
	_free(picker)
	var back: String = SaveGame.restore(kept)
	return problem if problem != "" else back
