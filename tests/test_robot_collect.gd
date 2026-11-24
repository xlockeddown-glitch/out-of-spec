extends RefCounted
## Milestone 5: the robots' COLLECT SPOOL card.

const JobsTest: GDScript = preload("res://tests/test_robot_jobs.gd")
const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")
const ROBOT: String = "TR-1"
const GRIP: String = "robot_grip_torque@TR-1"


## The robot job fixture with an exact robot at Robotics 2.
func _run(body: Callable) -> String:
	return JobsTest.new()._run(func(gs: GameStateScript) -> String:
		for id: String in gs.robot_sensor_ids(ROBOT):
			gs.get_sensor(id).error = 0.0
		gs.farm_skill_xp["robotics"] = gs.xp_for_level(2)
		return body.call(gs))


func _molt(gs: GameStateScript) -> void:
	gs.molt_progress = 1.0
	gs.molt_stage = gs.MoltStage.MOLTED


func test_gates() -> String:
	return _run(_check_gates)


func _check_gates(gs: GameStateScript) -> String:
	gs.farm_skill_xp["robotics"] = gs.xp_for_level(2) - 1
	if gs.add_robot_collect_card(ROBOT) != "COLLECT SPOOL cards need Robotics level 2.":
		return "It needs Robotics 2: %s" % gs.add_robot_collect_card(ROBOT)
	gs.farm_skill_xp["robotics"] = gs.xp_for_level(2)
	var record: Dictionary = gs.last_cal_records[GRIP]
	gs.last_cal_records.erase(GRIP)
	if not gs.add_robot_collect_card(ROBOT).contains("Grip Torque Sensor: not calibrated"):
		return "It needs a calibrated grip: %s" % gs.add_robot_collect_card(ROBOT)
	gs.last_cal_records[GRIP] = record
	gs.set_rover_uplink("rover_1", false)
	if gs.add_robot_collect_card(ROBOT) == "":
		return "No line of sight, no card."
	gs.set_rover_uplink("rover_1", true)
	if gs.add_robot_collect_card("TR-9") == "" or gs.add_robot_card(ROBOT, "spool") == "":
		return "An unknown robot, or the wrong job, takes no spool card."
	if gs.add_robot_collect_card(ROBOT) != "":
		return "It must take the card."
	if gs.robot_card_text(gs.robot_cards(ROBOT)[0]) != "COLLECT SPOOL when it is ready":
		return "The card must say its job."
	if gs.add_robot_card(ROBOT, "clock") != "" or gs.add_robot_collect_card(ROBOT) == "":
		return "Two slots, two cards."
	var data: Dictionary = gs.farm_to_dict()
	if gs.farm_dict_problem(data) != "":
		return "The card must save: %s" % gs.farm_dict_problem(data)
	data["robots"][ROBOT]["cards"][0]["trigger"] = "clock"
	return "" if gs.farm_dict_problem(data) != "" else "A spool card has no other trigger."


func test_collects() -> String:
	return _run(_check_collects)


func _check_collects(gs: GameStateScript) -> String:
	gs.add_robot_collect_card(ROBOT)
	var spools: int = gs.optical_silk_spools
	gs._run_robot_cards()
	if gs.optical_silk_spools != spools or gs.get_sensor(GRIP).error != 0.0:
		return "With no spool ready it does nothing."
	var xp: Array = [gs.farm_skill_xp["robotics"], gs.farm_skill_xp.get("husbandry", 0)]
	_molt(gs)
	gs._run_robot_cards()
	if gs.optical_silk_spools != spools + 1 or gs.is_spool_ready() or gs.molt_progress != 0.0:
		return "It must collect the spool and start the next molt."
	if gs.get_sensor(GRIP).error == 0.0 or gs.get_sensor("robot_joint_encoder@TR-1").error == 0.0 \
			or gs.get_sensor("robot_tank_pressure@TR-1").error != 0.0:
		return "Only the grip and the encoder wear."
	if gs.farm_skill_xp["robotics"] != xp[0] + 1 or gs.farm_skill_xp.get("husbandry", 0) != xp[1]:
		return "A robot's work earns Robotics XP only."
	# Another one can be collected the same day.
	_molt(gs)
	gs._run_robot_cards()
	return "" if gs.optical_silk_spools == spools + 2 else "Each spool is collected as it is ready."


func test_holds() -> String:
	return _run(_check_holds)


func _check_holds(gs: GameStateScript) -> String:
	gs.add_robot_collect_card(ROBOT)
	var grip: DriftingSensor = gs.get_sensor(GRIP)
	grip.error = grip.mpe * 1.1
	var spools: int = gs.optical_silk_spools
	_molt(gs)
	gs._run_robot_cards()
	if gs.optical_silk_spools != spools or not gs.is_spool_ready():
		return "A robot with a bad grip holds."
	gs.set_interlock_override(ROBOT, true)
	gs._run_robot_cards()
	return "" if gs.optical_silk_spools == spools + 1 else "With the interlock overridden it collects."
