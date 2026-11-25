extends RefCounted
## What the co-op screens say, and the title menu ending a guest's session.

const TitleScript: GDScript = preload("res://scripts/ui/title_menu.gd")


func test_the_strip_says_who_is_in() -> String:
	var nobody: Array[String] = []
	var alone: Array[String] = ["player_1"]
	var both: Array[String] = ["player_1", "player_2"]
	var got: Array[String] = [CoopUI.strip_text(nobody, "player_1", false, false),
		CoopUI.strip_text(alone, "player_1", true, false), CoopUI.strip_text(both, "player_2", false, false)]
	if got[0] != "" or not "WAITING" in got[1] or not "2 PLAYERS, YOU ARE PLAYER 2" in got[2]:
		return "Got %s" % [got]
	if not "TOO BIG" in CoopUI.strip_text(both, "player_1", true, true):
		return "The host must hear that the farm is not shared any more"
	var none_in_bed: Array[String] = []
	if not "PLAYER 1 IS DRIVING" in CoopUI.strip_text(both, "player_2", false, false, none_in_bed, "player_1") \
			or "DRIVING" in CoopUI.strip_text(both, "player_1", true, false, none_in_bed, "player_1"):
		return "The strip must say who else drives"
	var who: String = CoopUI.players_text(both, "player_2")
	return "" if who == "PLAYER 1  HOST\nPLAYER 2  YOU" else "Got %s" % who


func test_the_host_is_told_its_addresses() -> String:
	var two: String = CoopUI.host_text(24711, ["10.0.0.2", "10.0.0.3"])
	var none: String = CoopUI.host_text(24711, [])
	if not "port 24711" in two or not "10.0.0.2 or 10.0.0.3" in two or not "no network" in none:
		return "Got %s and %s" % [two, none]
	for address: String in CoopUI.local_addresses():
		if not address.is_valid_ip_address() or address.begins_with("127."):
			return "Not an address to share: %s" % address
	return ""


func test_the_title_menu_ends_a_guest_s_session() -> String:
	var paused: bool = GameClock.paused
	var speed: float = GameClock.seconds_per_day
	var own_id: String = GameState.local_player_id
	CoopSession._own_id = own_id
	GameState.local_player_id = "player_2"
	FarmCommands.guest = true
	GameClock.seconds_per_day = 5.0
	CoopScenes._note = "Why."
	var title: Control = TitleScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(title)
	var problem: String = ""
	if FarmCommands.guest or GameState.local_player_id != own_id or not GameClock.paused or GameClock.seconds_per_day != GameClock.DEFAULT_SECONDS_PER_DAY:
		problem = "Still a guest, or the host's clock"
	elif title._note.text != "Why." or CoopScenes.take_note() != "":
		problem = "It must say why, once: %s" % title._note.text
	else:
		title._show_join()
		title._address.text = "not an address"
		title._on_join()
		if title._join_button.disabled or title._note.text == "":
			problem = "A bad address must be refused, and another tried"
	title.free()
	CoopSession.leave()
	FarmCommands.guest = false
	GameState.local_player_id = own_id
	GameClock.paused = paused
	GameClock.seconds_per_day = speed
	return problem
