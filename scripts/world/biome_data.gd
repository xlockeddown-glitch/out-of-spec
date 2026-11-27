class_name BiomeData
extends RefCounted
## Reads data/biomes.json (docs/design/biomes.md section 6, build step 3): the
## farm hub and the five biomes on the 240 m land, with each one's centre,
## reach, level band, ground tint, sign line, marker and zone entrances. Pure
## static readers and a data check; no node, no scene, and nothing in play
## reads it yet.
##
## It loads its own file, not through DataManager, because DataManager's table
## list is another script's to change, and nothing in play needs the table yet.
## The load reports every fault with push_error, checks the table before it is
## kept, and keeps nothing usable if the check fails.

const PATH: String = "res://data/biomes.json"
const FARM: StringName = &"farm"

## The land the table is laid on is Terrain.HALF_M each way from the middle (120 m,
## 240 m across; biomes.md 7.1, Question 5). The old middle, which keeps its
## ground, is the inner Terrain.OLD_HALF_M.
## A marker keeps this far from the edge, so its pad has ground under it.
const EDGE_MARGIN_M: float = 4.0
## The farm plot is 12 by 12 cells of 2 m (GameState.PLOT), half-width in metres.
const PLOT_HALF_M: float = 12.0
## A marker's middle keeps this far outside the plot's edge.
const PLOT_CLEAR_M: float = 3.0

## A marker's rover pad is 4 by 4 m, like the tunnel pad and the calibration pad.
const PAD_HALF_M: float = 2.0
## A pad keeps this much clear of anything solid or built [PLACEHOLDER].
const PAD_CLEAR_M: float = 1.0
## The ground under a pad may differ this much between its corners, edges and
## middle [PLACEHOLDER]. The old land's heights cannot change, so a pad goes where
## the land is already near flat.
const PAD_SPREAD_MAX_M: float = 0.25

## The bands are zone levels, as in zones.json (the Badlands' is the Earthworks
## level of biomes.md section 2).
const LEVEL_MIN: int = 1
const LEVEL_MAX: int = 99
## How far a biome's centre may lie from its bearing, in degrees [PLACEHOLDER].
const BEARING_SLACK_DEG: float = 20.0

## A road runs from the edge of the farm's level circle to its pad (step 8). Its
## strip is this wide each side of the line, so 3 m across [PLACEHOLDER]; the
## paint fades out over the next ROAD_EDGE_M.
const ROAD_HALF_M: float = 1.5
const ROAD_EDGE_M: float = 1.0
## The first waypoint lies this near the farm's level circle (Terrain.FARM_LEVEL_M).
const ROAD_START_SLACK_M: float = 2.0
## The last waypoint lies on or this near the pad's edge, as the Chebyshev
## distance from the marker (the pad's half-width plus a little).
const ROAD_END_SLACK_M: float = 0.5
const ROAD_TEXT: String = "Keep the road clear."

const ROLES: Array[String] = ["hub", "spoke", "open"]

const FIELDS: Dictionary = {
	"id": TYPE_STRING,
	"name": TYPE_STRING,
	"role": TYPE_STRING,
	"centre": TYPE_ARRAY,
	"reach_m": TYPE_FLOAT,
	"band": TYPE_ARRAY,
	"tint": TYPE_STRING,
	"ground_tint": TYPE_STRING,
	"sign": TYPE_STRING,
	"marker": TYPE_ARRAY,
	"road": TYPE_ARRAY,
	"entrances": TYPE_ARRAY,
}

## Built things in scenes/main_farm.tscn a marker's pad must stay clear of: x, z,
## and the half-width in x and in z, in metres (from the scene's collision shapes
## and models; the pads, the board and the bay are their real sizes). The land's
## own rocks are read from HillDressing.ROCKS, not listed here.
const SCENE_SPOTS: Array[Vector4] = [
	Vector4(0, 2, 1.2, 1.6),        # rover start
	Vector4(8, 14, 2.5, 2.0),       # dome airlock
	Vector4(13.5, 14.5, 3.5, 3.0),  # field calibration pad, with its tripod, jig and table
	Vector4(-3, 14, 2.0, 2.0),      # drop pod
	Vector4(1.5, 17.5, 3.5, 3.5),   # farm notice board (its pad is 7 by 7)
	Vector4(16.5, -2, 4.0, 3.5),    # Bram's bay, the rover pad and the air dryer
	Vector4(-11.6, 13.2, 1.5, 1.5), # water cistern
	Vector4(-9, 13.2, 1.0, 1.0),    # irrigation junction
	Vector4(-7.8, 12.5, 0.5, 0.5),  # soil probe
	Vector4(3, 13, 1.0, 1.0),       # harvest crate
	Vector4(1, 13.3, 1.5, 1.5),     # shipping pallet
	Vector4(-20, 8, 1.0, 1.0),      # scrub bush A
	Vector4(9, -20, 1.0, 1.0),      # scrub bush B
	Vector4(-6, 19, 1.0, 1.0),      # dry stump A
	Vector4(17, -14, 1.0, 1.0),     # dry stump B
	Vector4(20.5, -19, 4.0, 3.0),   # tunnel mouth
	Vector4(20.5, -15.5, 2.0, 2.0), # tunnel pad
	Vector4(-70, -70, 4.0, 4.0),    # satellite relay
	Vector4(63, 8, 8.0, 6.0),       # the wash
	Vector4(-17, -10, 2.5, 2.0),    # RockA, solid
	Vector4(-9, -17, 2.0, 2.5),     # RockB, solid
	Vector4(16, 9, 2.0, 2.0),       # RockC, solid
	Vector4(5, -16, 1.5, 1.5),      # RockD, solid
	Vector4(5.5, 16.5, 0.5, 0.5),   # weather mast
	Vector4(-9.5, 17, 0.8, 0.6),    # solar skid
	Vector4(-17.5, 5.4, 0.6, 0.6),  # core drill
	Vector4(-14, 1, 0.7, 0.6),      # sorting skip
	Vector4(-17, -4.6, 0.4, 0.4),   # seismic thumper
	Vector4(-14, -14, 1.0, 1.0),    # cobbles A
	Vector4(20, 13, 1.0, 1.0),      # cobbles B
	Vector4(-1, -25, 7.0, 1.5),     # the gulch, x -8 to 6
	Vector4(0, -30, 10.0, 1.5),     # the plateau rim
	Vector4(46, 8, 1.5, 1.5), Vector4(52, 14, 1.5, 1.5), Vector4(46, 20, 1.5, 1.5),
	Vector4(56, 22, 1.5, 1.5), Vector4(50, 28, 1.5, 1.5), Vector4(44, 32, 1.5, 1.5),
	Vector4(58, 30, 1.5, 1.5), Vector4(52, 36, 1.5, 1.5),  # ore fissures, in the Badlands
]

static var _cache: Array[Dictionary] = []
static var _loaded: bool = false
static var _road_cells: Dictionary[Vector2i, bool] = {}
static var _road_cells_ready: bool = false


# --- Loading --------------------------------------------------------------------

## The table, read and checked once. If the file is missing, unreadable or fails
## the check, each fault is reported and the list is empty. reload() tries again.
static func rows() -> Array[Dictionary]:
	if not _loaded:
		var found: Dictionary = read_file(PATH)
		for line: String in found["errors"] as Array:
			push_error(line)
		_cache = []
		if (found["errors"] as Array).is_empty():
			_cache.assign(found["rows"])
			for row: Dictionary in _cache:
				_freeze(row)
		_cache.make_read_only()
		_loaded = true
	return _cache


## Forget what was read, so the next reader reads the file again (for tests).
static func reload() -> void:
	_cache = []
	_loaded = false
	_road_cells.clear()
	_road_cells_ready = false


## The rows exactly as the file holds them, unchecked and not read-only (so a
## test can feed problems() a bad file). Empty if the file is unreadable.
static func raw_rows() -> Array:
	return read_raw(PATH)["rows"] as Array


## Reads one file, without checking the rows: {"rows": the rows, "errors": one
## line each}. A missing file, a JSON fault (with its line) or a missing "biomes"
## list gives errors, and then rows is empty.
static func read_raw(path: String) -> Dictionary:
	var out: Dictionary = {"rows": [], "errors": []}
	var errors: Array = out["errors"]
	if not FileAccess.file_exists(path):
		errors.append("%s: file not found" % path)
		return out
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s: line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return out
	var data: Variant = json.data
	if not data is Dictionary or not (data as Dictionary).get("biomes") is Array:
		errors.append("%s: no \"biomes\" list" % path)
		return out
	out["rows"] = (data as Dictionary)["biomes"]
	return out


## Reads and checks one file: {"rows": the rows, "errors": one line each}. Any
## fault of read_raw or of problems() gives errors, and then rows is empty.
static func read_file(path: String) -> Dictionary:
	var out: Dictionary = read_raw(path)
	var errors: Array = out["errors"]
	if errors.is_empty():
		for line: String in problems(out["rows"] as Array):
			errors.append("%s: %s" % [path, line])
	if not errors.is_empty():
		out["rows"] = []
	return out


## Makes a row and everything inside it read-only (DataManager does the same).
static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in (value as Dictionary).keys():
			_freeze((value as Dictionary)[key])
		(value as Dictionary).make_read_only()
	elif value is Array:
		for item: Variant in value as Array:
			_freeze(item)
		(value as Array).make_read_only()


# --- Readers --------------------------------------------------------------------

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


## The road of `id` as waypoints (x, z), from the farm to its pad. Empty for the farm
## and for a biome with no road (the Basalt Ridge's marker is at the farm's edge).
static func road(id: StringName) -> Array[Vector2]:
	return road_in(biome(id))


## The road of one row.
static func road_in(row: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var raw: Variant = row.get("road")
	if raw is Array:
		for part: Variant in raw as Array:
			out.append(_point(part))
	return out


## How far `at` is from the nearest road line, in metres (INF if there is no road).
static func road_gap(at: Vector2) -> float:
	var best: float = INF
	for id: StringName in ids():
		var line: Array[Vector2] = road(id)
		for i: int in range(line.size() - 1):
			best = minf(best, segment_gap(at, line[i], line[i + 1]))
	return best


## Whether `at` lies in a road's strip.
static func on_road(at: Vector2) -> bool:
	return road_gap(at) <= ROAD_HALF_M


## How much road paint `gap` metres from a road line gets: 1 in the strip, falling
## smoothly to 0 over ROAD_EDGE_M beyond it.
static func road_weight(gap: float) -> float:
	if gap <= ROAD_HALF_M:
		return 1.0
	if gap >= ROAD_HALF_M + ROAD_EDGE_M:
		return 0.0
	return smoothstep(1.0, 0.0, (gap - ROAD_HALF_M) / ROAD_EDGE_M)


## Whether a cell lies on a road, so it can not be dug or built on: its middle is
## within the strip's half-width plus half a cell. Not part of Terrain.can_dig,
## which ore pockets and old-save hashes read; dug_problem still accepts old digging.
static func is_road_cell(cell: Vector2i) -> bool:
	if not _road_cells_ready:
		_road_cells.clear()
		var reach: float = ROAD_HALF_M + Terrain.CELL_M * 0.5
		for id: StringName in ids():
			var line: Array[Vector2] = road(id)
			for i: int in range(line.size() - 1):
				var low: Vector2 = line[i].min(line[i + 1]) - Vector2(reach, reach)
				var high: Vector2 = line[i].max(line[i + 1]) + Vector2(reach, reach)
				var first := Vector2i(floori(low.x / Terrain.CELL_M), floori(low.y / Terrain.CELL_M))
				var last := Vector2i(floori(high.x / Terrain.CELL_M), floori(high.y / Terrain.CELL_M))
				for x: int in range(first.x, last.x + 1):
					for z: int in range(first.y, last.y + 1):
						var middle := (Vector2(x, z) + Vector2(0.5, 0.5)) * Terrain.CELL_M
						if segment_gap(middle, line[i], line[i + 1]) < reach:
							_road_cells[Vector2i(x, z)] = true
		_road_cells_ready = true
	return _road_cells.has(cell)


## The distance from `at` to the segment a-b.
static func segment_gap(at: Vector2, a: Vector2, b: Vector2) -> float:
	var run: Vector2 = b - a
	var length_sq: float = run.length_squared()
	var t: float = 0.0 if length_sq <= 0.0 else clampf((at - a).dot(run) / length_sq, 0.0, 1.0)
	return at.distance_to(a + run * t)


## What is wrong with a road: its waypoints, where it starts and ends, and what its
## strip touches (the plot, built things, rocks, fissures, and its own pad's sign).
static func road_problems(label: String, line: Array[Vector2], marker_at: Vector2) -> Array[String]:
	var out: Array[String] = []
	if line.is_empty():
		return out
	if line.size() < 2:
		out.append("%s: road needs at least two waypoints" % label)
		return out
	var start_gap: float = absf(line[0].length() - Terrain.FARM_LEVEL_M)
	if start_gap > ROAD_START_SLACK_M:
		out.append("%s: road starts %.1f m from the farm's level circle, over the %.1f m limit" % [label, start_gap, ROAD_START_SLACK_M])
	var end: Vector2 = line[line.size() - 1]
	var end_reach: float = PAD_HALF_M + ROAD_END_SLACK_M
	if maxf(absf(end.x - marker_at.x), absf(end.y - marker_at.y)) > end_reach:
		out.append("%s: road ends at (%s, %s), not at its pad's edge" % [label, end.x, end.y])
	var plot := Rect2(Vector2(-PLOT_HALF_M, -PLOT_HALF_M), Vector2(PLOT_HALF_M, PLOT_HALF_M) * 2.0)
	var boxes: Array[Vector4] = spots()
	boxes.append(Vector4(marker_at.x + PAD_HALF_M + 0.7, marker_at.y, 0.75, 0.2))  # its pad's sign
	for i: int in range(line.size() - 1):
		var a: Vector2 = line[i]
		var b: Vector2 = line[i + 1]
		if a.distance_to(b) < 1.0:
			out.append("%s: road waypoints %d and %d are under 1 m apart" % [label, i, i + 1])
			continue
		var steps: int = ceili(a.distance_to(b) / 0.25)
		var hit_plot: bool = false
		var hit: Dictionary[int, bool] = {}
		for k: int in range(steps + 1):
			var at: Vector2 = a.lerp(b, float(k) / steps)
			if absf(at.x) > Terrain.HALF_M - ROAD_HALF_M or absf(at.y) > Terrain.HALF_M - ROAD_HALF_M:
				out.append("%s: road leaves the land at (%s, %s)" % [label, at.x, at.y])
				break
			if not hit_plot and plot.grow(ROAD_HALF_M).has_point(at):
				hit_plot = true
				out.append("%s: road touches the farm plot at (%s, %s)" % [label, at.x, at.y])
			for n: int in boxes.size():
				var box: Vector4 = boxes[n]
				var dx: float = maxf(absf(at.x - box.x) - box.z, 0.0)
				var dz: float = maxf(absf(at.y - box.y) - box.w, 0.0)
				if not hit.has(n) and dx * dx + dz * dz < ROAD_HALF_M * ROAD_HALF_M:
					hit[n] = true
					out.append("%s: road touches the thing at (%s, %s)" % [label, box.x, box.y])
	return out


## The ground colour of `id`, or magenta for an unknown id so it shows.
static func tint(id: StringName) -> Color:
	var text: String = str(biome(id).get("tint", ""))
	return Color(text) if Color.html_is_valid(text) else Color.MAGENTA


## The colour the real ground of `id` leans toward in play, or white for an unknown id
## (no change). It is a multiplier on the height tint, not the F8 overlay's colour.
static func ground_tint(id: StringName) -> Color:
	var text: String = str(biome(id).get("ground_tint", ""))
	return Color(text) if Color.html_is_valid(text) else Color.WHITE


## The zone-level band of `id` as (min, max), or (0, 0) for an unknown id.
static func band(id: StringName) -> Vector2i:
	var raw: Variant = biome(id).get("band")
	if raw is Array and (raw as Array).size() == 2:
		return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	return Vector2i.ZERO


## The line on the biome's sign, or "" for an unknown id.
static func sign_text(id: StringName) -> String:
	return str(biome(id).get("sign", ""))


## The zone ids with a way in inside the biome, in table order.
static func zones(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var raw: Variant = biome(id).get("entrances")
	if raw is Array:
		for entrance: Variant in raw as Array:
			out.append(StringName(str((entrance as Dictionary).get("zone", ""))))
	return out


## Where `zone`'s way in is inside biome `id`, or null when it is not placed.
static func entrance_at(id: StringName, zone: StringName) -> Variant:
	var raw: Variant = biome(id).get("entrances")
	if raw is Array:
		for entrance: Variant in raw as Array:
			var spot: Dictionary = entrance
			if str(spot.get("zone", "")) == String(zone):
				return _point(spot["at"]) if spot.get("at") is Array else null
	return null


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
		var covers: bool = distance <= _number(row.get("reach_m"))
		if role == "hub" and covers:
			return id
		if role == "open":
			open_id = id
		elif role == "spoke" and covers and distance < best_distance:
			best = id
			best_distance = distance
	return best if best != &"" else open_id


# --- Ground the markers sit on --------------------------------------------------

## Every built thing and solid rock a pad must keep off, as x, z, half-width x,
## half-width z. The rocks come from HillDressing.ROCKS, each as the square its
## longest side makes (a rock may stand any way).
static func spots() -> Array[Vector4]:
	var out: Array[Vector4] = SCENE_SPOTS.duplicate()
	for at: Vector2i in HillDressing.ROCKS:
		var size: Vector3 = HillDressing.ROCK_SIZE_M[HillDressing.ROCKS[at]]
		var half: float = maxf(size.x, size.z) * 0.5
		out.append(Vector4(at.x, at.y, half, half))
	return out


## The height spread (highest less lowest) of the ground under a 4 by 4 m pad
## whose middle is `at`: every 1 m point of the 5 by 5 grid over the pad, read with
## Terrain.height (which blends between the 1 m points, so a middle that is not on
## a whole metre is read right) on the land as it is with no digging.
static func pad_spread_m(at: Vector2) -> float:
	var low: float = INF
	var high: float = -INF
	var none: Dictionary[Vector2i, int] = {}
	for dx: int in range(-2, 3):
		for dz: int in range(-2, 3):
			var h: float = Terrain.height(Vector2(at.x + dx, at.y + dz), none)
			low = minf(low, h)
			high = maxf(high, h)
	return high - low


## What is wrong with putting a rover pad (4 by 4 m) at `at`: the plot, built
## things and rocks, the relay road, and ground that is not near flat.
static func pad_problems(label: String, field: String, at: Vector2) -> Array[String]:
	var out: Array[String] = []
	var plot: float = PLOT_HALF_M + PLOT_CLEAR_M
	if absf(at.x) < plot and absf(at.y) < plot:
		out.append("%s: %s is on the farm plot" % [label, field])
	var reach_m: float = PAD_HALF_M + PAD_CLEAR_M
	for spot: Vector4 in spots():
		if absf(at.x - spot.x) < spot.z + reach_m and absf(at.y - spot.y) < spot.w + reach_m:
			out.append("%s: %s pad is on or too near the thing at (%s, %s)" % [label, field, spot.x, spot.y])
	var along: float = clampf(at.dot(Terrain.RELAY_WAY), 0.0, Terrain.RELAY.length())
	var road_gap: float = at.distance_to(Terrain.RELAY_WAY * along)
	if road_gap < Terrain.ROAD_LEVEL_M + PAD_HALF_M * sqrt(2.0):
		out.append("%s: %s pad is %.1f m from the relay road, inside its %d m level strip" % [label, field, road_gap, int(Terrain.ROAD_LEVEL_M)])
	var spread: float = pad_spread_m(at)
	if spread > PAD_SPREAD_MAX_M:
		out.append("%s: %s pad ground varies by %.2f m, over the %.2f m limit" % [label, field, spread, PAD_SPREAD_MAX_M])
	return out


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
		var label: String = _label(row, i)
		if typeof(row.get("role")) == TYPE_STRING:
			roles[row["role"]] = int(roles.get(row["role"], 0)) + 1
		var before: int = out.size()
		for field: String in FIELDS:
			if not row.has(field):
				out.append("%s: missing %s" % [label, field])
			elif not _type_ok(row[field], int(FIELDS[field])):
				out.append("%s: %s has the wrong type" % [label, field])
		if typeof(row.get("id")) == TYPE_STRING:
			if str(row["id"]).strip_edges().is_empty():
				out.append("row %d: empty id" % i)
			elif seen.has(row["id"]):
				out.append("%s: duplicate id" % label)
			seen[row["id"]] = true
		if out.size() > before:
			continue
		out.append_array(_row_problems(label, row))
		sound.append(row)
	for role: String in ["hub", "open"]:
		if int(roles.get(role, 0)) != 1:
			out.append("the table needs exactly one %s row, not %d" % [role, int(roles.get(role, 0))])
	# Only when every row is sound can the points be asked where they fall.
	if out.is_empty():
		out.append_array(_table_problems(sound))
	return out


## The name a row goes by in a message.
static func _label(row: Dictionary, index: int) -> String:
	var id: Variant = row.get("id")
	if id is String and not (id as String).strip_edges().is_empty():
		return id
	return "row %d" % index


static func _row_problems(label: String, row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not ROLES.has(str(row["role"])):
		out.append("%s: unknown role %s" % [label, row["role"]])
	if str(row["name"]).strip_edges().is_empty():
		out.append("%s: empty name" % label)
	if str(row["sign"]).strip_edges().is_empty():
		out.append("%s: empty sign" % label)
	if float(row["reach_m"]) <= 0.0:
		out.append("%s: reach_m must be above 0" % label)
	if not Color.html_is_valid(str(row["tint"])):
		out.append("%s: tint %s is not a colour" % [label, row["tint"]])
	if not Color.html_is_valid(str(row["ground_tint"])):
		out.append("%s: ground_tint %s is not a colour" % [label, row["ground_tint"]])
	out.append_array(_band_problems(label, row["band"]))
	for field: String in ["centre", "marker"]:
		out.append_array(_point_problems(label, field, row[field]))
	for i: int in (row["road"] as Array).size():
		out.append_array(_point_problems(label, "road waypoint %d" % i, (row["road"] as Array)[i]))
	if str(row["role"]) == "hub" and not (row["road"] as Array).is_empty():
		out.append("%s: the hub has no road" % label)
	var bearing: Variant = row.get("bearing_deg")
	if str(row["role"]) == "hub":
		if bearing != null:
			out.append("%s: the hub has no bearing_deg" % label)
	elif bearing == null or (typeof(bearing) != TYPE_FLOAT and typeof(bearing) != TYPE_INT):
		out.append("%s: a spoke or open biome needs a bearing_deg" % label)
	elif float(bearing) < 0.0 or float(bearing) >= 360.0:
		out.append("%s: bearing_deg %s must be from 0 up to 360" % [label, bearing])
	for i: int in (row["entrances"] as Array).size():
		out.append_array(_entrance_problems(label, i, (row["entrances"] as Array)[i]))
	return out


static func _entrance_problems(label: String, index: int, entrance: Variant) -> Array[String]:
	var out: Array[String] = []
	if not entrance is Dictionary or not (entrance as Dictionary).has("zone") or not (entrance as Dictionary).has("at"):
		out.append("%s: entrance %d must be {zone, at}" % [label, index])
		return out
	var spot: Dictionary = entrance
	if not spot["zone"] is String or not ZoneData.has_zone(StringName(spot["zone"] as String)):
		out.append("%s: entrance %d zone %s is not a zones.json id" % [label, index, spot["zone"]])
	if spot["at"] != null:
		out.append_array(_point_problems(label, "entrance %d at" % index, spot["at"]))
	return out


static func _type_ok(value: Variant, want: int) -> bool:
	if want == TYPE_FLOAT:
		return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT
	return typeof(value) == want


## A point is [x, z]: two numbers, inside the land (a marker, inside the edge
## margin too).
static func _point_problems(label: String, field: String, raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if not raw is Array or (raw as Array).size() != 2:
		out.append("%s: %s must be [x, z]" % [label, field])
		return out
	for part: Variant in raw as Array:
		if typeof(part) != TYPE_FLOAT and typeof(part) != TYPE_INT:
			out.append("%s: %s must be two numbers" % [label, field])
			return out
	var is_marker: bool = field == "marker"
	var limit: float = Terrain.HALF_M - (EDGE_MARGIN_M if is_marker else 0.0)
	var p: Vector2 = _point(raw)
	if absf(p.x) > limit or absf(p.y) > limit:
		var rule: String = "%d m land's %d m edge margin" % [int(Terrain.HALF_M * 2.0), int(EDGE_MARGIN_M)] if is_marker else "%d m land" % int(Terrain.HALF_M * 2.0)
		out.append("%s: %s (%s, %s) is outside the %s" % [label, field, p.x, p.y, rule])
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


## The rules that need the whole table: zones claimed once, where every centre,
## marker and entrance falls and what they sit on, and whether a biome's centre
## lies on its bearing.
static func _table_problems(table: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	var claimed: Dictionary = {}
	var pads: Array[Dictionary] = []
	for row: Dictionary in table:
		var id: String = str(row["id"])
		out.append_array(_place_problems(id, row, table))
		for entrance: Dictionary in row["entrances"]:
			var zone: String = str(entrance["zone"])
			if claimed.has(zone):
				out.append("%s: zone %s is also an entrance of %s" % [id, zone, claimed[zone]])
			claimed[zone] = id
		pads.append({"id": id, "at": _point(row["marker"])})
	for row: Dictionary in table:
		for entrance: Dictionary in row["entrances"]:
			if entrance["at"] == null:
				continue
			var at: Vector2 = _point(entrance["at"])
			for pad: Dictionary in pads:
				var m: Vector2 = pad["at"]
				if absf(at.x - m.x) < PAD_HALF_M + PAD_CLEAR_M and absf(at.y - m.y) < PAD_HALF_M + PAD_CLEAR_M:
					out.append("%s: marker is on the %s entrance of %s" % [pad["id"], entrance["zone"], row["id"]])
	for i: int in pads.size():
		for j: int in range(i + 1, pads.size()):
			var a: Vector2 = pads[i]["at"]
			var b: Vector2 = pads[j]["at"]
			if absf(a.x - b.x) < PAD_HALF_M * 2.0 + PAD_CLEAR_M and absf(a.y - b.y) < PAD_HALF_M * 2.0 + PAD_CLEAR_M:
				out.append("%s: marker is on the marker of %s" % [pads[i]["id"], pads[j]["id"]])
	return out


static func _place_problems(label: String, row: Dictionary, table: Array) -> Array[String]:
	var out: Array[String] = []
	var id := StringName(label)
	var marker_at: Vector2 = _point(row["marker"])
	out.append_array(pad_problems(label, "marker", marker_at))
	out.append_array(road_problems(label, road_in(row), marker_at))
	var centre_at: Vector2 = _point(row["centre"])
	for spot: Vector4 in spots():
		if absf(centre_at.x - spot.x) < spot.z and absf(centre_at.y - spot.y) < spot.w:
			out.append("%s: centre is on the thing at (%s, %s)" % [label, spot.x, spot.y])
	if at_in(table, centre_at) != id:
		out.append("%s: its own centre falls in %s" % [label, at_in(table, centre_at)])
	if at_in(table, marker_at) != id:
		out.append("%s: its marker falls in %s" % [label, at_in(table, marker_at)])
	for entrance: Dictionary in row["entrances"]:
		if entrance["at"] == null:
			continue
		var at: Vector2 = _point(entrance["at"])
		if at_in(table, at) != id:
			out.append("%s: its %s entrance falls in %s" % [label, entrance["zone"], at_in(table, at)])
	if str(row["role"]) != "hub":
		var actual: float = fposmod(rad_to_deg(atan2(centre_at.x, -centre_at.y)), 360.0)
		var gap: float = absf(fposmod(float(row["bearing_deg"]) - actual + 180.0, 360.0) - 180.0)
		if gap > BEARING_SLACK_DEG:
			out.append("%s: bearing_deg %s is %d degrees off its centre's bearing %d" % [label, row["bearing_deg"], int(gap), int(actual)])
	return out


static func _point(raw: Variant) -> Vector2:
	if raw is Array and (raw as Array).size() == 2:
		return Vector2(_number((raw as Array)[0]), _number((raw as Array)[1]))
	return Vector2.ZERO


## A number out of JSON, or 0 for anything else (null, text), so a reader never
## trips on a bad value.
static func _number(raw: Variant) -> float:
	return float(raw) if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT else 0.0
