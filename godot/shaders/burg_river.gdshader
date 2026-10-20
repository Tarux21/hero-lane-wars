// Burgkarte: klarer Stadtfluss zwischen den Teams, fließt sanft (helle Wellenlinien), dunkler zur Mitte.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform float river_x = 0.0;
uniform float half_w = 2.5;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float d = clamp(abs(wpos.x - river_x) / half_w, 0.0, 1.0);
	vec3 deep = vec3(0.07, 0.30, 0.42);
	vec3 shallow = vec3(0.22, 0.52, 0.55);
	vec3 col = mix(deep, shallow, d * d);
	vec2 p = vec2(wpos.x * 1.3, wpos.z * 0.35 + TIME * 0.9);
	float w = noise(p * 1.7) * noise(p * 0.8 + 3.0);
	col += vec3(0.55, 0.65, 0.6) * smoothstep(0.42, 0.6, w) * 0.5;
	ALBEDO = col;
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
