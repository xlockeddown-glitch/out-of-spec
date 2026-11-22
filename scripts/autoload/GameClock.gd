extends Node
## In-game time. Autoloaded as `GameClock`.
##
## A day runs morning to morning: day 1 starts at DAY_START_HOUR (06:00) and
## each new day starts at the next 06:00, when `day_started` fires (dispatches,
## audits). Time-based drift is fed from `time_advanced`.

## Emitted every frame the clock runs, with the in-game days that elapsed.
signal time_advanced(delta_days: float)
## Fires at each morning after day 1 (day 1 is "already started" at boot).
signal day_started(day_index: int)

const DAY_START_HOUR: float = 6.0
const HOURS_PER_DAY: float = 24.0
## Real seconds per in-game day. Stardew-style pacing; tune by feel.
const DEFAULT_SECONDS_PER_DAY: float = 720.0

var seconds_per_day: float = DEFAULT_SECONDS_PER_DAY
var paused: bool = false

## Days since the save started. 0.0 = day 1, 06:00.
var elapsed_days: float = 0.0


func _process(delta: float) -> void:
	if paused or seconds_per_day <= 0.0:
		return
	advance(delta / seconds_per_day)


## Moves time forward. Drift and day_started follow from this. (Molt still
## runs on real seconds in GameState for the 20 s playtest.)
func advance(delta_days: float) -> void:
	if delta_days <= 0.0:
		return
	var previous_day: int = get_day_index()
	elapsed_days += delta_days
	time_advanced.emit(delta_days)
	for day: int in range(previous_day + 1, get_day_index() + 1):
		day_started.emit(day)


## Debug helper: jump to the next 06:00. Sensors drift for the skipped time.
func skip_to_next_morning() -> void:
	advance(float(get_day_index()) - elapsed_days)


## 1-based day number.
func get_day_index() -> int:
	return floori(elapsed_days) + 1


## Hours since midnight, 0.0 to 24.0.
func get_hour() -> float:
	return fmod(DAY_START_HOUR + fmod(elapsed_days, 1.0) * HOURS_PER_DAY, HOURS_PER_DAY)


## Maps a wall-clock hour to elapsed time within a 1-based game day.
func elapsed_at_hour(day_index: int, hour: float) -> float:
	var hours_since_start: float = fposmod(hour - DAY_START_HOUR, HOURS_PER_DAY)
	return float(day_index - 1) + hours_since_start / HOURS_PER_DAY


## "DAY 3  14:20"
func format_now() -> String:
	var hour: float = get_hour()
	return "DAY %d  %02d:%02d" % [get_day_index(), floori(hour), floori(fmod(hour, 1.0) * 60.0)]
