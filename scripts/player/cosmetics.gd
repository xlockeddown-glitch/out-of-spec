class_name Cosmetics
extends RefCounted
## Late-level cosmetics and titles (slice 35; docs/design/quests_levels_story.md
## §3.4 rows 85/92/99, §4.2 rows 50/75/99, §4.3 total-level milestones).
## Pure rules and palette lookups (ScopeTheme constants only, no raw hex).
## Every color choice, cap, threshold and string here is a [PLACEHOLDER].

const GATE_ROBOT_PAINT: String = "robot_paint"
const GATE_HALFWAY_PLAQUE: String = "halfway_plaque"
const GATE_GOLD_BORDER: String = "gold_border"

## [PLACEHOLDER] Personal skill cosmetic unlock thresholds (§4.2).
const LAB_COAT_LEVEL: int = 50
const CAL_INITIALS_LEVEL: int = 75
const CERT_TITLE_LEVEL: int = 99

## [PLACEHOLDER] Robot nameplate cap (characters, sanitized).
const MAX_NAMEPLATE: int = 12

## [PLACEHOLDER] Robot paint choices: default ("") plus 4 palette colors.
const ROBOT_PAINTS: Array[Dictionary] = [
	{ "id": "", "name": "Stock", "color": ScopeTheme.ENAMEL },
	{ "id": "terra", "name": "Terracotta", "color": ScopeTheme.TERRA },
	{ "id": "teal", "name": "Teal", "color": ScopeTheme.TEAL },
	{ "id": "amber", "name": "Amber", "color": ScopeTheme.AMBER },
	{ "id": "slate", "name": "Slate", "color": ScopeTheme.GLASS_LINE },
]

## [PLACEHOLDER] Personal lab coat color choices: default ("") plus 3 palette colors.
const COAT_COLORS: Array[Dictionary] = [
	{ "id": "", "name": "Standard", "color": ScopeTheme.ENAMEL_TOP },
	{ "id": "teal", "name": "Meridiani Teal", "color": ScopeTheme.TEAL },
	{ "id": "amber", "name": "Amber", "color": ScopeTheme.AMBER },
	{ "id": "terra", "name": "Terracotta", "color": ScopeTheme.TERRA },
]

## [PLACEHOLDER] Total-level milestone titles (§4.3), ordered ascending by level.
const TOTAL_LEVEL_TITLES: Array[Dictionary] = [
	{ "level": 50, "title": "Apprentice" },
	{ "level": 150, "title": "Technician" },
	{ "level": 300, "title": "Metrologist" },
	{ "level": 500, "title": "Principal" },
	{ "level": 693, "title": "In Spec" },
]

## [PLACEHOLDER] Odalys's mug phone line and bench prop text (lab level 99, once only).
const ODALYS_MUG_PHONE: String = "[Odalys Brandt, BNH Dispatch] Lab level 99. I am sending down my good mug, the one with the chipped rim. Keep it off the calibration certificates. Warmly, Dispatch."
const ODALYS_MUG_HINT: String = "Odalys's mug"
const ODALYS_MUG_INSPECT: String = "Odalys Brandt's ceramic mug, sent down from Dispatch at lab level 99. A faint chip on the rim. Warmly, Dispatch."


## True when `paint_id` is "" (stock) or one of the 4 robot paint choices.
static func is_robot_paint(paint_id: Variant) -> bool:
	if not (paint_id is String or paint_id is StringName):
		return false
	var key: String = str(paint_id)
	for entry: Dictionary in ROBOT_PAINTS:
		if str(entry["id"]) == key:
			return true
	return false


## Palette Color for a robot paint id (falls back to stock enamel).
static func robot_paint_color(paint_id: String) -> Color:
	for entry: Dictionary in ROBOT_PAINTS:
		if str(entry["id"]) == paint_id:
			return entry["color"] as Color
	return ScopeTheme.ENAMEL


## Display name for a robot paint id.
static func robot_paint_name(paint_id: String) -> String:
	for entry: Dictionary in ROBOT_PAINTS:
		if str(entry["id"]) == paint_id:
			return str(entry["name"])
	return "Stock"


## Next paint id in cycle order for UI buttons.
static func next_robot_paint(current: String) -> String:
	for i: int in ROBOT_PAINTS.size():
		if str(ROBOT_PAINTS[i]["id"]) == current:
			return str(ROBOT_PAINTS[(i + 1) % ROBOT_PAINTS.size()]["id"])
	return str(ROBOT_PAINTS[1]["id"])


## Sanitizes a robot nameplate: strips control chars (C0, DEL, C1), "[" markup
## openers, bidi/zero-width marks, trims whitespace, and caps at MAX_NAMEPLATE.
static func clean_nameplate(text: Variant) -> String:
	if not text is String:
		return ""
	var raw: String = text as String
	var kept: String = ""
	for i: int in raw.length():
		var code: int = raw.unicode_at(i)
		if code < 32 or (code >= 127 and code <= 159) or code == 91:
			continue
		if (code >= 0x200B and code <= 0x200F) or (code >= 0x202A and code <= 0x202E) \
				or (code >= 0x2060 and code <= 0x2069) or code == 0xFEFF:
			continue
		kept += raw[i]
	return kept.strip_edges().left(MAX_NAMEPLATE).strip_edges()


## True when `color_id` is "" (standard) or one of the 3 lab coat color choices.
static func is_coat_color(color_id: Variant) -> bool:
	if not (color_id is String or color_id is StringName):
		return false
	var key: String = str(color_id)
	for entry: Dictionary in COAT_COLORS:
		if str(entry["id"]) == key:
			return true
	return false


## Palette Color for a lab coat color id.
static func coat_color(color_id: String) -> Color:
	for entry: Dictionary in COAT_COLORS:
		if str(entry["id"]) == color_id:
			return entry["color"] as Color
	return ScopeTheme.ENAMEL_TOP


## Display name for a lab coat color id.
static func coat_color_name(color_id: String) -> String:
	for entry: Dictionary in COAT_COLORS:
		if str(entry["id"]) == color_id:
			return str(entry["name"])
	return "Standard"


## Next coat color id in cycle order (step +1 or -1).
static func step_coat_color(current: String, step: int) -> String:
	var idx: int = 0
	for i: int in COAT_COLORS.size():
		if str(COAT_COLORS[i]["id"]) == current:
			idx = i
			break
	return str(COAT_COLORS[posmod(idx + step, COAT_COLORS.size())]["id"])


## True when `player_id` has reached level 50 in any personal skill.
static func has_lab_coat_unlock(farm: Node, player_id: String = "") -> bool:
	for skill: String in farm.skill_ids():
		if farm.skill_level(skill, player_id) >= LAB_COAT_LEVEL:
			return true
	return false


## True when `player_id` has reached Calibration 75.
static func has_cal_initials_unlock(farm: Node, player_id: String = "") -> bool:
	return farm.skill_level("calibration", player_id) >= CAL_INITIALS_LEVEL


## Two-character uppercase initials for `player_id` from their character name,
## falling back to player id (e.g. "player_1" -> "P1").
static func player_initials(farm: Node, player_id: String = "") -> String:
	var pid: String = farm.local_player_id if player_id == "" else player_id
	var chosen: String = str(farm.loadout_of(pid).get("name", "")).strip_edges()
	if chosen != "":
		var words: PackedStringArray = chosen.split(" ", false)
		if words.size() >= 2:
			return (words[0].left(1) + words[1].left(1)).to_upper()
		return chosen.left(2).to_upper()
	var suffix: String = pid.trim_prefix("player_")
	if suffix != pid and suffix != "":
		return ("P" + suffix).left(2).to_upper()
	return pid.left(2).to_upper()


## Certificate title for a player with any personal skill at 99 ("<Skill> 99"
## [PLACEHOLDER]), or "" if none has reached 99.
static func skill_99_title(farm: Node, player_id: String = "") -> String:
	for skill: String in farm.skill_ids():
		if farm.skill_level(skill, player_id) >= CERT_TITLE_LEVEL:
			var rec: Dictionary = DataManager.get_record(&"skills", skill, "skills")
			var display: String = str(rec.get("display_name", skill))
			return "%s %d" % [display, CERT_TITLE_LEVEL]
	return ""


## Sum of a player's personal skill levels (7 to 693).
static func total_level(farm: Node, player_id: String = "") -> int:
	var total: int = 0
	for skill: String in farm.skill_ids():
		total += farm.skill_level(skill, player_id)
	return total


## Highest total-level milestone title reached, or "" below 50.
static func total_level_title(total: int) -> String:
	var best: String = ""
	for row: Dictionary in TOTAL_LEVEL_TITLES:
		if total >= int(row["level"]):
			best = str(row["title"])
	return best


## Highest milestone title for `player_id` on `farm`, or "" below 50.
static func player_title(farm: Node, player_id: String = "") -> String:
	return total_level_title(total_level(farm, player_id))


## Formatted name tag text for co-op (character name or player id, plus title if reached).
static func name_tag_text(farm: Node, player_id: String) -> String:
	var chosen: String = str(farm.loadout_of(player_id).get("name", "")).strip_edges()
	var base: String = chosen if chosen != "" else player_id.replace("_", " ").to_upper()
	var title: String = player_title(farm, player_id)
	return "%s · %s" % [base, title] if title != "" else base
