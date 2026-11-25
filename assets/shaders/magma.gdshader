shader_type spatial;
render_mode unshaded;

// Crust plates with glowing cracks. Chunky, stepped, no smooth blends.
uniform vec3 crust : source_color = vec3(0.17, 0.05, 0.03);
uniform vec3 crack : source_color = vec3(1.0, 0.45, 0.07);
uniform vec3 hot : source_color = vec3(1.0, 0.8, 0.25);
uniform float pixel_m = 0.125;
uniform float plate_m = 0.9;
uniform float crack_w = 0.12;
uniform float flow_m = 0.25;
uniform float step_s = 0.5;

varying vec3 world_at;
varying vec3 world_up;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = floor(world_at.xz / pixel_m) * pixel_m;
	p.x += floor(TIME / step_s) * flow_m * 0.35;
	vec2 q = p / plate_m;
	vec2 cell = floor(q);
	vec2 local = fract(q);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 n = vec2(float(i), float(j));
			vec2 site = n + hash2(cell + n);
			float d = length(site - local);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = cell + n;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float edge = (d2 - d1) * plate_m;
	float pulse = step(0.5, fract(hash2(id).x + floor(TIME / step_s) * 0.25));
	vec3 rgb = crust * (0.7 + 0.6 * hash2(id).y);
	if (edge < crack_w) {
		rgb = mix(crack, hot, pulse * step(edge, crack_w * 0.45));
	}
	// Sides and walls stay dark.
	if (world_up.y < 0.5) {
		rgb = crust * 0.6;
	}
	ALBEDO = rgb * (0.85 + 0.3 * COLOR.r);
}
