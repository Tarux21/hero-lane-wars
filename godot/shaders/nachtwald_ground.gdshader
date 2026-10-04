// Nachtwald: Waldboden statt einfarbiger Fläche. Dunkle Erde mit Laub, Moosflecken, kleinen Steinchen und Zweigen (alles aus Rauschen, ohne Texturdateien).
shader_type spatial;

uniform vec3 soil : source_color = vec3(0.075, 0.062, 0.095);
uniform vec3 soil2 : source_color = vec3(0.11, 0.085, 0.10);
uniform vec3 leaf : source_color = vec3(0.17, 0.11, 0.09);
uniform vec3 leaf2 : source_color = vec3(0.21, 0.15, 0.08);
uniform vec3 moss : source_color = vec3(0.07, 0.15, 0.09);
uniform vec3 twig : source_color = vec3(0.05, 0.04, 0.04);

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
	// Grundton: Erde in großen und mittleren Flecken
	vec3 col = mix(soil, soil2, smoothstep(0.35, 0.7, fbm(p * 0.12)));
	col *= 0.85 + 0.3 * fbm(p * 1.7);
	// Laub: kleine Blätter (Zellen mit zufälliger Form), in Haufen dichter
	vec2 lc = floor(p * 3.2);
	vec2 lf = fract(p * 3.2) - 0.5;
	float lh = hash21(lc);
	float ang = lh * 6.283;
	vec2 lr = vec2(cos(ang) * lf.x - sin(ang) * lf.y, sin(ang) * lf.x + cos(ang) * lf.y);
	float leaf_shape = 1.0 - smoothstep(0.18, 0.24, length(lr * vec2(1.0, 2.1)));
	float heap = smoothstep(0.42, 0.7, fbm(p * 0.35 + 7.0));
	float leaves = leaf_shape * step(1.0 - (0.25 + 0.55 * heap), hash21(lc + 3.0));
	col = mix(col, mix(leaf, leaf2, hash21(lc + 9.0)) * (0.7 + 0.5 * lh), leaves * 0.85);
	// Moosflecken
	float m = smoothstep(0.52, 0.72, fbm(p * 0.45 + 21.0));
	col = mix(col, moss * (0.75 + 0.5 * vnoise(p * 5.0)), m * 0.8);
	// Zweige: kurze dunkle Linien
	vec2 tc = floor(p * 0.9);
	vec2 tf = fract(p * 0.9) - 0.5;
	float ta = hash21(tc + 5.0) * 6.283;
	vec2 td = vec2(cos(ta), sin(ta));
	float along = dot(tf, td);
	float across = abs(dot(tf, vec2(-td.y, td.x)));
	float tw = (1.0 - smoothstep(0.012, 0.025, across)) * (1.0 - smoothstep(0.22, 0.3, abs(along))) * step(0.6, hash21(tc + 2.0));
	col = mix(col, twig, tw * 0.9);
	// Steinchen
	vec2 sc = floor(p * 1.6);
	float sh = hash21(sc + 11.0);
	float stone = (1.0 - smoothstep(0.06, 0.1, length(fract(p * 1.6) - 0.5 - (vec2(hash21(sc), hash21(sc + 1.0)) - 0.5) * 0.5))) * step(0.86, sh);
	col = mix(col, vec3(0.16, 0.15, 0.17) * (0.8 + 0.4 * sh), stone);
	ALBEDO = col;
	ROUGHNESS = 0.97;
}
