// Nachtwald: Giftfluss zwischen den Teams (statt Lava). Fließendes, leuchtendes Gift mit weichen, schlammigen Ufern.
// Nahe der Basis gabelt er sich: ein Seitenarm biegt zur eigenen Seite (kleineres x) aus und fließt wieder zurück.
// Zwischen Hauptfluss und Seitenarm liegt die Insel mit dem Giftbrunnen (Pool der gesendeten Monster).
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

uniform float river_x = 0.0;
uniform float half_w = 2.5;
uniform float fork_z0 = -14.0;                  // Beginn der Gabelung (näher an der Basis)
uniform float fork_z1 = -36.0;                  // Ende der Gabelung
uniform float arm_off = 9.5;                    // so weit biegt der Seitenarm aus (Mitte der Gabelung)
uniform float arm_half = 1.7;
uniform float glow = 0.55;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = wpos.xz;
	float en = (fbm(p * 0.55) - 0.5) * 0.9;
	float d = abs(p.x - river_x) - (half_w + en);
	float t = clamp((fork_z0 - p.y) / (fork_z0 - fork_z1), 0.0, 1.0);
	if (p.y < fork_z0 && p.y > fork_z1) {
		float off = arm_off * pow(sin(t * PI), 0.6);
		float da = abs(p.x - (river_x - off)) - (arm_half + en * 0.6);
		d = min(d, da);
	}
	float a = smoothstep(0.45, -0.35, d);
	float flow = fbm(vec2(p.x * 0.8, p.y * 0.3 - TIME * 0.5));
	float foam = smoothstep(0.56, 0.78, fbm(vec2(p.x * 1.7, p.y * 0.7 - TIME * 0.9) + 3.0));
	vec2 bc = floor(p * 3.0);
	float bub = step(0.97, hash21(bc + floor(TIME * 1.2 + hash21(bc) * 4.0))) * (1.0 - smoothstep(0.12, 0.3, length(fract(p * 3.0) - 0.5))) * smoothstep(-0.3, -1.2, d);   // runde Blasen
	vec3 deep = vec3(0.04, 0.22, 0.05);
	vec3 bright = vec3(0.42, 1.0, 0.22);
	vec3 col = mix(deep, bright, flow * 0.55 + foam * 0.5 + bub);
	float bank = smoothstep(-0.9, 0.25, d);                // schlammiger Rand
	col = mix(col, vec3(0.06, 0.09, 0.04), bank * 0.85);
	ALBEDO = col;
	EMISSION = col * (0.7 + 1.3 * foam + 2.0 * bub) * (1.0 - bank * 0.8) * glow;
	ROUGHNESS = 0.25;
	ALPHA = a;
}
