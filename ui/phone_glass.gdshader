shader_type canvas_item;
// The phone's glass, over the screen: faint scan lines, darker corners, one
// soft reflection, and a little snow when the uplink is weak.

uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

float noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float line = step(0.5, fract(UV.y * 205.0)) * 0.03;
	vec2 c = UV * 2.0 - 1.0;
	float corner = smoothstep(0.75, 1.9, dot(c, c)) * 0.1;
	float shine = smoothstep(0.0, 0.015, UV.x * 0.55 - UV.y + 0.1) * (1.0 - UV.y * 2.2) * 0.045;
	// Coarse and slow, so that it never hides the text.
	float grain = step(0.965, noise(floor(UV * vec2(190.0, 270.0)) + floor(TIME * 12.0))) * snow * 0.06;
	float light = max(shine, 0.0) + grain + flash * 0.12;
	float dark = line + corner;
	float a = clamp(light + dark, 0.0, 1.0);
	COLOR = vec4(vec3(0.75, 1.0, 0.95) * light / max(a, 0.001), a);
}
