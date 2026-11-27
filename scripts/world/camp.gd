class_name Camp
extends RefCounted
## The camp-outs (docs/design/zones.md sections 6.2 and 12.4, build step 12): one camp
## spot in a zone's hub, shut until a quest opens it for the farm, supplies bought
## at the hub from the shared wallet, and a night there counts as going to bed with no
## rescue fee. Pure rules and words; the farm's state (`camps_open`, `camp_supplies`)
## lives in GameState. Every number is a [PLACEHOLDER].

## A zone's camp cell, in its hub's map (depth 0, which the 06:00 reseed does not touch).
## A later PR gives another zone a camp with one line here.
const CELLS: Dictionary[String, Vector2i] = {
	"lava_tubes": Vector2i(16, 12),
}
## One night's supplies [PLACEHOLDER].
const SUPPLY_COST_CREDITS: int = 30
## The most nights of supplies the farm holds [PLACEHOLDER].
const MAX_SUPPLIES: int = 3
## The rover is this near the camp (m) to use it [PLACEHOLDER], as the hub's rack is.
const REACH_M: float = 4.0
## What the host's word of the rover lags, so a screen that was in reach is not refused [PLACEHOLDER].
const HOST_REACH_SLACK_M: float = 1.5
## The count a night at the camp adds to a player's action_counts, for the Two Sunsets step.
const NIGHT_COUNT: String = "camp_night"


static func has_camp(zone: String) -> bool:
	return CELLS.has(zone)


## The zones that have a camp, in a fixed order.
static func zones() -> Array[String]:
	var found: Array[String] = []
	found.assign(CELLS.keys())
	found.sort()
	return found


## The camp's cell in its zone's hub map, or (-1, -1) for a zone with none.
static func cell(zone: String) -> Vector2i:
	return CELLS.get(zone, Vector2i(-1, -1))


## The middle of the camp's cell on its zone's hub, or the origin for a zone with none.
static func position(zone: String) -> Vector3:
	if not has_camp(zone):
		return Vector3.ZERO
	return TunnelRock.at_in(ZoneDepth.grid_for(0, 0, 0, zone), cell(zone))


## `at` is within reach of the camp: `slack` is added on the host, which hears of the
## rover a moment late.
static func near(zone: String, at: Vector3, slack: float = 0.0) -> bool:
	if not has_camp(zone):
		return false
	var there: Vector3 = position(zone)
	return Vector2(there.x - at.x, there.z - at.z).length() <= REACH_M + slack


## Why the farm can't buy a night's supplies, or "". `here` is the buyer's place and
## `depth` their depth, `near_now` whether the rover is by the camp.
static func buy_problem(zone: String, open: bool, here: String, depth: int, supplies: int, credits: int, near_now: bool) -> String:
	if here != zone or depth != 0 or not has_camp(zone):
		return "Camp supplies are sold at the camp in the hub."
	if not open:
		return "The camp is shut: a quest opens it."
	if supplies >= MAX_SUPPLIES:
		return "The farm holds %d nights of supplies already." % MAX_SUPPLIES
	if not near_now:
		return "The rover is too far from the camp."
	if credits < SUPPLY_COST_CREDITS:
		return "A night's supplies cost %d credits." % SUPPLY_COST_CREDITS
	return ""


## Why a player can't sleep at the camp, or "". `zone` is the zone they are in and
## `depth` their depth there; `rover_here` whether the field rover is in that zone at
## depth 0; `near_now` whether it is by the camp.
static func sleep_problem(zone: String, open: bool, depth: int, rover_here: bool, near_now: bool, supplies: int) -> String:
	if not has_camp(zone):
		return "There is no camp here. Go to bed from the farm, or the camp in the hub."
	if depth != 0:
		return "The camp is in the hub, not down here."
	if not open:
		return "The camp is shut: a quest opens it."
	if not rover_here or not near_now:
		return "Park the rover at the camp first."
	if supplies < 1:
		return "No supplies for the night. Buy a night's supplies at the camp (%d credits)." % SUPPLY_COST_CREDITS
	return ""


## Why a saved `camps_open` can't stand, or "".
static func open_problem(value: Variant) -> String:
	if not value is Array:
		return "'camps_open' is not a list."
	var seen: Array[String] = []
	for zone: Variant in value:
		if not zone is String or not has_camp(zone):
			return "'camps_open' holds a zone with no camp."
		if zone in seen:
			return "'camps_open' holds a zone twice."
		seen.append(zone)
	return ""


## Why a saved supply count can't stand, or "".
static func supplies_problem(value: Variant) -> String:
	if not value is int or value < 0 or value > MAX_SUPPLIES:
		return "'camp_supplies' is not between 0 and %d." % MAX_SUPPLIES
	return ""
