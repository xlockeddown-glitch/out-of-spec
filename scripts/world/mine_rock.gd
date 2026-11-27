class_name MineRock
extends TunnelRock
## The Colony Mine's rock: TunnelRock, but it follows the Mine's depth. TunnelRock's own
## _enter_tree only knows the Lava Tubes and the Aquifer, and it is not edited here, so
## this replaces it (no super: that would follow the Lava Tubes). The hub is the Lava
## hub's grid for now [PLACEHOLDER]; a hub grid of the Mine's own is a later PR.


func _enter_tree() -> void:
	# Before any child's _ready: the map is the one the rover is at.
	ZoneDepth.follow(GameState.rover_depth, GameState.world_seed, GameClock.get_day_index(), MineDepth.ZONE)
