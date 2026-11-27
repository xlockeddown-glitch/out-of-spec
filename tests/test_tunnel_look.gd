extends RefCounted
## Lava Tubes hub and depth props look (feat/tunnel-props-look): builds
## LavaHubProps and ZoneDepthProps, verifies every named node the game uses
## still exists at the right spot, and frees everything cleanly.


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func test_lava_hub_props_keeps_all_named_nodes_and_adds_tunnel_details() -> String:
	var hub := LavaHubProps.new()
	_root().add_child(hub)
	var problem: String = ""
	var rack: Node = hub.get_node_or_null("BeaconRack")
	var beacons: Node = hub.get_node_or_null("BeaconRack/Beacons")
	var board: Node = hub.get_node_or_null("NoticeBoard")
	if rack == null or beacons == null or board == null:
		problem = "Hub is missing BeaconRack, Beacons, or NoticeBoard."
	elif board.get_node_or_null("SupportArch") == null:
		problem = "Hub NoticeBoard should include a SupportArch accent."
	elif rack.get_node_or_null("RubblePile") == null:
		problem = "Hub BeaconRack should include a RubblePile accent."
	else:
		for spot_id: String in LavaHub.spot_ids():
			var spot: Node3D = hub.spot_node(spot_id)
			if spot == null or spot.name != "Spot_" + spot_id:
				problem = "Missing hub beacon spot '%s'." % spot_id
				break
			if spot.position != LavaHub.spot_position(spot_id):
				problem = "Spot '%s' moved from %s to %s." % [spot_id, LavaHub.spot_position(spot_id), spot.position]
				break
	if problem == "":
		hub.show_placed([LavaHub.spot_ids()[0]])
		var placed_spot: Node3D = hub.spot_node(LavaHub.spot_ids()[0])
		if placed_spot.get_child_count() < 4:
			problem = "Placed beacon spot should build plinth, mast, cap, and light."
	_free(hub)
	return problem


func test_zone_depth_props_keeps_hatch_lift_finds_and_vents() -> String:
	var props := ZoneDepthProps.new()
	_root().add_child(props)
	var problem: String = ""
	props.build_hatch(0)
	props.build_lift(1, false)
	var hatch: Node3D = props.get_node_or_null("Hatch") as Node3D
	var broken_lift: Node3D = props.get_node_or_null("Lift") as Node3D
	if hatch == null or hatch.position != ZoneDepth.descent_position(0):
		problem = "Hatch missing or moved."
	elif hatch.get_node_or_null("SupportArch") == null:
		problem = "Hatch should have a SupportArch over its mouth."
	elif broken_lift == null or broken_lift.get_node_or_null("RubblePile") == null:
		problem = "Broken lift should show a RubblePile accent."
	if problem == "":
		props.build_lift(1, true)
		var repaired_lift: Node3D = props.get_node_or_null("Lift") as Node3D
		if repaired_lift == null or repaired_lift.position != ZoneDepth.lift_position(1):
			problem = "Repaired lift missing or moved."
	if problem == "":
		var layout_data: Dictionary = {
			"finds": [
				{ "id": "f_ore", "kind": "ore", "cell": Vector2i(1, 1) },
				{ "id": "f_min", "kind": "mineral", "cell": Vector2i(2, 1) },
				{ "id": "f_sam", "kind": "sample", "cell": Vector2i(3, 1) },
			],
		}
		props.build_finds(layout_data, ["f_min"])
		if props.find_node("f_ore") == null or not props.find_node("f_ore").visible:
			problem = "Untaken ore find must exist and be visible."
		elif props.find_node("f_min") == null or props.find_node("f_min").visible:
			problem = "Taken mineral find must exist and be hidden."
		elif props.find_node("f_sam") == null or not props.find_node("f_sam").visible:
			problem = "Untaken sample find must exist and be visible."
	if problem == "":
		var vents: Array = [{ "id": "v1", "cell": Vector2i(4, 1), "period": 0.1, "phase": 0.0 }]
		props.build_vents(vents)
		var vent_node: Node3D = props.get_node_or_null("Vent_v1") as Node3D
		if vent_node == null or vent_node.position != TunnelRock.at(Vector2i(4, 1)):
			problem = "Vent_v1 missing or moved."
		else:
			props.show_heat(0.0)
	_free(props)
	return problem


func test_lava_hub_material_helpers_hand_out_fresh_materials() -> String:
	# Other scenes (FloodedAquifer's pools) change the material they get back, so
	# LavaHubProps._flat/_glow must never return TunnelLook's shared cache.
	var a: StandardMaterial3D = LavaHubProps._flat(TunnelLook.REGOLITH)
	var b: StandardMaterial3D = LavaHubProps._flat(TunnelLook.REGOLITH)
	if a == b or a == TunnelLook.flat_mat(TunnelLook.REGOLITH):
		return "_flat handed out a shared material."
	if LavaHubProps._glow(TunnelLook.BRASS, 0.6) == LavaHubProps._glow(TunnelLook.BRASS, 0.6):
		return "_glow handed out a shared material."
	return ""
