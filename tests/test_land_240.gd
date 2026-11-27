extends RefCounted
## The land grown from 160 m to 240 m: the old middle and everything drawn over it
## stays as it was, so an old save loads onto the same ground, and the new ring can be
## driven, walked and dug. The frozen numbers below were taken on the 160 m land,
## before it grew (biomes.md section 6, step 2). Never change them.

const SEED: int = 424242
const SEED_B: int = 7
## A farm's reference blocks over the old land, by seed 424242: how many and a hash.
const OLD_BLOCKS: int = 152
const OLD_BLOCKS_HASH: int = 396033623
## Heights of the old land with these five cells dug, hashed over every old point.
const OLD_DUG_CELLS: Array[Vector2i] = [Vector2i(30, 30), Vector2i(31, 30), Vector2i(-35, 20), Vector2i(38, -10), Vector2i(-38, -38), Vector2i(10, 36)]
## Of those, the ones the land lets be dug (the freeze took five).
const OLD_DUG_COUNT: int = 5
const OLD_DUG_HASH: int = 2385797109
## Pocket cells of 240 farms (seeds 7919 * 1..240) and four chained replacements for
## each, hashed. Taken on the 160 m code: this is what an old save's seed must give.
const OLD_POCKETS_HASH: int = 639962704
const OLD_REPLACEMENTS_HASH: int = 1291208380
## The natural plants: how many and a hash of where each stands.
const OLD_PLANTS: int = 545
const OLD_PLANTS_HASH: int = 532874052


func test_the_land_is_240_m_and_keeps_the_old_edge() -> String:
	if Terrain.SIZE_M != 240 or Terrain.HALF_M != 120 or Terrain.OLD_SIZE_M != 160 or Terrain.OLD_HALF_M != 80:
		return "The land must be 240 m, grown from 160 m."
	return ""


func test_every_point_of_the_old_land_has_its_old_height() -> String:
	## The frozen hash of the old middle is in test_hills (HASH); this checks the
	## real ground is the old working-out at every old point.
	for z: int in range(-Terrain.OLD_HALF_M, Terrain.OLD_HALF_M + 1):
		for x: int in range(-Terrain.OLD_HALF_M, Terrain.OLD_HALF_M + 1):
			if Terrain.natural(Vector2i(x, z)) != Terrain._work_out(x, z):
				return "The old ground changed at (%d, %d)." % [x, z]
	return ""


func test_an_old_save_digging_is_at_the_same_places_and_heights() -> String:
	var dug: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in OLD_DUG_CELLS:
		if Terrain.can_dig(cell):
			dug[cell] = 1
	if dug.size() != OLD_DUG_COUNT:
		return "The old dug cells are not the same ones: %d can be dug." % dug.size()
	if Terrain.dug_problem(dug) != "":
		return "The old digging is not a farm's digging: %s" % Terrain.dug_problem(dug)
	var hashed: int = 17
	for x: int in range(-Terrain.OLD_HALF_M, Terrain.OLD_HALF_M + 1):
		for z: int in range(-Terrain.OLD_HALF_M, Terrain.OLD_HALF_M + 1):
			hashed = (hashed * 31 + roundi(Terrain.point_height(Vector2i(x, z), dug) * 256.0)) & 0xffffffff
	return "" if hashed == OLD_DUG_HASH else "The dug old land changed: its hash is %d." % hashed


func test_old_found_blocks_and_pockets_are_where_they_were() -> String:
	var hashed: int = 17
	var blocks: int = 0
	for x: int in range(-40, 40):
		for z: int in range(-40, 40):
			var block: Dictionary = ReferenceBlock.at(SEED, Vector2i(x, z))
			if not block.is_empty():
				blocks += 1
				hashed = (hashed * 31 + x * 1000 + z + int(block["certified"] * 10) + int(block["size_index"]) * 7 + int(block["grade"])) & 0xffffffff
	if blocks != OLD_BLOCKS or hashed != OLD_BLOCKS_HASH:
		return "The old blocks changed: %d, hash %d." % [blocks, hashed]
	var want: Array[Vector2i] = [Vector2i(-22, 28), Vector2i(25, 15), Vector2i(-31, -1), Vector2i(-27, -17), Vector2i(3, 28), Vector2i(33, 9)]
	if OrePocket.cells(SEED) != want:
		return "The old farm's ore pockets moved: %s" % [OrePocket.cells(SEED)]
	var want_b: Array[Vector2i] = [Vector2i(-18, 1), Vector2i(27, -38), Vector2i(7, 24), Vector2i(-16, 28), Vector2i(-4, 23), Vector2i(28, -24)]
	if OrePocket.cells(SEED_B) != want_b:
		return "The second old farm's ore pockets moved: %s" % [OrePocket.cells(SEED_B)]
	return ""


func test_the_new_ring_holds_no_block_or_pocket_for_now() -> String:
	for seed_value: int in [SEED, SEED_B]:
		for x: int in range(-60, 60):
			for z: int in range(-60, 60):
				var cell := Vector2i(x, z)
				if not Terrain.in_old_land(cell) and not ReferenceBlock.at(seed_value, cell).is_empty():
					return "The ring has a block at %s." % cell
		for cell: Vector2i in OrePocket.cells(seed_value):
			if not Terrain.in_old_land(cell):
				return "The ring has a pocket at %s." % cell
	return ""


func test_the_plants_stand_where_they_stood() -> String:
	var plants: Array = HillDressing.plants()
	var hashed: int = 17
	for placed: Variant in plants:
		hashed = (hashed * 31 + roundi(placed.at.x * 100.0) + roundi(placed.at.z * 100.0) * 7 + placed.quarter_turns) & 0xffffffff
		if maxf(absf(placed.at.x), absf(placed.at.z)) > Terrain.OLD_HALF_M:
			return "A plant stands in the ring at %s." % placed.at
	if plants.size() != OLD_PLANTS or hashed != OLD_PLANTS_HASH:
		return "The plants changed: %d, hash %d." % [plants.size(), hashed]
	return ""


func test_the_ring_can_be_dug_but_not_its_edge() -> String:
	var none: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in [Vector2i(50, 50), Vector2i(-55, 20), Vector2i(20, -55), Vector2i(-55, -55)]:
		if Terrain.in_old_land(cell) or Terrain.dig_problem(cell, none) != "":
			return "The ring cell %s can't be dug: %s" % [cell, Terrain.dig_problem(cell, none)]
	for cell: Vector2i in [Vector2i(59, 0), Vector2i(0, -60), Vector2i(-61, 5)]:
		if Terrain.can_dig(cell):
			return "The edge cell %s must not be diggable." % cell
	var dug: Dictionary[Vector2i, int] = {Vector2i(50, 50): 1}
	var at := Vector2i(Terrain.CELL_M * 50 + 1, Terrain.CELL_M * 50 + 1)
	if Terrain.point_height(at, dug) >= Terrain.natural(at):
		return "A dug step in the ring must lower the ground."
	return ""


func test_the_rim_holds_at_the_new_edge() -> String:
	for i: int in range(-Terrain.HALF_M, Terrain.HALF_M + 1, 4):
		for edge: Vector2i in [Vector2i(i, Terrain.HALF_M), Vector2i(i, -Terrain.HALF_M), Vector2i(Terrain.HALF_M, i), Vector2i(-Terrain.HALF_M, i)]:
			if Terrain.natural(edge) < Terrain.RIM_M - 0.3:
				return "The rim is low at %s: %.2f m." % [edge, Terrain.natural(edge)]
	return ""


func test_the_rover_reaches_115_m_and_not_past_the_edge() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var rover := RoverController.new()
	tree.root.add_child(rover)
	var edge_m: float = Terrain.HALF_M - rover.wheelbase_m
	var problem: String = ""
	for way: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		rover.global_position = way * 115.0
		rover._keep_off_edge()
		if problem == "" and not rover.global_position.is_equal_approx(way * 115.0):
			problem = "At 115 m toward %s it got to %s." % [way, rover.global_position]
		rover.global_position = way * 300.0
		rover._keep_off_edge()
		if problem == "" and not rover.global_position.is_equal_approx(way * edge_m):
			problem = "Past the edge toward %s it got to %s." % [way, rover.global_position]
	rover.free()
	return problem


func test_the_walker_reaches_115_m_and_not_past_the_edge() -> String:
	for at: Vector2 in [Vector2(115, 0), Vector2(-115, 0), Vector2(0, 115), Vector2(0, -115)]:
		if not Walker._is_free(at):
			return "The walker can't stand at %s." % at
	for at: Vector2 in [Vector2(Terrain.HALF_M + 1.0, 0), Vector2(0, -Terrain.HALF_M - 1.0), Vector2(200, 200)]:
		if Walker._is_free(at):
			return "The walker can stand past the edge at %s." % at
	return ""


func test_240_old_farms_keep_their_pockets_and_replacements() -> String:
	var cells_hash: int = 17
	var next_hash: int = 17
	var none: Dictionary = {}
	for i: int in range(1, 241):
		var seed_value: int = i * 7919
		var cells: Array[Vector2i] = OrePocket.cells(seed_value)
		for cell: Vector2i in cells:
			cells_hash = (cells_hash * 31 + cell.x * 100 + cell.y) & 0xffffffff
			if not Terrain.in_old_land(cell):
				return "Seed %d has a pocket outside the old land at %s." % [seed_value, cell]
		var extra: Array[Vector2i] = []
		var from: Vector2i = cells[0]
		for _step: int in 4:
			var grown: Vector2i = OrePocket.replacement(seed_value, from, none, none, extra)
			next_hash = (next_hash * 31 + grown.x * 100 + grown.y) & 0xffffffff
			if grown != OrePocket.NONE and not Terrain.in_old_land(grown):
				return "Seed %d grows a pocket outside the old land at %s." % [seed_value, grown]
			extra.append(grown)
			from = grown
	if cells_hash != OLD_POCKETS_HASH or next_hash != OLD_REPLACEMENTS_HASH:
		return "Old farms' pockets changed: %d, %d." % [cells_hash, next_hash]
	return ""
