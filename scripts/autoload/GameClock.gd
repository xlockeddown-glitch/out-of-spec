extends Node
## In-game time. Autoloaded as `GameClock`.
##
## Week 2: just a running day counter so time-based drift has a source.
## Week 3 grows this into the morning-to-night cycle (dispatch timing, etc.).

## Emitted every frame the clock runs, with the in-game days that elapsed.
signal time_advanced(delta_days: float)
signal day_started(day_index: int)

## Real seconds per in-game day. Placeholder until the Week 3 day loop.
var seconds_per_day: float = 600.0
var paused: bool = false

## Days since the save started. Day 1 begins at 0.0.
var elapsed_days: float = 0.0


func _process(delta: float) -> void:
	if paused or seconds_per_day <= 0.0:
		return
	var delta_days: float = delta / seconds_per_day
	var previous_day: int = get_day_index()
	elapsed_days += delta_days
	time_advanced.emit(delta_days)
	if get_day_index() != previous_day:
		day_started.emit(get_day_index())


## 1-based day number.
func get_day_index() -> int:
	return floori(elapsed_days) + 1
