class_name Loadout
extends RefCounted
## The picker's data: six slots of four parts each (Ryan, Nov 27), three on the
## character and three on the tractor. The first part of every slot is the default,
## what everyone has had so far. Only the Power Unit and the Wheel Type change how the
## tractor drives; the rest are looks. Every number, shape and colour here is a
## [PLACEHOLDER] until the real art and a playtest.

const HEAD: StringName = &"head"
const UPPER: StringName = &"upper"
const LOWER: StringName = &"lower"
const CHASSIS: StringName = &"chassis"
const POWER: StringName = &"power"
const WHEELS: StringName = &"wheels"
## In the order the picker shows them.
const SLOTS: Array[StringName] = [HEAD, UPPER, LOWER, CHASSIS, POWER, WHEELS]
const SLOT_TITLES: Dictionary[StringName, String] = {
	HEAD: "HEAD WEAR", UPPER: "UPPER BODY", LOWER: "LOWER BODY",
	CHASSIS: "CHASSIS", POWER: "POWER UNIT", WHEELS: "WHEEL TYPE",
}
## The character's name is this long at most, and shown as this when left empty.
const MAX_NAME: int = 16
const UNNAMED: String = "Operator"
## The drive multipliers a part may carry, and what each one is on the rover.
## A part names only those it changes; the others are 1.
const DRIVE_KEYS: Array[StringName] = [&"speed", &"accel", &"brake", &"turn", &"wade"]
## The top speed all multipliers together may reach, as a share of the base: the host
## accepts a rover pose only up to CoopRovers.REACH_MPS, and the base is 6 m/s. The best
## pair of parts gives 1.21; drive() clamps to this, so no table edit can pass it.
const MAX_SPEED_FACTOR: float = 1.21
## Matte roughness for generated tractor loadout look meshes [PLACEHOLDER].
const LOOK_ROUGHNESS: float = 0.9

## Slot -> its four parts, the default first. A part: id, name, trade-off text (wheels
## and power only), the drive multipliers it changes, and its look: boxes of centre,
## size and colour, in the voxels of WalkerModel for the character and in meters on the
## rover for the tractor.
static var PARTS: Dictionary[StringName, Array] = _build()


static func _build() -> Dictionary[StringName, Array]:
	var green: Color = ScopeTheme.TEAL.darkened(0.45)
	var out: Dictionary[StringName, Array] = {}
	out[HEAD] = [
		_part(&"survey_helmet", "Survey Helmet", "", {}, []),
		_part(&"mechanic_cap_goggles", "Mechanic Cap & Goggles", "", {}, [
			_box(0.0, 8.15, 0.0, 2.7, 0.5, 2.7, ScopeTheme.TERRA_DARK), _box(0.0, 8.0, -1.5, 2.2, 0.2, 0.8, ScopeTheme.TERRA_DARK),
			_box(0.0, 7.4, -1.2, 2.2, 0.4, 0.4, ScopeTheme.AMBER)]),
		_part(&"sun_brim_hat", "Sun-Brim Hat", "", {}, [
			_box(0.0, 8.0, 0.0, 4.4, 0.2, 4.4, ScopeTheme.ENAMEL_LIP), _box(0.0, 8.4, 0.0, 2.4, 0.7, 2.4, ScopeTheme.ENAMEL)]),
		_part(&"canyon_respirator_hood", "Canyon Respirator Hood", "", {}, [
			_box(0.0, 6.9, 0.2, 2.9, 2.8, 2.6, ScopeTheme.TERRA), _box(0.0, 6.1, -1.3, 1.2, 0.9, 0.6, ScopeTheme.GLASS_LINE)]),
	]
	out[UPPER] = [
		_part(&"frontier_flight_suit", "Frontier Flight Suit", "", {}, []),
		_part(&"calibration_lab_coat", "Calibration Lab Coat", "", {}, [
			_box(0.0, 3.9, 0.0, 2.9, 3.2, 1.8, ScopeTheme.ENAMEL_TOP)]),
		_part(&"mechanic_coverall", "Mechanic Coverall", "", {}, [
			_box(0.0, 4.25, -0.8, 2.6, 2.6, 0.2, ScopeTheme.AMBER), _box(0.0, 3.0, 0.0, 2.7, 0.4, 1.7, ScopeTheme.SHADOW)]),
		_part(&"botanist_field_vest", "Botanist Field Vest", "", {}, [
			_box(0.0, 4.4, 0.0, 2.9, 2.0, 1.7, green)]),
	]
	out[LOWER] = [
		_part(&"standard_field_boots", "Standard Field Boots", "", {}, []),
		_part(&"mechanic_workpants", "Mechanic Workpants", "", {}, [
			_box(-0.75, 1.9, 0.0, 1.15, 2.2, 1.15, ScopeTheme.GLASS_LINE), _box(0.75, 1.9, 0.0, 1.15, 2.2, 1.15, ScopeTheme.GLASS_LINE)]),
		_part(&"thermal_basalt_greaves", "Thermal Basalt Greaves", "", {}, [
			_box(-0.75, 1.2, -0.6, 1.1, 1.6, 0.3, ScopeTheme.TERRA_DARK), _box(0.75, 1.2, -0.6, 1.1, 1.6, 0.3, ScopeTheme.TERRA_DARK),
			_box(-0.75, 2.4, -0.6, 1.2, 0.5, 0.4, ScopeTheme.TERRA_DARK), _box(0.75, 2.4, -0.6, 1.2, 0.5, 0.4, ScopeTheme.TERRA_DARK)]),
		_part(&"botanist_waders", "Botanist Waders", "", {}, [
			_box(-0.75, 1.9, 0.0, 1.2, 3.2, 1.2, green), _box(0.75, 1.9, 0.0, 1.2, 3.2, 1.2, green)]),
	]
	out[CHASSIS] = [
		_part(&"standard_utility_cab", "Standard Utility Cab", "", {}, []),
		_part(&"open_roll_cage_surveyor", "Open Roll-Cage Surveyor", "", {}, [
			_box(-0.55, 1.6, 0.05, 0.06, 0.9, 0.06, ScopeTheme.AMBER), _box(0.55, 1.6, 0.05, 0.06, 0.9, 0.06, ScopeTheme.AMBER),
			_box(-0.55, 1.6, 0.95, 0.06, 0.9, 0.06, ScopeTheme.AMBER), _box(0.55, 1.6, 0.95, 0.06, 0.9, 0.06, ScopeTheme.AMBER),
			_box(0.0, 2.05, 0.5, 1.2, 0.06, 1.0, ScopeTheme.AMBER)]),
		_part(&"tunnel_armor_hull", "Tunnel Armor Hull", "", {}, [
			_box(-0.75, 0.75, 0.0, 0.12, 0.5, 2.2, ScopeTheme.SHADOW), _box(0.75, 0.75, 0.0, 0.12, 0.5, 2.2, ScopeTheme.SHADOW),
			_box(0.0, 0.7, -1.3, 1.3, 0.5, 0.15, ScopeTheme.SHADOW)]),
		_part(&"flatbed_cargo_frame", "Flatbed Cargo Frame", "", {}, [
			_box(0.0, 0.95, 1.5, 1.4, 0.1, 1.0, ScopeTheme.ENAMEL_LIP), _box(-0.65, 1.15, 1.5, 0.06, 0.3, 1.0, ScopeTheme.ENAMEL_LIP),
			_box(0.65, 1.15, 1.5, 0.06, 0.3, 1.0, ScopeTheme.ENAMEL_LIP)]),
	]
	# [PLACEHOLDER] numbers. Each part trades one thing for another; 1 is today.
	out[POWER] = [
		_part(&"thermal_diesel_block", "Thermal Diesel Block", "As it is today.", {}, []),
		_part(&"twin_cell_battery_pack", "Twin-Cell Battery Pack", "+ acceleration, − top speed", {&"accel": 1.2, &"speed": 0.95}, [
			_box(-0.3, 0.95, 1.1, 0.4, 0.3, 0.5, ScopeTheme.TEAL), _box(0.3, 0.95, 1.1, 0.4, 0.3, 0.5, ScopeTheme.TEAL)]),
		_part(&"folding_solar_array", "Folding Solar Array", "+ top speed, − acceleration", {&"speed": 1.1, &"accel": 0.7}, [
			_box(0.0, 2.0, 0.6, 1.6, 0.05, 1.2, ScopeTheme.GLASS_DEEP), _box(0.0, 1.8, 0.6, 0.06, 0.4, 0.06, ScopeTheme.AMBER)]),
		_part(&"silk_coil_harmonic_cell", "Silk-Coil Harmonic Cell", "+ acceleration and braking, − top speed", {&"accel": 1.3, &"brake": 1.3, &"speed": 0.9}, [
			_box(0.0, 1.05, 1.15, 0.5, 0.5, 0.5, ScopeTheme.ENAMEL_TOP), _box(0.0, 1.05, 1.15, 0.6, 0.1, 0.6, ScopeTheme.AMBER)]),
	]
	out[WHEELS] = [
		_part(&"standard_ag_tires", "Standard Ag Tires", "As it is today.", {}, []),
		_part(&"wide_crawler_tracks", "Wide Crawler Tracks", "+ wading, − top speed, − turning", {&"wade": 1.25, &"speed": 0.85, &"turn": 0.8}, [
			_box(-0.95, 0.35, 0.0, 0.5, 0.7, 2.4, ScopeTheme.SHADOW), _box(0.95, 0.35, 0.0, 0.5, 0.7, 2.4, ScopeTheme.SHADOW)]),
		_part(&"rock_climber_wheels", "Rock-Climber Wheels", "+ wading, + turning, − top speed", {&"wade": 1.15, &"turn": 1.1, &"speed": 0.9}, [
			_box(-1.0, 0.55, -0.8, 0.35, 1.1, 1.1, ScopeTheme.GLASS_LINE), _box(1.0, 0.55, -0.8, 0.35, 1.1, 1.1, ScopeTheme.GLASS_LINE),
			_box(-1.0, 0.55, 0.8, 0.35, 1.1, 1.1, ScopeTheme.GLASS_LINE), _box(1.0, 0.55, 0.8, 0.35, 1.1, 1.1, ScopeTheme.GLASS_LINE)]),
		_part(&"six_wheel_survey_bogie", "Six-Wheel Survey Bogie", "+ top speed, − turning", {&"speed": 1.1, &"turn": 0.85}, [
			_box(-0.95, 0.45, 0.0, 0.3, 0.9, 0.9, ScopeTheme.SHADOW), _box(0.95, 0.45, 0.0, 0.3, 0.9, 0.9, ScopeTheme.SHADOW),
			_box(0.0, 0.5, 0.0, 1.6, 0.1, 0.1, ScopeTheme.SHADOW)]),
	]
	return out


static func _part(id: StringName, label: String, trade_off: String, drive: Dictionary, look: Array) -> Dictionary:
	return { "id": id, "name": label, "trade_off": trade_off, "drive": drive, "look": look }


static func _box(x: float, y: float, z: float, w: float, h: float, d: float, color: Color) -> Dictionary:
	return { "at": Vector3(x, y, z), "size": Vector3(w, h, d), "color": color }


## The default part of each slot.
static func default_parts() -> Dictionary:
	var out: Dictionary = {}
	for slot: StringName in SLOTS:
		out[slot] = PARTS[slot][0]["id"]
	return out


static func parts_of(slot: StringName) -> Array:
	return PARTS.get(slot, [])


## The part `id` in `slot`, or the slot's default when there is none.
static func part(slot: StringName, id: Variant) -> Dictionary:
	var parts: Array = parts_of(slot)
	if parts.is_empty():
		return {}
	for entry: Dictionary in parts:
		if str(id) == String(entry["id"]):
			return entry
	return parts[0]


static func is_part(slot: StringName, id: Variant) -> bool:
	if not (id is String or id is StringName):
		return false
	for entry: Dictionary in parts_of(slot):
		if str(id) == String(entry["id"]):
			return true
	return false


## `parts` with every slot present and every unknown or missing part the default.
static func clean(parts: Variant) -> Dictionary:
	var out: Dictionary = default_parts()
	if not parts is Dictionary:
		return out
	for slot: StringName in SLOTS:
		var given: Variant = (parts as Dictionary).get(String(slot), (parts as Dictionary).get(slot))
		if is_part(slot, given):
			out[slot] = StringName(str(given))
	return out


## The name as it may be kept: no control characters (C0, DEL, C1), no direction
## overrides or zero-width marks, no "[" (it would open markup), trimmed, cut to MAX_NAME.
## GameState.set_loadout refuses a longer name before it gets here.
static func clean_name(text: Variant) -> String:
	if not text is String:
		return ""
	var kept: String = ""
	for i: int in (text as String).length():
		var code: int = (text as String).unicode_at(i)
		if code < 32 or (code >= 127 and code <= 159) or code == 91:
			continue
		if (code >= 0x200B and code <= 0x200F) or (code >= 0x202A and code <= 0x202E) 				or (code >= 0x2060 and code <= 0x2069) or code == 0xFEFF:
			continue
		kept += (text as String)[i]
	return kept.strip_edges().left(MAX_NAME).strip_edges()


## The name shown for a stored one.
static func shown_name(stored: String) -> String:
	return stored if stored != "" else UNNAMED


## Parts as a request carries them: the index of each part in its slot, in SLOTS order
## ("0,2,0,1,0,3"). A request may hold only text and numbers, and ids are longer than the
## 64 letters one text may be.
static func encode(parts: Dictionary) -> String:
	var cleaned: Dictionary = clean(parts)
	var out: PackedStringArray = []
	for slot: StringName in SLOTS:
		out.append(str(index_of(slot, cleaned[slot])))
	return ",".join(out)


## The parts for `text`, or an empty dictionary when it is not one index per slot.
static func decode(text: String) -> Dictionary:
	var pieces: PackedStringArray = text.split(",")
	if pieces.size() != SLOTS.size():
		return {}
	var out: Dictionary = {}
	for i: int in SLOTS.size():
		if not pieces[i].is_valid_int():
			return {}
		var index: int = pieces[i].to_int()
		if index < 0 or index >= parts_of(SLOTS[i]).size() or str(index) != pieces[i]:
			return {}
		out[SLOTS[i]] = parts_of(SLOTS[i])[index]["id"]
	return out


static func index_of(slot: StringName, id: Variant) -> int:
	var parts: Array = parts_of(slot)
	for i: int in parts.size():
		if str(id) == String(parts[i]["id"]):
			return i
	return 0


## The drive multipliers of a set of parts: the wheels' and the power unit's multiplied
## together, 1 for what no part changes. The defaults give exactly 1 for all of them.
static func drive(parts: Variant) -> Dictionary:
	var cleaned: Dictionary = clean(parts)
	var out: Dictionary = {}
	for key: StringName in DRIVE_KEYS:
		out[key] = 1.0
	for slot: StringName in [POWER, WHEELS]:
		var changes: Dictionary = part(slot, cleaned[slot])["drive"]
		for key: StringName in changes:
			out[key] = float(out[key]) * float(changes[key])
	out[&"speed"] = minf(float(out[&"speed"]), MAX_SPEED_FACTOR)
	return out


## Builds the rover's LoadoutLook Node3D for the tractor slots (chassis, power, wheels)
## in `parts`, or returns null when those parts add no look meshes.
static func build_look(parts: Dictionary) -> Node3D:
	var cleaned: Dictionary = clean(parts)
	var specs: Array = []
	for slot: StringName in [CHASSIS, POWER, WHEELS]:
		specs.append_array(part(slot, cleaned[slot])["look"])
	if specs.is_empty():
		return null
	var root := Node3D.new()
	root.name = &"LoadoutLook"
	for spec: Dictionary in specs:
		var mesh := BoxMesh.new()
		mesh.size = spec["size"]
		var material := StandardMaterial3D.new()
		material.albedo_color = spec["color"]
		material.roughness = LOOK_ROUGHNESS
		mesh.material = material
		var box := MeshInstance3D.new()
		box.mesh = mesh
		box.position = spec["at"]
		root.add_child(box)
	return root


## "" or why a stored loadout (name and parts) can't be loaded. An unknown part is not a
## problem: it loads as the default. What it must be is plain data of the right kind.
static func entry_problem(entry: Variant) -> String:
	if not entry is Dictionary:
		return "a loadout that is not a dictionary"
	if not (entry as Dictionary).get("name", "") is String or ((entry as Dictionary).get("name", "") as String).length() > MAX_NAME:
		return "a loadout with a bad name"
	var parts: Variant = (entry as Dictionary).get("parts", {})
	if not parts is Dictionary:
		return "a loadout with no parts dictionary"
	if (parts as Dictionary).size() > SLOTS.size():
		return "a loadout with too many parts"
	for key: Variant in parts:
		if not (key is String or key is StringName) or not (parts[key] is String or parts[key] is StringName):
			return "a loadout part that is not text"
	return ""
