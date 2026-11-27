extends RefCounted
## The dig outline and the dig command act on one cell (RoverController.dig_target()),
## teal when the host's rule would let the dig work and amber when not; a small drift
## keeps a dig in flight, a large one cancels it.

const FACINGS_DEG: Array[float] = [0.0, 90.0, 180.0, 270.0, 33.0]


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


## A cell that can be dug now, with its east neighbour, holding no block and no pocket.
func _diggable_cell() -> Vector2i:
	for x: int in range(-30, 30):
		for z: int in range(-30, 30):
			var cell := Vector2i(x, z)
			if GameState.dig_problem(cell) == "" and GameState.dig_problem(cell + Vector2i(1, 0)) == "" and _plain(cell):
				return cell
	return Vector2i.MAX


func _plain(cell: Vector2i) -> bool:
	for near: Vector2i in [cell, cell + Vector2i(1, 0)]:
		if not ReferenceBlock.at(GameState.world_seed, near).is_empty() or near in OrePocket.cells(GameState.world_seed) or near in GameState.new_pockets:
			return false
	return true


const SETUP: String = "Test setup: no plain diggable cell found"


func _forward(deg: float) -> Vector3:
	var a: float = deg_to_rad(deg)
	return Vector3(-sin(a), 0.0, -cos(a))


## A rover on the farm's ground standing `behind_m` before the middle of `cell`, facing `deg`.
func _rover(cell: Vector2i, deg: float, behind_m: float = 2.0) -> RoverController:
	var rover := RoverController.new()
	rover.rover_id = "test_dig_rover"
	rover.ground = TerrainGround.new()
	_root().add_child(rover)
	var middle := Vector3(cell.x * Terrain.CELL_M + 1.0, 0.0, cell.y * Terrain.CELL_M + 1.0)
	rover.global_position = middle - _forward(deg) * behind_m
	rover.rotation_degrees = Vector3(0.0, deg, 0.0)
	return rover


func _free(rover: RoverController) -> void:
	var id: String = rover.rover_id
	rover.ground.free()
	rover.free()
	GameState.rover_transforms.erase(id)


func test_the_outline_and_the_command_name_the_cell_in_front() -> String:
	var cell: Vector2i = _diggable_cell()
	if cell == Vector2i.MAX:
		return SETUP
	var bad: PackedStringArray = []
	for deg: float in FACINGS_DEG:
		var rover: RoverController = _rover(cell, deg, 2.0)
		var ahead := Vector2(rover.global_position.x, rover.global_position.z) + Vector2(_forward(deg).x, _forward(deg).z) * rover.dig_reach_m
		var want: Vector2i = Terrain.cell_at(ahead)
		if rover.dig_target() != want or rover.dig_cell() != want:
			bad.append("%s deg: target %s, cell %s, wanted %s" % [deg, rover.dig_target(), rover.dig_cell(), want])
		rover.queue_command(RoverController.Command.DIG)
		if rover._commands.size() != 1 or rover._commands[0].cell != want:
			bad.append("%s deg: the command does not carry the lit %s" % [deg, want])
		_free(rover)
	return "" if bad.is_empty() else "; ".join(bad)


func test_the_outline_is_teal_when_diggable_and_amber_when_not() -> String:
	var cell: Vector2i = _diggable_cell()
	if cell == Vector2i.MAX:
		return SETUP
	var rover: RoverController = _rover(cell, 0.0)
	var bad: PackedStringArray = []
	if DigOutline.state_of(rover) != DigOutline.State.DIGGABLE:
		bad.append("open ground was not diggable: '%s'" % rover.dig_problem())
	var target: Vector2i = rover.dig_target()
	GameState.stone_pieces[target] = StonePieces.WALL
	if DigOutline.state_of(rover) != DigOutline.State.BLOCKED or rover.dig_problem() != GameState.STONE_IN_THE_WAY:
		bad.append("built stone did not block (%s)" % rover.dig_problem())
	GameState.stone_pieces.erase(target)
	GameState.dug[target] = Terrain.MAX_DIG_STEPS
	if DigOutline.state_of(rover) != DigOutline.State.BLOCKED:
		bad.append("a full-depth cell did not block")
	GameState.dug.erase(target)
	rover._speed_mps = 3.0
	if DigOutline.state_of(rover) != DigOutline.State.BLOCKED or rover.dig_problem() != RoverController.STOP_FIRST:
		bad.append("a rolling rover did not block")
	rover._speed_mps = 0.0
	# Level ground at the farm's middle cannot be dug.
	rover.global_position = Vector3.ZERO
	rover.rotation_degrees = Vector3.ZERO
	if DigOutline.state_of(rover) != DigOutline.State.BLOCKED or rover.dig_problem() == "":
		bad.append("level ground at the farm did not block")
	if DigOutline.color_of(DigOutline.State.DIGGABLE) != ScopeTheme.TEAL or DigOutline.color_of(DigOutline.State.BLOCKED) != ScopeTheme.AMBER:
		bad.append("colours are not teal and amber")
	_free(rover)
	return "" if bad.is_empty() else "; ".join(bad)


func test_the_outline_is_hidden_only_when_no_dig_can_be_aimed() -> String:
	var cell: Vector2i = _diggable_cell()
	if cell == Vector2i.MAX:
		return SETUP
	var rover: RoverController = _rover(cell, 0.0)
	var bad: PackedStringArray = []
	rover.hide()
	if DigOutline.state_of(rover) != DigOutline.State.HIDDEN:
		bad.append("an unseen rover shows it")
	rover.show()
	var held: bool = GameState.rover_lent
	var held_zone: String = GameState.rover_zone
	GameState.rover_zone = "lava_tubes"
	GameState.rover_lent = true
	rover.rover_id = GameState.ROVER
	if DigOutline.state_of(rover) != DigOutline.State.HIDDEN:
		bad.append("an away rover shows it")
	GameState.rover_zone = held_zone
	GameState.rover_lent = held
	rover.rover_id = "test_dig_rover"
	var ground: TerrainGround = rover.ground
	rover.ground = null
	if DigOutline.state_of(rover) != DigOutline.State.HIDDEN:
		bad.append("no ground shows it")
	rover.ground = ground
	if DigOutline.state_of(null) != DigOutline.State.HIDDEN:
		bad.append("no rover shows it")
	_free(rover)
	return "" if bad.is_empty() else "; ".join(bad)


func test_a_small_drift_keeps_the_dig_and_a_large_one_cancels_it() -> String:
	var cell: Vector2i = _diggable_cell()
	if cell == Vector2i.MAX:
		return SETUP
	var rover: RoverController = _rover(cell, 0.0)
	var said: Array[String] = []
	rover.dig_rejected.connect(func(why: String) -> void: said.append(why))
	var bad: PackedStringArray = []
	rover.queue_command(RoverController.Command.DIG)
	var lit: Vector2i = rover.dig_target()
	rover.global_position += Vector3(rover.dig_drift_m * 0.5, 0.0, 0.0)
	rover._cancel_drifted_digs()
	if rover._commands.size() != 1 or not said.is_empty():
		bad.append("a small drift cancelled the dig")
	elif rover.dig_target() != lit or rover._commands[0].cell != lit:
		bad.append("the lit cell moved with the rover while the dig was in flight")
	rover.global_position += Vector3(rover.dig_drift_m * 2.0, 0.0, 0.0)
	rover._cancel_drifted_digs()
	if not rover._commands.is_empty() or said != [RoverController.MOVED_REFUSAL]:
		bad.append("a large drift did not cancel it (%s)" % [said])
	_free(rover)
	return "" if bad.is_empty() else "; ".join(bad)


func test_a_dig_that_drifted_a_little_digs_the_lit_cell_and_a_fast_one_does_not() -> String:
	var cell: Vector2i = _diggable_cell()
	if cell == Vector2i.MAX:
		return SETUP
	var rover: RoverController = _rover(cell, 90.0)
	var said: Array[String] = []
	rover.dig_rejected.connect(func(why: String) -> void: said.append(why))
	var bad: PackedStringArray = []
	var lit: Vector2i = rover.dig_target()
	var held: Dictionary = SaveGame.snapshot()
	var dug_before: Dictionary[Vector2i, int] = GameState.dug.duplicate()
	rover.queue_command(RoverController.Command.DIG)
	var cmd: RoverController.UplinkCommand = rover._commands[0]
	# It drifted, and turned a little, but within the allowance.
	rover.global_position += Vector3(0.0, 0.0, rover.dig_drift_m * 0.5)
	rover.rotation_degrees = Vector3(0.0, 120.0, 0.0)
	rover._speed_mps = rover.dig_drift_speed_mps * 0.5
	rover._execute(cmd)
	if GameState.dug.get(lit, 0) != dug_before.get(lit, 0) + 1:
		bad.append("the lit cell %s was not dug (%s)" % [lit, said])
	if GameState.dug.size() != dug_before.size() + (0 if dug_before.has(lit) else 1):
		bad.append("another cell was dug")
	# Too fast: refused, and nothing more is dug.
	rover._speed_mps = rover.dig_drift_speed_mps * 4.0
	rover._execute(cmd)
	if GameState.dug.get(lit, 0) != dug_before.get(lit, 0) + 1 or said != [RoverController.STOP_FIRST]:
		bad.append("a fast rover dug or said %s" % [said])
	var back: String = SaveGame.restore(held)
	GameState.terrain_changed.emit()
	_free(rover)
	if back != "":
		bad.append("the farm did not restore: %s" % back)
	return "" if bad.is_empty() else "; ".join(bad)


func test_two_presses_each_keep_their_own_cell_and_origin() -> String:
	var cell: Vector2i = _diggable_cell()
	if cell == Vector2i.MAX:
		return SETUP
	var rover: RoverController = _rover(cell, 0.0)
	var said: Array[String] = []
	rover.dig_rejected.connect(func(why: String) -> void: said.append(why))
	var bad: PackedStringArray = []
	rover.queue_command(RoverController.Command.DIG)
	var first: Vector2i = rover.dig_cell()
	var start: Vector3 = rover.global_position
	rover.global_position += Vector3(0.0, 0.0, -rover.dig_drift_m * 0.6)
	var second: Vector2i = rover.dig_cell()
	rover.queue_command(RoverController.Command.DIG)
	var a: RoverController.UplinkCommand = rover._commands[0]
	var b: RoverController.UplinkCommand = rover._commands[1]
	if a.cell != first or a.origin != start or b.cell != second or b.origin != rover.global_position:
		bad.append("the presses did not keep their own cell and origin")
	if rover.dig_target() != first:
		bad.append("the outline must show the dig that lands first")
	# Past the first press's allowance, but not the second's: only the first goes.
	rover.global_position += Vector3(0.0, 0.0, -rover.dig_drift_m * 0.6)
	rover._cancel_drifted_digs()
	if rover._commands.size() != 1 or rover._commands[0] != b or said != [RoverController.MOVED_REFUSAL]:
		bad.append("only the first press should have been cancelled (%s)" % [said])
	if rover.dig_target() != second:
		bad.append("the outline did not move on to the next dig")
	# Several together say it once.
	said.clear()
	rover.queue_command(RoverController.Command.DIG)
	rover.queue_command(RoverController.Command.DIG)
	rover.global_position += Vector3(0.0, 0.0, -rover.dig_drift_m * 3.0)
	rover._cancel_drifted_digs()
	if not rover._commands.is_empty() or said.size() != 1:
		bad.append("three drifted digs should be one line (%s)" % [said])
	_free(rover)
	return "" if bad.is_empty() else "; ".join(bad)
