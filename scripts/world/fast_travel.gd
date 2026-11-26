class_name FastTravel
extends RefCounted
## Fast travel (docs/design/zones.md section 8.1, build step 7): from the console
## in the dome a player goes to a zone they have been to, in the zone's field
## rover, and the farm's rover stays home. Pure rules and words; GameState
## applies them (`fast_travel`, `leave_zone`). Every word is [PLACEHOLDER].

## What an arrival does with the zone's field rover.
const START: String = "start"      # none is live: one starts at the zone's start
const JOIN: String = "join"        # one is live: the player joins it where it is
const RE_PARK: String = "re_park"  # live, but left below with nobody below: back to the hub

const TEXT: Dictionary = {
	"console_in_dome": "The fast-travel console is in the dome.",
	"no_zone": "There is no way to that place yet.",
	"field_rover_out": "Someone is in there with the rover. Go by the dome console, or wait until they are out.",
	"use_the_mouth": "The farm's rover is out there: it comes home by the tunnel mouth.",
	"someone_driving": "Someone is driving the rover there. Try again in a moment.",
	"title": "FAST TRAVEL",
	"hint": "Choose a place. The farm's rover stays home.",
	"none": "Nowhere to go yet.",
	"go": "Go",
	"close": "Close",
	"warn_again": "Press again to go.",
}


## True while a console request is out: the dome's airlock stays shut, so a
## trip the host has agreed to is not left without its screen.
static var pending: bool = false


static func text(key: String) -> String:
	return str(TEXT.get(key, ""))


## What an arrival does. `live`: a zone's rover is there; `depth`: how far below
## the hub it is; `places` the [place, depth] of everyone else in the zone. A rover
## below is only started again when nobody at all is in the zone: someone in the
## hub may be on the way down (the host records them late).
static func arrival_plan(live: bool, depth: int, places: Array) -> String:
	if not live:
		return START
	if depth <= 0:
		return JOIN
	return JOIN if not places.is_empty() else RE_PARK


## The places the console offers: one row { id, name, warning } per zone with a
## scene that the farm has been to, in the table's order. `warning` is the soft gate's line, "" for none.
static func destinations(lab_level: int, unlocked: Array) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for id: StringName in ZoneData.ids():
		if ZoneData.is_playable(id) and unlocked.has(String(id)):
			found.append({ "id": String(id), "name": str(ZoneData.zone(id).get("name", id)), "warning": ZoneData.warning_text(id, lab_level) })
	return found
