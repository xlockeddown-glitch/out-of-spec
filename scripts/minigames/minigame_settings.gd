class_name MinigameSettings
extends RefCounted
## The player's own mini-game choices, kept on this machine and not in the farm:
## the CAREFUL switch and the difficulty (docs/design/quests_levels_story.md
## sections 7.4 and 7.5). Rewards are the same on every setting.

enum Mode { STANDARD, RELAXED, SHARP, OFF }

const SECTION: String = "minigames"
## Sweet spot width and needle speed, as factors of Standard. Relaxed is the
## design's; Sharp is a [PLACEHOLDER].
const SWEET_FACTOR: Dictionary[int, float] = { Mode.STANDARD: 1.0, Mode.RELAXED: 1.5, Mode.SHARP: 0.75, Mode.OFF: 1.0 }
const SPEED_FACTOR: Dictionary[int, float] = { Mode.STANDARD: 1.0, Mode.RELAXED: 0.7, Mode.SHARP: 1.2, Mode.OFF: 1.0 }
const MODE_NAMES: Dictionary[int, String] = {
	Mode.STANDARD: "GAME: STANDARD", Mode.RELAXED: "GAME: RELAXED",
	Mode.SHARP: "GAME: SHARP", Mode.OFF: "GAME: OFF",
}

## Only tests set another.
static var path: String = "user://player_settings.cfg"

static var _loaded_from: String = ""
static var _file: ConfigFile


static func careful() -> bool:
	return bool(_config().get_value(SECTION, "careful", false))


static func set_careful(on: bool) -> void:
	_keep("careful", on)


static func mode() -> int:
	var kept: Variant = _config().get_value(SECTION, "mode", Mode.STANDARD)
	return int(kept) if kept is int and Mode.values().has(kept) else Mode.STANDARD


static func set_mode(next: int) -> void:
	_keep("mode", next if Mode.values().has(next) else Mode.STANDARD)


static func sweet_factor(of_mode: int) -> float:
	return SWEET_FACTOR.get(of_mode, 1.0)


static func speed_factor(of_mode: int) -> float:
	return SPEED_FACTOR.get(of_mode, 1.0)


static func _keep(key: String, value: Variant) -> void:
	_config().set_value(SECTION, key, value)
	_file.save(path)


static func _config() -> ConfigFile:
	if _file == null or _loaded_from != path:
		_file = ConfigFile.new()
		_file.load(path)
		_loaded_from = path
	return _file
