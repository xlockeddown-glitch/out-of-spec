extends RefCounted


func test_before_morning_belongs_to_the_same_game_day() -> String:
	if not is_equal_approx(GameClock.elapsed_at_hour(1, 0.0), 0.75):
		return "Midnight on day one must be 18 hours after its morning."
	if not is_equal_approx(GameClock.elapsed_at_hour(3, 2.0), 2.0 + 20.0 / 24.0):
		return "The 02:00 on day three must be 20 hours after its morning."
	return ""


func test_morning_and_later_hours() -> String:
	if not is_equal_approx(GameClock.elapsed_at_hour(3, 6.0), 2.0):
		return "Day three begins at 06:00, exactly two elapsed days in."
	if not is_equal_approx(GameClock.elapsed_at_hour(3, 18.0), 2.5):
		return "The 18:00 on day three must be half a day after its morning."
	return ""


func test_every_exact_minute_shows() -> String:
	var saved: float = GameClock.elapsed_days
	var problem: String = ""
	for day: int in [1, 7, 365]:
		for minute: int in 24 * 60:
			GameClock.elapsed_days = GameClock.elapsed_at_hour(day, minute / 60.0)
			@warning_ignore("integer_division")
			var want: String = "DAY %d  %02d:%02d" % [day, minute / 60, minute % 60]
			if GameClock.format_now() != want:
				problem = "Want %s, got %s" % [want, GameClock.format_now()]
	GameClock.elapsed_days = saved
	return problem
