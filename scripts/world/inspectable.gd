class_name Inspectable
extends Clickable
## A placed prop the player can inspect (Ryan, 2026-11-22: "Inspect on click").
## Hover shows the prop's name; a click emits `inspected` with its name and
## description from data/props.json. Needs a CollisionShape3D child, like any
## Clickable. Scene roots connect `inspected` to their log or toast.

signal inspected(text: String)

const GROUP: StringName = &"inspectable"

## Key in data/props.json.
@export var prop_id: String = ""


func _ready() -> void:
	add_to_group(GROUP)
	hint = display_name(prop_id)
	clicked.connect(func() -> void: inspected.emit(inspect_text(prop_id)))


static func display_name(id: String) -> String:
	return str(DataManager.get_value(&"props", id + "/display_name", id))


## "NAME: description", or just the name when the prop has no description.
static func inspect_text(id: String) -> String:
	var description: String = str(DataManager.get_value(&"props", id + "/description", ""))
	var title: String = display_name(id)
	return title if description.is_empty() else "%s: %s" % [title, description]
