class_name Ford
extends Node3D
## The wash's water on the arch hill. Terrain cuts the bed; this draws the water
## and stops a rover at the deep part. A rover wades the shallows. The same on every
## PC, so nothing of it is saved or sent.

## The blocks that stop a rover are this wide [PLACEHOLDER].
const BLOCK_M: float = 0.5
## They reach from this far below the water to this far above it, so they stop a
## wheel at the water's edge but not the signal [PLACEHOLDER].
const BLOCK_BELOW_M: float = 1.0
const BLOCK_ABOVE_M: float = 0.8
const LAYER_WORLD: int = 1


## The wash's ellipse's box.
static func area() -> Rect2:
	return Rect2(Terrain.WASH_AT - Terrain.WASH_RADII, Terrain.WASH_RADII * 2.0)


## The natural ground in the wash; no water anywhere else.
static func ground_m(at: Vector2) -> float:
	var none: Dictionary[Vector2i, int] = {}
	return Terrain.height(at, none) if Terrain.wash_out(at) < 1.0 else INF


func _ready() -> void:
	var water := VoxelWater.new()
	water.name = "Water"
	water.fill(area(), Terrain.WASH_LEVEL_M, ground_m)
	add_child(water)
	_build_blocks()


## One box for each run along x of deep blocks.
func _build_blocks() -> void:
	var box: Rect2 = area()
	var height_m: float = BLOCK_BELOW_M + BLOCK_ABOVE_M
	for z: int in ceili(box.size.y / BLOCK_M):
		var x: int = 0
		var across: int = ceili(box.size.x / BLOCK_M)
		while x < across:
			if not _is_deep_block(box, x, z):
				x += 1
				continue
			var run: int = 1
			while x + run < across and _is_deep_block(box, x + run, z):
				run += 1
			var shape := BoxShape3D.new()
			shape.size = Vector3(run * BLOCK_M, height_m, BLOCK_M)
			var holder := CollisionShape3D.new()
			holder.shape = shape
			var body := StaticBody3D.new()
			body.name = "Deep"
			body.collision_layer = LAYER_WORLD
			body.collision_mask = 0
			body.position = Vector3(
				box.position.x + (x + run * 0.5) * BLOCK_M, Terrain.WASH_LEVEL_M + (BLOCK_ABOVE_M - BLOCK_BELOW_M) * 0.5, box.position.y + (z + 0.5) * BLOCK_M
			)
			body.add_child(holder)
			add_child(body, true)
			x += run


## A block stands where its middle or any corner is deep, so no deep water is left
## uncovered.
func _is_deep_block(box: Rect2, x: int, z: int) -> bool:
	for dx: float in [0.0, 0.5, 1.0]:
		for dz: float in [0.0, 0.5, 1.0]:
			if Terrain.is_deep(box.position + (Vector2(x + dx, z + dz)) * BLOCK_M):
				return true
	return false
