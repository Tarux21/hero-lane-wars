// Burgkarte, Lane-Boden: Kopfsteinpflaster in Burghof und Stadt (z > town_end), danach Feldweg aus Erde mit Grasrändern.
// Weiche Ränder zur Wiese; die Fläche ist breiter als die Lane (Ränder laufen aus).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, depth_prepass_alpha;

uniform float center_x = 0.0;
uniform float half_w = 5.4;
uniform float town_end = -52.0;      // ab hier (weiter weg) Feldweg
uniform float court_z = 1.5;         // ab hier (zur Basis hin) Burghof: Pflaster über die ganze Breite

varying vec3 wpos;

vec2 h2(vec2 p) { p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3))); return fract(sin(p) * 43758.5453); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
// Voronoi: Abstand zur Fuge (x) und Zufallswert der Zelle (y)
vec2 cells(vec2 p) {
	vec2 n = floor(p); vec2 f = fract(p);
	float d1 = 8.0; float d2 = 8.0; vec2 id = vec2(0.0);
	for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j));
		vec2 o = h2(n + g) * 0.85;
		vec2 r = g + o - f;
		float d = dot(r, r);
		if (d < d1) { d2 = d1; d1 = d; id = n + g; } else if (d < d2) { d2 = d; }
	}
	return vec2(sqrt(d2) - sqrt(d1), hash(id));
}

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz;
	float dx = abs(wpos.x - center_x);
	float edge_n = noise(p * 0.7) * 1.2;
	bool court = wpos.z > court_z;
	float town = smoothstep(town_end - 3.0, town_end + 3.0, wpos.z);
	// Pflaster
	vec2 c = cells(p * 1.35);
	float joint = smoothstep(0.02, 0.09, c.x);
	vec3 stone = mix(vec3(0.46, 0.42, 0.37), vec3(0.70, 0.64, 0.54), c.y) * (0.9 + 0.15 * noise(p * 6.0));
	vec3 cob = mix(vec3(0.24, 0.21, 0.17), stone, joint);
	// Feldweg
	vec3 dirt = mix(vec3(0.55, 0.42, 0.25), vec3(0.68, 0.55, 0.34), noise(p * 0.4)) * (0.9 + 0.15 * noise(p * 4.0));
	float rut = smoothstep(0.6, 0.0, abs(abs(wpos.x - center_x) - half_w * 0.45)) * 0.12;   // Fahrspuren
	dirt *= 1.0 - rut;
	vec3 col = mix(dirt, cob, court ? 1.0 : town);
	float half_here = court ? 40.0 : (half_w + mix(0.6, 0.15, town));
	float a = 1.0 - smoothstep(half_here - 0.6 - edge_n * (1.0 - town), half_here + 0.4, dx);
	ALBEDO = col;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.95;
}
