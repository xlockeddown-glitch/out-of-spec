extends RefCounted
## Stone from broken boulders, and the walls, pads and channels built from it.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const CommandsScript: GDScript = preload("res://scripts/autoload/FarmCommands.gd")
const SEED: int = 424242

var _none: Array[Transform3D] = []
var _no_pieces: Dictionary[Vector2i, int] = {}


func _make() -> Node:
	var gs: Node = GameStateScript.new()
	gs.build_registry()
	gs.set_world_seed(SEED)
	return gs


## Cells on open ground, spaced apart so one piece never touches another.
func _cells(count: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for x: int in range(-20, 20, 4):
		for z: int in range(-20, 20, 4):
			var cell := Vector2i(x, z)
			if found.size() < count and StonePieces.problem(cell, StonePieces.WALL, _no_pieces, _none) == "":
				found.append(cell)
	return found


func _at(cell: Vector2i) -> Vector3i:
	return Vector3i(cell.x, 0, cell.y)


func _pose(cell: Vector2i) -> Transform3D:
	var middle: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * Terrain.CELL_M
	return Transform3D(Basis.IDENTITY, Vector3(middle.x, 0.0, middle.y))


func _break(gs: Node, id: StringName) -> void:
	for i: int in GameStateScript.BOULDER_HITS:
		gs.hit_boulder(id)


func test_a_broken_boulder_gives_stone_once() -> String:
	var gs: Node = _make()
	var told: Array[int] = [0]
	gs.stone_changed.connect(func() -> void: told[0] += 1)
	var problems: PackedStringArray = []
	for i: int in GameStateScript.BOULDER_HITS - 1:
		gs.hit_boulder(&"RockA")
	if gs.stone != 0 or told[0] != 0:
		problems.append("A boulder that stands gave stone: %d" % gs.stone)
	gs.hit_boulder(&"RockA")
	if gs.stone != StonePieces.PER_BOULDER or told[0] != 1:
		problems.append("The breaking hit must give %d stone, and say so once: %d, %d" % [StonePieces.PER_BOULDER, gs.stone, told[0]])
	gs.hit_boulder(&"RockA")
	gs.hit_boulder(&"Nothing")
	if gs.stone != StonePieces.PER_BOULDER:
		problems.append("A broken boulder, or none, gave stone again.")
	_break(gs, &"RockB")
	if gs.stone != 2 * StonePieces.PER_BOULDER:
		problems.append("Another boulder must give its stone too: %d" % gs.stone)
	gs.free()
	return "\n".join(problems)


func test_a_piece_costs_its_stone_and_taking_it_up_gives_all_back() -> String:
	var gs: Node = _make()
	var cells: Array[Vector2i] = _cells(3)
	var problems: PackedStringArray = []
	gs.stone = 10
	for kind: int in 3:
		var before: int = gs.stone
		if gs.place_stone(_at(cells[kind]), kind) != "" or gs.stone != before - StonePieces.cost(kind) or gs.stone_pieces.get(cells[kind], -1) != kind:
			problems.append("%s: building must cost %d" % [StonePieces.kind_name(kind), StonePieces.cost(kind)])
	for round: int in 5:
		for kind: int in 3:
			# A build where something stands is refused, so a late press takes nothing up.
			if gs.place_stone(_at(cells[kind]), (kind + 1) % 3) == "":
				problems.append("A piece was built on another")
			if gs.place_stone(_at(cells[kind]), StonePieces.TAKE_UP) != "":
				problems.append("A piece could not be taken up")
			if gs.place_stone(_at(cells[kind]), kind) != "":
				problems.append("A piece could not be built again")
	for kind: int in 3:
		gs.place_stone(_at(cells[kind]), StonePieces.TAKE_UP)
		if gs.place_stone(_at(cells[kind]), StonePieces.TAKE_UP) == "":
			problems.append("A bare cell was taken up")
	if gs.stone != 10 or not gs.stone_pieces.is_empty():
		problems.append("Building and taking up must leave the stock as it was, not %d" % gs.stone)
	gs.free()
	return "\n".join(problems)


func test_a_piece_is_refused_without_stone_or_where_it_cannot_stand() -> String:
	var gs: Node = _make()
	var cell: Vector2i = _cells(1)[0]
	var problems: PackedStringArray = []
	if gs.place_stone(_at(cell), StonePieces.WALL) == "" or not gs.stone_pieces.is_empty():
		problems.append("A wall was built with no stone.")
	gs.stone = StonePieces.cost(StonePieces.WALL) - 1
	if gs.place_stone(_at(cell), StonePieces.WALL) == "":
		problems.append("A wall was built with too little stone.")
	gs.stone = 50
	for bad: Vector3i in [Vector3i(0, 0, 0), Vector3i(cell.x, 1, cell.y), Vector3i(10000, 0, 0)]:
		if gs.place_stone(bad, StonePieces.PAD) == "":
			problems.append("A piece was built at %s" % [bad])
	if gs.place_stone(_at(cell), 7) == "" or gs.place_stone(_at(cell), -2) == "":
		problems.append("A piece of no kind was built.")
	if gs.stone != 50 or not gs.stone_pieces.is_empty():
		problems.append("A refusal changed the stock or the pieces.")
	# What must stay clear: the relay and the spawn.
	for place: Vector2 in [Terrain.RELAY, Vector2.ZERO]:
		if StonePieces.problem(Terrain.cell_at(place), StonePieces.PAD, _no_pieces, _none) == "":
			problems.append("A piece was allowed at %s" % [place])
	gs.free()
	return "\n".join(problems)


func test_a_wall_needs_room_and_never_traps_a_rover() -> String:
	var gs: Node = _make()
	var cell: Vector2i = _cells(1)[0]
	var problems: PackedStringArray = []
	gs.stone = 50
	gs.rover_transforms[gs.ROVER] = _pose(cell)
	if gs.place_stone(_at(cell), StonePieces.WALL) == "":
		problems.append("A wall was built under the rover.")
	if gs.place_stone(_at(cell), StonePieces.PAD) != "" or gs.stone_pieces.get(cell, -1) != StonePieces.PAD:
		problems.append("A pad is for driving over, so it may go under the rover.")
	gs.place_stone(_at(cell), StonePieces.TAKE_UP)
	if not gs.stone_pieces.is_empty():
		problems.append("The second press must take the pad up, as TAKE_UP.")
	# Walls around the rover: only the one that shuts the last way out is a trap.
	var around: Array[Vector2i] = []
	for neighbor: Vector2i in [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
		around.append(cell + neighbor)
	var rovers: Array[Transform3D] = [_pose(cell)]
	var walls: Dictionary[Vector2i, int] = {}
	for i: int in around.size():
		var problem: String = StonePieces.problem(around[i], StonePieces.WALL, walls, rovers)
		var last: bool = i == around.size() - 1
		if last and not problem.begins_with("That would trap"):
			problems.append("The wall that shut the rover in was allowed: '%s'" % problem)
		if not last and problem.begins_with("That would trap"):
			problems.append("A wall was refused as a trap while a way out was left.")
		walls[around[i]] = StonePieces.WALL
	gs.free()
	return "\n".join(problems)


func test_a_rover_that_is_away_does_not_block() -> String:
	var gs: Node = _make()
	var cell: Vector2i = _cells(1)[0]
	gs.stone = 50
	gs.rover_transforms[gs.TUNNEL_ROVER] = _pose(cell)
	var problem: String = gs.place_stone(_at(cell), StonePieces.WALL)
	gs.free()
	return "" if problem == "" else "A rover in the tunnels held up a wall on the farm: %s" % problem


func test_ground_under_a_piece_cannot_be_dug_or_filled() -> String:
	var gs: Node = _make()
	var cell: Vector2i = _cells(1)[0]
	var problems: PackedStringArray = []
	gs.stone = 50
	gs.dig(_at(cell))
	gs.place_stone(_at(cell), StonePieces.PAD)
	if gs.dig(_at(cell)) != GameStateScript.STONE_IN_THE_WAY or gs.fill(_at(cell)) != GameStateScript.STONE_IN_THE_WAY:
		problems.append("The ground under a pad was changed.")
	if gs.dug.get(cell, 0) != 1:
		problems.append("The dug depth under a pad moved: %d" % gs.dug.get(cell, 0))
	gs.place_stone(_at(cell), StonePieces.TAKE_UP)
	var problem: String = gs.fill(_at(cell))
	if problem != "" or gs.dug.has(cell):
		problems.append("The ground could not be filled once the pad was up: %s" % problem)
	gs.free()
	return "\n".join(problems)


func test_channel_cells_are_the_channels() -> String:
	var gs: Node = _make()
	var cells: Array[Vector2i] = _cells(3)
	gs.stone = 50
	gs.place_stone(_at(cells[0]), StonePieces.CHANNEL)
	gs.place_stone(_at(cells[1]), StonePieces.WALL)
	gs.place_stone(_at(cells[2]), StonePieces.CHANNEL)
	var channels: Array[Vector2i] = gs.channel_cells()
	channels.sort()
	var want: Array[Vector2i] = [cells[0], cells[2]]
	want.sort()
	gs.free()
	return "" if channels == want else "Channels are %s, not %s" % [channels, want]


func test_stone_and_pieces_survive_a_save_and_bad_ones_are_refused() -> String:
	var gs: Node = _make()
	var cells: Array[Vector2i] = _cells(2)
	var problems: PackedStringArray = []
	gs.stone = 9
	gs.place_stone(_at(cells[0]), StonePieces.WALL)
	gs.place_stone(_at(cells[1]), StonePieces.CHANNEL)
	var data: Dictionary = gs.farm_to_dict()
	var back: Node = _make()
	if back.farm_from_dict(data) != "" or back.stone != gs.stone or back.stone_pieces != gs.stone_pieces:
		problems.append("The stock and the pieces must come back: %d, %s" % [back.stone, back.stone_pieces])
	var told: Array[int] = [0]
	back.stone_changed.connect(func() -> void: told[0] += 1)
	back.farm_from_dict(data)
	if told[0] != 1:
		problems.append("Loading must tell the stone changed.")
	for bad: Dictionary in [{ "stone": -1 }, { "stone": StonePieces.MAX_STONE + 1 }, { "stone": "9" },
			{ "stone_pieces": { Vector2i.ZERO: StonePieces.WALL } }, { "stone_pieces": { cells[0]: 3 } },
			{ "stone_pieces": { cells[0]: "wall" } }, { "stone_pieces": { "x": 0 } }, { "stone_pieces": [] }]:
		var copy: Dictionary = gs.farm_to_dict()
		copy.merge(bad, true)
		if gs.farm_dict_problem(copy) == "":
			problems.append("Loaded %s" % [bad])
	var old: Dictionary = gs.farm_to_dict()
	old.erase("stone")
	old.erase("stone_pieces")
	if gs.farm_from_dict(old) != "" or gs.stone != 0 or not gs.stone_pieces.is_empty():
		problems.append("A save from before stone must load with none.")
	old["boulder_hits"] = { &"RockA": gs.BOULDER_HITS, &"RockB": 1 }
	if gs.farm_from_dict(old) != "" or gs.stone != StonePieces.PER_BOULDER:
		problems.append("A save from before stone must get the stone of its broken boulders: %d" % gs.stone)
	gs.free()
	back.free()
	return "\n".join(problems)


func test_a_guest_builds_and_takes_up_through_the_host() -> String:
	var commands: Node = CommandsScript.new()
	commands.state = _make()
	var gs: Node = commands.state
	var cell: Vector2i = _cells(1)[0]
	var problems: PackedStringArray = []
	gs.stone = 5
	if commands.execute("player_2", &"place_stone", [_at(cell), StonePieces.WALL]) != "" or gs.stone != 5 - StonePieces.cost(StonePieces.WALL):
		problems.append("A guest's wall must be built and paid for from the farm's stone.")
	if commands.execute("player_2", &"place_stone", [_at(cell), StonePieces.TAKE_UP]) != "" or gs.stone != 5 or not gs.stone_pieces.is_empty():
		problems.append("A guest must be able to take it up for all its stone.")
	if commands.execute("player_2", &"place_stone", [_at(cell), "wall"]) == "":
		problems.append("A kind that is no number must be refused before it reaches the farm.")
	gs.free()
	commands.free()
	return "\n".join(problems)


func test_a_guest_is_shown_the_stone_and_the_pieces() -> String:
	var shown: Array = FarmSync.SHOWN_BY.get(&"stone_changed", [])
	return "" if "stone" in shown and "stone_pieces" in shown else "FarmSync must show both to a guest."


func test_a_wall_stops_rovers_and_not_the_uplink() -> String:
	var cell: Vector2i = _cells(1)[0]
	var box: AABB = StonePieces.wall_box(cell, GameState.dug)
	var problems: PackedStringArray = []
	var middle := Vector2((Vector2(cell) + Vector2.ONE * 0.5) * Terrain.CELL_M)
	var ground: float = Terrain.height(middle, GameState.dug)
	if box.end.y < ground + StonePieces.WALL_M - 0.001 or box.position.y > ground:
		problems.append("A wall must stand %s m over its cell and reach the ground: %s" % [StonePieces.WALL_M, box])
	var view := StonePiecesView.new()
	GameState.stone_pieces[cell] = StonePieces.WALL
	view._add(cell)
	GameState.stone_pieces.erase(cell)
	var body: StaticBody3D = view.get_child(0) as StaticBody3D
	if body == null:
		problems.append("A wall must be a body.")
	else:
		if body.collision_layer != 1 or body.collision_mask != 0:
			problems.append("A wall must be on layer 1 only (rovers, not the uplink's mask 4): %d" % body.collision_layer)
		var shape: BoxShape3D = (body.get_child(0) as CollisionShape3D).shape as BoxShape3D
		if shape == null or not shape.size.is_equal_approx(box.size):
			problems.append("A wall's shape must be its box.")
		if body.get_node_or_null("Mesh") == null:
			problems.append("A wall must be drawn.")
	view.free()
	return "\n".join(problems)


func test_a_save_with_a_piece_where_a_rock_now_stands_loads() -> String:
	for rock: Vector2i in HillDressing.ROCKS:
		var cell: Vector2i = Terrain.cell_at(Vector2(rock))
		var pieces: Dictionary[Vector2i, int] = {cell: StonePieces.WALL}
		if StonePieces.pieces_problem(pieces) != "":
			return "The save with a wall at %s is refused." % cell
		var none: Dictionary[Vector2i, int] = {}
		var rovers: Array[Transform3D] = []
		if StonePieces.problem(cell, StonePieces.WALL, none, rovers) == "":
			return "A wall is built in the rock at %s." % cell
	return ""
