extends RefCounted
## Rare moon/pod tarantula species (feat/rare-tarantulas): data rows, sane wider
## climate bands, uncaught species adding no enclosures, and dome terrarium looks.

const ALLOWED_ZONES: Array[String] = ["phobos", "deimos", "ice_caves"]
const EXPECTED_NAMES: Dictionary = {
	"banded_regolith_runner": "Banded Regolith Runner",
	"rime_carapace_spinner": "Rime Carapace Spinner",
	"brass_glint_reticle": "Brass Glint Reticle",
	"low_g_titan_carapace": "Low-G Titan Carapace",
}
const REQUIRED_FIELDS: Array[String] = [
	"id", "common_name", "scientific_name", "tier", "found_in", "visual_hook",
	"source", "substrate", "ideal_temp_c", "temp_tolerance_c",
	"ideal_humidity_pct", "humidity_tolerance_pct", "molt_days",
	"silk_grade", "optical_silk_yield", "lag_reduction_pct",
]


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func test_four_rare_species_exist_with_every_field() -> String:
	for id: String in EXPECTED_NAMES:
		var rec: Dictionary = DataManager.get_record(GameState.SPECIES_TABLE, StringName(id))
		if rec.is_empty():
			return "Missing rare species '%s' in tarantula_species.json." % id
		for field: String in REQUIRED_FIELDS:
			if not rec.has(field) or rec[field] == null:
				return "Rare species '%s' is missing field '%s'." % [id, field]
		if str(rec["common_name"]) != str(EXPECTED_NAMES[id]):
			return "Species '%s' has common_name '%s', wanted '%s'." % [id, rec["common_name"], EXPECTED_NAMES[id]]
		if str(rec["tier"]) != "rare":
			return "Species '%s' has tier '%s', wanted 'rare'." % [id, rec["tier"]]
		if not str(rec["found_in"]) in ALLOWED_ZONES:
			return "Species '%s' found_in '%s' not in %s." % [id, rec["found_in"], ALLOWED_ZONES]
		if str(rec["scientific_name"]).strip_edges() == "":
			return "Species '%s' needs a fictional scientific_name." % id
	return ""


func test_rare_species_bands_are_sane_and_wider() -> String:
	for id: String in EXPECTED_NAMES:
		var rec: Dictionary = DataManager.get_record(GameState.SPECIES_TABLE, StringName(id))
		var temp: float = float(rec["ideal_temp_c"])
		var temp_tol: float = float(rec["temp_tolerance_c"])
		var hum: float = float(rec["ideal_humidity_pct"])
		var hum_tol: float = float(rec["humidity_tolerance_pct"])
		var molt: int = int(rec["molt_days"])
		var grade: int = int(rec["silk_grade"])
		var yield_n: int = int(rec["optical_silk_yield"])
		var lag: float = float(rec["lag_reduction_pct"])
		if temp < 10.0 or temp > 35.0:
			return "%s ideal_temp_c out of sane range: %s" % [id, temp]
		if temp_tol < 4.5 or temp_tol > 12.0:
			return "%s temp_tolerance_c should be a wider moon band (4.5..12): %s" % [id, temp_tol]
		if hum < 25.0 or hum > 90.0 or hum - hum_tol < 0.0 or hum + hum_tol > 100.0:
			return "%s humidity band (%s +/- %s) is out of 0..100." % [id, hum, hum_tol]
		if hum_tol < 15.0 or hum_tol > 35.0:
			return "%s humidity_tolerance_pct should be a wider moon band (15..35): %s" % [id, hum_tol]
		if molt < 1 or grade < 1 or yield_n < 1 or lag <= 0.0 or lag > 50.0:
			return "%s silk/molt numbers are out of sane bounds." % id
	return ""


func test_uncaught_rare_species_add_no_enclosures_and_build_looks() -> String:
	var saved_enclosures: Dictionary = GameState.enclosures.duplicate(true)
	for id: String in EXPECTED_NAMES:
		GameState.enclosures.erase(id)
	var problem: String = ""
	var titan_scale: float = 0.0
	var base_scale: float = 0.0
	for id: String in EXPECTED_NAMES:
		if GameState.is_caught(id):
			problem = "Uncaught rare species '%s' should not be caught." % id
			break
		var terr := Terrarium.new()
		terr.species_id = id
		var spider_root := Node3D.new()
		spider_root.name = &"Tarantula"
		terr.add_child(spider_root)
		terr.tarantula = spider_root
		_root().add_child(terr)
		var look := spider_root.get_node_or_null("RareSpider") as Node3D
		if look == null:
			problem = "Terrarium did not build RareSpider look for '%s'." % id
		elif look.get_node_or_null("Mark") == null:
			problem = "RareSpider for '%s' is missing its Mark node." % id
		elif spider_root.visible:
			problem = "Uncaught rare species '%s' must stay hidden in its terrarium." % id
		else:
			if id == RareSpiderLook.TITAN_ID:
				titan_scale = look.scale.x
			else:
				base_scale = look.scale.x
		_free(terr)
		if problem != "":
			break
	GameState.enclosures = saved_enclosures
	if problem != "":
		return problem
	return "" if titan_scale > base_scale else "Low-G Titan Carapace should scale larger than the other rare species."
