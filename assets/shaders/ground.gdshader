shader_type spatial;
// The ground: vertex color times the base color, and on steep faces (dug pit
// sides) strata bands from Ryan's plateau colors so a wall reads as layers.

uniform vec4 base : source_color = vec4(0.42, 0.5, 0.3, 1.0);
uniform vec4 band_1 : source_color = vec4(0.659, 0.259, 0.169, 1.0);
uniform vec4 band_2 : source_color = vec4(0.557, 0.208, 0.133, 1.0);
uniform vec4 band_3 : source_color = vec4(0.431, 0.149, 0.09, 1.0);
uniform vec4 band_4 : source_color = vec4(0.761, 0.42, 0.29, 1.0);
// The upward part of a normal where a face starts, and ends, to read as a wall.
// Hills are under 15 degrees (0.966); dug sides are about 27 degrees (0.89) on
// level land. One that faces up a steep hill can be flatter and stay ground.
uniform float wall_from = 0.955;
uniform float wall_to = 0.925;
uniform float band_m = 0.25;
uniform float strata_mix = 0.8;

varying vec3 world_at;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 ground = COLOR.rgb * base.rgb;
	// The face's own slope, from the screen, though the vertex normals are smooth.
	vec3 face = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	face *= sign(dot(face, VIEW));
	float wall = 1.0 - smoothstep(wall_to, wall_from, (INV_VIEW_MATRIX * vec4(face, 0.0)).y);
	// Walls are lit as the flat faces they are, so their layers show.
	NORMAL = normalize(mix(NORMAL, face, wall));
	// Layers are level, a little wavy so they are not ruled lines.
	float layer = world_at.y / band_m + 0.3 * sin(world_at.x * 1.7 + world_at.z * 2.3);
	float id = floor(layer);
	float pick = hash(id) * 4.0;
	vec3 rock = band_1.rgb;
	rock = mix(rock, band_2.rgb, step(1.0, pick));
	rock = mix(rock, band_3.rgb, step(2.0, pick));
	rock = mix(rock, band_4.rgb, step(3.0, pick));
	// A dark seam where one layer meets the next.
	rock *= 0.85 + 0.15 * smoothstep(0.0, 0.18, fract(layer));
	ALBEDO = mix(ground, rock, wall * strata_mix);
	ROUGHNESS = 1.0;
}
