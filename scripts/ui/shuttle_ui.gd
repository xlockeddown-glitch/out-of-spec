class_name ShuttleUI
extends Control
## The landing pad terminal's panel (biomes.md section 6 step 12): one launch
## window line for each moon, the fare, whether the farm holds the shuttle license
## the party that would fly (everyone on the farm at the terminal, GameState.shuttle_party)
## with the total fare, and a Book button for each moon. A press sends `book_shuttle` with
## that party's size and shows the reason it came back with. A booking that goes through (Phobos or Deimos) takes
## this screen to the moon's hub at once. It looks like FastTravelUI. Esc closes it.

const TEAL: Color = SkillsUI.TEAL
const TEXT: Color = SkillsUI.TEXT
const DIM: Color = SkillsUI.DIM
## How often the open panel looks at who is at the terminal, in seconds.
const WATCH_S: float = 0.5

var _lines: VBoxContainer
var _status: Label
var _close_button: Button
var _focus_before: Control
var _busy: bool = false
## The party the panel last drew (player ids, this player first): what Book sends.
var _party_ids: Array[String] = []
var _watch: float = 0.0
## The expedition section (zones step 18): its lines, and the Book button with the total it shows.
var _exp_lines: VBoxContainer
var _exp_book: Button
## The total the section last showed: what Book sends, so the host can refuse a changed price.
var _exp_total: int = 0
## Where a booked screen goes; only tests set it (the real swap would change the scene).
var change_scene: Callable = Callable()


## The panel's lines for a farm at `elapsed_days`: a window line for each moon, the
## fare, the party (`others`: the names of the other people who would fly) with the
## total fare, then the license line. Tests and the panel both use this.
## The expedition section for `people` flying at `elapsed_days` ({ lines, problem, total }):
## the length and the return day, the whole cost split, and why it can't be booked (""
## when it can). It is shown before Book, so the price is never a surprise. The host
## checks again; this is the same rule (Shuttle.expedition_problem) with this copy's data.
static func expedition_view(elapsed_days: float, people: int) -> Dictionary:
	var out: Array[String] = []
	var back: float = Shuttle.expedition_end(elapsed_days)
	out.append(Shuttle.text("terminal_exp_plan") % [SP811.integer(Shuttle.expedition_nights()), SP811.integer(floori(back) + 1), Shuttle.clock_text(back)])
	var cost: Dictionary = GameState.expedition_cost(people)
	var held: int = GameState.camp_supplies
	out.append(Shuttle.text("terminal_exp_cost") % [SP811.integer(int(cost["fare"])), SP811.integer(Shuttle.fare()), SP811.integer(people),
		SP811.integer(int(cost["supplies"])), SP811.integer(int(cost["needed"])), SP811.integer(held), SP811.integer(int(cost["total"]))])
	var permit: String = "expedition_permit"
	var problem: String = Shuttle.expedition_problem(Shuttle.DEIMOS, GameState.lab_level(), GameState.shuttle_licensed, GameState.credits, people,
		elapsed_days, ZoneData.is_playable(&"deimos"), GameState.lab_gate_level(permit), GameState.lab_gate_open(permit),
		GameState.expedition_quest_taken(GameState.local_player_id), held)
	if problem != "":
		out.append(problem)
	return { "lines": out, "problem": problem, "total": int(cost["total"]) }


static func lines(elapsed_days: float, licensed: bool, others: Array[String] = []) -> Array[String]:
	var out: Array[String] = []
	for moon: String in Shuttle.MOONS:
		out.append(Shuttle.window_line(moon, elapsed_days))
	out.append(Shuttle.text("terminal_fare") % SP811.integer(Shuttle.fare()))
	if others.is_empty():
		out.append(Shuttle.text("terminal_party_alone"))
	else:
		out.append(Shuttle.text("terminal_party") % [SP811.integer(others.size() + 1), " and ".join(others)])
	out.append(Shuttle.text("terminal_total") % SP811.integer(Shuttle.fare() * (others.size() + 1)))
	out.append(Shuttle.text("terminal_licensed") if licensed else Shuttle.text("terminal_unlicensed"))
	return out


func _ready() -> void:
	add_to_group(QuestsUI.MODAL_GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.add_theme_stylebox_override(&"panel", PlanBoardUI._panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	column.add_child(PlanBoardUI._label(Shuttle.text("terminal_title"), TEAL, 30))
	column.add_child(PlanBoardUI._label(Shuttle.text("terminal_hint"), DIM, 18))
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override(&"separation", 6)
	column.add_child(_lines)
	var books := HBoxContainer.new()
	books.name = "Books"
	books.add_theme_constant_override(&"separation", 12)
	for moon: String in Shuttle.MOONS:
		var book: Button = PlanBoardUI._button(Shuttle.text("terminal_book") % Shuttle.moon_name(moon))
		book.name = "Book_" + moon
		book.pressed.connect(_on_book.bind(moon))
		books.add_child(book)
	column.add_child(books)
	column.add_child(PlanBoardUI._label(Shuttle.text("terminal_exp_title"), TEAL, 24))
	_exp_lines = VBoxContainer.new()
	_exp_lines.name = "ExpeditionLines"
	_exp_lines.add_theme_constant_override(&"separation", 4)
	column.add_child(_exp_lines)
	_exp_book = PlanBoardUI._button(Shuttle.text("terminal_exp_book") % "0")
	_exp_book.name = "Book_expedition"
	_exp_book.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_exp_book.pressed.connect(_on_book_expedition)
	column.add_child(_exp_book)
	_status = PlanBoardUI._label("", TEXT, 18)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_close_button = PlanBoardUI._button("%s  (%s)" % [Shuttle.text("terminal_close"), Controls.key_label(&"ui_cancel")])
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	GameState.shuttle_license_changed.connect(_on_license_changed)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


## The names of the other people who would fly if this player booked now, as the game
## shows them elsewhere (CoopUI.player_name).
static func others_flying() -> Array[String]:
	var out: Array[String] = []
	for id: String in GameState.shuttle_party(GameState.local_player_id):
		if id != GameState.local_player_id:
			out.append(CoopUI.player_name(id))
	return out


func open() -> void:
	if QuestsUI.other_panel_open(get_tree(), self):
		return
	_focus_before = get_viewport().gui_get_focus_owner()
	_status.text = ""
	_refresh()
	show()
	_close_button.grab_focus()


func close() -> void:
	hide()
	var before: Control = _focus_before
	_focus_before = null
	if is_instance_valid(before) and before.is_inside_tree() and before.is_visible_in_tree():
		before.grab_focus()
	elif _close_button.has_focus():
		_close_button.release_focus()


## Who is at the terminal changes as people walk: look again while the panel is open.
func _process(delta: float) -> void:
	if not visible:
		return
	_watch += delta
	if _watch >= WATCH_S:
		_watch = 0.0
		_refresh()


## A teammate's exam can give the license while the panel is open.
func _on_license_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_party_ids = GameState.shuttle_party(GameState.local_player_id)
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	var others: Array[String] = []
	for id: String in _party_ids:
		if id != GameState.local_player_id:
			others.append(CoopUI.player_name(id))
	for line: String in lines(GameClock.elapsed_days, GameState.shuttle_licensed, others):
		var label: Label = PlanBoardUI._label(line, TEXT, 20)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lines.add_child(label)
	_refresh_expedition(_party_ids.size())


## Redraws the expedition section for `people`. A traveller already away sees the away line.
func _refresh_expedition(people: int) -> void:
	for child: Node in _exp_lines.get_children():
		_exp_lines.remove_child(child)
		child.queue_free()
	var view: Dictionary = expedition_view(GameClock.elapsed_days, maxi(people, 1))
	var shown: Array[String] = []
	shown.assign(view["lines"])
	for line: String in shown:
		var label: Label = PlanBoardUI._label(line, TEXT, 18)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_exp_lines.add_child(label)
	_exp_total = int(view["total"])
	_exp_book.text = Shuttle.text("terminal_exp_book") % SP811.integer(_exp_total)
	_exp_book.disabled = String(view["problem"]) != ""


## Books the expedition for the drawn party at the total the section shows (the host
## refuses if the price moved), then goes to the hub as a day trip does.
func _on_book_expedition() -> void:
	if _busy:
		return
	_busy = true
	var ids: Array = []
	ids.assign(_party_ids)
	var problem: String = await FarmCommands.request(&"book_expedition", [Shuttle.DEIMOS, ids, _exp_total])
	_busy = false
	if not is_inside_tree():
		return
	_status.text = problem
	_refresh()
	if problem == "":
		close()
		_enter_hub(Shuttle.DEIMOS)


## Asks the host for a seat for exactly the party the panel last drew (their ids, this
## player first), so a walk-up or walk-off since is a refusal, not a surprise fare;
## the reason it refuses with is shown as it came.
func _on_book(moon: String) -> void:
	if _busy:
		return
	_busy = true
	# A plain list on the wire: the host takes texts, typed or not.
	var ids: Array = []
	ids.assign(_party_ids)
	var problem: String = await FarmCommands.request(&"book_shuttle", [moon, ids])
	_busy = false
	if not is_inside_tree():
		return
	_status.text = problem
	_refresh()
	if problem == "":
		# Booked and paid: the shuttle has left, and this screen is at the moon's hub.
		close()
		_enter_hub(moon)


## This screen goes to `moon`'s hub, unless it is there or on its way: a guest's screen
## follows the host's synced trip (SceneSwitcher.reconcile_trip), which can come first.
func _enter_hub(moon: String) -> void:
	var hub: String = ZoneData.hub_scene(StringName(moon))
	var current: Node = get_tree().current_scene if is_inside_tree() else null
	if hub == "" or (current != null and current.scene_file_path == hub):
		return
	if change_scene.is_valid():
		change_scene.call(hub)
	else:
		SceneSwitcher.go_to(hub)
