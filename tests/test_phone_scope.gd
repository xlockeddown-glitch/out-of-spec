extends RefCounted
## The field phone in the Scope family (feat/phone-scope): its own case and glass
## from ScopeTheme, and every row it showed before still there with the same text.

const HudScene: PackedScene = preload("res://ui/field_phone_hud.tscn")


func _hud() -> FieldPhoneHUD:
	var hud: FieldPhoneHUD = HudScene.instantiate() as FieldPhoneHUD
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	return hud


func _free(hud: FieldPhoneHUD) -> void:
	(Engine.get_main_loop() as SceneTree).root.remove_child(hud)
	hud.free()


func test_the_phone_uses_the_scope_theme() -> String:
	var hud: FieldPhoneHUD = _hud()
	var problem: String = ""
	var case_box := (hud.get_node("Bezel") as Control).get_theme_stylebox("panel") as StyleBoxFlat
	var glass_box := (hud.get_node("Bezel/Screen") as Control).get_theme_stylebox("panel") as StyleBoxFlat
	var band := hud.get_node("Band") as PanelContainer
	if hud.theme != ScopeTheme.theme():
		problem = "The phone must carry the Scope theme."
	elif case_box.bg_color != ScopeTheme.ENAMEL or case_box.border_color != ScopeTheme.TERRA_DARK:
		problem = "The case must be putty with a terracotta edge."
	elif glass_box.bg_color != ScopeTheme.SHADOW:
		problem = "The screen must be the dark Scope glass."
	elif (band.get_theme_stylebox("panel") as StyleBoxFlat).bg_color != ScopeTheme.TERRA:
		problem = "The band across the top must be terracotta."
	elif hud._zero_button.theme_type_variation != ScopeTheme.PHONE_KEY_OUTLINE \
			or (hud._zero_button.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_left != 8.0:
		problem = "The zero key must be the small outlined phone key."
	elif (hud._zero_button.get_theme_stylebox("normal") as StyleBoxFlat).border_width_bottom > 4:
		problem = "The phone keys' bottom edge must fit their small margins."
	_free(hud)
	return problem


func test_the_cards_are_cream_with_dark_ink_and_a_state_chip() -> String:
	var hud: FieldPhoneHUD = _hud()
	var problem: String = ""
	var cards: Array[PanelContainer] = []
	for card_name: String in ["HeaderCard", "DriftCard", "LogCard"]:
		cards.append(hud.get_node("Bezel/Screen/Content/" + card_name) as PanelContainer)
	var captions: Array[Label] = [hud._tolerance_label, hud._drift_value.get_parent().get_child(0) as Label,
		hud._log_label.get_parent().get_child(0) as Label]
	var plain: Array[Label] = [hud._clock_label, hud._credits_label, hud._drift_value, hud._log_label]
	hud.set_credits(5)
	hud.set_drift(0.3, DriftingSensor.Band.GUARDBAND)
	for card: PanelContainer in cards:
		if card.theme_type_variation != ScopeTheme.PHONE_CARD:
			problem = "%s must carry ScopePhoneCard." % card.name
		elif (card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color != ScopeTheme.ENAMEL_TOP:
			problem = "%s must be cream." % card.name
	for label: Label in plain:
		if problem == "" and label.get_theme_color("font_color") != ScopeTheme.CARD_INK:
			problem = "Text on a card must be the dark card ink: %s" % label.name
	for label: Label in captions:
		if problem == "" and label.get_theme_color("font_color") != ScopeTheme.CARD_INK_MUTED:
			problem = "A caption on a card must be the muted card ink: %s" % label.name
	hud.set_credits(-5)
	if problem == "" and hud._credits_label.get_theme_color("font_color") != ScopeTheme.CARD_ALERT:
		problem = "Negative credits must be the card alert red."
	var bands: Array[int] = [DriftingSensor.Band.IN_BAND, DriftingSensor.Band.GUARDBAND, DriftingSensor.Band.OUT_OF_TOLERANCE]
	var wants: Array[Color] = [ScopeTheme.TEAL, ScopeTheme.AMBER, ScopeTheme.RED]
	var chip := hud._status_label.get_parent() as PanelContainer
	for i: int in bands.size():
		hud.set_drift(0.3, bands[i])
		var edge := chip.get_theme_stylebox("panel") as StyleBoxFlat
		if problem == "" and (hud._status_label.get_theme_color("font_color") != wants[i] 				or edge.border_color != wants[i] or edge.bg_color != ScopeTheme.GLASS_DEEP 				or hud._drift_value.get_theme_color("font_color") != ScopeTheme.CARD_INK):
			problem = "The state chip must follow band %d." % bands[i]
	if problem == "" and chip.get_parent().get_parent().name != &"DriftCard":
		problem = "The chip must sit on the drift card."
	if problem == "" and hud._clock_label.get_parent().get_parent().get_parent() != cards[0]:
		problem = "Day, time and credits must sit on the header card."
	if problem == "" and (hud._zero_button.get_parent().get_parent() != cards[1] or hud._log_label.get_parent().get_parent() != cards[2]):
		problem = "The zero key belongs on the drift card and the log on the log card."
	if problem == "" and hud._zero_button.theme_type_variation != ScopeTheme.PHONE_KEY_OUTLINE:
		problem = "The zero key must be outlined."
	_free(hud)
	return problem


func test_the_case_is_the_same_size_and_the_other_keys_still_work() -> String:
	var holder := Control.new()
	holder.size = Vector2(1920, 1080)
	(Engine.get_main_loop() as SceneTree).root.add_child(holder)
	var hud: FieldPhoneHUD = HudScene.instantiate() as FieldPhoneHUD
	holder.add_child(hud)
	var problem: String = ""
	# The phone column keeps its width (0.8 of 0.32 of 1080p) and full height.
	var width: float = 1920.0 * (1.0 - hud.anchor_left)
	if absf(width - 491.5) > 2.0:
		problem = "The phone must stay 491.5 px wide at 1080p: %s" % width
	var pressed: Array[String] = []
	hud.slot_spool_pressed.connect(func() -> void: pressed.append("spool"))
	hud.enter_dome_pressed.connect(func() -> void: pressed.append("dome"))
	hud._slot_spool_button.pressed.emit()
	hud._dome_button.pressed.emit()
	if problem == "" and pressed != ["spool", "dome"]:
		problem = "The spool and dome keys must send their signals: %s" % [pressed]
	for key: Button in [hud._slot_spool_button, hud._dome_button, hud._trade_button]:
		if problem == "" and key.theme_type_variation != ScopeTheme.PHONE_KEY:
			problem = "%s must be a phone key." % key.name
	hud.set_relay(false, false, "0", false)
	if problem == "" and hud._relay_status_label.get_theme_color("font_color") != ScopeTheme.INK_MUTED:
		problem = "A stock relay must be muted."
	hud.set_relay(true, true, "0", false)
	if problem == "" and hud._relay_status_label.get_theme_color("font_color") != FieldPhoneHUD.COLOR_WARN:
		problem = "A damaged relay must be amber."
	hud.set_relay(true, false, "0", false)
	if problem == "" and hud._relay_status_label.get_theme_color("font_color") != ScopeTheme.TEAL:
		problem = "A working relay must be teal."
	if problem == "" and hud._link_label.get_theme_color("font_color") != ScopeTheme.INK_MUTED:
		problem = "The link text must be muted until the uplink is set."
	holder.remove_child(hud)
	hud.free()
	(Engine.get_main_loop() as SceneTree).root.remove_child(holder)
	holder.free()
	return problem


func test_every_row_the_phone_showed_is_still_there() -> String:
	var hud: FieldPhoneHUD = _hud()
	hud.configure("SAT-RELAY", 0.5, 0.25)
	hud.set_clock("DAY 3  09:40")
	hud.set_credits(1240)
	hud.set_uplink(true, 0.75, 0.32)
	hud.set_drift(0.31, DriftingSensor.Band.GUARDBAND)
	hud.set_relay(true, false, "2", true)
	hud.set_ore(4)
	hud.set_credibility("TRUSTED, 40 % to ACCREDITED", "Contract", "LEVEL 4")
	hud.set_gauge_set("GAUGE SET 12/81")
	hud.set_lights(true)
	hud.push_log("one")
	var got: Dictionary[String, String] = {
		"clock": hud._clock_label.text, "credits": hud._credits_label.text, "relay": hud._relay_label.text,
		"link": hud._link_label.text, "lag": hud._lag_label.text, "status": hud._status_label.text,
		"tol": hud._tolerance_label.text, "relay_status": hud._relay_status_label.text,
		"spools": hud._spool_label.text, "ore": hud._ore_label.text, "cred": hud._credibility_label.text,
		"gauge": hud._gauge_label.text, "lights": hud._lights_label.text, "log": hud._log_label.text,
		"title": (hud.get_node("Bezel/Screen/Content/Title") as Label).text,
		"caption": ((hud.get_node("Bezel/Screen/Content/DriftCard") as Control).get_child(0).get_child(0) as Label).text,
	}
	var want: Dictionary[String, String] = {
		"clock": "DAY 3  09:40", "credits": "1 240 CR", "relay": "SAT-RELAY", "link": "LOS CLEAR",
		"lag": "UPLINK LAG  320 ms", "status": "IN GUARD BAND", "tol": "MPE ±0.50°   ACCEPT ±0.13° (25 %)",
		"relay_status": "RELAY: OPTICAL SILK", "spools": "SILK SPOOLS 2", "ore": "ORE 4   ",
		"cred": "CRED: TRUSTED, 40 % to ACCREDITED\nLAB: LEVEL 4\nContract", "gauge": "GAUGE SET 12/81",
		"lights": "LIGHTS: ON", "log": "one", "title": "FIELD PHONE // UPLINK", "caption": "STEERING DRIFT (AS-FOUND)",
	}
	var problem: String = ""
	for key: String in want:
		# Numbers format through SP811, so only the digits are compared for credits.
		if key == "credits":
			if not (hud._credits_label.text.ends_with(" CR") and hud._credits_label.text.contains("240")):
				problem = "Credits row changed: %s" % hud._credits_label.text
		elif str(got[key]) != str(want[key]):
			problem = "Row %s changed: %s" % [key, got[key]]
	if problem == "" and (hud._drift_value.text != SP811.signed(0.31) + "°" or hud._drift_value.get_parent().get_parent().name != &"DriftCard"):
		problem = "The drift reading must sit on its card: %s" % hud._drift_value.text
	# The keys the phone had are still its buttons.
	if problem == "" and (not hud._zero_button.text.begins_with("ZERO STEERING") or not hud._dome_button.text.begins_with("ENTER DOME") \
			or hud._slot_spool_button.text != "INSTALL SILK SPOOL" or hud._slot_spool_button.disabled):
		problem = "The phone's keys changed: %s | %s | %s" % [hud._zero_button.text, hud._dome_button.text, hud._slot_spool_button.text]
	_free(hud)
	return problem


func test_bram_and_the_jobs_keep_their_rows_and_work() -> String:
	var hud: FieldPhoneHUD = _hud()
	var pressed: Array[String] = []
	hud.trade_pressed.connect(func() -> void: pressed.append("trade"))
	hud.zero_steering_pressed.connect(func() -> void: pressed.append("zero"))
	hud.buy_standard_pressed.connect(func(id: String) -> void: pressed.append(id))
	hud.wheel_service_pressed.connect(func() -> void: pressed.append("wheels"))
	hud.accept_job_pressed.connect(func(i: int) -> void: pressed.append("job%d" % i))
	var standards: Array[Dictionary] = [{"id": "a", "text": "BUY A", "disabled": false}]
	var offers: Array[Dictionary] = [{"text": "Recal", "disabled": false}]
	var empty: Array[Dictionary] = []
	hud._process(0.0)
	var zero_key: String = "[%s]" % Controls.short_prompt(&"rover_zero_steering")
	hud.show_bram("Treads for ore.", 6, 9, false)
	hud.show_standards(standards, "")
	hud.show_wheel_service("Wheel nuts due", true)
	hud.show_jobs(PackedStringArray(["Dome seal check"]), offers, "")
	hud.set_molt("MOLT: DUE")
	var problem: String = ""
	var accept: Button = hud._jobs_box.get_child(1) as Button
	if not hud._bram_panel.visible or hud._bram_label.text != "BRAM: Treads for ore.":
		problem = "Bram's line must show."
	elif hud._trade_button.text != "TRADE 6 ORE: WIDE TREADS  [%s]" % Controls.short_prompt(&"interact"):
		problem = "Bram's trade key changed: %s" % hud._trade_button.text
	elif hud._zero_button.text != "ZERO STEERING  " + zero_key:
		problem = "The zero key must end in its prompt: %s" % hud._zero_button.text
	elif (hud._standards_box.get_child(0) as Button).theme_type_variation != ScopeTheme.PHONE_KEY:
		problem = "Bram's stock must be phone keys."
	elif hud._wheels_button.text != "Wheel nuts due  [%s]" % Controls.short_prompt(&"wheel_service") \
			or hud._wheels_button.theme_type_variation != ScopeTheme.PHONE_KEY:
		problem = "The wheel key changed: %s" % hud._wheels_button.text
	elif not hud._molt_label.visible or hud._molt_label.text != "MOLT: DUE":
		problem = "The molt row must show its text."
	elif (hud._jobs_box.get_child(0) as Label).text != "Dome seal check" or accept.text != "ACCEPT Recal" \
			or accept.theme_type_variation != ScopeTheme.PHONE_KEY:
		problem = "The job list changed."
	else:
		hud._trade_button.pressed.emit()
		hud._zero_button.pressed.emit()
		(hud._standards_box.get_child(0) as Button).pressed.emit()
		hud._wheels_button.pressed.emit()
		accept.pressed.emit()
		if pressed != ["trade", "zero", "a", "wheels", "job0"]:
			problem = "Keys must still send their signals: %s" % [pressed]
	# show_jobs queue_frees the old rows; free them now so the test leaves no orphans.
	for old: Node in hud._jobs_box.get_children():
		hud._jobs_box.remove_child(old)
		old.free()
	hud.show_jobs(PackedStringArray(), empty, "No offers today")
	if problem == "" and ((hud._jobs_box.get_child(0) as Label).text != "No offers today" \
			or (hud._jobs_box.get_child(0) as Label).get_theme_color("font_color") != ScopeTheme.INK_MUTED):
		problem = "The jobs note must be a muted caption."
	hud.hide_bram()
	if problem == "" and hud._bram_panel.visible:
		problem = "Leaving Bram's bay must hide his panel."
	_free(hud)
	return problem
