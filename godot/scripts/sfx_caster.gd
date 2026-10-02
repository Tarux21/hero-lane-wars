extends RefCounted
## Klänge der Caster-Fähigkeiten (Feuer, Frost, Blitz, Elementare). Werden beim Start aus Rauschen und Schwingungen
## berechnet, keine Audiodateien. Jeder Klang besteht aus Schichten (Rauschen, Ton, Knistern, Wumms), die einzeln
## auf gleiche Lautstärke gebracht und dann gemischt werden.

const RATE := 22050

const NAMES := ["fire_cast", "fire_ignite", "meteor_fall", "meteor_hit", "frost_cast", "frost_zone", "zap", "zap_crit",
	"summon_fire", "summon_frost", "summon_lightning", "flame_jet", "elem_vanish", "elem_shot_fire", "elem_shot_frost", "elem_shot_lightning", "caster_shot"]
const GAPS := {"caster_shot": 0.12, "zap": 0.03, "zap_crit": 0.03, "elem_shot_fire": 0.15, "elem_shot_frost": 0.15, "elem_shot_lightning": 0.15, "fire_ignite": 0.2}


static func build(name: String) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var dur := 1.0
	var parts: Array = []                        # [Schicht, Start (s), Lautstärke]
	match name:
		"fire_cast":
			dur = 0.85
			parts = [[_noise(rng, 0.65, 400, 2600, 0.5, 0.3, 2.5), 0.0, 0.7], [_tone(0.5, 150, 70, "sawtooth", 0.02, 4.0), 0.0, 0.35],
				[_crackle(rng, 0.6, 60, 20, 3.0), 0.15, 0.35]]
		"fire_ignite":
			dur = 1.2
			parts = [[_boom(0.6, 90, 38, 5.0), 0.0, 0.8], [_noise(rng, 0.5, 1400, 160, 0.6, 0.005, 5.0), 0.0, 0.6],
				[_crackle(rng, 0.95, 90, 25, 2.0), 0.05, 0.5], [_rumble(rng, 0.8, 250, 0.03, 3.0), 0.0, 0.4]]
		"meteor_fall":
			dur = 0.95
			parts = [[_tone(0.9, 1600, 280, "sine", 0.1, 0.6, 6.0, 0.02), 0.0, 0.25], [_noise(rng, 0.9, 250, 2200, 0.6, 0.8, 0.0), 0.0, 0.55],
				[_rumble(rng, 0.9, 150, 0.8, 0.0), 0.0, 0.3]]
		"meteor_hit":
			dur = 1.9
			parts = [[_boom(1.4, 70, 22, 3.0), 0.0, 1.0], [_noise(rng, 1.0, 2200, 90, 0.7, 0.003, 3.5), 0.0, 0.8],
				[_rumble(rng, 1.7, 180, 0.05, 2.0), 0.0, 0.6], [_crackle(rng, 1.5, 70, 12, 2.0), 0.1, 0.4]]
		"frost_cast":                                   # Kältekegel (wie WoW): eisiger Luftstoß, knackendes Eis, dumpfer Schlag
			dur = 1.05
			parts = [[_noise(rng, 0.75, 3600, 1300, 0.6, 0.03, 2.4), 0.0, 0.85], [_noise(rng, 0.5, 4400, 2400, 0.5, 0.02, 4.0), 0.02, 0.35],
				[_ice_crackle(rng, 0.9, 180, 25, 2.2), 0.05, 0.55], [_tone(0.3, 130, 55, "sine", 0.004, 4.5), 0.0, 0.5],
				[_noise(rng, 0.35, 3000, 1500, 0.5, 0.02, 4.0), 0.22, 0.3],
				[_tone(0.25, 1850, 1700, "sine", 0.002, 7.0, 0.0, 0.0, 22.0, 0.5), 0.12, 0.08], [_tone(0.2, 2650, 2400, "sine", 0.002, 8.0), 0.2, 0.06]]
		"frost_zone":
			dur = 0.9
			parts = [[_noise(rng, 0.6, 3800, 1800, 0.55, 0.05, 3.0), 0.0, 0.4], [_ice_crackle(rng, 0.8, 120, 20, 2.0), 0.0, 0.6], [_tone(0.25, 110, 60, "sine", 0.004, 5.0), 0.0, 0.4],
				[_tone(0.2, 2100, 1950, "sine", 0.002, 8.0), 0.1, 0.07]]
		"zap":
			dur = 0.4
			parts = [[_noise(rng, 0.12, 6500, 700, 0.5, 0.002, 5.0), 0.0, 0.8], [_tone(0.3, 140, 90, "sawtooth", 0.002, 6.0, 0.0, 0.0, 90.0, 0.8), 0.0, 0.35],
				[_tone(0.1, 2400, 500, "square", 0.001, 6.0), 0.0, 0.2], [_crackle(rng, 0.3, 120, 30, 2.0), 0.0, 0.4]]
		"zap_crit":
			dur = 0.65
			parts = [[_noise(rng, 0.16, 7000, 600, 0.5, 0.002, 5.0), 0.0, 0.9], [_tone(0.4, 160, 80, "sawtooth", 0.002, 5.0, 0.0, 0.0, 90.0, 0.8), 0.0, 0.4],
				[_tone(0.35, 3200, 1200, "sine", 0.002, 5.0), 0.0, 0.2], [_boom(0.3, 110, 45, 6.0), 0.0, 0.6], [_crackle(rng, 0.5, 140, 30, 2.0), 0.0, 0.5]]
		"summon_fire":
			dur = 1.7
			parts = [[_noise(rng, 1.2, 200, 1400, 0.6, 0.8, 1.0), 0.0, 0.35], [_crackle(rng, 1.2, 40, 100, 0.0), 0.3, 0.3],
				[_boom(0.7, 100, 40, 5.0), 0.85, 0.8], [_noise(rng, 0.4, 1800, 300, 0.6, 0.003, 5.0), 0.85, 0.6]]
			for fr in [98.0, 147.0, 196.0]:
				parts.append([_tone(1.4, fr, fr, "triangle", 0.7, 1.5), 0.0, 0.3])
		"summon_frost":
			dur = 1.7
			parts = [[_noise(rng, 1.2, 4000, 8000, 0.4, 0.8, 1.0), 0.0, 0.2], [_noise(rng, 0.05, 6000, 5000, 0.5, 0.001, 8.0), 0.85, 0.5]]
			for fr in [392.0, 587.0, 784.0, 1175.0]:
				parts.append([_tone(1.4, fr, fr, "sine", 0.7, 1.2, 0.0, 0.0, 6.0, 0.3), 0.0, 0.22])
			parts.append([_ice_crackle(rng, 0.8, 160, 30, 2.0), 0.85, 0.5])
			parts.append([_tone(0.3, 130, 55, "sine", 0.004, 4.5), 0.85, 0.5])
		"summon_lightning":
			dur = 1.7
			parts = [[_noise(rng, 1.2, 300, 5000, 0.5, 0.85, 1.0), 0.0, 0.3], [_boom(0.5, 110, 45, 6.0), 0.85, 0.6]]
			for fr in [110.0, 165.0]:
				parts.append([_tone(1.4, fr, fr, "sawtooth", 0.7, 1.5, 0.0, 0.0, 40.0, 0.6), 0.0, 0.25])
			for i in 3:
				parts.append([_noise(rng, 0.12, 6500, 700, 0.5, 0.002, 5.0), 0.85 + i * 0.1, 0.8])
				parts.append([_crackle(rng, 0.25, 120, 30, 2.0), 0.85 + i * 0.1, 0.4])
		"flame_jet":
			dur = 0.95
			parts = [[_noise(rng, 0.85, 900, 500, 0.5, 0.08, 1.5), 0.0, 0.7], [_crackle(rng, 0.8, 100, 30, 1.0), 0.0, 0.4], [_rumble(rng, 0.8, 220, 0.05, 1.5), 0.0, 0.3]]
		"elem_vanish":
			dur = 0.6
			parts = [[_tone(0.5, 500, 120, "sine", 0.01, 4.0), 0.0, 0.3], [_noise(rng, 0.4, 3000, 400, 0.6, 0.01, 4.0), 0.0, 0.4]]
		"caster_shot":
			dur = 0.22
			parts = [[_noise(rng, 0.18, 700, 1900, 0.6, 0.04, 3.5), 0.0, 0.7], [_tone(0.14, 260, 140, "triangle", 0.01, 5.0), 0.0, 0.25], [_crackle(rng, 0.15, 80, 40, 2.0), 0.03, 0.2]]
		"elem_shot_fire":
			dur = 0.25
			parts = [[_noise(rng, 0.2, 1000, 350, 0.6, 0.005, 4.0), 0.0, 0.6], [_tone(0.15, 300, 120, "sawtooth", 0.005, 5.0), 0.0, 0.25]]
		"elem_shot_frost":
			dur = 0.25
			parts = [[_tone(0.2, 3200, 2000, "sine", 0.002, 6.0), 0.0, 0.3], [_noise(rng, 0.1, 6000, 3000, 0.4, 0.002, 6.0), 0.0, 0.4]]
		"elem_shot_lightning":
			dur = 0.25
			parts = [[_noise(rng, 0.1, 5000, 1000, 0.5, 0.002, 5.0), 0.0, 0.6], [_tone(0.2, 180, 100, "sawtooth", 0.002, 6.0, 0.0, 0.0, 80.0, 0.8), 0.0, 0.2]]
	var buf := PackedFloat32Array()
	buf.resize(int(dur * RATE) + 64)
	for p in parts:
		_add(buf, p[0], float(p[1]), float(p[2]))
	var peak := 0.0001
	for v in buf:
		peak = maxf(peak, absf(v))
	for i in buf.size():                           # weich begrenzen, auf 0,85 aussteuern
		buf[i] = tanh(buf[i] / peak * 1.3) / tanh(1.3) * 0.85
	for i in mini(96, buf.size()):                  # kurzes Ausblenden am Ende (kein Knacken)
		buf[buf.size() - 1 - i] *= float(i) / 96.0
	return buf


static func _add(buf: PackedFloat32Array, layer: PackedFloat32Array, start_s: float, vol: float) -> void:
	var s := int(start_s * RATE)
	for i in layer.size():
		if s + i >= buf.size():
			break
		buf[s + i] += layer[i] * vol


static func _norm(b: PackedFloat32Array) -> PackedFloat32Array:
	var peak := 0.0001
	for v in b:
		peak = maxf(peak, absf(v))
	for i in b.size():
		b[i] /= peak
	return b


static func _env(i: int, count: int, att: float, tail: float) -> float:
	var a := minf(1.0, float(i) / maxf(1.0, att * RATE))
	return a * exp(-tail * float(i) / float(count))


## Bandpass-Rauschen mit wanderndem Frequenzband. damp: kleiner = schmaler (klingender)
static func _noise(rng: RandomNumberGenerator, dur: float, f0: float, f1: float, damp: float, att: float, tail: float) -> PackedFloat32Array:
	var count := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(count)
	var lp := 0.0
	var bp := 0.0
	for i in count:
		var f := f0 * pow(maxf(40.0, f1) / f0, float(i) / float(count))
		var k := 2.0 * sin(PI * minf(f, RATE * 0.22) / RATE)           # obere Grenze: darüber wird das Filter instabil
		var hp := (rng.randf() * 2.0 - 1.0) - lp - maxf(0.45, damp) * bp
		bp += k * hp
		lp += k * bp
		b[i] = bp * _env(i, count, att, tail)
	return _norm(b)


static func _tone(dur: float, f0: float, f1: float, form: String, att: float, tail: float, vib_hz: float = 0.0, vib_depth: float = 0.0, am_hz: float = 0.0, am_depth: float = 0.0) -> PackedFloat32Array:
	var count := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(count)
	var phase := 0.0
	for i in count:
		var tt := float(i) / RATE
		var f := f0 * pow(maxf(20.0, f1) / f0, float(i) / float(count))
		if vib_hz > 0.0:
			f *= 1.0 + vib_depth * sin(TAU * vib_hz * tt)
		phase += f / RATE
		var ph := phase - floorf(phase)
		var s := 0.0
		match form:
			"sine": s = sin(ph * TAU)
			"square": s = 1.0 if ph < 0.5 else -1.0
			"sawtooth": s = 2.0 * ph - 1.0
			"triangle": s = 4.0 * absf(ph - 0.5) - 1.0
		var am := 1.0
		if am_hz > 0.0:
			am = 1.0 - am_depth * (0.5 + 0.5 * sin(TAU * am_hz * tt))
		b[i] = s * am * _env(i, count, att, tail)
	return _norm(b)


## Knistern: zufällige kurze Knacker, Dichte (pro Sekunde) wandert von rate0 nach rate1
static func _crackle(rng: RandomNumberGenerator, dur: float, rate0: float, rate1: float, tail: float) -> PackedFloat32Array:
	var count := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(count)
	var i := 0
	while i < count:
		var f := float(i) / float(count)
		var rate := lerpf(rate0, rate1, f)
		var amp := rng.randf_range(0.2, 1.0) * exp(-tail * f)
		var len := rng.randi_range(8, 60)
		var sgn := 1.0 if rng.randf() < 0.5 else -1.0
		for j in len:
			if i + j >= count:
				break
			b[i + j] += sgn * amp * exp(-5.0 * float(j) / len) * (rng.randf() * 1.2 - 0.2)
		i += int(maxf(1.0, -log(maxf(0.001, rng.randf())) / maxf(1.0, rate) * RATE))
	return _norm(b)


## Eisknistern: sehr kurze, helle Knacker (Dichte wandert von rate0 nach rate1)
static func _ice_crackle(rng: RandomNumberGenerator, dur: float, rate0: float, rate1: float, tail: float) -> PackedFloat32Array:
	var count := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(count)
	var i := 0
	while i < count:
		var f := float(i) / float(count)
		var rate := lerpf(rate0, rate1, f)
		var amp := rng.randf_range(0.25, 1.0) * exp(-tail * f)
		var len := rng.randi_range(3, 12)
		var sgn := 1.0 if rng.randf() < 0.5 else -1.0
		for j in len:
			if i + j >= count:
				break
			b[i + j] += sgn * amp * exp(-3.0 * float(j) / len) * (1.0 if j % 2 == 0 else -0.7)
		i += int(maxf(1.0, -log(maxf(0.001, rng.randf())) / maxf(1.0, rate) * RATE))
	return _norm(b)


## Wumms: abfallender Sinus mit Sättigung
static func _boom(dur: float, f0: float, f1: float, tail: float) -> PackedFloat32Array:
	var count := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(count)
	var phase := 0.0
	for i in count:
		var f := f0 * pow(f1 / f0, float(i) / float(count))
		phase += f / RATE
		b[i] = tanh(2.2 * sin(phase * TAU)) * _env(i, count, 0.002, tail)
	return _norm(b)


## Dumpfes Grollen: tiefpassgefiltertes Rauschen
static func _rumble(rng: RandomNumberGenerator, dur: float, f: float, att: float, tail: float) -> PackedFloat32Array:
	var count := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(count)
	var a := 1.0 - exp(-TAU * f / RATE)
	var y := 0.0
	var y2 := 0.0
	for i in count:
		y += a * ((rng.randf() * 2.0 - 1.0) - y)
		y2 += a * (y - y2)
		b[i] = y2 * _env(i, count, att, tail)
	return _norm(b)
