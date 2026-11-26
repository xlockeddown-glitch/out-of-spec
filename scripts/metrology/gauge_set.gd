class_name GaugeSet
extends RefCounted
## The 81-piece inch gauge block set a farm collects from its buried blocks.
##
## Each buried block (ReferenceBlock) is one piece of the set: a size and a grade
## come from the farm's seed and its cell, so every PC agrees. Nothing here is
## saved; the set is worked out from the cells found (GameState.found_blocks),
## which the save already lists and checks, so the host owns it and a guest is
## only told.
##
## The real composition of the standard 81-piece inch set is 9 blocks of
## 0.1001-0.1009 in, 49 of 0.101-0.149 in, 19 of 0.050-0.950 in and 4 of 1, 2, 3
## and 4 in. Sources:
## https://www.zoro.com/starrett-gage-block-set-01001-4000-in-81-pcs-rs81b/i/G2756442/
## https://littlemachineshop.com/products/gage-block-set-rectangular-81-pieces

## Sizes in ten-thousandths of an inch, whole numbers so no two compare by float.
## 9 of 0.1001-0.1009, 49 of 0.101-0.149, 19 of 0.050-0.950, then 1, 2, 3 and 4 in.
const SIZES_TEN_THOUSANDTHS: Array[int] = [
	1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1010, 1020, 1030,
	1040, 1050, 1060, 1070, 1080, 1090, 1100, 1110, 1120, 1130, 1140, 1150,
	1160, 1170, 1180, 1190, 1200, 1210, 1220, 1230, 1240, 1250, 1260, 1270,
	1280, 1290, 1300, 1310, 1320, 1330, 1340, 1350, 1360, 1370, 1380, 1390,
	1400, 1410, 1420, 1430, 1440, 1450, 1460, 1470, 1480, 1490, 500, 1000,
	1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000, 5500, 6000, 6500, 7000,
	7500, 8000, 8500, 9000, 9500, 10000, 20000, 30000, 40000,
]
## The grades, best first. The game's own naming (Ryan's choice), not the standard's:
## ASME B89.1.9 names its grades K, 00, 0, AS-1 and AS-2.
const GRADES: Array[String] = ["00", "0", "1"]
## Chance in percent a found block is each grade, best first [PLACEHOLDER].
const GRADE_ODDS_PERCENT: Array[int] = [15, 35, 50]

const NEW: StringName = &"new"
const BETTER: StringName = &"better"
const DUPLICATE: StringName = &"duplicate"


## The number of pieces in a full set: the sizes in the table.
static func size_count() -> int:
	return SIZES_TEN_THOUSANDTHS.size()


## A piece's size in inches.
static func size_in(index: int) -> float:
	return SIZES_TEN_THOUSANDTHS[index] / 10000.0


## A grade index (0 is best) from a roll of 0 to 99.
static func grade_from_roll(roll: int) -> int:
	var edge: int = 0
	for grade: int in GRADE_ODDS_PERCENT.size():
		edge += GRADE_ODDS_PERCENT[grade]
		if roll < edge:
			return grade
	return GRADE_ODDS_PERCENT.size() - 1


## The set held by the blocks in `cells`: size index -> best grade index of the
## pieces of that size. A second piece of a size only counts if its grade is better.
##
## Each block has a size drawn from the seed and its cell, but the draw is kind: the
## cells are walked in a fixed order (x, then y, so not the order they were found),
## and a block whose drawn size is already held takes the next free size up, wrapping
## round. So the first 81 blocks always make 81 different sizes. Once all 81 are
## held a block keeps its own drawn size and can only improve a grade. The result
## depends only on the seed and the set of cells, so every PC and every reload agrees.
static func pieces(world_seed: int, cells: Array) -> Dictionary:
	var unique: Dictionary = {}
	for cell: Variant in cells:
		if cell is Vector2i and not ReferenceBlock.at(world_seed, cell).is_empty():
			unique[cell] = true
	var ordered: Array = unique.keys()
	ordered.sort_custom(_cell_before)
	var out: Dictionary = {}
	var total: int = size_count()
	for cell: Vector2i in ordered:
		var block: Dictionary = ReferenceBlock.at(world_seed, cell)
		var size: int = block["size_index"]
		while out.size() < total and out.has(size):
			size = (size + 1) % total
		out[size] = mini(out.get(size, GRADES.size()), block["grade"])
	return out


static func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y if a.x == b.x else a.x < b.x


## What finding `block` adds to the blocks in `before`: NEW size, a BETTER grade
## of a size held, or a DUPLICATE that adds nothing. Compares the set before and
## after, since the new block may take a free size other than its drawn one.
static func finding(world_seed: int, before: Array, block: Dictionary) -> StringName:
	var held: Dictionary = pieces(world_seed, before)
	var after: Dictionary = pieces(world_seed, before + [block["cell"]])
	if after.size() > held.size():
		return NEW
	for size: Variant in after:
		if after[size] < held.get(size, GRADES.size()):
			return BETTER
	return DUPLICATE


static func is_complete(held: Dictionary) -> bool:
	return held.size() == size_count()


## The set's grade index: that of its worst piece, so one weak block lowers the
## set. -1 for an empty set. Only a full set has a grade as a set.
static func set_grade(held: Dictionary) -> int:
	var worst: int = -1
	for size: Variant in held:
		worst = maxi(worst, held[size])
	return worst


## What the phone shows: "" with no piece, else the count and the grade.
static func text(held: Dictionary) -> String:
	if held.is_empty():
		return ""
	if is_complete(held):
		return "GAUGE SET %d/%d: GRADE %s" % [held.size(), size_count(), GRADES[set_grade(held)]]
	return "GAUGE SET %d/%d, worst piece grade %s" % [held.size(), size_count(), GRADES[set_grade(held)]]
