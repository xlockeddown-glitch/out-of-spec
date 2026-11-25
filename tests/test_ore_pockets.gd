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
			if Terrain.dig_problem(cell, dug) != "" or not ReferenceBlock.at(seed_value, cell).is_empty() or cells.count(cell) != 1:
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
	for bad: Variant in [{ cell + Vector2i.RIGHT: true }, { Vector2i.ZERO: true }, { cell: false }, { cell: 1 }, { "x": true }, { Vector3i(cell.x, 0, cell.y): true }, []]:
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
