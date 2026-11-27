class_name BiomeData
extends RefCounted
## Reads data/biomes.json (docs/design/biomes.md section 6, build step 3): the
## farm hub and the five biomes on the 240 m land, with each one's centre,
## reach, level band, ground tint, sign line, marker and zone entrance. Pure
## static readers and a data check; no node, no scene, and nothing in play
## reads it yet. It loads its own file so no other script has to change.

const PATH: String = "res://data/biomes.json"
const FARM: StringName = &"farm"

## The land the table is laid on: x and z run from -120 to 120 m (biomes.md 7.1,
## Question 5). The old middle, which keeps its ground, is the inner 80 m.
const LAND_HALF_M: float = 120.0
## A marker keeps this far from the edge, so its pad has ground under it.
const EDGE_MARGIN_M: float = 4.0
## The farm plot is 12 by 12 cells of 2 m (GameState.PLOT), half-width in metres.
const PLOT_HALF_M: float = 12.0
## A marker keeps this far outside the plot.
const PLOT_CLEAR_M: float = 2.0

## The bands are lab levels, as in zones.json.
const LEVEL_MIN: int = 1
const LEVEL_MAX: int = 99
## How far a biome's centre may lie from its bearing, in degrees [PLACEHOLDER].
const BEARING_SLACK_DEG: float = 20.0

const ROLES: Array[String] = ["hub", "spoke", "open"]

const FIELDS: Dictionary = {
	"id": TYPE_STRING,
	"name": TYPE_STRING,
	"role": TYPE_STRING,
	"centre": TYPE_ARRAY,
	"reach_m": TYPE_FLOAT,
	"band": TYPE_ARRAY,
	"tint": TYPE_STRING,
	"sign": TYPE_STRING,
	"marker": TYPE_ARRAY,
}

## Places the scene already holds that a marker must stay clear of: x, z and
## the clear radius in metres (read from scenes/main_farm.tscn). The plot,
## the farm board and the tunnel mouth are the ones a sign could land on.
const KNOWN_SPOTS: Array[Vector3] = [
	Vector3(0, 2, 3),         # rover start
	Vector3(8, 14, 4),        # dome airlock
	Vector3(13.5, 15, 4),     # field calibration pad
	Vector3(-3, 14, 4),       # drop pod
	Vector3(1.5, 17.5, 3),    # farm notice board
	Vector3(16, -2, 5),       # Bram's bay and the rover pad beside it
	Vector3(20.5, -19, 6),    # tunnel mouth
	Vector3(20.5, -15.5, 4),  # tunnel pad
	Vector3(-70, -70, 8),     # satellite relay
	Vector3(63, 8, 8),        # the wash
	Vector3(-16, 3, 3), Vector3(-19, -3, 3), Vector3(-15, 12, 3), Vector3(4, -19, 3),
	Vector3(-3, -21, 3), Vector3(19, 4, 3), Vector3(21, -9, 3), Vector3(11, 18, 3),  # ore fissures
	Vector3(-14, -14, 3),     # the gulch bend
]

static var _cache: Array[Dictionary] = []
static var _loaded: bool = false


# --- Readers --------------------------------------------------------------------

## The table, read once. An unreadable file gives an empty list.
static func rows() -> Array[Dictionary]:
	if not _loaded:
		_cache = []
		for row: Variant in raw_rows():
			if row is Dictionary:
				_cache.append(row)
		_loaded = true
	return _cache


## The rows exactly as the file holds them (for the check). Empty if unreadable.
static func raw_rows() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and (parsed as Dictionary).get("biomes") is Array:
		return (parsed as Dictionary)["biomes"]
	return []


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for row: Dictionary in rows():
		out.append(StringName(str(row.get("id", ""))))
	return out


static func has_biome(id: StringName) -> bool:
	return not biome(id).is_empty()


## The row for `id`, or an empty Dictionary. Read-only.
static func biome(id: StringName) -> Dictionary:
	for row: Dictionary in rows():
		if str(row.get("id", "")) == String(id):
			return row
	return {}


static func display_name(id: StringName) -> String:
	return str(biome(id).get("name", ""))


static func centre(id: StringName) -> Vector2:
	return _point(biome(id).get("centre"))


static func reach(id: StringName) -> float:
	return float(biome(id).get("reach_m", 0.0))


## The sign and the rover pad of `id`, in metres (x, z). (0, 0) for an unknown id.
static func marker(id: StringName) -> Vector2:
	return _point(biome(id).get("marker"))


## The ground colour of `id`, or magenta for an unknown id so it shows.
static func tint(id: StringName) -> Color:
	var text: String = str(biome(id).get("tint", ""))
	return Color(text) if Color.html_is_valid(text) else Color.MAGENTA


## The lab-level band of `id` as (min, max), or (0, 0) for an unknown id.
static func band(id: StringName) -> Vector2i:
	var raw: Variant = biome(id).get("band")
	if raw is Array and (raw as Array).size() == 2:
		return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	return Vector2i.ZERO


## The line on the biome's sign, or "" for an unknown id.
static func sign_text(id: StringName) -> String:
	return str(biome(id).get("sign", ""))


## The zone id behind the biome's entrance, or &"" when it has none.
static func zone_entrance(id: StringName) -> StringName:
	var zone: Variant = biome(id).get("zone_entrance")
	return StringName(zone as String) if zone is String else &""


## Where that entrance is today, or null when it is not built or placed.
static func entrance_at(id: StringName) -> Variant:
	var raw: Variant = biome(id).get("entrance_at")
	return _point(raw) if raw is Array else null


## Which biome holds the ground at `at` (x, z in metres).
##
## The rule: the farm hub wins inside its reach, so the middle is always the
## farm. Outside it, the spoke biome whose reach covers the point wins, the
## nearest centre if more than one does. A point no reach covers is the open
## land and belongs to the "open" biome (the Badlands). Why this and not
## nearest-centre everywhere: biomes.md 2.2 says the land between the roads is
## Badlands, so the Badlands is whatever the others do not claim; and a plain
## nearest-centre rule would hand the far corners to whichever spoke is closest
## and make the sizes depend on how many biomes there are. Every point answers.
static func biome_at(at: Vector2) -> StringName:
	return at_in(rows(), at)


## The same rule over any list of rows, so a test can feed it a table.
static func at_in(table: Array, at: Vector2) -> StringName:
	var open_id: StringName = &""
	var best: StringName = &""
	var best_distance: float = INF
	for item: Variant in table:
		if not item is Dictionary:
			continue
		var row: Dictionary = item
		var id := StringName(str(row.get("id", "")))
		var role: String = str(row.get("role", ""))
		var distance: float = at.distance_to(_point(row.get("centre")))
		var covers: bool = distance <= float(row.get("reach_m", 0.0))
		if role == "hub" and covers:
			return id
		if role == "open":
			open_id = id
		elif role == "spoke" and covers and distance < best_distance:
			best = id
			best_distance = distance
	return best if best != &"" else open_id


# --- The check ------------------------------------------------------------------

## What is wrong with a list of rows: one line each, empty when it is sound.
## Types are checked with JSON in mind (numbers arrive as floats).
static func problems(table: Array) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	var roles: Dictionary = {}
	var sound: Array[Dictionary] = []
	for i: int in table.size():
		if not table[i] is Dictionary:
			out.append("row %d is not an object" % i)
			continue
		var row: Dictionary = table[i]
		var label: String = str(row.get("id", "row %d" % i))
		var before: int = out.size()
		for field: String in FIELDS:
			if not row.has(field):
				out.append("%s: missing %s" % [label, field])
			elif not _type_ok(row[field], int(FIELDS[field])):
				out.append("%s: %s has the wrong type" % [label, field])
		if typeof(row.get("id")) == TYPE_STRING:
			if str(row["id"]).is_empty():
				out.append("row %d: empty id" % i)
			elif seen.has(row["id"]):
				out.append("%s: duplicate id" % label)
			seen[row["id"]] = true
		if out.size() > before:
			continue
		out.append_array(_row_problems(label, row))
		roles[row["role"]] = int(roles.get(row["role"], 0)) + 1
		sound.append(row)
	for role: String in ["hub", "open"]:
		if int(roles.get(role, 0)) != 1:
			out.append("the table needs exactly one %s row, not %d" % [role, int(roles.get(role, 0))])
	# Only when every row is sound can the points be asked where they fall.
	if out.is_empty():
		for row: Dictionary in sound:
			out.append_array(_place_problems(str(row["id"]), row, sound))
	return out


static func _row_problems(label: String, row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not ROLES.has(str(row["role"])):
		out.append("%s: unknown role %s" % [label, row["role"]])
	if str(row["name"]).is_empty():
		out.append("%s: empty name" % label)
	if str(row["sign"]).strip_edges().is_empty():
		out.append("%s: empty sign" % label)
	if float(row["reach_m"]) <= 0.0:
		out.append("%s: reach_m must be above 0" % label)
	if not Color.html_is_valid(str(row["tint"])):
		out.append("%s: tint %s is not a colour" % [label, row["tint"]])
	out.append_array(_band_problems(label, row["band"]))
	for field: String in ["centre", "marker"]:
		out.append_array(_point_problems(label, field, row[field]))
	var zone: Variant = row.get("zone_entrance")
	if zone != null and (not zone is String or not ZoneData.has_zone(StringName(zone as String))):
		out.append("%s: zone_entrance %s is not a zones.json id" % [label, zone])
	var at: Variant = row.get("entrance_at")
	if at != null:
		out.append_array(_point_problems(label, "entrance_at", at))
		if zone == null:
			out.append("%s: entrance_at without a zone_entrance" % label)
	return out


static func _type_ok(value: Variant, want: int) -> bool:
	if want == TYPE_FLOAT:
		return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT
	return typeof(value) == want


## A point is [x, z]: two numbers, inside the land.
static func _point_problems(label: String, field: String, raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if not raw is Array or (raw as Array).size() != 2:
		out.append("%s: %s must be [x, z]" % [label, field])
		return out
	for part: Variant in raw as Array:
		if typeof(part) != TYPE_FLOAT and typeof(part) != TYPE_INT:
			out.append("%s: %s must be two numbers" % [label, field])
			return out
	var limit: float = LAND_HALF_M - (EDGE_MARGIN_M if field == "marker" else 0.0)
	var p: Vector2 = _point(raw)
	if absf(p.x) > limit or absf(p.y) > limit:
		out.append("%s: %s (%s, %s) is outside the %d m land" % [label, field, p.x, p.y, int(limit * 2.0)])
	return out


static func _band_problems(label: String, raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if (raw as Array).size() != 2:
		out.append("%s: band must be [min, max]" % label)
		return out
	for edge: Variant in raw as Array:
		if (typeof(edge) != TYPE_FLOAT and typeof(edge) != TYPE_INT) or float(edge) != floorf(float(edge)):
			out.append("%s: band edges must be whole levels" % label)
			return out
	var lo: int = int((raw as Array)[0])
	var hi: int = int((raw as Array)[1])
	if lo > hi or lo < LEVEL_MIN or hi > LEVEL_MAX:
		out.append("%s: band %d to %d must have min <= max within %d to %d" % [label, lo, hi, LEVEL_MIN, LEVEL_MAX])
	return out


## The rules that need the whole table: where the marker and the entrance fall,
## what they sit on, and whether a biome's centre lies on its bearing.
static func _place_problems(label: String, row: Dictionary, table: Array) -> Array[String]:
	var out: Array[String] = []
	var id := StringName(label)
	var marker_at: Vector2 = _point(row["marker"])
	if absf(marker_at.x) < PLOT_HALF_M + PLOT_CLEAR_M and absf(marker_at.y) < PLOT_HALF_M + PLOT_CLEAR_M:
		out.append("%s: marker is on the farm plot" % label)
	for spot: Vector3 in KNOWN_SPOTS:
		if marker_at.distance_to(Vector2(spot.x, spot.y)) < spot.z:
			out.append("%s: marker is within %s m of the known spot at (%s, %s)" % [label, spot.z, spot.x, spot.y])
	if at_in(table, _point(row["centre"])) != id:
		out.append("%s: its own centre falls in %s" % [label, at_in(table, _point(row["centre"]))])
	if at_in(table, marker_at) != id:
		out.append("%s: its marker falls in %s" % [label, at_in(table, marker_at)])
	if row.get("entrance_at") != null and at_in(table, _point(row["entrance_at"])) != id:
		out.append("%s: its entrance falls in %s" % [label, at_in(table, _point(row["entrance_at"]))])
	if str(row["role"]) != "hub":
		var bearing: Variant = row.get("bearing_deg")
		if bearing == null or (typeof(bearing) != TYPE_FLOAT and typeof(bearing) != TYPE_INT):
			out.append("%s: a spoke or open biome needs a bearing_deg" % label)
		else:
			var from: Vector2 = _point(row["centre"])
			var actual: float = fposmod(rad_to_deg(atan2(from.x, -from.y)), 360.0)
			var gap: float = absf(fposmod(float(bearing) - actual + 180.0, 360.0) - 180.0)
			if gap > BEARING_SLACK_DEG:
				out.append("%s: bearing_deg %s is %d degrees off its centre's bearing %d" % [label, bearing, int(gap), int(actual)])
	return out


static func _point(raw: Variant) -> Vector2:
	if raw is Array and (raw as Array).size() == 2:
		return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	return Vector2.ZERO
