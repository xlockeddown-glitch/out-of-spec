class_name ZoneExposure
extends RefCounted
## The zones that run on the shared exposure clock: GameState's `cold_since` stamps (saved and
## synced) read as the Ice Caves' cold, Valles Marineris' thin air or the Olympus Mons caves' heat.
## One lookup per zone instead of a branch per zone in the farm: the grace on leaving, the reading,
## whether a spent suit stops finds, the words, and the first long drive of the far sites. Every
## number is the zone's own (IceDepth, VallesDepth, OlympusDepth); nothing here is a number.

const PLACES: Array[String] = [IceDepth.ZONE, VallesDepth.ZONE, OlympusDepth.ZONE]
## The far sites: a first trip costs rover time, then fast travel is free.
const FAR_SITES: Array[String] = [VallesDepth.ZONE, OlympusDepth.ZONE]


static func is_place(place: String) -> bool:
	return place in PLACES


static func is_far(zone: String) -> bool:
	return zone in FAR_SITES


## Whether leaving `zone` at `left` is still within its own grace at `now`.
static func within_grace(zone: String, left: float, now: float) -> bool:
	if zone == VallesDepth.ZONE:
		return VallesDepth.within_grace(left, now)
	if zone == OlympusDepth.ZONE:
		return OlympusDepth.within_grace(left, now)
	return IceDepth.within_grace(left, now)


## The reading, 0 to 100 %, of a player in `zone` who came in at stamp `since`, at `now`.
static func used(zone: String, since: float, now: float) -> float:
	if zone == VallesDepth.ZONE:
		return VallesDepth.air_used(since, now)
	if zone == OlympusDepth.ZONE:
		return OlympusDepth.heat_used(since, now)
	return IceDepth.cold(since, now)


## True for a zone whose spent suit stops the host taking finds (not the Ice Caves').
static func blocks_finds(zone: String) -> bool:
	return zone == VallesDepth.ZONE or zone == OlympusDepth.ZONE


static func is_out(zone: String, reading: float) -> bool:
	if zone == OlympusDepth.ZONE:
		return OlympusDepth.heat_is_out(reading)
	return VallesDepth.air_is_out(reading)


static func out_reply(zone: String) -> String:
	if zone == OlympusDepth.ZONE:
		return OlympusDepth.heat_out_reply()
	return VallesDepth.air_out_reply()


## The game hours a first trip into `zone` costs (0 once visited, and for a zone that is no far site).
static func drive_hours(zone: String, visited: bool) -> float:
	if zone == VallesDepth.ZONE:
		return VallesDepth.drive_hours(visited)
	if zone == OlympusDepth.ZONE:
		return OlympusDepth.drive_hours(visited)
	return 0.0


static func drive_too_late_text(zone: String) -> String:
	return OlympusDepth.drive_too_late_text() if zone == OlympusDepth.ZONE else VallesDepth.drive_too_late_text()
