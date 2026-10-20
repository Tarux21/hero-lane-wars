// Burgkarte: Bach zwischen den Teams. Geschwungenes Ufer (Mäander + Rauschen), Kiesstreifen am Rand, klares Wasser,
// sanfte Strömungslinien in Fließrichtung, heller Schaum am Ufer. Außerhalb des Kiesufers wird nichts gezeichnet (Wiese bleibt).
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform float river_x = 0.0;
uniform float half_w = 3.0;
uniform vec3 deep_c : source_color = vec3(0.06, 0.26, 0.30);
uniform vec3 shallow_c : source_color = vec3(0.30, 0.48, 0.38);
uniform vec3 gravel_c : source_color = vec3(0.55, 0.48, 0.36);
uniform float soft_edge = 1.0;          // 0 = gerader Kanal (alte Varianten), 1 = Bach mit Kiesufer
varying vec3 wpos;

float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }   // ohne sin(): keine Klötzchen bei großen Koordinaten
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int k = 0; k < 4; k++) { v += a * noise(p); p = p * 2.07 + 13.1; a *= 0.5; } return v; }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float meander = (sin(wpos.z * 0.09) * 0.7 + sin(wpos.z * 0.23 + 1.7) * 0.3) * soft_edge;   // Bach schlängelt sich leicht
	float cx = river_x + meander;
	float edge_n = (fbm(vec2(wpos.z * 0.35, 3.1)) - 0.5) * 1.1 * soft_edge;
	float d = abs(wpos.x - cx) - (half_w + edge_n);                                    // < 0: Wasser, 0..1,1: Kiesufer
	if (d > 1.1 * soft_edge) { discard; }
	float t = clamp(-d / half_w, 0.0, 1.0);                                            // 0 am Ufer, 1 in der Mitte
	vec3 water = mix(shallow_c, deep_c, smoothstep(0.0, 0.8, t));
	vec2 fp = vec2((wpos.x - cx) * 1.1, wpos.z * 0.22 + TIME * 0.35);               // Strömung zieht in Fließrichtung
	float flow = fbm(fp + vec2(fbm(fp * 0.7 + TIME * 0.05) * 1.5, 0.0));
	water += vec3(0.20, 0.26, 0.24) * smoothstep(0.55, 0.75, flow) * 0.55;
	float foam = smoothstep(0.35, 0.0, -d) * (0.5 + 0.5 * noise(vec2(wpos.z * 1.6 + TIME * 0.8, wpos.x * 3.0))) * soft_edge;
	water = mix(water, vec3(0.80, 0.86, 0.82), foam * 0.45);
	vec3 gravel = gravel_c * (0.75 + 0.45 * noise(wpos.xz * 5.5)) * (0.85 + 0.2 * noise(wpos.xz * 1.3));
	gravel *= mix(1.0, 0.72, smoothstep(1.1, 0.0, d) * 0.6);                          // nasser Kies dunkler
	float is_water = step(d, 0.0);
	ALBEDO = mix(gravel, water, is_water);
	ROUGHNESS = mix(0.95, 0.08, is_water);
	SPECULAR = mix(0.2, 0.7, is_water);
}
