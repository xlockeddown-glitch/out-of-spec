extends RefCounted
## Buried angle blocks: where they are, that each comes once, and the field check.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const SEED: int = 424242


func _make(seed_value: int = SEED) -> Node:
	var gs: Node = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(seed_value)
	return gs


## Cells that can be dug a first step with nothing dug, with and without a block.
func _cells(seed_value: int) -> Dictionary:
	var none: Dictionary[Vector2i, int] = {}
	var out: Dictionary = { "block": [], "plain": [] }
	for x: int in range(-40, 40):
		for z: int in range(-40, 40):
			var cell := Vector2i(x, z)
			if Terrain.dig_problem(cell, none) == "":
				out["block" if not ReferenceBlock.at(seed_value, cell).is_empty() else "plain"].append(cell)
	return out


func _block_cell(gs: Node) -> Vector2i:
	return _cells(gs.world_seed)["block"][0]


func test_blocks_are_rare_and_the_same_for_a_seed() -> String:
	var cells: Dictionary = _cells(SEED)
	var blocks: int = cells["block"].size()
	var total: int = blocks + cells["plain"].size()
	if total < 300 or blocks < 1 or blocks * 10 > total:
		return "%d of %d diggable cells hold a block; it must be rare, and not none." % [blocks, total]
	if _cells(SEED)["block"] != cells["block"]:
		return "The same seed must hold the same blocks."
	if _cells(SEED + 1)["block"] == cells["block"]:
		return "Another seed must hold other blocks."
	var cell: Vector2i = cells["block"][0]
	var one: Dictionary = ReferenceBlock.at(SEED, cell)
	var again: Dictionary = ReferenceBlock.at(SEED, cell)
	if one != again or not ReferenceBlock.ANGLES_DEG.has(one["certified"]):
		return "A block's value must be fixed, and one of the certified angles."
	if absf(one["true_value"] - one["certified"]) > ReferenceBlock.U_DEG:
		return "A block must be true to within its certificate's uncertainty."
	if not ReferenceBlock.at(SEED, Vector2i(0, 0)).is_empty():
		return "Level ground holds no block."
	return ""


func test_digging_finds_a_block_once_even_after_filling() -> String:
	var gs: Node = _make()
	var cell: Vector2i = _block_cell(gs)
	var plain: Vector2i = _cells(SEED)["plain"][0]
	var told: Array = [0]
	gs.blocks_changed.connect(func() -> void: told[0] += 1)
	gs.dig(Vector3i(plain.x, 0, plain.y))
	var problems: PackedStringArray = []
	if not gs.found_blocks.is_empty():
		problems.append("Plain ground gave a block.")
	if gs.dig(Vector3i(cell.x, 0, cell.y)) != "" or gs.found_blocks.size() != 1 or told[0] != 1:
		problems.append("Digging a block's cell must give it, and say so.")
	gs.fill(Vector3i(cell.x, 0, cell.y))
	gs.dig(Vector3i(cell.x, 0, cell.y))
	gs.dig(Vector3i(cell.x, 0, cell.y))
	if gs.found_blocks.size() != 1 or told[0] != 1:
		problems.append("A cell must give its block only once, filled and dug again or not.")
	if gs.dig(Vector3i(0, 0, 0)) == "" or gs.found_blocks.size() != 1:
		problems.append("A refused dig must give nothing.")
	gs.free()
	return "\n".join(problems)


func test_a_reload_does_not_roll_again() -> String:
	var gs: Node = _make()
	var cell: Vector2i = _block_cell(gs)
	gs.dig(Vector3i(cell.x, 0, cell.y))
	var saved: Dictionary = gs.farm_to_dict()
	var back: Node = _make(SEED + 99)
	var problems: PackedStringArray = []
	if back.farm_from_dict(saved) != "" or back.found_blocks != gs.found_blocks:
		problems.append("The blocks found must come back.")
	if back.block_in_hand() != gs.block_in_hand() or back.block_in_hand().is_empty():
		problems.append("The block in hand must come back the same.")
	back.fill(Vector3i(cell.x, 0, cell.y))
	back.dig(Vector3i(cell.x, 0, cell.y))
	if back.found_blocks.size() != 1:
		problems.append("A reloaded farm must not give a cell's block twice.")
	var fresh: Node = _make()
	if fresh.farm_from_dict(fresh.farm_to_dict()) != "" or not fresh.found_blocks.is_empty():
		problems.append("Loading must find no block.")
	for node: Node in [gs, back, fresh]:
		node.free()
	return "\n".join(problems)


func test_a_check_uses_the_last_block_found() -> String:
	var gs: Node = _make()
	var cells: Array = _cells(SEED)["block"]
	var problems: PackedStringArray = []
	# The later cell first, so the order is the finding and not the cells'.
	for cell: Vector2i in [cells[1], cells[0], cells[2]]:
		gs.dig(Vector3i(cell.x, 0, cell.y))
		if gs.block_in_hand() != ReferenceBlock.at(SEED, cell):
			problems.append("Digging up %s must put its block in hand." % cell)
	var back: Node = _make()
	if back.farm_from_dict(str_to_var(var_to_str(gs.farm_to_dict()))) != "" or back.block_in_hand() != gs.block_in_hand():
		problems.append("The same block must be in hand after a load.")
	gs.free()
	back.free()
	return "
".join(problems)


func test_a_save_is_refused_if_its_blocks_cant_be_there() -> String:
	var gs: Node = _make()
	var cell: Vector2i = _block_cell(gs)
	var plain: Vector2i = _cells(SEED)["plain"][0]
	var problems: PackedStringArray = []
	var good: Dictionary = gs.farm_to_dict()
	good["found_blocks"] = { cell: true }
	if gs.farm_dict_problem(good) != "":
		problems.append("A block where one lies must load: %s" % gs.farm_dict_problem(good))
	var bads: Array = [{ plain: true }, { Vector2i(0, 0): true }, { cell: false }, { cell: 1 }, { "x": true }, { Vector3i(cell.x, 0, cell.y): true }, []]
	for bad: Variant in bads:
		var data: Dictionary = gs.farm_to_dict()
		data["found_blocks"] = bad
		if gs.farm_dict_problem(data) == "":
			problems.append("Loaded blocks %s" % [bad])
	var old: Dictionary = gs.farm_to_dict()
	old.erase("found_blocks")
	if gs.farm_dict_problem(old) != "" or gs.farm_from_dict(old) != "" or not gs.found_blocks.is_empty():
		problems.append("A save from before blocks must load with none.")
	gs.free()
	return "\n".join(problems)


func test_the_host_does_a_guests_check() -> String:
	var commands: Node = CommandsScript.new()
	commands.state = _make()
	var gs: Node = commands.state
	var problems: PackedStringArray = []
	var none: Dictionary = commands.execute("player_2", &"check_with_block", [gs.STEERING_ID])
	if not none.get("refused", false) or none.has("reading"):
		problems.append("With no block, a check must be refused and read nothing: %s" % [none])
	var cell: Vector2i = _block_cell(gs)
	commands.execute("player_2", &"dig", [Vector3i(cell.x, 0, cell.y)])
	var done: Dictionary = commands.execute("player_2", &"check_with_block", [gs.STEERING_ID])
	if done.get("refused", true) or not done.has("reading") or not done.has("error"):
		problems.append("A guest's check must be done by the host: %s" % [done])
	var humid: Dictionary = commands.execute("player_2", &"check_with_block", [gs.HYGROMETER_ID])
	if not humid.get("refused", false) or not "humidity" in str(humid.get("reason", "")) or humid.has("reading"):
		problems.append("An angle block must not check humidity: %s" % [humid])
	if not commands.execute("player_2", &"check_with_block", ["no_such_sensor"]).get("refused", false):
		problems.append("An unknown sensor must be refused.")
	gs.free()
	commands.free()
	return "\n".join(problems)


func test_the_check_reads_the_error() -> String:
	var block: Dictionary = { "certified": 30.0, "u": 0.02, "k": 2.0, "true_value": 30.01 }
	var dish: DriftingSensor = DriftingSensor.from_config("relay_dish_azimuth")
	var steer: DriftingSensor = DriftingSensor.from_config("rover_steering_encoder")
	var problems: PackedStringArray = []
	steer.error = 1.5
	var big: Dictionary = ReferenceBlock.check(steer, block)
	if absf(big["error"] - 1.51) > 0.06 or big["verdict"] != ReferenceBlock.VERDICT_WITHIN:
		problems.append("A 1.5 degree error on a 4 degree MPE: %s" % [big])
	steer.error = -4.6
	if ReferenceBlock.check(steer, block)["verdict"] != ReferenceBlock.VERDICT_OUTSIDE:
		problems.append("-4.6 degrees must be outside a 4 degree MPE.")
	dish.error = 0.0
	var zero: Dictionary = ReferenceBlock.check(dish, block)
	if zero["verdict"] != ReferenceBlock.VERDICT_WITHIN or absf(zero["error"] - 0.01) > 0.0051:
		problems.append("A true dish reads the block's own off-ness: %s" % [zero])
	dish.error = 1.0
	if ReferenceBlock.check(dish, block)["verdict"] != ReferenceBlock.VERDICT_OUTSIDE:
		problems.append("A 1 degree dish error must be outside 0.45.")
	dish.error = 0.44
	if ReferenceBlock.check(dish, block)["verdict"] != ReferenceBlock.VERDICT_UNCLEAR:
		problems.append("An error at the limit, within the uncertainty, can't be told.")
	dish.error = 0.30
	dish.reference_offset = 0.30
	if absf(ReferenceBlock.check(dish, block)["error"] - 0.31) > 0.0051:
		problems.append("The check must read the true error, not the displayed one.")
	return "\n".join(problems)


func test_the_check_changes_nothing() -> String:
	var gs: Node = _make()
	var cell: Vector2i = _block_cell(gs)
	gs.dig(Vector3i(cell.x, 0, cell.y))
	var sensor: DriftingSensor = gs.get_sensor("relay_dish_azimuth")
	sensor.error = 0.3
	var before: PackedByteArray = var_to_bytes(gs.farm_to_dict())
	for i: int in 3:
		gs.check_with_block("relay_dish_azimuth")
		gs.check_with_block(gs.STEERING_ID)
	var problems: PackedStringArray = []
	if before != var_to_bytes(gs.farm_to_dict()):
		problems.append("A check changed the farm.")
	if sensor.error != 0.3:
		problems.append("A check is not a calibration.")
	if gs.found_blocks.size() != 1 or gs.block_in_hand().is_empty():
		problems.append("The block must be kept.")
	gs.free()
	return "\n".join(problems)
