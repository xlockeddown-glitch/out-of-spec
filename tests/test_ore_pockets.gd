extends RefCounted
## Buried ore pockets: where they are, that each comes once, and the survey that
## points at them with the steering encoder's error.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const SEED: int = 424242
const NORTH_M := Vector2(0.0, 20.0)

var _none: Dictionary[Vector2i, bool] = {}


func _make(seed_value: int = SEED) -> Node:
	var gs: Node = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(seed_value)
	return gs


func _middle(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5) * Terrain.CELL_M


## A place some meters from a pocket where no other is nearer.
func _near(cell: Vector2i) -> Vector2:
	return _middle(cell) + Vector2(3.0, 0.0)


func _survey(gs: Node, at: Vector2) -> Dictionary:
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(at.x, 0.0, at.y))
	return gs.survey_ore()


func _off_deg(one: float, other: float) -> float:
	return rad_to_deg(angle_difference(deg_to_rad(other), deg_to_rad(one)))


func test_pockets_are_few_and_the_same_for_a_seed() -> String:
	var dug: Dictionary[Vector2i, int] = {}
	var first: Array[Vector2i] = OrePocket.cells(SEED).duplicate()
	var other: Array[Vector2i] = OrePocket.cells(SEED + 1).duplicate()
	if first.size() != OrePocket.COUNT or first == other or OrePocket.cells(SEED) != first:
		return "A seed must hold the same few pockets, and another seed others: %s, %s" % [first, other]
	for seed_value: int in range(SEED, SEED + 20):
		var cells: Array[Vector2i] = OrePocket.cells(seed_value)
		var around := Rect2i(cells[0], Vector2i.ZERO)
		for cell: Vector2i in cells:
			around = around.expand(cell)
		if around.size.x < 20 or around.size.y < 20:
			return "Seed %d: the pockets must lie about the farm, not in a clump: %s" % [seed_value, cells]
		for cell: Vector2i in cells:
			if Terrain.dig_problem(cell, dug, true) != "" or not ReferenceBlock.at(seed_value, cell).is_empty() or cells.count(cell) != 1:
				return "Seed %d: %s can't be dug, holds a block, or is there twice." % [seed_value, cell]
	return ""


func test_digging_gives_a_pocket_once() -> String:
	var gs: Node = _make()
	var cell: Vector2i = OrePocket.cells(SEED)[0]
	var at := Vector3i(cell.x, 0, cell.y)
	var beside := at + Vector3i(1, 0, 0)
	var told: Array[int] = [0, 0]
	gs.pockets_changed.connect(func() -> void: told[0] += 1)
	gs.ore_changed.connect(func(_ore: int) -> void: told[1] += 1)
	var problems: PackedStringArray = []
	gs.dig(beside)
	if gs.crystal_ore != 0 or not gs.found_pockets.is_empty():
		problems.append("Plain ground gave ore.")
	if gs.dig(at) != "" or gs.crystal_ore != OrePocket.ORE or told != [1, 1]:
		problems.append("A pocket must give its ore, and say so: %d, %s" % [gs.crystal_ore, told])
	gs.fill(at)
	gs.dig(at)
	gs.fill(at)
	gs.dig(at)
	if gs.crystal_ore != OrePocket.ORE or gs.found_pockets.size() != 1:
		problems.append("A pocket gave its ore again.")
	var back: Node = _make(SEED + 9)
	if back.farm_from_dict(gs.farm_to_dict()) != "" or back.found_pockets != gs.found_pockets:
		problems.append("The pockets found must come back.")
	back.fill(at)
	back.dig(at)
	if back.crystal_ore != OrePocket.ORE:
		problems.append("A reloaded farm gave a pocket's ore again.")
	gs.free()
	back.free()
	return "\n".join(problems)


func test_a_save_is_refused_if_its_pockets_cant_be_there() -> String:
	var gs: Node = _make()
	var cell: Vector2i = OrePocket.cells(SEED)[0]
	var problems: PackedStringArray = []
	var good: Dictionary = gs.farm_to_dict()
	good["found_pockets"] = { cell: true }
	if gs.farm_dict_problem(good) != "":
		problems.append("A pocket where one lies must load: %s" % gs.farm_dict_problem(good))
	for bad: Variant in [{ Vector2i(9999, 0): true }, { cell: false }, { cell: 1 }, { "x": true }, { Vector3i(cell.x, 0, cell.y): true }, []]:
		var data: Dictionary = gs.farm_to_dict()
		data["found_pockets"] = bad
		if gs.farm_dict_problem(data) == "":
			problems.append("Loaded pockets %s" % [bad])
	gs.found_pockets[cell] = true
	var old: Dictionary = gs.farm_to_dict()
	old.erase("found_pockets")
	if gs.farm_from_dict(old) != "" or not gs.found_pockets.is_empty():
		problems.append("A save from before pockets must load with none.")
	gs.free()
	return "\n".join(problems)


func test_bearings_turn_clockwise_from_north() -> String:
	var at := Vector2(5.0, 7.0)
	for pair: Array in [[Vector2(0, -9), 0.0], [Vector2(9, 0), 90.0], [Vector2(0, 9), 180.0], [Vector2(-9, 0), 270.0]]:
		if absf(OrePocket.bearing_deg(at, at + pair[0]) - pair[1]) > 0.001:
			return "Toward %s must be %s: %s" % [pair[0], pair[1], OrePocket.bearing_deg(at, at + pair[0])]
		if OrePocket.way(pair[1]).distance_to((pair[0] as Vector2).normalized()) > 0.001:
			return "Bearing %s must point %s." % [pair[1], pair[0]]
	return ""


func test_the_reading_is_the_true_bearing_plus_the_true_error() -> String:
	var steer: DriftingSensor = DriftingSensor.from_config("rover_steering_encoder")
	var problems: PackedStringArray = []
	var digit: float = steer.resolution
	for cell: Vector2i in OrePocket.cells(SEED):
		var at: Vector2 = _near(cell)
		var truly: float = OrePocket.bearing_deg(at, OrePocket.nearest(SEED, _none, at))
		# A hidden offset must not matter: only the true error does.
		for error: float in [0.0, 3.0, -8.0]:
			steer.error = error
			steer.reference_offset = 1.5
			var record: Dictionary = OrePocket.survey(steer, SEED, _none, at)
			if not record["found"] or absf(_off_deg(record["bearing"], truly) - error) > digit:
				problems.append("%s with error %s: true %s, reads %s" % [cell, error, truly, record])
			elif record["bearing"] < 0.0 or record["bearing"] >= 360.0:
				problems.append("A bearing is from 0 up to 360: %s" % record["bearing"])
			if record.keys() != ["refused", "found", "bearing", "mpe", "from"]:
				problems.append("The answer must not tell the true error or spot: %s" % [record])
	# The digit must not round up to 360.
	steer.error = 359.99 - OrePocket.bearing_deg(_near(OrePocket.cells(SEED)[0]), OrePocket.nearest(SEED, _none, _near(OrePocket.cells(SEED)[0])))
	if OrePocket.survey(steer, SEED, _none, _near(OrePocket.cells(SEED)[0]))["bearing"] >= 360.0:
		problems.append("359.99 must read 0.")
	return "\n".join(problems)


func test_a_drifted_encoder_crosses_two_readings_in_the_wrong_place() -> String:
	var steer: DriftingSensor = DriftingSensor.from_config("rover_steering_encoder")
	var missed: Dictionary[float, float] = {}
	for error: float in [0.0, 3.2, 8.0]:
		steer.error = error
		var cell: Vector2i = OrePocket.cells(SEED)[0]
		var found: Dictionary[Vector2i, bool] = {}
		for other: Vector2i in OrePocket.cells(SEED):
			if other != cell:
				found[other] = true
		var spots: Array[Vector2] = [_middle(cell) + Vector2(25.0, 0.0), _middle(cell) + NORTH_M]
		var ways: Array[Vector2] = []
		for spot: Vector2 in spots:
			ways.append(OrePocket.way(OrePocket.survey(steer, SEED, found, spot)["bearing"]))
		var cross: Variant = Geometry2D.line_intersects_line(spots[0], ways[0], spots[1], ways[1])
		missed[error] = (cross as Vector2).distance_to(_middle(cell))
	if missed[0.0] > 0.2 or missed[3.2] > 2.0 * Terrain.CELL_M or missed[8.0] < 1.5 * Terrain.CELL_M or missed[8.0] < missed[3.2]:
		return "Readings must cross at the pocket only if the encoder is true: %s" % missed
	return ""


func test_a_survey_finds_the_nearest_not_dug_and_says_if_none() -> String:
	var gs: Node = _make()
	var problems: PackedStringArray = []
	gs.steering.error = 0.0
	var cell: Vector2i = OrePocket.cells(SEED)[0]
	var at: Vector2 = _near(cell)
	if OrePocket.nearest(SEED, gs.found_pockets, at) != _middle(cell):
		problems.append("The nearest pocket must be the one 3 m off.")
	gs.dig(Vector3i(cell.x, 0, cell.y))
	if OrePocket.nearest(SEED, gs.found_pockets, at) == _middle(cell):
		problems.append("A pocket dug up must not be pointed at.")
	if OrePocket.nearest(SEED, _none, _middle(cell) + Vector2(0.0, OrePocket.RANGE_M + 0.1)) == _middle(cell):
		problems.append("A pocket past the range was pointed at.")
	for other: Vector2i in OrePocket.cells(SEED):
		gs.found_pockets[other] = true
	var record: Dictionary = _survey(gs, at)
	if record.get("refused", true) or record.get("found", true) or record.has("bearing"):
		problems.append("With none left it must say so and read nothing: %s" % [record])
	gs.free()
	return "\n".join(problems)


func test_no_reading_without_a_usable_sensor_or_rover() -> String:
	var gs: Node = _make()
	var problems: PackedStringArray = []
	var at: Vector2 = _near(OrePocket.cells(SEED)[0])
	var humid: DriftingSensor = DriftingSensor.from_config("dome_hygrometer_rh")
	var broken: DriftingSensor = DriftingSensor.from_config("rover_steering_encoder")
	broken.error = NAN
	var records: Array[Dictionary] = [
		OrePocket.survey(null, SEED, _none, at), OrePocket.survey(humid, SEED, _none, at),
		gs.survey_ore(),
	]
	if not is_finite(broken.error):
		records.append(OrePocket.survey(broken, SEED, _none, at))
	gs.rover_in_tunnels = true
	records.append(_survey(gs, at))
	gs.rover_in_tunnels = false
	gs.sensors.erase(gs.STEERING_ID)
	records.append(_survey(gs, at))
	for record: Dictionary in records:
		if not record.get("refused", false) or str(record.get("reason", "")) == "" or record.has("bearing"):
			problems.append("It must be refused with a reason: %d %s" % [records.find(record), record])
	gs.free()
	return "\n".join(problems)


func test_a_guest_surveys_and_digs_through_the_host() -> String:
	var commands: Node = CommandsScript.new()
	commands.state = _make()
	var gs: Node = commands.state
	gs.steering.error = 2.0
	var cell: Vector2i = OrePocket.cells(SEED)[0]
	var at: Vector2 = _near(cell)
	var problems: PackedStringArray = []
	gs.rover_transforms[gs.ROVER] = Transform3D(Basis.IDENTITY, Vector3(at.x, 0.0, at.y))
	var told: Dictionary = commands.execute("player_2", &"survey_ore", [])
	if told != OrePocket.survey(gs.steering, SEED, _none, at) or not told.get("found", false):
		problems.append("A guest must get the host's answer: %s" % [told])
	if not CoopSession.is_plain([told]):
		problems.append("The answer must cross the wire: %s" % [told])
	if not commands.execute("player_2", &"survey_ore", [at]).get("refused", false):
		problems.append("A guest's word on where the rover is must be refused.")
	commands.execute("player_2", &"dig", [Vector3i(cell.x, 0, cell.y)])
	if gs.crystal_ore != OrePocket.ORE:
		problems.append("A guest's dig must give the farm its ore.")
	gs.free()
	commands.free()
	return "\n".join(problems)


func test_a_survey_changes_nothing() -> String:
	var gs: Node = _make()
	gs.steering.error = 2.0
	_survey(gs, _near(OrePocket.cells(SEED)[0]))
	var before: PackedByteArray = var_to_bytes(gs.farm_to_dict())
	for i: int in 3:
		gs.survey_ore()
	var same: bool = before == var_to_bytes(gs.farm_to_dict())
	gs.free()
	return "" if same else "A survey changed the farm."


## Digs every live pocket, then grows replacements on the host's day `day`.
func _dig_all(gs: Node, day: int) -> void:
	for cell: Vector2i in OrePocket.cells(SEED) + gs.new_pockets:
		if not gs.found_pockets.has(cell):
			gs.dig(Vector3i(cell.x, 0, cell.y))
	gs._grow_pockets(day)


func _live(gs: Node) -> int:
	var live: int = 0
	for cell: Vector2i in OrePocket.cells(SEED) + gs.new_pockets:
		live += 0 if gs.found_pockets.has(cell) else 1
	return live


func test_a_dug_pocket_stays_empty_and_a_new_one_appears_later() -> String:
	var gs: Node = _make()
	var cell: Vector2i = OrePocket.cells(SEED)[0]
	gs.dig(Vector3i(cell.x, 0, cell.y))
	var due: int = gs.pocket_pending[cell]
	if due != GameClock.get_day_index() + OrePocket.REGROW_DAYS or not gs.new_pockets.is_empty():
		return "A dug pocket must wait REGROW_DAYS for its replacement: %s %s" % [gs.pocket_pending, gs.new_pockets]
	gs._grow_pockets(due - 1)
	if not gs.new_pockets.is_empty():
		return "A new pocket came before its day."
	var told: Array[int] = [0]
	gs.pockets_changed.connect(func() -> void: told[0] += 1)
	gs._grow_pockets(due)
	if gs.new_pockets.size() != 1 or not gs.pocket_pending.is_empty() or told[0] != 1:
		return "One new pocket must come on the day, and say so: %s %d" % [gs.new_pockets, told[0]]
	var grown: Vector2i = gs.new_pockets[0]
	if grown == cell or gs.found_pockets.has(grown) or grown in OrePocket.cells(SEED):
		return "The new pocket is on a dug cell or a first pocket: %s" % grown
	var ore: int = gs.crystal_ore
	gs.fill(Vector3i(cell.x, 0, cell.y))
	gs.dig(Vector3i(cell.x, 0, cell.y))
	gs._grow_pockets(due + 50)
	if gs.crystal_ore != ore or gs.new_pockets.size() != 1:
		return "A dug pocket refilled."
	gs.dig(Vector3i(grown.x, 0, grown.y))
	if gs.crystal_ore != ore + OrePocket.ORE or not gs.found_pockets.has(grown):
		return "A new pocket must give its ore like the first ones."
	gs.free()
	return ""


func test_new_pockets_avoid_dug_and_blocked_cells_and_stay_few() -> String:
	var gs: Node = _make()
	var cell: Vector2i = OrePocket.cells(SEED)[0]
	var first: Vector2i = OrePocket.replacement(SEED, cell, gs.dug, gs.found_pockets, gs.new_pockets)
	gs.dug[first] = 1
	var second: Vector2i = OrePocket.replacement(SEED, cell, gs.dug, gs.found_pockets, gs.new_pockets)
	if second == first or second == OrePocket.NONE:
		return "A dug cell must not get a pocket: %s %s" % [first, second]
	gs.dug.clear()
	var problems: PackedStringArray = []
	var max_live: int = 0
	for day: int in range(10, 400, 5):
		_dig_all(gs, day)
		max_live = maxi(max_live, _live(gs))
	for grown: Vector2i in gs.new_pockets:
		if not Terrain.can_dig(grown) or Terrain.is_near_water(grown) or not ReferenceBlock.at(SEED, grown).is_empty() \
				or HillDressing.is_at_rock(grown) or gs.new_pockets.count(grown) != 1 or grown in OrePocket.cells(SEED):
			problems.append("New pocket %s can't be there." % grown)
	if max_live > OrePocket.COUNT or gs.new_pockets.size() < 20:
		problems.append("Live pockets must stay at most %d and the farm must keep growing them: %d live, %d grown" % [
			OrePocket.COUNT, max_live, gs.new_pockets.size()])
	gs.free()
	return "\n".join(problems)


func test_a_guest_and_a_reload_agree_on_new_pockets() -> String:
	var host: Node = _make()
	_dig_all(host, 100000)
	var guest: Node = _make(SEED + 5)
	if guest.farm_from_dict(host.farm_to_dict()) != "":
		return "The farm with new pockets must load: %s" % guest.farm_dict_problem(host.farm_to_dict())
	if guest.new_pockets != host.new_pockets or guest.pocket_pending != host.pocket_pending or host.new_pockets.is_empty():
		return "A guest must hold the host's new pockets: %s vs %s" % [guest.new_pockets, host.new_pockets]
	var cell: Vector2i = host.new_pockets[0]
	var at: Vector2 = _near(cell)
	var told: Dictionary = _survey(host, at)
	var seen: Dictionary = _survey(guest, at)
	if not told.get("found", false) or told != seen:
		return "Survey must find a new pocket the same for host and guest: %s vs %s" % [told, seen]
	if OrePocket.nearest(SEED, host.found_pockets, at, host.new_pockets) != _middle(cell):
		return "Survey must point at the new pocket."
	if OrePocket.nearest(SEED, host.found_pockets, at) == _middle(cell):
		return "Without the farm's new pockets the survey would not know them."
	host.dig(Vector3i(cell.x, 0, cell.y))
	if guest.farm_from_dict(host.farm_to_dict()) != "" or guest.found_pockets != host.found_pockets \
			or guest.pocket_pending != host.pocket_pending:
		return "A dug new pocket must reach the guest."
	if OrePocket.nearest(SEED, guest.found_pockets, at, guest.new_pockets) == _middle(cell):
		return "A dug new pocket must not be surveyed again."
	var back: Node = _make(SEED + 9)
	if back.farm_from_dict(host.farm_to_dict()) != "" or back.new_pockets != host.new_pockets:
		return "New pockets must survive a save."
	var ore: int = back.crystal_ore
	back.fill(Vector3i(cell.x, 0, cell.y))
	back.dig(Vector3i(cell.x, 0, cell.y))
	if back.crystal_ore != ore:
		return "A reloaded farm gave a new pocket's ore again."
	for gs: Node in [host, guest, back]:
		gs.free()
	return ""


func test_a_save_is_refused_if_its_new_pockets_cant_be_there() -> String:
	var gs: Node = _make()
	var cell: Vector2i = OrePocket.cells(SEED)[0]
	var problems: PackedStringArray = []
	var good: Dictionary = gs.farm_to_dict()
	var other: Vector2i = OrePocket.cells(SEED)[1]
	good["found_pockets"] = { cell: true, other: true }
	good["pocket_pending"] = { cell: 3 }
	var fine: Vector2i = OrePocket.cells(SEED + 1)[0]
	good["new_pockets"] = [fine]
	if gs.farm_dict_problem(good) != "":
		problems.append("New pockets must load: %s" % gs.farm_dict_problem(good))
	var bads: Array[Array] = [
		["new_pockets", [Vector2i(9999, 0)]], ["new_pockets", [fine, fine]], ["new_pockets", ["x"]],
		["new_pockets", {}], ["pocket_pending", { Vector2i(6, 6): 3 }], ["pocket_pending", { cell: -1 }],
		["pocket_pending", { cell: "3" }], ["pocket_pending", []],
		["new_pockets", [OrePocket.cells(SEED)[2]]],
		["pocket_pending", { cell: 3, other: 3 }],
	]
	for bad: Array in bads:
		var data: Dictionary = good.duplicate(true)
		data[bad[0]] = bad[1]
		if gs.farm_dict_problem(data) == "":
			problems.append("Loaded %s %s" % [bad[0], bad[1]])
	var old: Dictionary = gs.farm_to_dict()
	old.erase("new_pockets")
	old.erase("pocket_pending")
	if gs.farm_from_dict(old) != "" or not gs.new_pockets.is_empty():
		problems.append("A save from before new pockets must load with none.")
	gs.free()
	return "\n".join(problems)


func test_an_old_save_regrows_its_dug_pockets() -> String:
	var gs: Node = _make()
	var cell: Vector2i = OrePocket.cells(SEED)[0]
	var old: Dictionary = gs.farm_to_dict()
	old["found_pockets"] = { cell: true }
	old.erase("new_pockets")
	old.erase("pocket_pending")
	var loaded: Node = _make(SEED + 3)
	if loaded.farm_from_dict(old) != "":
		return "An old save with dug pockets must load: %s" % loaded.farm_dict_problem(old)
	var due: int = GameClock.get_day_index() + OrePocket.REGROW_DAYS
	if loaded.pocket_pending != { cell: due }:
		return "An old save's dug pocket must wait REGROW_DAYS: %s" % loaded.pocket_pending
	var day: int = GameClock.get_day_index()
	for _morning: int in OrePocket.REGROW_DAYS:
		day += 1
		loaded._grow_pockets(day)
	if loaded.new_pockets.size() != 1 or not loaded.pocket_pending.is_empty():
		return "An old save's pocket must regrow after REGROW_DAYS mornings: %s %s" % [loaded.new_pockets, loaded.pocket_pending]
	gs.free()
	loaded.free()
	return ""


func test_a_farm_stops_growing_at_max_new() -> String:
	var gs: Node = _make()
	var cell: Vector2i = OrePocket.cells(SEED)[0]
	gs.dig(Vector3i(cell.x, 0, cell.y))
	for i: int in OrePocket.MAX_NEW:
		gs.new_pockets.append(Vector2i(1000 + i, 0))
	gs._grow_pockets(gs.pocket_pending[cell] + 10)
	var problem: String = ""
	if gs.new_pockets.size() != OrePocket.MAX_NEW or not gs.pocket_pending.has(cell):
		problem = "A full farm must grow nothing and keep the entry pending."
	gs.free()
	return problem


func test_the_morning_grows_pockets_and_a_guest_does_not() -> String:
	var gs: Node = _make()
	var cell: Vector2i = OrePocket.cells(SEED)[0]
	gs.dig(Vector3i(cell.x, 0, cell.y))
	var due: int = gs.pocket_pending[cell]
	var held: bool = FarmCommands.guest
	FarmCommands.guest = true
	gs._on_day_started(due)
	gs._grow_pockets(due)
	FarmCommands.guest = held
	if not gs.new_pockets.is_empty() or not gs.pocket_pending.has(cell):
		return "A guest must not grow pockets."
	var told: Array[int] = [0]
	gs.pockets_changed.connect(func() -> void: told[0] += 1)
	gs._on_day_started(due)
	var problem: String = ""
	if gs.new_pockets.size() != 1 or not gs.pocket_pending.is_empty() or told[0] != 1:
		problem = "The morning must grow the pocket and say so: %s %s %d" % [gs.new_pockets, gs.pocket_pending, told[0]]
	gs.free()
	return problem


func test_no_room_leaves_the_pocket_pending() -> String:
	var gs: Node = _make()
	var cell: Vector2i = OrePocket.cells(SEED)[0]
	gs.dig(Vector3i(cell.x, 0, cell.y))
	var room: Vector2i = OrePocket.replacement(SEED, cell, gs.dug, gs.found_pockets, gs.new_pockets)
	if room == OrePocket.NONE:
		return "The farm must have room for a pocket."
	@warning_ignore("integer_division")
	var limit: int = Terrain.HALF_M / Terrain.CELL_M
	var built: Dictionary[Vector2i, int] = {}
	for x: int in range(-limit, limit):
		for z: int in range(-limit, limit):
			built[Vector2i(x, z)] = 0
	if OrePocket.replacement(SEED, cell, gs.dug, gs.found_pockets, gs.new_pockets, built) != OrePocket.NONE:
		return "A cell under a stone piece must not get a pocket."
	gs.stone_pieces = built
	var due: int = gs.pocket_pending[cell]
	gs._grow_pockets(due)
	var problem: String = ""
	if not gs.new_pockets.is_empty() or not gs.pocket_pending.has(cell):
		problem = "A draw with no room must leave the pocket pending."
	gs.free()
	return problem


func test_a_guest_is_told_when_only_pockets_change() -> String:
	var host: Node = _make()
	var cell: Vector2i = OrePocket.cells(SEED)[0]
	host.dig(Vector3i(cell.x, 0, cell.y))
	var guest: Node = _make()
	var bytes: PackedByteArray = FarmSync.capture(host)
	var held: bool = FarmCommands.guest
	var elapsed: float = GameClock.elapsed_days
	var open: bool = SaveGame.farm_open
	FarmCommands.guest = true
	var problem: String = FarmSync.update(bytes, guest)
	FarmCommands.guest = held
	GameClock.elapsed_days = elapsed
	SaveGame.farm_open = open
	if problem != "":
		return problem
	for field: String in ["new_pockets", "pocket_pending"]:
		var before: Dictionary = guest.farm_to_dict()
		var told: Array[int] = [0]
		var listener: Callable = func() -> void: told[0] += 1
		guest.pockets_changed.connect(listener)
		if field == "new_pockets":
			guest.new_pockets.append(Vector2i(50, 50))
		else:
			guest.pocket_pending[cell] += 1
		FarmSync._show_changes(guest, before, false)
		guest.pockets_changed.disconnect(listener)
		if told[0] != 1:
			problem += "A change to '%s' alone must emit pockets_changed. " % field
	host.free()
	guest.free()
	return problem
