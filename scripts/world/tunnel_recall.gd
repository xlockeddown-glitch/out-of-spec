class_name TunnelRecall
extends RefCounted
## The recall: a player still in the basalt tunnels late in the night is warned
## and then carried out by a recovery crew (docs/design/zones.md section 6.1).
## Pure rules; GameState applies them. Every number is in data/economy.json
## ("tunnel_recall") [PLACEHOLDER].

const TABLE: StringName = &"economy"
const PATH: String = "tunnel_recall/"

## What the clock says to do about a player in the tunnels.
const NOTHING: String = ""
const WARN: String = "warn"
const RESCUE: String = "rescue"


static func number(key: String, fallback: float) -> float:
	return DataManager.get_number(TABLE, PATH + key, fallback)


static func text(key: String) -> String:
	return str(DataManager.get_value(TABLE, PATH + key, ""))


## The in-game time of a clock hour late in `day` (1-based). The day runs
## 06:00 to 06:00, so 00:00 and 02:00 belong to the end of it.
static func at_hour(day: int, hour: float) -> float:
	return float(day - 1) + fposmod(hour - 6.0, 24.0) / 24.0


## What to do at `elapsed_days` for a player in the tunnels, given the day the
## warning and the rescue were last given for (0: never). A player who comes
## in, or a farm that loads, after the hour gets the step that is due then, and
## each is given once a day.
static func phase(elapsed_days: float, warned_day: int, rescued_day: int) -> String:
	var day: int = floori(elapsed_days) + 1
	if rescued_day == day:
		return NOTHING
	if elapsed_days >= at_hour(day, number("rescue_hour", 2.0)):
		return RESCUE
	if warned_day != day and elapsed_days >= at_hour(day, number("warn_hour", 0.0)):
		return WARN
	return NOTHING


## Driving in after the rescue hour (until 06:00) would be rescued at once and
## charged for nothing, so the mouth is closed then.
static func closed(elapsed_days: float) -> bool:
	return phase(elapsed_days, 0, 0) == RESCUE


## What a rescue costs, given the shared wallet and the ore gained in the tunnels: { credits,
## ore, waived }. The fee never takes the wallet below 0: the crew takes what
## there is and `waived` is the rest. The ore is a share of what is carried,
## rounded down, so a little ore costs nothing [PLACEHOLDER].
static func cost(wallet: int, ore: int) -> Dictionary:
	var fee: int = maxi(int(number("fee_credits", 50.0)), 0)
	var taken: int = clampi(wallet, 0, fee)
	var share: Variant = DataManager.get_value(TABLE, PATH + "ore_share", [1, 3])
	var ok: bool = share is Array and (share as Array).size() == 2
	var numerator: int = maxi(int((share as Array)[0]), 0) if ok else 1
	var denominator: int = maxi(int((share as Array)[1]), 1) if ok else 3
	var lost: int = clampi(floori(float(maxi(ore, 0) * numerator) / float(denominator)), 0, maxi(ore, 0))
	return { "credits": taken, "ore": lost, "waived": fee - taken }
