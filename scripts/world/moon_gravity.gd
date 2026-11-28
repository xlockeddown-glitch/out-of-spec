class_name MoonGravity
extends RefCounted
## What walking is like on the moons: the pull, the pace, the small hop each step makes,
## the jump and how little you steer in the air. All pure, so the walker and the tests
## read the same numbers. Game values, not the real ones (Phobos is about 1/1700 of
## Earth's pull, which would not read as play). Every number is a [PLACEHOLDER].
## Any other place (the farm) has the farm's pull and pace.

## Fall, m/s^2. The farm's is Walker.FALL_MPS2 (9.8) [PLACEHOLDER].
const PHOBOS_FALL_MPS2: float = 1.6
const DEIMOS_FALL_MPS2: float = 2.0
## On-foot speed, m/s: Phobos as the farm's, Deimos "as Phobos, slower" [PLACEHOLDER].
const PHOBOS_SPEED_MPS: float = Walker.SPEED_MPS
const DEIMOS_SPEED_MPS: float = 3.4
## How high each step lifts the walker's body (a look only), m [PLACEHOLDER].
const PHOBOS_HOP_M: float = 0.12
const DEIMOS_HOP_M: float = 0.14
## One hop's length, s: a step's beat, slower on Deimos [PLACEHOLDER].
const PHOBOS_HOP_S: float = 0.5
const DEIMOS_HOP_S: float = 0.65
## Straight-up speed of a jump, m/s [PLACEHOLDER]. At these the jump lasts
## 2 * jump / fall: 2.5 s on Phobos and 2.2 s on Deimos.
const PHOBOS_JUMP_MPS: float = 2.0
const DEIMOS_JUMP_MPS: float = 2.2
## In the air the walker's sideways speed turns toward the keys this much, m/s^2:
## little, so a run-and-jump lands past the mark [PLACEHOLDER].
const AIR_STEER_MPS2: float = 1.5


static func is_moon(moon: String) -> bool:
	return moon == Shuttle.PHOBOS or moon == Shuttle.DEIMOS


static func fall_mps2(moon: String) -> float:
	if moon == Shuttle.PHOBOS:
		return PHOBOS_FALL_MPS2
	return DEIMOS_FALL_MPS2 if moon == Shuttle.DEIMOS else Walker.FALL_MPS2


static func speed_mps(moon: String) -> float:
	if moon == Shuttle.DEIMOS:
		return DEIMOS_SPEED_MPS
	return PHOBOS_SPEED_MPS


static func hop_m(moon: String) -> float:
	if moon == Shuttle.PHOBOS:
		return PHOBOS_HOP_M
	return DEIMOS_HOP_M if moon == Shuttle.DEIMOS else 0.0


static func hop_s(moon: String) -> float:
	return DEIMOS_HOP_S if moon == Shuttle.DEIMOS else PHOBOS_HOP_S


static func jump_mps(moon: String) -> float:
	if moon == Shuttle.PHOBOS:
		return PHOBOS_JUMP_MPS
	return DEIMOS_JUMP_MPS if moon == Shuttle.DEIMOS else 0.0


## How far the body is lifted by the walk's hop `walked_s` seconds into it: a half
## sine per step, never below the deck. Flat on a tether or off a moon.
static func hop_offset_m(moon: String, walked_s: float, tethered: bool) -> float:
	if tethered or not is_moon(moon):
		return 0.0
	return hop_m(moon) * absf(sin(PI * walked_s / hop_s(moon)))


## How far a jump of `jump` m/s goes along the ground at `speed` m/s under `fall`
## m/s^2 with nothing steering it: speed times the time in the air.
static func jump_range_m(fall: float, jump: float, speed: float) -> float:
	return speed * 2.0 * jump / fall if fall > 0.0 else 0.0


## The sideways velocity one air tick on: it keeps its momentum and turns toward
## `want` (the heading, up to 1 long, times speed) by AIR_STEER_MPS2 at most. On a
## tether the walker steers fully, as on the ground.
static func air_velocity(current: Vector3, want: Vector3, speed: float, delta: float, tethered: bool) -> Vector3:
	var flat := Vector3(current.x, 0.0, current.z)
	var goal := Vector3(want.x, 0.0, want.z) * speed
	if tethered:
		return goal
	return flat.move_toward(goal, AIR_STEER_MPS2 * delta)
