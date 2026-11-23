class_name CalUncertainty
extends RefCounted
## Uncertainty budget, TUR and acceptance limit for one bench calibration
## (docs/design/equipment_skills_robots.md section 1.5; Ryan's Q5, Q7, Q13).
## Pure functions: give it the unit under test and the standard, get numbers.
##
##   U = k × √(u_spec² + u_cert² + u_res² + u_op² + u_robot²)
##   TUR = MPE / U
##   acceptance limit A = √(MPE² − U²)
##   |as-found| <= A: pass;  A < |as-found| <= MPE: indeterminate;  > MPE: fail
##
## u_op comes from the operator's Uncertainty skill; u_robot is 0 until robots
## (milestone 5).

const CONFIG_TABLE: StringName = &"sensor_drift_config"
const PASS: String = "pass"
const INDETERMINATE: String = "indeterminate"
const FAIL: String = "fail"


## Standard uncertainty from a spec half-width. A spec stated at a confidence
## (95 %) is treated as k = 2; one with no stated confidence is rectangular.
static func spec_to_standard(half_width: float, confidence_pct: float) -> float:
	if confidence_pct > 0.0:
		return absf(half_width) / 2.0
	return absf(half_width) / sqrt(3.0)


## Resolution term: half of one digit, rectangular.
static func resolution_to_standard(resolution: float) -> float:
	return absf(resolution) / 2.0 / sqrt(3.0)


## Full budget for calibrating `unit` against `standard`.
## u_op and u_robot are standard uncertainties in the unit's unit. The
## standard's terms are converted into the unit's unit through
## `unit.standard_sensitivity` (section 1.5: a different quantity in the chain).
static func budget(unit: DriftingSensor, standard: DriftingSensor, u_op: float = 0.0, u_robot: float = 0.0) -> Dictionary:
	var sensitivity: float = absf(unit.standard_sensitivity)
	var u_spec: float = spec_to_standard(standard.mpe, standard.spec_confidence_pct) * sensitivity
	var u_cert: float = (standard.certificate_uncertainty / standard.certificate_k * sensitivity
		if standard.certificate_k > 0.0 else 0.0)
	var u_res: float = resolution_to_standard(unit.resolution)
	var k: float = coverage_factor()
	var expanded: float = k * sqrt(u_spec * u_spec + u_cert * u_cert + u_res * u_res + u_op * u_op + u_robot * u_robot)
	var tur: float = unit.mpe / expanded if expanded > 0.0 else INF
	return {
		"standard_id": standard.instrument_id,
		"u_spec": u_spec,
		"u_cert": u_cert,
		"u_res": u_res,
		"u_op": u_op,
		"u_robot": u_robot,
		"k": k,
		"expanded_uncertainty": expanded,
		"tur": tur,
		"acceptance_limit": acceptance_limit(unit.mpe, expanded),
		"refused": tur < tur_floor(),
		"clean": tur >= tur_clean(),
	}


## RSS acceptance limit √(MPE² − U²); 0 when U >= MPE.
static func acceptance_limit(mpe: float, expanded: float) -> float:
	return sqrt(maxf(mpe * mpe - expanded * expanded, 0.0))


static func classify(as_found: float, mpe: float, limit: float) -> String:
	var magnitude: float = absf(as_found)
	if magnitude <= limit:
		return PASS
	if magnitude <= mpe:
		return INDETERMINATE
	return FAIL


static func coverage_factor() -> float:
	return DataManager.get_number(CONFIG_TABLE, "calibration_uncertainty/coverage_factor", 2.0)


static func tur_floor() -> float:
	return DataManager.get_number(CONFIG_TABLE, "calibration_uncertainty/tur_floor", 2.0)


static func tur_clean() -> float:
	return DataManager.get_number(CONFIG_TABLE, "calibration_uncertainty/tur_clean", 4.0)
