class_name QuestSeen
extends RefCounted
## Which quests this PC's player has already looked at on the board, so a new one
## can wear a NEW tag. Local to this PC only: one ConfigFile in the player's own
## user folder (like MinigameSettings), never in the farm save and never sent.
## A quest is keyed by the farm's seed, its id, and for a daily quest the day.

const SECTION: String = "seen"

## Overridable so a test writes elsewhere.
static var path: String = "user://quests_seen.cfg"

static var _loaded_from: String = ""
static var _file: ConfigFile


## The key a quest row is remembered by.
static func key_of(row: Dictionary) -> String:
	var key: String = "%s|%s" % [GameState.world_seed, str(row.get("id", ""))]
	if str(row.get("kind", "")) == QuestEngine.KIND_DAILY:
		key += "|%s" % str(row.get("day", 0))
	return key


static func is_new(row: Dictionary) -> bool:
	return not _config().has_section_key(SECTION, key_of(row))


## Marks every row of `rows` seen and keeps the file (only when something changed).
static func mark_seen(rows: Array) -> void:
	var changed: bool = false
	for row: Dictionary in rows:
		if is_new(row):
			_config().set_value(SECTION, key_of(row), true)
			changed = true
	if changed:
		_config().save(path)


static func _config() -> ConfigFile:
	if _file == null or _loaded_from != path:
		_file = ConfigFile.new()
		_file.load(path)
		_loaded_from = path
	return _file
