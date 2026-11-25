extends RefCounted
## Tilling changes GameState.tilled_cells only through GameState.till(), and
## the grid shows what GameState says was tilled (co-op groundwork). The
## GameState autoload's tilled cells are saved and restored.


func test_till_records_once_and_signals() -> String:
	var saved: Dictionary = GameState.tilled_cells.duplicate()
	var cell := Vector3i(5, 0, 5)
	GameState.tilled_cells.erase(cell)
	var seen: Array[Vector3i] = []
	var listen: Callable = func(tilled: Vector3i) -> void: seen.append(tilled)
	GameState.soil_tilled.connect(listen)
	var first: bool = GameState.till(cell)
	var second: bool = GameState.till(cell)
	var stored: bool = GameState.tilled_cells.has(cell)
	GameState.soil_tilled.disconnect(listen)
	GameState.tilled_cells = saved
	if not first or second or not stored or seen != [cell]:
		return "Tilling must record and signal a cell once: %s, %s, %s, %s" % [first, second, stored, seen]
	return ""


func test_grid_shows_own_and_other_tilling() -> String:
	var saved: Dictionary = GameState.tilled_cells.duplicate()
	var grid := FarmGrid.new()
	grid._ready()
	var here := Vector3i(0, 0, 0)
	var there := Vector3i(1, 0, 1)
	var not_shown := Vector3i(1, 0, 0)
	var off_plot := Vector3i(50, 0, 50)
	var changed: Array[Vector3i] = []
	grid.tile_changed.connect(func(cell: Vector3i, _tile: int) -> void: changed.append(cell))
	for cell: Vector3i in [here, there, not_shown]:
		GameState.tilled_cells.erase(cell)
		grid.set_cell_item(cell, FarmGrid.Tile.SOIL_UNTILLED)
	var results: Array[int] = [await grid.till_cell(here), await grid.till_cell(here), await grid.till_cell(off_plot)]
	GameState.till(there)  # as another player's rover would
	GameState.tilled_cells[not_shown] = true  # recorded, but the grid shows it untilled
	var shown_result: int = await grid.till_cell(not_shown)
	var shown_item: int = grid.get_cell_item(not_shown)
	var items: Array[int] = [grid.get_cell_item(here), grid.get_cell_item(there), grid.get_cell_item(off_plot)]
	var stored: bool = GameState.tilled_cells.has(here) and not GameState.tilled_cells.has(off_plot)
	grid.free()
	GameState.tilled_cells[off_plot] = true  # a cell no grid holds must not show on the next load
	var reloaded := FarmGrid.new()
	reloaded._ready()
	var reloaded_items: Array[int] = [reloaded.get_cell_item(here), reloaded.get_cell_item(off_plot)]
	reloaded.free()
	GameState.tilled_cells = saved
	var tilled: int = FarmGrid.Tile.SOIL_TILLED
	if results != [FarmGrid.TillResult.TILLED, FarmGrid.TillResult.ALREADY_TILLED, FarmGrid.TillResult.NOT_SOIL]:
		return "Wrong till results: %s" % [results]
	if items != [tilled, tilled, GridMap.INVALID_CELL_ITEM] or not stored:
		return "The grid must show tilled cells, and off-plot cells must stay out: %s" % [items]
	if shown_result != FarmGrid.TillResult.TILLED or shown_item != tilled:
		return "A recorded cell the grid had not shown must till: %s, %s" % [shown_result, shown_item]
	if changed != [here, there, not_shown]:
		return "tile_changed must fire once per tilled cell: %s" % [changed]
	if reloaded_items != [tilled, GridMap.INVALID_CELL_ITEM]:
		return "A reload must show tilled soil and no off-plot cells: %s" % [reloaded_items]
	return ""
