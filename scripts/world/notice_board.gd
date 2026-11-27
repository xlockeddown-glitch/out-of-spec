class_name NoticeBoard
extends RefCounted
## The notice boards' lines (the Lava Tubes hub's and the farm's) and where the
## farm's stands. Pure rules and words; the prop is LavaHubProps.board_node, and
## the quests are data/quests.json's. The farm board (docs/design/biomes.md
## section 4) lists the starter jobs: quests with `board` set to FARM. Every
## number here is a [PLACEHOLDER].

## What a quest's `board` says to be listed on the farm's board.
const FARM: String = "farm"
## The farm board's place: by the dome's airlock, south of the plot, clear of the
## crate and pallet, the weather mast, Bram's bay and the road to the tunnels.
const FARM_POSITION := Vector3(1.5, 0.0, 17.5)
## How near the rover must be to use it, in metres [PLACEHOLDER]. It reaches the
## corners of PAD_SIZE (3.5 m each way is 4.95 m, and the rover's own middle may be a
## little further out than the part of it that touches the pad).
const REACH_M: float = 6.5
## The pad round the board that shows the prompt: centred on the board, so a rover
## drives up to it from the farm side as well as from behind.
const PAD_SIZE := Vector3(7.0, 3.0, 7.0)


## True if a rover at `at` is near enough to the farm board to read it.
static func farm_near(at: Vector3) -> bool:
	return Vector2(FARM_POSITION.x - at.x, FARM_POSITION.z - at.z).length() <= REACH_M


## The lines of the quests with `key` set to `value`: each as not offered yet,
## accepted with its next step, or done. Quests are accepted when they are offered,
## so a board has no separate "offered". Reading only: nothing here accepts
## anything. `placed` is how many beacons are down (the Lava Tubes' step shows
## them). `prompts` adds what to press for a step that names an action, built
## now and never kept: the host's lines for a guest are made without.
static func lines(quests: Array, farm_state: Dictionary, own_state: Dictionary, key: String, value: String,
		placed: int = 0, prompts: bool = false) -> Array[String]:
	var out: Array[String] = []
	for quest: Variant in quests:
		if not quest is Dictionary or str(quest.get(key, "")) != value:
			continue
		var title: String = str(quest.get("title", ""))
		var own: bool = str(quest.get("scope", "")) == QuestEngine.SCOPE_PLAYER
		var entry: Variant = (own_state if own else farm_state).get(str(quest.get("id", "")))
		if not entry is Dictionary or not entry.get("steps_done") is Array:
			var gates: Variant = quest.get("gates", {})
			var level: int = int(gates.get("lab_level", 0)) if gates is Dictionary else 0
			out.append("BOARD: %s. Not offered yet%s." % [title, " (lab level %d)" % level if level > 0 else ""])
		elif int(entry.get("done", -1)) >= 0:
			out.append("BOARD: %s. Done." % title)
		else:
			var step: Dictionary = QuestLog.open_step(quest, entry)
			var count: String = ""
			if str(step.get("check", "")) == "beacons_placed":
				count = " (%d of %d)" % [mini(placed, QuestEngine.step_need(step)), QuestEngine.step_need(step)]
			var press: String = ""
			if prompts and step.get("prompt") is String and Controls.prompt(StringName(step["prompt"])) != "":
				press = " [%s]" % Controls.prompt(StringName(step["prompt"]))
			out.append("BOARD: %s. Accepted. Next: %s%s%s" % [title, str(step.get("text", "")), press, count])
	if out.is_empty():
		out.append("BOARD: no notices.")
	return out


## The farm board's lines, from the farm's and the player's own quest state.
static func farm_lines(quests: Array, farm_state: Dictionary, own_state: Dictionary, prompts: bool = false) -> Array[String]:
	return lines(quests, farm_state, own_state, QuestEngine.BOARD_KEY, FARM, 0, prompts)
