class_name IceRock
extends TunnelRock
## The Ice Caves' rock: TunnelRock, but it follows the caves' depth (TunnelRock's own
## _enter_tree is not edited, so this replaces it, with no super). The hub is the Lava
## hub's grid for now [PLACEHOLDER]; a hub grid of the caves' own is a later PR.


func _enter_tree() -> void:
	# Before any child's _ready: the map is the one the rover is at.
	ZoneDepth.follow(GameState.rover_depth, GameState.world_seed, GameClock.get_day_index(), IceDepth.ZONE)
