extends RefCounted
## The 81-piece gauge block set the buried blocks make: its sizes, grades,
## duplicates, save and load, and a guest's part.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const SEED: int = 424242
const PIN_X: int = -39
const PIN_Y: int = -25
const PIN_ANGLE: float = 15.0
const PIN_TRUE: float = 14.993210481014103


func _make(seed_value: int = SEED) -> Node:
	var gs: Node = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(seed_value)
	return gs


## Cells holding a block, scanned wide enough to find repeats of a size.
func _block_cells(seed_value: int = SEED) -> Array[Vector2i]:
	var none: Dictionary[Vector2i, int] = {}
	var out: Array[Vector2i] = []
	for x: int in range(-60, 60):
		for z: int in range(-60, 60):
			var cell := Vector2i(x, z)
			if Terrain.dig_problem(cell, none) == "" and not ReferenceBlock.at(seed_value, cell).is_empty():
				out.append(cell)
	return out


func test_the_set_is_the_81_piece_inch_set() -> String:
	var sizes: Array[int] = GaugeSet.SIZES_TEN_THOUSANDTHS
	var problems: PackedStringArray = []
	if sizes.size() != 81 or GaugeSet.size_count() != sizes.size():
		problems.append("The set must have 81 pieces, not %d." % sizes.size())
	var distinct: Dictionary = {}
	for size: int in sizes:
		distinct[size] = true
	if distinct.size() != 81:
		problems.append("Every size must differ: %d distinct." % distinct.size())
	var counts: Array[int] = [0, 0, 0, 0]
	for size: int in sizes:
		if size >= 10000:
			counts[3] += 1
		elif size % 500 == 0:
			counts[2] += 1
		elif size <= 1009:
			counts[0] += 1
		else:
			counts[1] += 1
	if counts != [9, 49, 19, 4]:
		problems.append("The set is 9, 49, 19 and 4 pieces by series, not %s." % [counts])
	if sizes.min() != 500 or sizes.max() != 40000 or not sizes.has(1001) or not sizes.has(1490):
		problems.append("The ends of the set are wrong.")
	if not is_equal_approx(GaugeSet.size_in(sizes.find(1001)), 0.1001) or not is_equal_approx(GaugeSet.size_in(sizes.find(40000)), 4.0):
		problems.append("Sizes must come out in inches.")
	return "\n".join(problems)


func test_a_block_is_one_piece_of_the_set() -> String:
	var problems: PackedStringArray = []
	var odds: int = 0
	for chance: int in GaugeSet.GRADE_ODDS_PERCENT:
		odds += chance
	if odds != 100 or GaugeSet.GRADES != ["00", "0", "1"]:
		problems.append("The grade odds must add to 100 over grades 00, 0 and 1.")
	var seen: Dictionary = {}
	for cell: Vector2i in _block_cells():
		var block: Dictionary = ReferenceBlock.at(SEED, cell)
		if block["size_index"] < 0 or block["size_index"] >= 81 or block["grade"] < 0 or block["grade"] > 2:
			problems.append("A block's piece is not in the set: %s" % [block])
			break
		seen[block["size_index"]] = true
		if ReferenceBlock.at(SEED, cell) != block:
			problems.append("A block's piece must be the same each time.")
			break
	if seen.size() < 20:
		problems.append("Blocks must come in many sizes: %d seen." % seen.size())
	return "\n".join(problems)


func test_grading_is_the_worst_piece() -> String:
	var problems: PackedStringArray = []
	if GaugeSet.set_grade({}) != -1 or GaugeSet.text({}) != "":
		problems.append("An empty set has no grade and nothing to show.")
	if GaugeSet.set_grade({ 0: 0, 1: 0, 2: 0 }) != 0 or GaugeSet.set_grade({ 0: 0, 1: 2, 2: 1 }) != 2:
		problems.append("A set is as good as its worst piece.")
	var full: Dictionary = {}
	for i: int in 81:
		full[i] = 0
	if not GaugeSet.is_complete(full) or GaugeSet.set_grade(full) != 0 or GaugeSet.text(full) != "GAUGE SET 81/81: GRADE 00":
		problems.append("A full set of grade 00 pieces is a grade 00 set: %s" % GaugeSet.text(full))
	full[40] = 1
	if GaugeSet.set_grade(full) != 1 or not GaugeSet.text(full).ends_with("GRADE 0"):
		problems.append("One grade 0 piece makes the set grade 0.")
	full.erase(3)
	if GaugeSet.is_complete(full) or not GaugeSet.text(full).begins_with("GAUGE SET 80/81"):
		problems.append("A set short of a piece is not complete.")
	var rolls: Array[int] = [0, 0, 0]
	for roll: int in 100:
		rolls[GaugeSet.grade_from_roll(roll)] += 1
	if rolls != GaugeSet.GRADE_ODDS_PERCENT:
		problems.append("The rolls must fall as the odds say: %s" % [rolls])
	return "\n".join(problems)


func test_a_duplicate_adds_nothing_unless_it_is_better() -> String:
	var cells: Array[Vector2i] = _block_cells()
	var problems: PackedStringArray = []
	if cells.size() < 100:
		return "The scan must hold more than 81 blocks (%d)." % cells.size()
	# With the set full, a later block keeps its own size: duplicate or better.
	var full: Array = cells.slice(0, 81)
	var held: Dictionary = GaugeSet.pieces(SEED, full)
	var same: Vector2i = Vector2i(-9999, 0)
	var up: Vector2i = Vector2i(-9999, 0)
	for cell: Vector2i in cells.slice(81):
		var block: Dictionary = ReferenceBlock.at(SEED, cell)
		if block["grade"] >= held[block["size_index"]] and same.x == -9999:
			same = cell
		if block["grade"] < held[block["size_index"]] and up.x == -9999:
			up = cell
	if same.x == -9999 or up.x == -9999:
		return "The scan must hold a duplicate of each kind."
	var dup_block: Dictionary = ReferenceBlock.at(SEED, same)
	var up_block: Dictionary = ReferenceBlock.at(SEED, up)
	if GaugeSet.finding(SEED, [], ReferenceBlock.at(SEED, cells[0])) != GaugeSet.NEW:
		problems.append("A size not held is new.")
	if GaugeSet.finding(SEED, full, dup_block) != GaugeSet.DUPLICATE:
		problems.append("A size held at no worse a grade is a duplicate.")
	if GaugeSet.finding(SEED, full, up_block) != GaugeSet.BETTER:
		problems.append("A better grade of a size held is better.")
	if GaugeSet.pieces(SEED, full + [same]) != held:
		problems.append("A duplicate must leave the set as it was.")
	var better: Dictionary = GaugeSet.pieces(SEED, full + [up])
	if better.size() != 81 or better[up_block["size_index"]] != up_block["grade"]:
		problems.append("The better block must take the piece's place.")
	# Digging them all: the duplicate is kept (found_blocks) and the set is the same.
	var gs: Node = _make()
	for cell: Vector2i in full + [same]:
		gs.dig(Vector3i(cell.x, 0, cell.y))
	if gs.found_blocks.size() != 82 or gs.gauge_pieces() != held:
		problems.append("The duplicate is kept, as one piece (%d blocks kept)." % gs.found_blocks.size())
	gs.free()
	return "
".join(problems)


func test_the_set_is_kept_and_saved() -> String:
	var gs: Node = _make()
	var cells: Array[Vector2i] = _block_cells()
	var problems: PackedStringArray = []
	for cell: Vector2i in cells.slice(0, 12):
		gs.dig(Vector3i(cell.x, 0, cell.y))
	var held: Dictionary = gs.gauge_pieces()
	if held.is_empty() or held != GaugeSet.pieces(SEED, cells.slice(0, 12)):
		problems.append("The set must be the blocks dug.")
	# Using a block to check an instrument must leave the set alone.
	gs.check_with_block(gs.STEERING_ID)
	if gs.gauge_pieces() != held:
		problems.append("A check must not use a piece up.")
	var back: Node = _make(SEED + 7)
	if back.farm_from_dict(str_to_var(var_to_str(gs.farm_to_dict()))) != "":
		problems.append("A saved set must load.")
	if back.gauge_pieces() != held:
		problems.append("The set must come back after a load.")
	var old: Dictionary = gs.farm_to_dict()
	old.erase("found_blocks")
	var older: Node = _make()
	if older.farm_dict_problem(old) != "" or older.farm_from_dict(old) != "" or not older.gauge_pieces().is_empty():
		problems.append("A save from before blocks must load with an empty set.")
	# A save that lists a cell holding no block is refused, so no piece can be made up.
	var bad: Dictionary = gs.farm_to_dict()
	bad["found_blocks"] = { Vector2i(0, 0): true }
	if gs.farm_dict_problem(bad) == "":
		problems.append("A set made of a cell with no block must be refused.")
	for node: Node in [gs, back, older]:
		node.free()
	return "\n".join(problems)


func test_a_guest_is_told_the_set_and_cant_make_one() -> String:
	var commands: Node = CommandsScript.new()
	commands.state = _make()
	var host: Node = commands.state
	var cells: Array[Vector2i] = _block_cells()
	var problems: PackedStringArray = []
	host.set_world_seed(SEED)
	# A guest digs a block's cell: the host's set grows.
	commands.execute("player_2", &"dig", [Vector3i(cells[0].x, 0, cells[0].y)])
	if host.gauge_pieces() != GaugeSet.pieces(SEED, [cells[0]]) or host.gauge_pieces().size() != 1:
		problems.append("A guest's dig must give the host's set its piece.")
	# A guest's dig where there is no block, or off the ground, gives no piece.
	commands.execute("player_2", &"dig", [Vector3i(0, 0, 0)])
	commands.execute("player_2", &"dig", [Vector3i(0, 5, 0)])
	if host.found_blocks.size() != 1:
		problems.append("A guest's dig of plain ground must give no block.")
	# The guest is told through the farm it is sent, and sees the same set.
	var guest: Node = _make(SEED + 1)
	if guest.farm_from_dict(str_to_var(var_to_str(host.farm_to_dict()))) != "":
		problems.append("A guest must be able to take the host's farm.")
	if guest.gauge_pieces() != host.gauge_pieces():
		problems.append("A guest must see the host's set.")
	# What a guest sends in place of the farm is checked: a made-up block is refused.
	var forged: Dictionary = host.farm_to_dict()
	forged["found_blocks"] = { Vector2i(0, 0): true, cells[0]: true }
	if guest.farm_dict_problem(forged) == "":
		problems.append("A farm with a made-up block must be refused.")
	for action: StringName in [&"gauge_set", &"add_gauge_piece", &"found_block"]:
		if commands.problem(action, []) == "":
			problems.append("There must be no guest command '%s' to hand over a piece." % action)
	guest.free()
	host.free()
	commands.free()
	return "\n".join(problems)


## Sorts of cell lists the tests walk: the cells reversed, and shuffled by a fixed rng.
func _orders(cells: Array[Vector2i]) -> Array:
	var reversed: Array = cells.duplicate()
	reversed.reverse()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var shuffled: Array = cells.duplicate()
	for i: int in range(shuffled.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var swap: Variant = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = swap
	return [reversed, shuffled]


func test_n_blocks_give_n_sizes_and_81_complete_the_set() -> String:
	var cells: Array[Vector2i] = _block_cells()
	var problems: PackedStringArray = []
	if cells.size() < 81:
		return "The scan must hold 81 blocks, found %d." % cells.size()
	for n: int in [1, 2, 10, 40, 80]:
		var held: Dictionary = GaugeSet.pieces(SEED, cells.slice(0, n))
		if held.size() != n:
			problems.append("%d blocks must give %d sizes, not %d." % [n, n, held.size()])
	var full: Dictionary = GaugeSet.pieces(SEED, cells.slice(0, 81))
	if not GaugeSet.is_complete(full):
		problems.append("81 blocks must make a complete set, not %d sizes." % full.size())
	# Spread cells, not a prefix of the scan, and a farm with another seed, do the same.
	var spread: Array = []
	for i: int in range(0, cells.size(), 2):
		spread.append(cells[i])
		if spread.size() == 81:
			break
	if spread.size() == 81 and not GaugeSet.is_complete(GaugeSet.pieces(SEED, spread)):
		problems.append("Any 81 blocks must make a complete set.")
	var other: Array[Vector2i] = _block_cells(SEED + 1)
	if other.size() >= 81 and not GaugeSet.is_complete(GaugeSet.pieces(SEED + 1, other.slice(0, 81))):
		problems.append("Another farm's first 81 blocks must make a complete set too.")
	# More blocks after the set is full only keep or improve it.
	var more: Dictionary = GaugeSet.pieces(SEED, cells)
	if more.size() != 81:
		problems.append("Every block of the scan together must still be 81 sizes, not %d." % more.size())
	return "
".join(problems)


func test_the_set_does_not_depend_on_the_order_of_finding() -> String:
	var cells: Array[Vector2i] = _block_cells()
	var problems: PackedStringArray = []
	for n: int in [5, 30, 81, cells.size()]:
		var part: Array[Vector2i] = cells.slice(0, n)
		var want: Dictionary = GaugeSet.pieces(SEED, part)
		for order: Array in _orders(part):
			if GaugeSet.pieces(SEED, order) != want:
				problems.append("The same %d cells in another order gave another set." % n)
		if GaugeSet.pieces(SEED, part + part) != want:
			problems.append("A cell listed twice must count once (%d cells)." % n)
	return "
".join(problems)


func test_finding_says_what_the_block_adds_whatever_the_draw() -> String:
	var cells: Array[Vector2i] = _block_cells()
	var problems: PackedStringArray = []
	var before: Array = []
	for i: int in 100:
		var block: Dictionary = ReferenceBlock.at(SEED, cells[i])
		var held: Dictionary = GaugeSet.pieces(SEED, before)
		var after: Dictionary = GaugeSet.pieces(SEED, before + [cells[i]])
		var kind: StringName = GaugeSet.finding(SEED, before, block)
		if (kind == GaugeSet.NEW) != (after.size() > held.size()):
			problems.append("Block %d: NEW must mean the set grew." % i)
		if i < 81 and kind != GaugeSet.NEW:
			problems.append("Block %d of the first 81 must be a new size, not %s." % [i, kind])
		if kind == GaugeSet.DUPLICATE and after != held:
			problems.append("Block %d: a duplicate must leave the set as it was." % i)
		before.append(cells[i])
	return "
".join(problems)


func test_every_size_can_be_reached() -> String:
	var seen: Dictionary = {}
	for cell: Vector2i in _block_cells():
		seen[ReferenceBlock.at(SEED, cell)["size_index"]] = true
	# A block's own draw reaches most sizes; the free-size walk supplies the rest.
	var held: Dictionary = GaugeSet.pieces(SEED, _block_cells())
	var problems: PackedStringArray = []
	for size: int in GaugeSet.size_count():
		if not held.has(size):
			problems.append("Size %d was never reached." % size)
			break
	if seen.size() < 50:
		problems.append("Blocks' own draws should reach most sizes: %d of 81." % seen.size())
	return "
".join(problems)


## The angle and true value of a known block are pinned so the size draw, which comes
## after them, can never move them.
func test_a_known_blocks_angle_and_true_value_are_pinned() -> String:
	var cell: Vector2i = _block_cells()[0]
	var block: Dictionary = ReferenceBlock.at(SEED, cell)
	var problems: PackedStringArray = []
	if cell != Vector2i(PIN_X, PIN_Y):
		problems.append("The first block of the scan is %s." % [cell])
	if block["certified"] != PIN_ANGLE or absf(block["true_value"] - PIN_TRUE) > 1e-12:
		problems.append("The angle and true value moved: %s, %s" % [block["certified"], str(block["true_value"])])
	return "
".join(problems)
