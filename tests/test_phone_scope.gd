extends RefCounted
## The field phone in the Scope family (feat/phone-scope): its own case and glass
## from ScopeTheme, and every row it showed before still there with the same text.

const HudScene: PackedScene = preload("res://ui/field_phone_hud.tscn")


func _hud() -> FieldPhoneHUD:
	var hud: FieldPhoneHUD = HudScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	return hud


func _free(hud: FieldPhoneHUD) -> void:
	(Engine.get_main_loop() as SceneTree).root.remove_child(hud)
	hud.free()


func test_the_phone_uses_the_scope_theme() -> String:
	var hud: FieldPhoneHUD = _hud()
	var problem: String = ""
	var case_box: StyleBoxFlat = hud.get_node("Bezel").get_theme_stylebox("panel")
	var glass_box: StyleBoxFlat = hud.get_node("Bezel/Screen").get_theme_stylebox("panel")
	var band: PanelContainer = hud.get_node("Band")
	if hud.theme != ScopeTheme.theme():
		problem = "The phone must carry the Scope theme."
	elif case_box.bg_color != ScopeTheme.ENAMEL or case_box.border_color != ScopeTheme.TERRA_DARK:
		problem = "The case must be putty with a terracotta edge."
	elif glass_box.bg_color != ScopeTheme.SHADOW:
		problem = "The screen must be the dark Scope glass."
	elif (band.get_theme_stylebox("panel") as StyleBoxFlat).bg_color != ScopeTheme.TERRA:
		problem = "The band across the top must be terracotta."
	elif not (hud._zero_button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.is_equal_approx(ScopeTheme.ENAMEL_INSET):
		problem = "The keys must be putty."
	_free(hud)
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
	var got: Dictionary = {
		"clock": hud._clock_label.text, "credits": hud._credits_label.text, "relay": hud._relay_label.text,
		"link": hud._link_label.text, "lag": hud._lag_label.text, "status": hud._status_label.text,
		"tol": hud._tolerance_label.text, "relay_status": hud._relay_status_label.text,
		"spools": hud._spool_label.text, "ore": hud._ore_label.text, "cred": hud._credibility_label.text,
		"gauge": hud._gauge_label.text, "lights": hud._lights_label.text, "log": hud._log_label.text,
		"title": (hud.get_node("Bezel/Screen/Content/Title") as Label).text,
		"caption": (hud.get_node("Bezel/Screen/DriftCard").get_child(0).get_child(0) as Label).text,
	}
	var want: Dictionary = {
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
	hud.show_bram("Treads for ore.", 6, 9, false)
	hud.show_standards([{"id": "a", "text": "BUY A", "disabled": false}] as Array[Dictionary], "")
	hud.show_wheel_service("Wheel nuts due", true)
	var problem: String = ""
	if not hud._bram_panel.visible or hud._bram_label.text != "BRAM: Treads for ore.":
		problem = "Bram's line must show."
	elif not hud._trade_button.text.begins_with("TRADE 6 ORE: WIDE TREADS"):
		problem = "Bram's trade key changed: %s" % hud._trade_button.text
	elif (hud._standards_box.get_child(0) as Button).theme_type_variation != ScopeTheme.PHONE_KEY:
		problem = "Bram's stock must be phone keys."
	else:
		hud._trade_button.pressed.emit()
		hud._zero_button.pressed.emit()
		(hud._standards_box.get_child(0) as Button).pressed.emit()
		if pressed != ["trade", "zero", "a"]:
			problem = "Keys must still send their signals: %s" % [pressed]
	hud.hide_bram()
	if problem == "" and hud._bram_panel.visible:
		problem = "Leaving Bram's bay must hide his panel."
	_free(hud)
	return problem
