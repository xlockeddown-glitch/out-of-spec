class_name StonePieces
## What the farm can build from broken boulders: a low wall, a level pad and a
## water channel, one on a 2 m cell of Terrain. The rules only: GameState keeps
## the stock and the pieces (cell -> kind), StonePiecesView draws them.

enum { WALL, PAD, CHANNEL }
## Asks to take up what is on the cell, not to build.
const TAKE_UP: int = -1

const KIND_NAMES: Array[String] = ["wall", "pad", "channel"]
## Stone a piece costs, by kind; taking it up gives all of it back [PLACEHOLDER].
const COSTS: Array[int] = [2, 1, 1]
## Stone a broken boulder gives [PLACEHOLDER]. The four boulders give 24.
const PER_BOULDER: int = 6
## No stock is bigger than this, so a save can be checked [PLACEHOLDER].
const MAX_STONE: int = 100000
## A wall stands this high above the middle of its cell, and a rover is taken as
## this wide and long when seeing whether it is in the way [PLACEHOLDER].
const WALL_M: float = 1.1
const ROVER_HALF := Vector2(0.8, 1.2)


static func is_kind(kind: int) -> bool:
	return kind >= 0 and kind < KIND_NAMES.size()


static func cost(kind: int) -> int:
	return COSTS[kind]


static func kind_name(kind: int) -> String:
	return KIND_NAMES[kind]


## The kind after this one, for the key that cycles them.
static func next_kind(kind: int) -> int:
	return (kind + 1) % KIND_NAMES.size()


## Why a piece can't be built on a cell, or "". `rovers` are where the rovers on
## the farm stand. Not about the stock.
static func problem(cell: Vector2i, kind: int, pieces: Dictionary[Vector2i, int], rovers: Array[Transform3D]) -> String:
	if not is_kind(kind):
		return "There is no such piece."
	# Level ground holds the plot, the pads, the gates, the props, the relay and
	# the spawn; the land's edge and what is near a rock go too.
	if not Terrain.can_dig(cell) or HillDressing.is_at_rock(cell):
		return "Nothing can be built on this ground."
	if pieces.has(cell):
		return "Something is built here."
	# A rover drives over a pad or a channel, so only a wall needs the room.
	if kind == WALL:
		for pose: Transform3D in rovers:
			if covers(cell, pose):
				return "The rover is in the way. Back it up."
		for pose: Transform3D in rovers:
			if _boxed_in(Terrain.cell_at(Vector2(pose.origin.x, pose.origin.z)), cell, pieces):
				return "That would trap the rover."
	return ""


## True if a rover standing as `pose` is over any of the cell.
static func covers(cell: Vector2i, pose: Transform3D) -> bool:
	var at := Vector2(pose.origin.x, pose.origin.z)
	var right := Vector2(pose.basis.x.x, pose.basis.x.z).normalized()
	var ahead := Vector2(pose.basis.z.x, pose.basis.z.z).normalized()
	for i: int in range(-4, 5):
		for j: int in range(-6, 7):
			var point: Vector2 = at + right * ROVER_HALF.x * i / 4.0 + ahead * ROVER_HALF.y * j / 6.0
			if Terrain.cell_at(point) == cell:
				return true
	return false


## True if a wall on `wall` leaves all four sides of `middle` walled: a rover
## is too wide for the gap at a corner.
static func _boxed_in(middle: Vector2i, wall: Vector2i, pieces: Dictionary[Vector2i, int]) -> bool:
	var sides: Array[Vector2i] = [middle + Vector2i.LEFT, middle + Vector2i.RIGHT, middle + Vector2i.UP, middle + Vector2i.DOWN]
	if not wall in sides:
		return false
	for around: Vector2i in sides:
		if around != wall and pieces.get(around, -1) != WALL:
			return false
	return true


## Why these can't be a farm's pieces, or "". They may hold anything.
static func pieces_problem(pieces: Dictionary) -> String:
	for cell: Variant in pieces:
		if not cell is Vector2i or not pieces[cell] is int or not is_kind(pieces[cell]):
			return "has an entry that is not a piece."
		if not Terrain.can_dig(cell) or HillDressing.is_at_rock(cell):
			return "has a piece where nothing can be built."
	return ""


## The cells that hold a channel, for the water that will run in them.
static func channel_cells(pieces: Dictionary[Vector2i, int]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in pieces:
		if pieces[cell] == CHANNEL:
			cells.append(cell)
	return cells


## The rough box a wall fills on its cell, in the world.
static func wall_box(cell: Vector2i, dug: Dictionary[Vector2i, int]) -> AABB:
	var low: float = INF
	var middle := Vector2((Vector2(cell) + Vector2.ONE * 0.5) * Terrain.CELL_M)
	for x: int in Terrain.CELL_M + 1:
		for z: int in Terrain.CELL_M + 1:
			low = minf(low, Terrain.point_height(cell * Terrain.CELL_M + Vector2i(x, z), dug))
	var top: float = Terrain.height(middle, dug) + WALL_M
	var size := Vector3(Terrain.CELL_M * 0.95, top - low + 0.15, Terrain.CELL_M * 0.95)
	return AABB(Vector3(middle.x - size.x / 2.0, low - 0.15, middle.y - size.z / 2.0), size)
