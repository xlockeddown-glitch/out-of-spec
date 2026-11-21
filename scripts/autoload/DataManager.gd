extends Node
## Global read-only game data. Autoloaded as `DataManager` (no class_name on
## purpose: it would collide with the autoload singleton name).
##
## Files are loaded as-is (no required envelope). Two ways to read them:
##   - Record sections: arrays of objects with a string "id", indexed by id.
##     Declared in RECORD_SECTIONS. Section "" means the file root is the array.
##     -> get_record(), get_records(), get_ids()
##   - Anything else (keyed objects like instruments, guardband, npcs):
##     -> get_value("instruments/rover_steering_encoder/max_permissible_error")
##
## Treat returned Dictionaries/Arrays as read-only; they are the cached data.
##
## EXPORT NOTE: .json is not a Godot resource. Add `data/*.json` to
## Export > Resources > "Filters to export non-resource files", or the
## exported build will ship without its data.

signal data_loaded(all_ok: bool)
signal table_failed(table: StringName, reason: String)

## Table name -> res:// path.
const DATA_FILES: Dictionary = {
	&"tarantula_species": "res://data/tarantula_species.json",
	&"crops": "res://data/crops.json",
	&"sensor_drift_config": "res://data/sensor_drift_config.json",
	&"dialogue_dispatches": "res://data/dialogue_dispatches.json",
	&"items": "res://data/items.json",
	&"economy": "res://data/economy.json",
}

## Table -> { section -> required fields (besides "id") }.
## Records missing a required field are skipped with a warning.
const RECORD_SECTIONS: Dictionary = {
	# Alien morphs carry nulls for values the art bible hasn't defined yet, so
	# numeric fields are checked where they are used, not here.
	&"tarantula_species": {
		"": ["common_name", "tier"],
	},
	&"crops": {
		"": ["name", "growth_days", "soil_moisture_target", "tolerance_band"],
	},
	&"dialogue_dispatches": {
		"morning_dispatches": ["sender", "text"],
		"audit_fines": ["title", "credit_penalty"],
	},
	&"sensor_drift_config": {},
	&"items": {},
	&"economy": {},
}

var is_loaded: bool = false

var _raw: Dictionary = {}      # StringName table -> Variant (parsed JSON root)
var _records: Dictionary = {}  # StringName table -> { String section -> { StringName id -> Dictionary } }


func _ready() -> void:
	reload_all()


## (Re)loads every table. Returns true only if all tables loaded cleanly.
func reload_all() -> bool:
	_raw.clear()
	_records.clear()
	var all_ok: bool = true
	for table_key: Variant in DATA_FILES:
		var table: StringName = table_key
		if not _load_table(table, DATA_FILES[table] as String):
			all_ok = false
	is_loaded = true
	data_loaded.emit(all_ok)
	return all_ok


# --- Record API ---------------------------------------------------------------

func has_record(table: StringName, id: StringName, section: String = "") -> bool:
	return _section_index(table, section).has(id)


## Returns the record, or an empty Dictionary if not found.
func get_record(table: StringName, id: StringName, section: String = "") -> Dictionary:
	var record: Variant = _section_index(table, section).get(id, {})
	return record as Dictionary


func get_records(table: StringName, section: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(_section_index(table, section).values())
	return out


func get_ids(table: StringName, section: String = "") -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_section_index(table, section).keys())
	return out


# --- Path API -----------------------------------------------------------------

func get_raw(table: StringName) -> Variant:
	return _raw.get(table)


## Walks a "/"-separated path through objects (by key) and arrays (by index).
## Returns `fallback` if any step is missing.
func get_value(table: StringName, path: String, fallback: Variant = null) -> Variant:
	var node: Variant = _raw.get(table)
	for part: String in path.split("/", false):
		match typeof(node):
			TYPE_DICTIONARY:
				var dict: Dictionary = node
				if not dict.has(part):
					return fallback
				node = dict[part]
			TYPE_ARRAY:
				var arr: Array = node
				if not part.is_valid_int() or int(part) < 0 or int(part) >= arr.size():
					return fallback
				node = arr[int(part)]
			_:
				return fallback
	return node


## Numeric value at `path`. JSON numbers arrive as float; ints are accepted too.
func get_number(table: StringName, path: String, fallback: float) -> float:
	var value: Variant = get_value(table, path, fallback)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	push_warning("DataManager[%s] '%s' is not a number; using %s." % [table, path, fallback])
	return fallback


# --- Loading ------------------------------------------------------------------

func _section_index(table: StringName, section: String) -> Dictionary:
	var sections: Dictionary = _records.get(table, {})
	var index: Variant = sections.get(section, {})
	return index as Dictionary


func _load_table(table: StringName, path: String) -> bool:
	_records[table] = {}

	if not FileAccess.file_exists(path):
		return _fail(table, "missing file %s" % path)

	var json := JSON.new()
	var err: Error = json.parse(FileAccess.get_file_as_string(path))
	if err != OK:
		return _fail(table, "%s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
	_raw[table] = json.data

	var all_ok: bool = true
	var sections: Dictionary = RECORD_SECTIONS.get(table, {})
	for section_key: Variant in sections:
		var section: String = section_key
		var source: Variant = json.data if section.is_empty() else get_value(table, section)
		if typeof(source) != TYPE_ARRAY:
			all_ok = _fail(table, "%s: section '%s' must be an array" % [path, section]) and all_ok
			continue
		(_records[table] as Dictionary)[section] = _index_records(
			"%s%s" % [table, "" if section.is_empty() else "/" + section],
			source as Array,
			sections[section] as Array)

	print_verbose("DataManager: %s loaded." % table)
	return all_ok


func _index_records(label: String, raw_records: Array, required: Array) -> Dictionary:
	var index: Dictionary = {}
	for i: int in raw_records.size():
		if typeof(raw_records[i]) != TYPE_DICTIONARY:
			push_warning("DataManager[%s] item %d is not an object; skipped." % [label, i])
			continue
		var record: Dictionary = raw_records[i]

		var raw_id: Variant = record.get("id")
		if typeof(raw_id) != TYPE_STRING or (raw_id as String).is_empty():
			push_warning("DataManager[%s] item %d has no string 'id'; skipped." % [label, i])
			continue
		var id := StringName(raw_id as String)
		if index.has(id):
			push_warning("DataManager[%s] duplicate id '%s'; later item skipped." % [label, id])
			continue

		var missing: Array = required.filter(func(field: Variant) -> bool: return not record.has(field))
		if not missing.is_empty():
			push_warning("DataManager[%s] '%s' missing %s; skipped." % [label, id, missing])
			continue

		record.make_read_only()
		index[id] = record
	return index


func _fail(table: StringName, reason: String) -> bool:
	push_error("DataManager[%s] %s" % [table, reason])
	table_failed.emit(table, reason)
	return false
