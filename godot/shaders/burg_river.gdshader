// Burgkarte: klarer Stadtfluss zwischen den Teams, fließt sanft (helle Wellenlinien), dunkler zur Mitte.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform float river_x = 0.0;
uniform float half_w = 2.5;
uniform vec3 deep_c : source_color = vec3(0.05, 0.20, 0.30);
uniform vec3 shallow_c : source_color = vec3(0.14, 0.36, 0.42);
uniform float soft_edge = 0.0;          // Bach: Rand läuft weich in den Kiesgrund aus
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float d = clamp(abs(wpos.x - river_x) / half_w, 0.0, 1.0);
	vec3 deep = deep_c;
	vec3 shallow = shallow_c;
	vec3 col = mix(deep, shallow, d * d);
	vec2 p = vec2(wpos.x * 1.3, wpos.z * 0.35 + TIME * 0.9);
	float w = noise(p * 1.7) * noise(p * 0.8 + 3.0);
	col += vec3(0.45, 0.55, 0.55) * smoothstep(0.45, 0.62, w) * 0.35;
	if (soft_edge > 0.5) {
		float e = smoothstep(0.78, 1.15, abs(wpos.x - river_x) / half_w + (noise(wpos.xz * 0.9) - 0.5) * 0.25);
		col = mix(col, vec3(0.50, 0.44, 0.32) * (0.85 + 0.3 * noise(wpos.xz * 4.0)), e);
	}
	ALBEDO = col;
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
