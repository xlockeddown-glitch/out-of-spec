extends RefCounted
## Headless checks that the shed exuvia stays GameState.EXUVIA_LINGER_DAYS
## after the spool is taken, then goes. The GameState is never added to the
## tree; GameClock.elapsed_days is saved and restored.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")


func test_exuvia_lingers_then_goes() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = GameStateScript.new()
	var day: int = 3
	GameClock.elapsed_days = float(day - 1) + 0.5  # midday on day 3
	var before: bool = gs.is_exuvia_visible()
	gs.molt_stage = GameStateScript.MoltStage.MOLTED
	var molted: bool = gs.is_exuvia_visible()
	var took: bool = gs.collect_spool()
	var after_pickup: bool = gs.is_exuvia_visible()
	var linger: int = GameStateScript.EXUVIA_LINGER_DAYS
	GameClock.elapsed_days = float(day + linger - 1) - 0.01  # last moment it should still show
	var last_moment: bool = gs.is_exuvia_visible()
	GameClock.elapsed_days = float(day + linger - 1)  # the morning it goes
	var gone: bool = gs.is_exuvia_visible()
	GameClock.elapsed_days = saved
	gs.free()
	if before:
		return "No exuvia may show before the first molt."
	if not molted or not took:
		return "A molted enclosure must show the exuvia and give a spool."
	if linger > 0 and (not after_pickup or not last_moment):
		return "The exuvia must stay %d day(s) after the spool is taken." % linger
	if gone:
		return "The exuvia must be gone on the morning of day %d." % (day + linger)
	return ""
