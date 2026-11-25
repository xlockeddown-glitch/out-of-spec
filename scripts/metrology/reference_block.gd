class_name ReferenceBlock
extends RefCounted
## Angle blocks buried in the ground, and the field check they allow.
##
## Which cell holds one comes from the farm's seed and the cell alone, so every
## PC agrees and a reload re-rolls nothing. A block is a certified angle: its
## certificate gives a value and an expanded uncertainty, and its true value is
## off from the certified one by a hidden amount within that uncertainty. The
## check reads an instrument against it and changes nothing on the instrument.

## One diggable cell in this many holds a block [PLACEHOLDER].
const ODDS: int = 30
## Certified angles, in degrees [PLACEHOLDER].
const ANGLES_DEG: Array[float] = [15.0, 30.0, 45.0]
## Expanded uncertainty on every certificate, in degrees, and its k [PLACEHOLDER]:
## the same as the rotary table's.
const U_DEG: float = 0.02
const K: float = 2.0
## An angle block checks instruments whose error is in this unit, and no others.
const UNIT: String = "degrees"

const VERDICT_WITHIN: String = "within"
const VERDICT_OUTSIDE: String = "outside"
const VERDICT_UNCLEAR: String = "unclear"


## The block in `cell` of the farm with `world_seed`, or {}: { cell, certified,
## u, k, true_value } in degrees. true_value is hidden from the player.
static func at(world_seed: int, cell: Vector2i) -> Dictionary:
	if not Terrain.can_dig(cell):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:block:%d:%d" % [world_seed, cell.x, cell.y])
	if rng.randi() % ODDS != 0:
		return {}
	var certified: float = ANGLES_DEG[rng.randi() % ANGLES_DEG.size()]
	var off: float = clampf(rng.randfn(0.0, U_DEG / K), -U_DEG, U_DEG)
	return { "cell": cell, "certified": certified, "u": U_DEG, "k": K, "true_value": certified + off }


## Why `sensor` can't be checked with a block, or "".
static func problem(sensor: DriftingSensor) -> String:
	if sensor == null:
		return "There is no such instrument."
	if sensor.error_unit != UNIT:
		return "An angle block can't check %s." % sensor.quantity_name()
	return ""


## What `sensor` reads put against `block`, and what that says. The reading is
## the true angle plus the sensor's true error, to one digit. The error is the
## reading less the certified value, so it carries the block's own off-ness;
## its uncertainty is the block's and the digit's. Within the MPE only if the
## error plus that uncertainty is; outside only if the error less it still is.
## Reads the sensor and never writes it. { refused, reason } if it can't be done.
static func check(sensor: DriftingSensor, block: Dictionary) -> Dictionary:
	var why: String = problem(sensor)
	if why != "":
		return { "refused": true, "reason": why }
	var reading: float = block["true_value"] + sensor.error
	if sensor.resolution > 0.0:
		reading = snappedf(reading, sensor.resolution)
	var error: float = reading - block["certified"]
	var u_block: float = float(block["u"]) / float(block["k"])
	var u_digit: float = CalUncertainty.resolution_to_standard(sensor.resolution)
	var expanded: float = float(block["k"]) * sqrt(u_block * u_block + u_digit * u_digit)
	var verdict: String = VERDICT_UNCLEAR
	if absf(error) + expanded <= sensor.mpe:
		verdict = VERDICT_WITHIN
	elif absf(error) - expanded > sensor.mpe:
		verdict = VERDICT_OUTSIDE
	return {
		"refused": false, "instrument_id": sensor.instrument_id, "certified": block["certified"],
		"block_u": block["u"], "block_k": block["k"], "reading": reading, "error": error,
		"error_u": expanded, "mpe": sensor.mpe, "verdict": verdict,
	}
