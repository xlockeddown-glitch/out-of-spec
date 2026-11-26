extends RefCounted
## Dispatch names (docs/design/quests_levels_story.md section 0.2, build order
## step 17): BNH sends the morning dispatches and Odalys signs each one
## "Warmly, Dispatch". The old corporation name is gone from the dispatch file.

const PATH: String = "res://data/dialogue_dispatches.json"
const SIGN_OFF: String = "Warmly, Dispatch."
## BNH's departments (section 0.2). A new sender is a decision, so it is listed here.
const SENDERS: Array[String] = [
	"BNH Compliance", "Calibration Desk", "Audit Division", "Metrology Governance",
	"HR & Morale", "Supply Chain", "Telemetry Ops", "Bio-Security Bot", "Drop-Pod Dispatch",
]


func test_no_dispatch_text_names_the_old_corporation() -> String:
	var raw: String = FileAccess.get_file_as_string(PATH)
	if raw.is_empty():
		return "%s could not be read." % PATH
	if raw.to_lower().contains("omnispec"):
		return "%s still says OmniSpec; the corporation is BNH." % PATH
	var corporation: String = str(DataManager.get_value(&"dialogue_dispatches", "megacorp_name", ""))
	return "" if corporation == "Brightwell-Nonesuch Habitats" else "megacorp_name is '%s'." % corporation


func test_every_morning_dispatch_is_from_bnh_and_signed() -> String:
	var dispatches: Array[Dictionary] = DataManager.get_records(&"dialogue_dispatches", "morning_dispatches")
	if dispatches.is_empty():
		return "No morning dispatches were read."
	for entry: Dictionary in dispatches:
		if not str(entry.get("sender", "")) in SENDERS:
			return "%s has a sender that is not a BNH department: '%s'." % [entry.get("id", "?"), entry.get("sender", "")]
		if not str(entry.get("text", "")).ends_with(SIGN_OFF):
			return "%s does not close with '%s'" % [entry.get("id", "?"), SIGN_OFF]
	return ""
