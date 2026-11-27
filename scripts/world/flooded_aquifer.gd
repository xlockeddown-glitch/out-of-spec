class_name FloodedAquifer
extends "res://scripts/basalt_tunnels.gd"
## The Flooded Aquifer's scene (zones step 13): the Lava Tubes' scene with the Aquifer's
## hub (wet rock and a pool, the way up, a notice board sign, the hatch down, the pump's
## crate) and its one depth (rooms, finds, pools). Built in code from primitives; the
## rules are AquiferDepth's and the host's. A look [PLACEHOLDER]: no art yet.

const CRATE: String = "crate"
const SIGN: String = "sign"
const POOL: String = "pool"

## Pool water & silt material parameters [PLACEHOLDER].
const SHALLOW_ALPHA: float = 0.68
const DEEP_ALPHA: float = 0.88
const SHALLOW_ROUGHNESS: float = 0.25
const DEEP_ROUGHNESS: float = 0.18
const SILT_ROUGHNESS: float = 0.72
const HUB_POOL_LIGHT_ENERGY: float = 0.6
const HUB_POOL_LIGHT_RANGE_M: float = 8.0

## The pools drained when this scene was built; the pump changing them builds it again.
var _built_drained: Array = []
var _water: Node3D


func _zone_id() -> String:
	return AquiferDepth.ZONE


func _build_zone() -> void:
	_below = ZoneDepth.local_depth > 0 and not ZoneDepth.local_layout.is_empty()
	_built_depth = ZoneDepth.local_depth if _below else 0
	_built_day = GameClock.get_day_index()
	_built_drained = AquiferDepth.drained_today(GameState.pools_drained, _built_day)
	GameClock.day_started.connect(_on_new_day)
	_depth_props = ZoneDepthProps.new()
	_rover.get_parent().add_child(_depth_props)
	_water = Node3D.new()
	_water.name = "Water"
	_rover.get_parent().add_child(_water)
	if _below:
		_depth_props.build_finds(ZoneDepth.local_layout, _taken_today())
		for pool: Dictionary in ZoneDepth.local_layout.get("pools", []):
			_draw_pool(pool, str(pool["id"]))
		GameState.finds_changed.connect(_on_finds_changed)
	else:
		_depth_props.build_hatch()
		_draw_pool({ "rect": AquiferDepth.HUB_POOL, "depth_m": AquiferDepth.DEEP_M[1], "drained": false }, "")
		_draw_crate()
		_draw_sign()


## Deterministic integer hash from cell/pool coordinates (no global RNG) [PLACEHOLDER].
static func _hash(x: int, y: int, salt: int = 0) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = ((h >> 16) ^ h) * 0x45d9f3b
	return absi((h >> 16) ^ h)


## A pool: translucent cold water (brighter shallow vs dark deep) or damp silt
## when drained, framed by wet-stone & ice rims and nearby frost patches. Pure
## looks; each pool gets its own unique surface material so draining or mutating
## one pool never leaks into another pool or TunnelLook's shared cache.
func _draw_pool(pool: Dictionary, pool_id: String) -> void:
	var box: Rect2 = AquiferDepth.pool_metres(pool)
	var rect: Rect2i = pool["rect"]
	var drained: bool = bool(pool["drained"])
	var shallow: bool = AquiferDepth.is_shallow(pool)
	var centre: Vector2 = box.get_center()

	var material: StandardMaterial3D
	if drained:
		material = TunnelLook.flat_mat_unique(TunnelLook.SILT, SILT_ROUGHNESS)
	elif shallow:
		material = TunnelLook.flat_mat_unique(TunnelLook.WATER_SHALLOW, SHALLOW_ROUGHNESS)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = SHALLOW_ALPHA
	else:
		material = TunnelLook.flat_mat_unique(TunnelLook.WATER_DEEP, DEEP_ROUGHNESS)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = DEEP_ALPHA

	var slab: MeshInstance3D = TunnelLook.part(TunnelLook.box(Vector3(box.size.x, 0.05, box.size.y)),
			Vector3(centre.x, 0.03, centre.y), material)
	slab.name = "Pool_" + pool_id
	_water.add_child(slab)

	var trim := Node3D.new()
	trim.name = "PoolTrim_" + pool_id
	_water.add_child(trim)
	_add_pool_rim(trim, box, rect)
	_add_pool_bed_detail(trim, box, rect, drained, shallow)
	_add_pool_frost(trim, box, rect)

	if pool_id == "":
		var glow := OmniLight3D.new()
		glow.name = "PoolGlow"
		glow.position = Vector3(centre.x, 1.4, centre.y)
		glow.light_color = TunnelLook.FROST
		glow.light_energy = HUB_POOL_LIGHT_ENERGY
		glow.omni_range = HUB_POOL_LIGHT_RANGE_M
		trim.add_child(glow)
	else:
		var text: String = "%s %s" % [pool_id.to_upper(), "DRAINED" if drained else ("WADE" if shallow else "DEEP")]
		_water.add_child(TunnelLook.label(text, Vector3(centre.x, 1.3, centre.y), TunnelLook.CRYSTAL))


## Stepped wet-stone and ice curbing hugging the four edges of a pool [PLACEHOLDER].
func _add_pool_rim(parent: Node3D, box: Rect2, rect: Rect2i) -> void:
	var wet_mat: Material = TunnelLook.flat_mat(TunnelLook.WET_STONE)
	var ice_mat: Material = TunnelLook.flat_mat(TunnelLook.FROST)
	var dark_mat: Material = TunnelLook.flat_mat(TunnelLook.BASALT_DARK)
	var step_m: float = 1.15
	var rim_w: float = 0.24
	var idx: int = 0

	# North & south edges.
	var cols: int = maxi(int(round(box.size.x / step_m)), 2)
	var seg_x: float = box.size.x / float(cols)
	for side: float in [-1.0, 1.0]:
		var z: float = box.get_center().y + side * (box.size.y * 0.5 + rim_w * 0.35)
		for i: int in cols:
			var h_val: int = _hash(rect.position.x + i, rect.position.y + int(side), idx)
			idx += 1
			var x: float = box.position.x + (float(i) + 0.5) * seg_x
			var height: float = 0.07 + float(h_val % 4) * 0.02
			var mat: Material = ice_mat if (h_val % 3 == 0) else (wet_mat if (h_val % 3 == 1) else dark_mat)
			parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(seg_x * 0.92, height, rim_w)),
					Vector3(x, height * 0.5, z), mat))

	# West & east edges.
	var rows: int = maxi(int(round(box.size.y / step_m)), 2)
	var seg_z: float = box.size.y / float(rows)
	for side: float in [-1.0, 1.0]:
		var x: float = box.get_center().x + side * (box.size.x * 0.5 + rim_w * 0.35)
		for j: int in rows:
			var h_val: int = _hash(rect.position.x + int(side), rect.position.y + j, 100 + idx)
			idx += 1
			var z: float = box.position.y + (float(j) + 0.5) * seg_z
			var height: float = 0.07 + float(h_val % 4) * 0.02
			var mat: Material = ice_mat if (h_val % 3 == 0) else wet_mat
			parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(rim_w, height, seg_z * 0.92)),
					Vector3(x, height * 0.5, z), mat))


## Surface & bed details that differentiate drained silt, shallow wading, and deep water [PLACEHOLDER].
func _add_pool_bed_detail(parent: Node3D, box: Rect2, rect: Rect2i, drained: bool, shallow: bool) -> void:
	var centre: Vector2 = box.get_center()
	if drained:
		var mud_mat: Material = TunnelLook.flat_mat(TunnelLook.SILT_DARK)
		var pebble_mat: Material = TunnelLook.flat_mat(TunnelLook.WET_STONE)
		var ice_mat: Material = TunnelLook.flat_mat(TunnelLook.ICE)
		for i: int in 5:
			var hx: int = _hash(rect.position.x, rect.position.y, 200 + i * 2)
			var hz: int = _hash(rect.position.x, rect.position.y, 201 + i * 2)
			var ox: float = (float(hx % 100) / 100.0 - 0.5) * (box.size.x - 1.0)
			var oz: float = (float(hz % 100) / 100.0 - 0.5) * (box.size.y - 1.0)
			var w: float = 0.55 + float(hx % 5) * 0.14
			var d: float = 0.45 + float(hz % 5) * 0.12
			parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(w, 0.03, d)),
					Vector3(centre.x + ox, 0.055, centre.y + oz), mud_mat))
			if i < 3:
				var p_mat: Material = ice_mat if i == 0 else pebble_mat
				parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.24, 0.08, 0.22)),
						Vector3(centre.x - ox * 0.7, 0.07, centre.y - oz * 0.7), p_mat, Vector3(0.0, float(hx % 45), 0.0)))
	elif shallow:
		var stone_mat: Material = TunnelLook.flat_mat(TunnelLook.WET_STONE)
		var mid_mat: Material = TunnelLook.flat_mat(TunnelLook.BASALT_MID)
		for i: int in 4:
			var hx: int = _hash(rect.position.x, rect.position.y, 300 + i * 2)
			var hz: int = _hash(rect.position.x, rect.position.y, 301 + i * 2)
			var ox: float = (float(hx % 100) / 100.0 - 0.5) * (box.size.x - 1.2)
			var oz: float = (float(hz % 100) / 100.0 - 0.5) * (box.size.y - 1.2)
			var mat: Material = stone_mat if (i % 2 == 0) else mid_mat
			parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.58, 0.03, 0.48)),
					Vector3(centre.x + ox, 0.015, centre.y + oz), mat, Vector3(0.0, float(hx % 30), 0.0)))
	else:
		# Deep basin dark liner + faint cold inner contour to read as deep water [PLACEHOLDER].
		var liner_w: float = maxf(box.size.x - 0.5, 0.5)
		var liner_d: float = maxf(box.size.y - 0.5, 0.5)
		parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(liner_w, 0.02, liner_d)),
				Vector3(centre.x, 0.008, centre.y), TunnelLook.flat_mat(TunnelLook.BASALT_DARK)))
		parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(liner_w * 0.72, 0.015, liner_d * 0.72)),
				Vector3(centre.x, 0.014, centre.y), TunnelLook.flat_mat(TunnelLook.WATER_DEEP.darkened(0.35))))


## Thin frost and rime plates clinging to the rock floor just outside the pool rim [PLACEHOLDER].
func _add_pool_frost(parent: Node3D, box: Rect2, rect: Rect2i) -> void:
	var frost_mat: Material = TunnelLook.flat_mat(TunnelLook.FROST)
	var ice_mat: Material = TunnelLook.flat_mat(TunnelLook.ICE)
	var centre: Vector2 = box.get_center()
	for i: int in 6:
		var h: int = _hash(rect.position.x, rect.position.y, 400 + i)
		var edge: int = i % 4
		var t: float = (float((h >> 3) % 80) / 100.0) - 0.4
		var out: float = 0.34 + float(h % 4) * 0.11
		var px: float = centre.x
		var pz: float = centre.y
		if edge == 0:
			px += t * box.size.x
			pz -= box.size.y * 0.5 + out
		elif edge == 1:
			px += t * box.size.x
			pz += box.size.y * 0.5 + out
		elif edge == 2:
			px -= box.size.x * 0.5 + out
			pz += t * box.size.y
		else:
			px += box.size.x * 0.5 + out
			pz += t * box.size.y
		var w: float = 0.44 + float((h >> 6) % 4) * 0.14
		var d: float = 0.36 + float((h >> 9) % 4) * 0.12
		var mat: Material = frost_mat if (i % 2 == 0) else ice_mat
		parent.add_child(TunnelLook.part(TunnelLook.box(Vector3(w, 0.025, d)),
				Vector3(px, 0.014, pz), mat, Vector3(0.0, float(h % 35) - 17.0, 0.0)))


## The crate that sells the pump: pallet skids, steel-framed regolith crate,
## brass collar, coiled rubber hose, pressure gauge, and label [PLACEHOLDER].
func _draw_crate() -> void:
	var crate := Node3D.new()
	crate.name = "PumpCrate"
	crate.position = AquiferDepth.crate_position()
	_depth_props.add_child(crate)
	var dark_mat: Material = TunnelLook.flat_mat(TunnelLook.BASALT_DARK)
	var steel_mat: Material = TunnelLook.flat_mat(TunnelLook.STEEL)
	var body_mat: Material = TunnelLook.flat_mat(TunnelLook.REGOLITH)
	var wood_mat: Material = TunnelLook.flat_mat(TunnelLook.TIMBER)
	var brass_mat: Material = TunnelLook.flat_mat(TunnelLook.BRASS)
	var hose_mat: Material = TunnelLook.flat_mat(TunnelLook.HOSE)
	var cream_mat: Material = TunnelLook.flat_mat(TunnelLook.CREAM)

	# Pallet base & runners.
	for z_off: float in [-0.36, 0.36]:
		crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.38, 0.08, 0.16)), Vector3(0.0, 0.04, z_off), dark_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.42, 0.06, 1.04)), Vector3(0.0, 0.11, 0.0), wood_mat))

	# Main crate housing + corner steel frame posts + brass band.
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.16, 0.78, 0.84)), Vector3(0.0, 0.53, 0.0), body_mat))
	for sx: float in [-0.57, 0.57]:
		for sz: float in [-0.41, 0.41]:
			crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.10, 0.84, 0.10)), Vector3(sx, 0.54, sz), steel_mat))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.26, 0.10, 0.94)), Vector3(0.0, 0.62, 0.0), TunnelLook.glow_mat(TunnelLook.BRASS, 0.5)))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(1.22, 0.08, 0.90)), Vector3(0.0, 0.96, 0.0), steel_mat))

	# Coiled pump hose resting on the crate top with a brass coupling.
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.28, 0.08), Vector3(-0.22, 1.04, 0.0), hose_mat))
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.24, 0.08), Vector3(-0.22, 1.11, 0.0), hose_mat))
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.12, 0.16), Vector3(-0.22, 1.08, 0.0), dark_mat))
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.06, 0.18), Vector3(0.04, 1.08, 0.16), brass_mat, Vector3(0.0, 0.0, 90.0)))

	# Pressure gauge on a brass stem.
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.04, 0.22), Vector3(0.34, 1.10, 0.18), brass_mat))
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.13, 0.06), Vector3(0.34, 1.24, 0.18), brass_mat, Vector3(90.0, 0.0, 0.0)))
	crate.add_child(TunnelLook.part(TunnelLook.cylinder(0.10, 0.07), Vector3(0.34, 1.24, 0.18), cream_mat, Vector3(90.0, 0.0, 0.0)))
	crate.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.03, 0.09, 0.08)), Vector3(0.35, 1.26, 0.18), TunnelLook.flat_mat(TunnelLook.CRYSTAL), Vector3(0.0, 0.0, -28.0)))

	crate.add_child(TunnelLook.label("PUMP CRATE", Vector3(0.0, 1.65, 0.0), TunnelLook.CRYSTAL))


## The notice board sign: matches the Lava hub's notice board with a light coat
## of Aquifer frost on the cap and footplates. Vance's notice is for later [PLACEHOLDER].
func _draw_sign() -> void:
	var board: Node3D = LavaHubProps.board_node("Vance: [later]")
	board.name = "NoticeSign"
	board.position = AquiferDepth.sign_position()
	_depth_props.add_child(board)
	var frost_mat: Material = TunnelLook.flat_mat(TunnelLook.FROST)
	board.add_child(TunnelLook.part(TunnelLook.box(Vector3(2.04, 0.04, 0.18)), Vector3(0.0, 1.74, 0.0), frost_mat))
	for x: float in [-0.82, 0.82]:
		board.add_child(TunnelLook.part(TunnelLook.box(Vector3(0.34, 0.03, 0.34)), Vector3(x, 0.018, 0.0), frost_mat))


func _process(_delta: float) -> void:
	_resync_depth()
	_hud.set_clock(GameClock.format_now())
	_hud.set_molt(GameState.molt_text() if GameState.has_skill_unlock("molt_on_phone") else "")
	_in_reach = false  # no Sentinel here
	_hub_near = _aquifer_near() if _rover.away_text() == "" else {}
	_tell_hub()


## The way down, the crate or the sign at the hub; below, the nearest find, else the
## nearest pool still full: or {}.
func _aquifer_near() -> Dictionary:
	var at: Vector3 = _rover.global_position
	if not _below:
		if AquiferDepth.near_hatch(at):
			return { "kind": HATCH, "id": "" }
		if AquiferDepth.near_crate(at):
			return { "kind": CRATE, "id": "" }
		if AquiferDepth.near_sign(at):
			return { "kind": SIGN, "id": "" }
		return {}
	var found: Dictionary = _nearest_find()
	if not found.is_empty():
		return found
	for pool: Dictionary in ZoneDepth.local_layout.get("pools", []):
		if not bool(pool["drained"]) and AquiferDepth.pool_gap_m(pool, at) <= AquiferDepth.PUMP_REACH_M:
			return { "kind": POOL, "id": str(pool["id"]) }
	return {}


func _tell_hub() -> void:
	var key: String = "%s:%s" % [_hub_near.get("kind", ""), _hub_near.get("id", "")] if not _hub_near.is_empty() else ""
	if key == _told_hub:
		return
	_told_hub = key
	match _hub_near.get("kind", ""):
		HATCH:
			_hud.push_log("WAY DOWN: press " + Controls.prompt(&"interact") + " to go down.")
		FIND:
			_hud.push_log("FIND: press " + Controls.prompt(&"interact") + " to take it.")
		CRATE:
			_hud.push_log("PUMP CRATE: %s. Press %s to %s." % [
				"the farm has the pump" if GameState.pump_owned else "a pump costs %d credits" % AquiferDepth.PUMP_COST_CREDITS,
				Controls.prompt(&"interact"), "check it" if GameState.pump_owned else "buy it"])
		SIGN:
			_hud.push_log("NOTICE SIGN: press " + Controls.prompt(&"interact") + " to read it.")
		POOL:
			_hud.push_log("POOL: press " + Controls.prompt(&"interact") + " to pump it dry for today.")


func _use_hub(target: Dictionary) -> void:
	match target["kind"]:
		CRATE:
			_use_crate()
		SIGN:
			_hud.push_log("NOTICE SIGN: Vance: [later]")
		POOL:
			_use_pump(str(target["id"]))
		_:
			super._use_hub(target)


func _use_crate() -> void:
	if GameState.pump_owned:
		_hud.push_log("PUMP CRATE: the farm has the pump already. Use it at a pool.")
		return
	var problem: String = await FarmCommands.request(&"buy_pump", [])
	if not is_inside_tree():
		return
	_told_hub = ""
	_hud.push_log("PUMP CRATE: " + (problem if problem != "" else "the farm bought a pump for %d credits." % AquiferDepth.PUMP_COST_CREDITS))


func _use_pump(pool_id: String) -> void:
	var problem: String = await FarmCommands.request(&"use_pump", [pool_id, int(ZoneDepth.local_layout.get("day", 0))])
	if not is_inside_tree():
		return
	_hud.push_log("PUMP: " + (problem if problem != "" else "%s drained for today." % pool_id.to_upper()))


func _taken_today() -> Array:
	return ZoneDepth.taken_today(GameState.finds_taken, AquiferDepth.ZONE, GameClock.get_day_index())


func _use_find(find_id: String) -> void:
	var problem: String = await FarmCommands.request(&"take_find", [find_id, int(ZoneDepth.local_layout.get("day", 0))])
	if not is_inside_tree():
		return
	if problem != "":
		_hud.push_log("FIND: " + problem)
		return
	var find: Dictionary = ZoneDepth.find_in(ZoneDepth.local_layout, find_id)
	_hud.push_log("FIND: " + AquiferDepth.reward_text(str(find.get("kind", ""))))


## The pump drained a pool (here or by a friend), so this depth is built again with the
## rover where it is.
func _resync_depth() -> void:
	super._resync_depth()
	if _below and not SceneSwitcher.is_busy() and GameState.rover_zone == AquiferDepth.ZONE and _rover.away_text() == "" and not _moving:
		var now: Array = AquiferDepth.drained_today(GameState.pools_drained, _built_day)
		if now.size() != _built_drained.size() or now.any(func(id: Variant) -> bool: return not id in _built_drained):
			_moving = true
			ZoneDepth.arrive_at = _rover.global_transform
			ZoneDepth.arrive_pending = true
			SceneSwitcher.swap_to(SceneSwitcher.AQUIFER_SCENE)


func _on_rover_entered_exit() -> void:
	_hud.push_log("WAY UP: press " + Controls.prompt(&"interact") + " to go up." if _below else "SINKHOLE: press " + Controls.prompt(&"interact") + " to climb out.")


## Takes the rover up the sinkhole and goes with it.
func _leave_tunnels() -> void:
	if _moving:
		return
	_moving = true
	if not GameState.rover_lent:
		# A field rover (the dome console's): the way home is the dome.
		var left: String = await FarmCommands.request(&"leave_zone")
		if not is_inside_tree():
			return
		if left != "":
			_moving = false
			_hud.push_log("SINKHOLE: " + left)
			return
		SceneSwitcher.outside = SceneSwitcher.FARM_SCENE
		SceneSwitcher.go_to(SceneSwitcher.DOME_SCENE)
		return
	var problem: String = await FarmCommands.request(&"move_rover_aquifer", [false])
	if not is_inside_tree():
		return
	if problem != "":
		_moving = false
		_hud.push_log("SINKHOLE: " + problem)
		return
	_move_granted = true
	_on_rover_place_changed()
