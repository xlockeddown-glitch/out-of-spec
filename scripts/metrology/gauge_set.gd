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
static var SIZES_TEN_THOUSANDTHS: Array[int] = _make_sizes()
## The pieces in a full set.
const COUNT: int = 81
## The grades, best first: ASME B89.1.9 names 00, 0 and 1.
const GRADES: Array[String] = ["00", "0", "1"]
## Chance in percent a found block is each grade, best first [PLACEHOLDER].
const GRADE_ODDS_PERCENT: Array[int] = [15, 35, 50]

const NEW: StringName = &"new"
const BETTER: StringName = &"better"
const DUPLICATE: StringName = &"duplicate"


static func _make_sizes() -> Array[int]:
	var out: Array[int] = []
	for n: int in range(1001, 1010):
		out.append(n)
	for n: int in range(1010, 1491, 10):
		out.append(n)
	for n: int in range(500, 9501, 500):
		out.append(n)
	for n: int in [10000, 20000, 30000, 40000]:
		out.append(n)
	return out


## The number of pieces in a full set; the tests hold it to the sizes made.
static func size_count() -> int:
	return COUNT


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
static func pieces(world_seed: int, cells: Array) -> Dictionary:
	var out: Dictionary = {}
	for cell: Variant in cells:
		var block: Dictionary = ReferenceBlock.at(world_seed, cell) if cell is Vector2i else {}
		if block.is_empty():
			continue
		var size: int = block["size_index"]
		out[size] = mini(out.get(size, GRADES.size()), block["grade"])
	return out


## What finding `block` adds to the blocks in `before`: NEW size, a BETTER grade
## of a size held, or a DUPLICATE that adds nothing.
static func finding(world_seed: int, before: Array, block: Dictionary) -> StringName:
	var held: Dictionary = pieces(world_seed, before)
	if not held.has(block["size_index"]):
		return NEW
	return BETTER if block["grade"] < held[block["size_index"]] else DUPLICATE


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
