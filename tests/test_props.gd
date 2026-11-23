extends RefCounted
## Inspect text for placed props (data/props.json) and the scenes that use it.

const SCENES: Array[String] = ["res://scenes/main_farm.tscn", "res://scenes/dome_interior.tscn"]


func _prop_ids() -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = DataManager.get_raw(&"props")
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for key: Variant in (raw as Dictionary).keys():
		if not str(key).begins_with("_"):
			out.append(str(key))
	return out


func test_every_prop_has_name_and_description() -> String:
	var ids: Array[String] = _prop_ids()
	if ids.is_empty():
		return "data/props.json has no props"
	for id: String in ids:
		for field: String in ["display_name", "description"]:
			var value: Variant = DataManager.get_value(&"props", id + "/" + field, null)
			if typeof(value) != TYPE_STRING or (value as String).is_empty():
				return "%s has no %s" % [id, field]
	return ""


func test_inspect_text_joins_name_and_description() -> String:
	var got: String = Inspectable.inspect_text("water_cistern")
	var want: String = "%s: %s" % [
		DataManager.get_value(&"props", "water_cistern/display_name", ""),
		DataManager.get_value(&"props", "water_cistern/description", "")]
	if got != want:
		return "got '%s', want '%s'" % [got, want]
	return ""


func test_unknown_prop_falls_back_to_its_id() -> String:
	if Inspectable.display_name("no_such_prop") != "no_such_prop":
		return "display_name did not fall back to the id"
	if Inspectable.inspect_text("no_such_prop") != "no_such_prop":
		return "inspect_text did not fall back to the id"
	return ""


## Every prop_id set in a scene names an entry in data/props.json, and every
## entry is used by some scene.
func test_scene_prop_ids_match_props_json() -> String:
	var ids: Array[String] = _prop_ids()
	var used: Dictionary = {}
	var regex := RegEx.create_from_string("(?m)^prop_id = \"([^\"]+)\"")
	for path: String in SCENES:
		var text: String = FileAccess.get_file_as_string(path)
		if text.is_empty():
			return "could not read %s" % path
		for m: RegExMatch in regex.search_all(text):
			var id: String = m.get_string(1)
			if id not in ids:
				return "%s uses prop_id '%s', which is not in data/props.json" % [path, id]
			used[id] = true
	for id: String in ids:
		if not used.has(id):
			return "data/props.json entry '%s' is not placed in any scene" % id
	return ""
