extends RefCounted
## Headless checks that the shed exuvia stays until the morning after the spool
## is taken (Ryan's call: 1 day), then goes. The GameState is never added to
## the tree; GameClock.elapsed_days is saved and restored.

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")


func test_exuvia_lingers_until_next_morning() -> String:
	var saved: float = GameClock.elapsed_days
	var gs: GameStateScript = GameStateScript.new()
	GameClock.elapsed_days = 2.5  # midday on day 3 (day 1 starts at elapsed 0)
	var before: bool = gs.is_exuvia_visible()
	gs.molt_stage = GameStateScript.MoltStage.MOLTED
	var molted: bool = gs.is_exuvia_visible()
	var took: bool = gs.collect_spool()
	var after_pickup: bool = gs.is_exuvia_visible()
	GameClock.elapsed_days = 2.99  # late on day 3
	var late_same_day: bool = gs.is_exuvia_visible()
	GameClock.elapsed_days = 3.0  # the morning of day 4
	var next_morning: bool = gs.is_exuvia_visible()
	GameClock.elapsed_days = saved
	gs.free()
	if before:
		return "No exuvia may show before the first molt."
	if not molted or not took:
		return "A molted enclosure must show the exuvia and give a spool."
	if not after_pickup or not late_same_day:
		return "The exuvia must stay for the rest of the day the spool is taken."
	if next_morning:
		return "The exuvia must be gone on the next morning."
	return ""
