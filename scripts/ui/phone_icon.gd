class_name PhoneIcon
extends Control
## A message's sender as a small pixel picture on a tile.

## Nine rows of nine: # the picture, + its darker parts.
const PICTURES: Dictionary = {
	"wrench": ".##...##. .##...##. .###.###. ..#####.. ...###... ...###... ...###... ...#+#... ...###...",
	"leaf": "......### ....##### ...###+## ..###+##. ..##+###. .##+###.. .#+###... .+....... +........",
	"stamp": "...###... ..#####.. ..#####.. ...###... ...###... .#######. .#######. ......... +++++++++",
	"drone": "###...### .#.....#. .#.###.#. .#######. ..#+++#.. ..#+#+#.. ..#+++#.. ...###... ..#...#..",
	"bird": "......... ....##... #..####+. ##.###... #######.. .######.. ..####... ...#.#... ..##.##..",
	"mug": ".#..#..#. ..#..#... ......... .######.. .#######. .######.# .#######. .######.. ..####...",
	"seal": "..#####.. .##+++##. .#+###+#. .#+###+#. .##+++##. ..#####.. ..##.##.. ..#...#.. .........",
	"robot": "....#.... ....#.... .#######. .#+###+#. .#+###+#. .#######. .##+++##. .#######. ..#...#..",
	"flask": "...###... ....#.... ...###... ...#.#... ..#...#.. ..#+++#.. .#+++++#. .#+++++#. .#######.",
	"dish": "......##. .#....#.. .##..##.. .###.#... .####.... .#####... ..+###... ..+...... .+++.....",
	"gear": "....#.... .##.#.##. .#######. ..##+##.. ####+#### ..##+##.. .#######. .##.#.##. ....#....",
	"board": "...###... .##+++##. .#######. .#+++++#. .#######. .#+++++#. .#######. .#+++##.. .#######.",
	"rover": "......... ..####... ..#++#### ..#++##+# ######### ######### .##...##. .##...##. .........",
	"bell": "....#.... ...###... ..#####.. ..#####.. ..#####.. .#######. .+++++++. ....#.... .........",
}
## Who says it -> [picture, tile color].
const SENDERS: Dictionary = {
	"BRAM": ["wrench", Color("#8A4B2C")],
	"LIN": ["leaf", Color("#3c6b3a")],
	"VANCE": ["stamp", Color("#5A4A66")],
	"AUD-1T": ["drone", Color("#5A4A66")],
	"KESTREL": ["bird", Color("#3F5878")],
	"MANAGER": ["mug", Color("#7a6a4a")],
	"OIRM": ["seal", Color("#2F5E63")],
	"OIRM CONTRACT": ["seal", Color("#2F5E63")],
	"ROBOT": ["robot", Color("#4A545E")],
	"LAB": ["flask", Color("#2F5E63")],
	"SYS": ["gear", Color("#39414B")],
	"JOB BOARD": ["board", Color("#7a6a4a")],
	"RECALL": ["bell", Color("#8A4B2C")],
	"AUDIT": ["stamp", Color("#5A4A66")],
	"DISPATCH": ["dish", Color("#3F5878")],
	"YOU": ["rover", Color("#8A4B2C")],
}
const OTHER: Array = ["bell", Color("#39414B")]
const TILE: float = 36.0

var sender: String = ""


func _init(who: String = "") -> void:
	sender = who
	custom_minimum_size = Vector2(TILE, TILE)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _draw() -> void:
	var look: Array = SENDERS.get(sender, OTHER)
	var tile: Color = look[1]
	var style := StyleBoxFlat.new()
	style.bg_color = tile
	style.set_corner_radius_all(9)
	style.border_color = tile.lightened(0.2)
	style.border_width_top = 2
	draw_style_box(style, Rect2(0, 0, TILE, TILE))
	var rows: PackedStringArray = str(PICTURES[look[0]]).split(" ")
	for y: int in rows.size():
		for x: int in rows[y].length():
			var mark: String = rows[y][x]
			if mark != ".":
				draw_rect(Rect2(4.5 + x * 3, 4.5 + y * 3, 3, 3), Color("#F1EBD8") if mark == "#" else tile.lightened(0.4))
