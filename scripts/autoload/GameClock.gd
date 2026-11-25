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
## Emitted after time_advanced when the clock ran on its own for a frame, and
## not for time jumps (a bench job, the F9 skip). The molt follows this.
signal clock_ran(delta_days: float)
## On a guest, each frame, for screens that show what the time allows. Nothing
## may change the farm on it.
signal guest_time_shown

const DAY_START_HOUR: float = 6.0
const HOURS_PER_DAY: float = 24.0
## Real seconds per in-game day. Stardew-style pacing; tune by feel.
const DEFAULT_SECONDS_PER_DAY: float = 720.0

var seconds_per_day: float = DEFAULT_SECONDS_PER_DAY
var paused: bool = false

## Days since the save started. 0.0 = day 1, 06:00.
var elapsed_days: float = 0.0

## The host's, with friends in: time stops just short of 06:00 (CoopBeds).
var morning_waits: bool = false

## A guest's clock may run this far past the host's last word (10 game minutes).
const MAX_AHEAD_DAYS: float = 10.0 / 1440.0
## It stops this short of 06:00 (one game second) until the host says it is
## morning. So does the host's own while the morning waits.
const BEFORE_MORNING_DAYS: float = 1.0 / 86400.0
## A guest's guess at the host's clock, and how far the guess may go.
var _host_days: float = 0.0
var _host_limit: float = 0.0


func _process(delta: float) -> void:
	if FarmCommands.guest:
		_run_as_guest(delta)
		return
	if paused or seconds_per_day <= 0.0:
		return
	var delta_days: float = delta / seconds_per_day
	var before: float = elapsed_days
	advance(delta_days)
	if morning_waits:
		delta_days = minf(delta_days, elapsed_days - before)
	if delta_days > 0.0:
		clock_ran.emit(delta_days)


## Moves time forward. Drift and day_started follow from this. A jump across
## 06:00 is split at each morning, so day_started sees the clock and the drift
## exactly as they were at 06:00.
func advance(delta_days: float) -> void:
	if FarmCommands.guest or delta_days <= 0.0:
		return
	var end: float = elapsed_days + delta_days
	if morning_waits:
		end = minf(end, floorf(elapsed_days) + 1.0 - BEFORE_MORNING_DAYS)
	while floorf(end) > floorf(elapsed_days):
		var morning: float = floorf(elapsed_days) + 1.0
		var step: float = morning - elapsed_days
		elapsed_days = morning
		time_advanced.emit(step)
		day_started.emit(get_day_index())
	if end > elapsed_days:
		var rest: float = end - elapsed_days
		elapsed_days = end
		time_advanced.emit(rest)


## On a guest: the host's clock, as it last said. A guest a little ahead waits
## for the host; only a host that is paused or far behind moves it back.
func follow(host_days: float, host_seconds_per_day: float, host_paused: bool) -> void:
	seconds_per_day = host_seconds_per_day
	_host_days = host_days
	_host_limit = host_days if host_paused else maxf(host_days,
		minf(host_days + MAX_AHEAD_DAYS, floorf(host_days) + 1.0 - BEFORE_MORNING_DAYS))
	if host_paused or elapsed_days > host_days + MAX_AHEAD_DAYS or floorf(elapsed_days) > floorf(host_days):
		elapsed_days = host_days
	elapsed_days = maxf(elapsed_days, host_days)


## Only shows the time, so no drift, no molt and no morning here:
## those come from the host (FarmSync).
func _run_as_guest(delta: float) -> void:
	if seconds_per_day <= 0.0:
		return
	_host_days = minf(_host_days + delta / seconds_per_day, _host_limit)
	elapsed_days = maxf(elapsed_days, _host_days)
	guest_time_shown.emit()


## True if the day would have to wait before this much time could pass.
func waits_within(delta_days: float) -> bool:
	return morning_waits and elapsed_days + delta_days > floorf(elapsed_days) + 1.0 - BEFORE_MORNING_DAYS


## Jumps to the next 06:00. Sensors drift for the skipped time.
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
	# An exact 12:20 can come out as 12:19.99999…, so ask when the next minute starts.
	var day: int = get_day_index()
	var minutes: int = floori(get_hour() * 60.0)
	var next: int = (minutes + 1) % (24 * 60)
	if next != floori(DAY_START_HOUR * 60.0) and elapsed_days >= elapsed_at_hour(day, next / 60.0):
		minutes = next
	@warning_ignore("integer_division")
	return "DAY %d  %02d:%02d" % [day, minutes / 60, minutes % 60]
