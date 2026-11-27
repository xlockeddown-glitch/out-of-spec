class_name RareSpiderLook
extends RefCounted
## Primitive-mesh terrarium looks for the four rare moon/pod tarantulas
## (data/tarantula_species.json, tier "rare"). Each species has a body colour,
## a leg colour, and one unmistakable visual mark taken from Ryan's concept art
## (colour band, frost, glint, size). Uses ScopeTheme colours only; every number
## below is a [PLACEHOLDER].

const BANDED_ID: String = "banded_regolith_runner"
const RIME_ID: String = "rime_carapace_spinner"
const GLINT_ID: String = "brass_glint_reticle"
const TITAN_ID: String = "low_g_titan_carapace"
const IDS: Array[String] = [BANDED_ID, RIME_ID, GLINT_ID, TITAN_ID]

## Default spider scale factor [PLACEHOLDER].
const BASE_SCALE: float = 1.0
## Low-G Titan Carapace scale factor (size hook) [PLACEHOLDER].
const TITAN_SCALE: float = 1.38
## Roughness for flat-matte spider parts [PLACEHOLDER].
const ROUGHNESS: float = 0.9
## Prosoma box size, in metres [PLACEHOLDER].
const PROSOMA_SIZE := Vector3(0.16, 0.08, 0.16)
## Prosoma position, in metres [PLACEHOLDER].
const PROSOMA_AT := Vector3(0.0, 0.05, -0.05)
## Abdomen box size, in metres [PLACEHOLDER].
const ABDOMEN_SIZE := Vector3(0.20, 0.11, 0.22)
## Abdomen position, in metres [PLACEHOLDER].
const ABDOMEN_AT := Vector3(0.0, 0.065, 0.13)
## Chelicerae box size, in metres [PLACEHOLDER].
const FANG_SIZE := Vector3(0.08, 0.05, 0.05)
## Chelicerae position, in metres [PLACEHOLDER].
const FANG_AT := Vector3(0.0, 0.035, -0.15)
## Leg segment box size, in metres [PLACEHOLDER].
const LEG_SIZE := Vector3(0.16, 0.04, 0.04)
## Leg horizontal offset from centreline, in metres [PLACEHOLDER].
const LEG_X_M: float = 0.15
## Leg vertical offset from ground, in metres [PLACEHOLDER].
const LEG_Y_M: float = 0.03
## Leg Z offsets for the four pairs, in metres [PLACEHOLDER].
const LEG_Z_M: PackedFloat32Array = [-0.11, -0.04, 0.03, 0.10]
## Banded Regolith Runner abdomen stripe size and position, in metres [PLACEHOLDER].
const BAND_SIZE := Vector3(0.21, 0.03, 0.06)
const BAND_AT := Vector3(0.0, 0.125, 0.13)
## Banded Regolith Runner secondary cream highlight size and position, in metres [PLACEHOLDER].
const BAND_TRIM_SIZE := Vector3(0.215, 0.015, 0.025)
const BAND_TRIM_AT := Vector3(0.0, 0.138, 0.10)
## Rime Carapace Spinner frost ridge size and position, in metres [PLACEHOLDER].
const FROST_SIZE := Vector3(0.14, 0.04, 0.18)
const FROST_AT := Vector3(0.0, 0.13, 0.12)
## Rime Carapace Spinner frost cap on prosoma, in metres [PLACEHOLDER].
const FROST_CAP_SIZE := Vector3(0.12, 0.03, 0.10)
const FROST_CAP_AT := Vector3(0.0, 0.098, -0.05)
## Brass Glint Reticle dorsal glint facet size and position, in metres [PLACEHOLDER].
const GLINT_SIZE := Vector3(0.12, 0.025, 0.12)
const GLINT_AT := Vector3(0.0, 0.096, -0.05)
## Brass Glint Reticle specular catch-voxel size and position, in metres [PLACEHOLDER].
const GLINT_SPECK_SIZE := Vector3(0.06, 0.025, 0.06)
const GLINT_SPECK_AT := Vector3(0.0, 0.125, 0.14)
## Low-G Titan Carapace dorsal armor plate size and position, in metres [PLACEHOLDER].
const TITAN_PLATE_SIZE := Vector3(0.17, 0.03, 0.14)
const TITAN_PLATE_AT := Vector3(0.0, 0.098, -0.05)


## True if `species_id` has a rare terrarium look defined here.
static func has_look(species_id: String) -> bool:
	return species_id in IDS


## Builds a primitive-mesh Node3D spider for `species_id`, or null if unknown.
static func build(species_id: String) -> Node3D:
	if not has_look(species_id):
		return null
	var palette: Dictionary = _palette(species_id)
	var body_mat: StandardMaterial3D = _mat(palette["body"] as Color)
	var leg_mat: StandardMaterial3D = _mat(palette["leg"] as Color)
	var mark_mat: StandardMaterial3D = _mat(palette["mark"] as Color)
	var accent_mat: StandardMaterial3D = _mat(palette["accent"] as Color)

	var root := Node3D.new()
	root.name = &"RareSpider"
	root.scale = Vector3.ONE * float(palette["scale"])

	root.add_child(_box(&"Prosoma", PROSOMA_SIZE, PROSOMA_AT, body_mat))
	root.add_child(_box(&"Abdomen", ABDOMEN_SIZE, ABDOMEN_AT, body_mat))
	root.add_child(_box(&"Chelicerae", FANG_SIZE, FANG_AT, leg_mat))

	for side: int in [-1, 1]:
		for i: int in LEG_Z_M.size():
			var leg_name: StringName = StringName("Leg_%s_%d" % ["L" if side < 0 else "R", i])
			root.add_child(_box(leg_name, LEG_SIZE, Vector3(LEG_X_M * side, LEG_Y_M, LEG_Z_M[i]), leg_mat))

	var mark := Node3D.new()
	mark.name = &"Mark"
	root.add_child(mark)
	match species_id:
		BANDED_ID:
			mark.add_child(_box(&"Band", BAND_SIZE, BAND_AT, mark_mat))
			mark.add_child(_box(&"BandTrim", BAND_TRIM_SIZE, BAND_TRIM_AT, accent_mat))
		RIME_ID:
			mark.add_child(_box(&"FrostRidge", FROST_SIZE, FROST_AT, mark_mat))
			mark.add_child(_box(&"FrostCap", FROST_CAP_SIZE, FROST_CAP_AT, accent_mat))
		GLINT_ID:
			mark.add_child(_box(&"GlintPlate", GLINT_SIZE, GLINT_AT, mark_mat))
			mark.add_child(_box(&"GlintSpeck", GLINT_SPECK_SIZE, GLINT_SPECK_AT, accent_mat))
		TITAN_ID:
			mark.add_child(_box(&"TitanPlate", TITAN_PLATE_SIZE, TITAN_PLATE_AT, mark_mat))
	return root


static func _palette(species_id: String) -> Dictionary:
	match species_id:
		BANDED_ID:
			return { "body": ScopeTheme.SHADOW, "leg": ScopeTheme.GLASS_LINE, "mark": ScopeTheme.AMBER, "accent": ScopeTheme.ENAMEL_TOP, "scale": BASE_SCALE }
		RIME_ID:
			return { "body": ScopeTheme.GLASS_CARD, "leg": ScopeTheme.GLASS_LINE, "mark": ScopeTheme.INK, "accent": ScopeTheme.ENAMEL_TOP, "scale": BASE_SCALE }
		GLINT_ID:
			return { "body": ScopeTheme.GLASS_DEEP, "leg": ScopeTheme.SHADOW, "mark": ScopeTheme.AMBER, "accent": ScopeTheme.ENAMEL_TOP, "scale": BASE_SCALE }
		TITAN_ID:
			return { "body": ScopeTheme.ENAMEL_LIP, "leg": ScopeTheme.CARD_INK_MUTED, "mark": ScopeTheme.TERRA, "accent": ScopeTheme.ENAMEL_INSET, "scale": TITAN_SCALE }
	return { "body": ScopeTheme.SHADOW, "leg": ScopeTheme.GLASS_LINE, "mark": ScopeTheme.AMBER, "accent": ScopeTheme.ENAMEL_TOP, "scale": BASE_SCALE }


static func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = ROUGHNESS
	return mat


static func _box(part_name: StringName, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	return node
