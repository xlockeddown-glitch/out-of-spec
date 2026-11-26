class_name GaugeStack
extends RefCounted
## A stack of gauge blocks wrung together to make one length
## (docs/design/quests_levels_story.md section 7.1, Wring the Blocks).
##
## The length asked for is always the sum of real pieces the farm holds
## (GaugeSet, by size index), so it can be built. Sizes are whole
## ten-thousandths of an inch, as GaugeSet has them, so a sum is exact.
## Everything here is worked out from the pieces held and a seed, and nothing is
## saved: the host and a guest's screen get the same length from the same farm.

## A stack has a joint to wring, so it takes this many pieces at least.
const MIN_BLOCKS: int = 2
## The pieces a named length is made of, where the farm holds that many [PLACEHOLDER].
const STACK_BLOCKS: int = 3
## The pieces laid out to pick from: those that make the length, and others the
## farm holds [PLACEHOLDER].
const TRAY_BLOCKS: int = 6


## The seed of the length a player is asked for: the farm's seed, the day and
## the player, all of which a guest's screen has too. So it is one length a day
## for each player [ASSUMPTION].
static func stack_seed(world_seed: int, day: int, player_id: String) -> int:
	return hash([world_seed, day, player_id, "gauge_stack"])


## The size indexes in `held` that are pieces of the set, each once, in order.
static func pieces_of(held: Array) -> Array[int]:
	var out: Array[int] = []
	for index: Variant in held:
		if index is int and index >= 0 and index < GaugeSet.size_count() and not index in out:
			out.append(index)
	out.sort()
	return out


## The length to build from the pieces in `held` (size indexes), or {} with
## fewer than MIN_BLOCKS:
##   target  the length, in ten-thousandths of an inch
##   sizes   the pieces it was made from (size indexes, in order)
##   tray    the pieces laid out to pick from, by size, smallest first
## The same `held` and `pick_seed` give the same answer on every PC.
static func target(held: Array, pick_seed: int) -> Dictionary:
	var pieces: Array[int] = pieces_of(held)
	if pieces.size() < MIN_BLOCKS:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = pick_seed
	# The seed's own shuffle: Array.shuffle() would use the global generator.
	for i: int in range(pieces.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var kept: int = pieces[i]
		pieces[i] = pieces[j]
		pieces[j] = kept
	var made: Array[int] = pieces.slice(0, mini(STACK_BLOCKS, pieces.size()))
	var tray: Array[int] = pieces.slice(0, mini(TRAY_BLOCKS, pieces.size()))
	made.sort()
	tray.sort_custom(func(a: int, b: int) -> bool:
		return GaugeSet.SIZES_TEN_THOUSANDTHS[a] < GaugeSet.SIZES_TEN_THOUSANDTHS[b])
	return { "target": total(made), "sizes": made, "tray": tray }


## The length of a stack of these pieces, in ten-thousandths of an inch. -1 if
## one is no piece of the set or is there twice: a set holds one of each size.
static func total(picked: Array) -> int:
	var sum: int = 0
	var seen: Array[int] = []
	for index: Variant in picked:
		if not index is int or index < 0 or index >= GaugeSet.size_count() or index in seen:
			return -1
		seen.append(index)
		sum += GaugeSet.SIZES_TEN_THOUSANDTHS[index]
	return sum


## Whether a stack of `picked` is `target_length` long: two pieces or more, each
## once, and the sum exact. Any pieces that add up do, not only the ones the
## length was made from.
static func is_made_by(target_length: int, picked: Array) -> bool:
	return picked.size() >= MIN_BLOCKS and target_length > 0 and total(picked) == target_length


## "0.3511 in".
static func length_text(ten_thousandths: int) -> String:
	return "%s in" % SP811.number(ten_thousandths / 10000.0, 4)
