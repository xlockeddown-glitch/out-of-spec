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
	# The Aquifer's hub is a stem and one room with a pool: the camp sits in the room's
	# south west corner, two cells from the pool, off the hatch, lift, crate and sign [PLACEHOLDER].
	"flooded_aquifer": Vector2i(9, 12),
	# The Ice Caves' hub is the Lava hub's map: the same east chamber as the Lava camp [PLACEHOLDER].
	"ice_caves": Vector2i(16, 12),
}
## A moon's camp spot, on its hub's deck (x, y, z) [PLACEHOLDER]: Deimos' expedition camp
## (zones step 18). Clear of the console, board, cache, pod, hab, shuttle, craters and the
## walker's arrival point; it is walked to on foot, not driven to. It has no cell.
const MOON_SPOTS: Dictionary[String, Vector3] = {
	"deimos": Vector3(6.0, 0.0, 8.0),
}
## A walker is this near a moon camp (m) to use it [PLACEHOLDER]. The host cannot know a
## moon walker's position, so the hub checks this on the screen, as it does the console.
const MOON_REACH_M: float = 5.0
## The most nights of supplies a saved farm may hold [PLACEHOLDER]: an expedition's party
## stocks nights for everyone at booking, so it is above MAX_SUPPLIES (the camp hub's cap).
## Two caps on purpose: MAX_SUPPLIES limits what the hub's Buy button adds (it refuses at 3), while
## HELD_MOST is only the most a loaded or synced value may be (a 4-night party can hold 8 at booking).
const HELD_MOST: int = 24
## The count a night at an expedition camp adds, for the expedition quest (not NIGHT_COUNT,
## so a moon night never counts for Two Sunsets).
const EXPEDITION_NIGHT_COUNT: String = "expedition_night"
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


## The count a night at `zone`'s camp adds. The Lava Tubes keep NIGHT_COUNT (Two Sunsets reads
## it); every other zone counts its own, so a night in one zone never counts for another's quest.
static func night_key(zone: String) -> String:
	return NIGHT_COUNT if zone == "lava_tubes" else NIGHT_COUNT + "_" + zone


## A night at the Ice Caves camp needs the heater the cold rule already uses: the player's
## pack must have been warmed by a heater cartridge lately, so the cold is under the drift
## threshold [PLACEHOLDER: no extra supply]. The camp's heater then keeps the night warm.
## Returns "" or why not; any other zone has no cold rule here.
static func cold_problem(zone: String, cold: float) -> String:
	if zone != IceDepth.ZONE or cold < IceDepth.COLD_THRESHOLD:
		return ""
	return "Too cold to sleep out: buy a heater cartridge at the hub crate first (%d credits). The pack is at %d %%." % [IceDepth.HEATER_COST_CREDITS, int(cold)]


static func has_camp(zone: String) -> bool:
	return CELLS.has(zone) or MOON_SPOTS.has(zone)


## True for a camp on a moon's deck (reached on foot, no rover).
static func is_moon_camp(zone: String) -> bool:
	return MOON_SPOTS.has(zone)


## The zones that have a camp, in a fixed order.
static func zones() -> Array[String]:
	var found: Array[String] = []
	found.assign(CELLS.keys())
	found.append_array(MOON_SPOTS.keys())
	found.sort()
	return found


## "" or why a moon camp's hub is not a bed for the local walker now: they are further than
## MOON_REACH_M from the camp (or the hub has no walker to say). `walker` is the hub's walker
## node (a Node3D) or null. A zone whose camp is not on a moon deck has no reach rule here.
static func moon_reach_refusal(zone: String, walker: Variant) -> String:
	if not is_moon_camp(zone):
		return ""
	if not walker is Node3D or not near(zone, (walker as Node3D).global_position):
		return Shuttle.text("camp_far_text")
	return ""


## The camp's cell in its zone's hub map, or (-1, -1) for a zone with none.
static func cell(zone: String) -> Vector2i:
	return CELLS.get(zone, Vector2i(-1, -1))


## The middle of the camp's cell on its zone's hub, or the origin for a zone with none.
static func position(zone: String) -> Vector3:
	if MOON_SPOTS.has(zone):
		return MOON_SPOTS[zone]
	if not has_camp(zone):
		return Vector3.ZERO
	return TunnelRock.at_in(ZoneDepth.grid_for(0, 0, 0, zone), cell(zone))


## `at` is within reach of the camp: `slack` is added on the host, which hears of the
## rover a moment late.
static func near(zone: String, at: Vector3, slack: float = 0.0) -> bool:
	if not has_camp(zone):
		return false
	var there: Vector3 = position(zone)
	var reach: float = MOON_REACH_M if is_moon_camp(zone) else REACH_M
	return Vector2(there.x - at.x, there.z - at.z).length() <= reach + slack


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


## Why a traveller can't sleep at a moon's camp tonight, or "". `holds_trip` whether they are
## on an expedition, `supplies` the farm's nights held (a night already paid for counts as one).
static func moon_sleep_problem(zone: String, open: bool, holds_trip: bool, supplies: int) -> String:
	if not is_moon_camp(zone):
		return "There is no camp here."
	if not holds_trip:
		return "The camp is for an expedition: book one at the pad terminal."
	if not open:
		return "The camp is shut: a quest opens it."
	if supplies < 1:
		return "No supplies for the night. An expedition is booked with its nights of supplies."
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
	if not value is int or value < 0 or value > HELD_MOST:
		return "'camp_supplies' is not between 0 and %d." % HELD_MOST
	return ""
