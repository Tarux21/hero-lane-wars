// Burgkarte: sonnige Wiese (goldgrün, weiche Farbflecken, feine Körnung), wie im Referenzbild.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 gold : source_color = vec3(0.56, 0.52, 0.22);
uniform vec3 green : source_color = vec3(0.30, 0.45, 0.14);
uniform vec3 dark : source_color = vec3(0.22, 0.32, 0.10);

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int k = 0; k < 4; k++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz;
	float big = fbm(p * 0.035);
	float mid = fbm(p * 0.18 + 7.0);
	vec3 c = mix(green, gold, smoothstep(0.35, 0.68, big));
	c = mix(c, dark, smoothstep(0.62, 0.85, mid) * 0.45);
	c *= 0.9 + 0.2 * noise(p * 3.1);                       // Grashalm-Körnung
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
