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
