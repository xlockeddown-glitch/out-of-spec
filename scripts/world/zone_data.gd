class_name ZoneData
extends RefCounted
## Reads data/zones.json (docs/design/zones.md section 2, build step 2): one row
## per zone, its lab-level band, hazards, finds, hub scene and entrance. Pure
## readers and a data check; no scene and no rule uses them yet. The band is
## what the content is tuned for, never a gate (section 7).

const TABLE: StringName = &"zones"
const SECTION: String = "zones"

## The fields every row must have, and the type each must be.
const FIELDS: Dictionary = {
	"id": TYPE_STRING,
	"name": TYPE_STRING,
	"area": TYPE_STRING,
	"band": TYPE_ARRAY,
	"hazards": TYPE_ARRAY,
	"finds": TYPE_ARRAY,
	"hub_scene": TYPE_STRING,
	"entrance": TYPE_STRING,
	"tarantula_hook": TYPE_STRING,
	"notes": TYPE_STRING,
}

const AREAS: Array[String] = ["underground", "moon", "far"]
const LEVEL_MIN: int = 1
const LEVEL_MAX: int = 99

## Hazard words (section 5 and section 11) [PLACEHOLDER].
const HAZARDS: Array[String] = [
	"heat", "loose_basalt", "dark", "water_depth", "pressure_drop", "collapse",
	"bad_air", "old_charges", "cold", "slick_ice", "white_out", "low_gravity",
	"dust", "launch_window", "locked_crates", "wind", "long_drives", "thin_air",
	"getting_lost", "vacuum", "debris", "radiation", "long_trip", "slow_wading",
	"scale", "drift",
]

## Find words (section 4 and section 11) [PLACEHOLDER].
const FINDS: Array[String] = [
	"crystal_ore", "ore", "minerals", "basalt_glass", "vent_samples",
	"water_samples", "drowned_gear", "lost_gear", "gauge_blocks", "robot_parts",
	"ice_cores", "frozen_probes", "station_data", "tarantulas", "smuggled_crates",
	"lost_standards", "sediment_samples", "metal_samples",
]


## Zone ids in table order.
static func ids() -> Array[StringName]:
	return DataManager.get_ids(TABLE, SECTION)


static func rows() -> Array[Dictionary]:
	return DataManager.get_records(TABLE, SECTION)


static func has_zone(id: StringName) -> bool:
	return DataManager.has_record(TABLE, id, SECTION)


## The row for `id`, or an empty Dictionary. Read-only.
static func zone(id: StringName) -> Dictionary:
	return DataManager.get_record(TABLE, id, SECTION)


## The lab-level band of `id` as (min, max), or (0, 0) for an unknown zone.
static func band(id: StringName) -> Vector2i:
	return band_of(zone(id))


static func band_of(row: Dictionary) -> Vector2i:
	var raw: Variant = row.get("band")
	if raw is Array and (raw as Array).size() == 2:
		return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	return Vector2i.ZERO


## Every zone whose band holds `level`, in table order. Bands overlap, so there
## are often several.
static func zones_for_level(level: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for row: Dictionary in rows():
		var b: Vector2i = band_of(row)
		if b != Vector2i.ZERO and level >= b.x and level <= b.y:
			out.append(StringName(str(row.get("id", ""))))
	return out


## The hub scene path of `id`, or "" while it has none.
static func hub_scene(id: StringName) -> String:
	return str(zone(id).get("hub_scene", ""))


## What is wrong with a list of rows: one line each, empty when it is sound.
## Types are checked with JSON in mind (numbers arrive as floats).
static func problems(table: Array) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for i: int in table.size():
		if not table[i] is Dictionary:
			out.append("row %d is not an object" % i)
			continue
		var row: Dictionary = table[i]
		var label: String = str(row.get("id", "row %d" % i))
		for field: String in FIELDS:
			if not row.has(field):
				out.append("%s: missing %s" % [label, field])
			elif typeof(row[field]) != int(FIELDS[field]):
				out.append("%s: %s has the wrong type" % [label, field])
		if typeof(row.get("id")) == TYPE_STRING:
			if str(row["id"]).is_empty():
				out.append("row %d: empty id" % i)
			elif seen.has(row["id"]):
				out.append("%s: duplicate id" % label)
			seen[row["id"]] = true
		if typeof(row.get("area")) == TYPE_STRING and not AREAS.has(str(row["area"])):
			out.append("%s: unknown area %s" % [label, row["area"]])
		out.append_array(_band_problems(label, row.get("band")))
		out.append_array(_words_problems(label, "hazards", row.get("hazards"), HAZARDS))
		out.append_array(_words_problems(label, "finds", row.get("finds"), FINDS))
		var scene: Variant = row.get("hub_scene")
		if scene is String and not (scene as String).is_empty():
			if not (scene as String).begins_with("res://") or not (scene as String).ends_with(".tscn") or not ResourceLoader.exists(scene, "PackedScene"):
				out.append("%s: hub_scene %s is not an existing scene" % [label, scene])
	return out


static func _band_problems(label: String, raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if not raw is Array:
		return out
	var band_array: Array = raw
	if band_array.size() != 2:
		out.append("%s: band must be [min, max]" % label)
		return out
	for edge: Variant in band_array:
		if typeof(edge) != TYPE_FLOAT and typeof(edge) != TYPE_INT:
			out.append("%s: band edges must be numbers" % label)
			return out
		if float(edge) != floorf(float(edge)):
			out.append("%s: band edges must be whole levels" % label)
			return out
	var lo: int = int(band_array[0])
	var hi: int = int(band_array[1])
	if lo > hi or lo < LEVEL_MIN or hi > LEVEL_MAX:
		out.append("%s: band %d-%d must have min <= max within %d-%d" % [label, lo, hi, LEVEL_MIN, LEVEL_MAX])
	return out


static func _words_problems(label: String, field: String, raw: Variant, allowed: Array[String]) -> Array[String]:
	var out: Array[String] = []
	if not raw is Array:
		return out
	if (raw as Array).is_empty():
		out.append("%s: %s is empty" % [label, field])
	var seen: Dictionary = {}
	for word: Variant in raw as Array:
		if not word is String or not allowed.has(word as String):
			out.append("%s: %s has %s, which is not an allowed word" % [label, field, word])
		elif seen.has(word):
			out.append("%s: %s repeats %s" % [label, field, word])
		seen[word] = true
	return out
