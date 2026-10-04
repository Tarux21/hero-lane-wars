// Nachtwald: alter, verwilderter Pflasterweg statt der eckigen Lane-Fläche.
// Zerbrochene, schiefe Platten mit Fugen und Lücken, Moos, Wurzeln; die Ränder sind unregelmäßig und weich und gehen in Erde und Waldboden über.
// Zum Lane-Ende (Spawn) löst sich das Pflaster auf: Moos, Wurzeln und Erde laufen unter den Spawn-Baum, es gibt keine sichtbare Kante.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

uniform float center_x = 0.0;                   // Mitte der Lane (Welt-x)
uniform float half_w = 5.4;                     // halbe Lane-Breite in Metern
uniform float s_end = 147.5;                    // Entfernung der Startlinie der Monster von der Basis (m)
uniform vec3 slab_col : source_color = vec3(0.42, 0.40, 0.36);
uniform vec3 moss_col : source_color = vec3(0.13, 0.30, 0.13);
uniform vec3 dirt_col : source_color = vec3(0.13, 0.10, 0.08);
uniform vec3 root_col : source_color = vec3(0.09, 0.06, 0.05);

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
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
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
	float dx = p.x - center_x;
	float s = -p.y;                                        // Tiefe entlang der Lane in Metern (Basis = 0)
	float n1 = fbm(p * 0.30);
	float n2 = fbm(p * 1.10 + 5.0);
	float edge = half_w - 0.5 + (n1 - 0.5) * 2.8 + (n2 - 0.5) * 0.8;      // unregelmäßiger Rand
	float d = abs(dx) - edge;                              // < 0: innen

	// Ende: Pflaster löst sich zur Startlinie hin auf (unregelmäßig), Erde und Wurzeln laufen weiter
	float fade_s = s_end - 11.0 + (n1 - 0.5) * 8.0 + (n2 - 0.5) * 2.5;
	float endk = smoothstep(fade_s, fade_s + 9.0, s);
	float paved = smoothstep(0.6, -0.6, d) * (1.0 - endk);
	float widen = endk * 3.5;                              // am Ende wird die Erdfläche zu einer Lichtung um den Baum
	float dirt_a = smoothstep(2.6 + widen, -0.3, d) * (1.0 - smoothstep(s_end + 2.0, s_end + 8.0 + (n1 - 0.5) * 4.0, s));

	// Platten: versetzte Reihen, je Reihe andere Breite, abgerundete Ecken, schiefe Fugen
	float rowid = floor(p.y / 1.15);
	float wscale = 0.8 + 0.55 * hash21(vec2(rowid, 5.0));
	vec2 size = vec2(1.35 * wscale, 1.15);
	vec2 g = vec2(dx / size.x, p.y / size.y);
	g.x += hash21(vec2(rowid, 3.0)) * 4.0 + (hash21(vec2(rowid, 9.0)) - 0.5) * 0.3 * g.y;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float h = hash21(cell + 17.0);
	vec2 hs = size * 0.5;
	vec2 q = abs((f - 0.5) * size) - (hs - 0.16);
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 0.16;      // Abstand zur abgerundeten Plattenkante (innen < 0)
	float joint = 1.0 - smoothstep(-0.10, -0.03, sd);
	float missing = step(0.80, h);                          // fehlende Platte: Erde
	vec3 sc = slab_col * (0.72 + 0.55 * h) * (0.9 + 0.2 * vnoise(p * 7.0));
	float crack = smoothstep(0.012, 0.0, abs(vnoise(p * vec2(3.1, 2.7) + cell) - 0.5)) * step(0.5, h);
	sc *= 1.0 - 0.45 * crack;

	// Moos: an Fugen, am Rand und zum Ende hin stärker
	float mn = fbm(p * 0.85 + 11.0);
	float near_edge = smoothstep(-2.8, 0.0, d);
	float moss = smoothstep(0.42, 0.68, mn + near_edge * 0.26 + (1.0 - joint) * 0.22 + endk * 0.35);
	vec3 mc = moss_col * (0.7 + 0.6 * vnoise(p * 6.0));
	float slabvis = joint * (1.0 - missing) * paved;
	vec3 col = mix(sc, mc, moss * 0.88);
	vec3 dirt = dirt_col * (0.75 + 0.5 * fbm(p * 2.2));
	dirt = mix(dirt, mc * 0.8, smoothstep(0.55, 0.8, fbm(p * 0.7 + 3.0)) * (0.35 + 0.4 * near_edge));
	vec3 base = mix(dirt, col, slabvis);

	// Wurzeln: dünne dunkle Linien, am Rand und zum Ende hin dichter
	float rn = abs(fbm(p * vec2(0.75, 0.75) + 31.0) - 0.5);
	float rn2 = abs(fbm(p * vec2(1.3, 1.3) + 47.0) - 0.5);
	float root = max(smoothstep(0.024, 0.004, rn), smoothstep(0.018, 0.003, rn2) * 0.8);
	float root_amt = 0.25 + 0.55 * near_edge + 0.5 * endk;
	base = mix(base, root_col, clamp(root * root_amt, 0.0, 0.92));

	ALBEDO = base;
	ROUGHNESS = 0.95;
	ALPHA = clamp(max(dirt_a * 0.96, paved), 0.0, 1.0);
}
