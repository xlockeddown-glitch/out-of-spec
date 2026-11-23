extends RefCounted
## Rovers change shared state only through GameState functions (co-op groundwork).

const GameStateScript: GDScript = preload("res://scripts/autoload/GameState.gd")


func test_parked_rovers_are_kept_apart() -> String:
	var gs: GameStateScript = GameStateScript.new()
	var spawn := Transform3D(Basis.IDENTITY, Vector3(9.0, 0.0, 9.0))
	var first := Transform3D(Basis.from_euler(Vector3(0.0, 1.0, 0.0)), Vector3(1.0, 2.0, 3.0))
	var before: Transform3D = gs.parked_rover_transform("rover_1", spawn)
	gs.park_rover("rover_1", first)
	var parked: Transform3D = gs.parked_rover_transform("rover_1", spawn)
	var second: Transform3D = gs.parked_rover_transform("rover_2", spawn)
	gs.free()
	if before != spawn:
		return "A rover never parked must stay where its scene puts it, got %s" % before
	if parked != first:
		return "A parked rover must come back where it was, got %s" % parked
	if second != spawn:
		return "Parking one rover must not move another, got %s" % second
	return ""


func test_driving_wears_steering_and_in_service_tires() -> String:
	var gs: GameStateScript = GameStateScript.new()
	gs.build_registry()
	var tire: DriftingSensor = gs.get_sensor(gs.TIRE_ID)
	var steering_before: float = gs.steering.error
	var tire_before: float = tire.error
	gs.add_rover_usage(1000.0)
	var steering_moved: bool = gs.steering.error != steering_before
	var tire_out_of_service_moved: bool = tire.error != tire_before
	gs.owned_standards["reference_gauge"] = true
	gs.add_rover_usage(1000.0)
	var in_service: bool = gs.is_in_service(gs.TIRE_ID)
	var tire_moved: bool = tire.error != tire_before
	gs.free()
	if not steering_moved:
		return "Driving must wear the steering encoder."
	if tire_out_of_service_moved:
		return "The tire gauge must not wear before it is in service."
	if not in_service or not tire_moved:
		return "Driving must wear the tire gauge once it is in service."
	return ""
