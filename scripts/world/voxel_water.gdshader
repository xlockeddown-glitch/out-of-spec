shader_type spatial;
render_mode specular_disabled;

// Every number here is [PLACEHOLDER].
// Patches this wide rise and fall together, a step at a time.
const float PATCH_M = 0.5;
const float STEP_S = 0.7;
const float STEP_M = 0.025;

varying flat vec3 tint;

void vertex() {
	vec3 column = MODEL_MATRIX[3].xyz;
	vec2 at = floor(column.xz / PATCH_M);
	float beat = floor(TIME / STEP_S);
	float wave = sin(at.x * 0.9 + beat * 0.8) + sin(at.y * 1.1 - beat * 0.6 + at.x * 0.5);
	float rise = clamp(round(wave * 0.7), -1.0, 1.0);
	// Foam comes and goes column by column.
	if (COLOR.a > 0.5) {
		rise = mod(floor(column.x * 4.0) + floor(column.z * 4.0) + floor(beat * 0.5), 3.0) < 1.0 ? 0.0 : 1.0;
	}
	if (VERTEX.y > 0.0) {
		VERTEX.y += rise * STEP_M / length(MODEL_MATRIX[1].xyz);
	}
	tint = COLOR.rgb * (1.0 + 0.1 * rise);
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 1.0;
}
