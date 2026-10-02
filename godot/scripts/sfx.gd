extends RefCounted
## Sounds: werden beim Start aus einfachen Schwingungen und Rauschen erzeugt (keine Audiodateien nötig).
## Die Klänge entsprechen dem Browser-Prototyp (index.html: SFX, tone, noise).

const RATE := 22050
const SfxCaster := preload("res://scripts/sfx_caster.gd")
# Name -> [Mindestabstand in s, Stimmen]. Stimme: ["t", f0, f1, dauer, form, lautstärke, verzögerung] oder ["n", dauer, f0, f1, lautstärke, verzögerung]
const DEFS := {
	"hit":   [0.05, [["n", 0.07, 1800, 600, 0.22, 0.0]]],
	"crit":  [0.05, [["n", 0.10, 2500, 700, 0.30, 0.0], ["t", 900, 1500, 0.12, "square", 0.12, 0.0]]],
	"kill":  [0.04, [["t", 420, 160, 0.09, "triangle", 0.22, 0.0]]],
	"hurt":  [0.12, [["t", 160, 60, 0.18, "sawtooth", 0.28, 0.0], ["n", 0.12, 400, 120, 0.20, 0.0]]],
	"die":   [0.5,  [["t", 260, 40, 0.7, "sawtooth", 0.30, 0.0], ["n", 0.5, 600, 80, 0.25, 0.0]]],
	"level": [0.3,  [["t", 523, 523, 0.22, "triangle", 0.22, 0.0], ["t", 659, 659, 0.22, "triangle", 0.22, 0.08], ["t", 784, 784, 0.22, "triangle", 0.22, 0.16], ["t", 1047, 1047, 0.22, "triangle", 0.22, 0.24]]],
	"leak":  [0.2,  [["t", 330, 150, 0.28, "square", 0.20, 0.0], ["t", 250, 110, 0.30, "square", 0.20, 0.12]]],
	"wave":  [0.5,  [["t", 196, 196, 0.45, "sawtooth", 0.16, 0.0], ["t", 247, 247, 0.45, "sawtooth", 0.12, 0.0]]],
	"boss":  [0.5,  [["t", 90, 50, 0.8, "sawtooth", 0.32, 0.0], ["n", 0.6, 300, 60, 0.30, 0.0]]],
	"send":  [0.05, [["t", 520, 780, 0.08, "square", 0.12, 0.0], ["t", 780, 1040, 0.08, "square", 0.10, 0.06]]],
	"heal":  [0.2,  [["t", 500, 800, 0.25, "sine", 0.20, 0.0], ["t", 700, 1100, 0.25, "sine", 0.15, 0.08]]],
	"win":   [1.0,  [["t", 523, 523, 0.3, "triangle", 0.26, 0.0], ["t", 659, 659, 0.3, "triangle", 0.26, 0.12], ["t", 784, 784, 0.3, "triangle", 0.26, 0.24], ["t", 1047, 1047, 0.3, "triangle", 0.26, 0.36], ["t", 1319, 1319, 0.3, "triangle", 0.26, 0.48]]],
	"lose":  [1.0,  [["t", 392, 353, 0.4, "sawtooth", 0.20, 0.0], ["t", 330, 297, 0.4, "sawtooth", 0.20, 0.18], ["t", 262, 236, 0.4, "sawtooth", 0.20, 0.36], ["t", 196, 176, 0.4, "sawtooth", 0.20, 0.54]]],
}

var streams: Dictionary = {}
var last: Dictionary = {}
var players: Array = []
var next_player := 0
var volume := 0.7                     # 0..1
var node: Node


func _init(host: Node) -> void:
	node = host
	for k in DEFS.keys():
		streams[k] = _make(DEFS[k][1])
	# "cast" gibt es je Skill-Platz in 4 Klangfarben
	for i in 4:
		streams["cast%d" % i] = _make([["n", 0.22, 300 + i * 250, maxf(60.0, 1800 - i * 200), 0.30, 0.0], ["t", 240 + i * 90, 500 + i * 160, 0.2, "sine", 0.15, 0.0]])
	for nm in SfxCaster.NAMES:
		streams[nm] = _wav(SfxCaster.build(nm))
	for i in 12:
		var pl := AudioStreamPlayer.new()
		host.add_child(pl)
		players.append(pl)


## Erzeugt aus den Stimmen einen Klang als 16-Bit-Mono-Stream
func _make(voices: Array) -> AudioStreamWAV:
	var total := 0.0
	for v in voices:
		var dur: float = v[3] if v[0] == "t" else v[1]
		var delay: float = v[6] if v[0] == "t" else v[5]
		total = maxf(total, dur + delay)
	var n := int(total * RATE) + 64
	var buf := PackedFloat32Array()
	buf.resize(n)
	for v in voices:
		if v[0] == "t":
			_tone(buf, float(v[1]), float(v[2]), float(v[3]), str(v[4]), float(v[5]), float(v[6]))
		else:
			_noise(buf, float(v[1]), float(v[2]), float(v[3]), float(v[4]), float(v[5]))
	return _wav(buf)


func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var n := buf.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var s := int(clampf(buf[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


func _env(i: int, count: int, vol: float) -> float:
	# exponentieller Abfall von vol auf 0,0001 (wie im Prototyp)
	return vol * pow(0.0001 / vol, float(i) / float(maxi(1, count)))


func _tone(buf: PackedFloat32Array, f0: float, f1: float, dur: float, form: String, vol: float, delay: float) -> void:
	var start := int(delay * RATE)
	var count := int(dur * RATE)
	var phase := 0.0
	for i in count:
		if start + i >= buf.size():
			break
		var f := f0 * pow(maxf(20.0, f1) / f0, float(i) / float(count))
		phase += f / RATE
		var ph := phase - floorf(phase)
		var s := 0.0
		match form:
			"sine": s = sin(ph * TAU)
			"square": s = 1.0 if ph < 0.5 else -1.0
			"sawtooth": s = 2.0 * ph - 1.0
			"triangle": s = 4.0 * absf(ph - 0.5) - 1.0
		buf[start + i] += s * _env(i, count, vol) * 0.6


func _noise(buf: PackedFloat32Array, dur: float, f0: float, f1: float, vol: float, delay: float) -> void:
	var start := int(delay * RATE)
	var count := int(dur * RATE)
	var lp := 0.0
	var bp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in count:
		if start + i >= buf.size():
			break
		var f := f0 * pow(maxf(40.0, f1) / f0, float(i) / float(count))
		var k := 2.0 * sin(PI * minf(f, RATE * 0.4) / RATE)           # Zustandsfilter: Bandpass um die wandernde Frequenz
		var white := rng.randf() * 2.0 - 1.0
		var hp := white - lp - 0.8 * bp
		bp += k * hp
		lp += k * bp
		buf[start + i] += bp * _env(i, count, vol) * 1.2


func play(name: String, vol: float = 1.0, pitch: float = 1.0) -> void:
	if volume <= 0.0 or not streams.has(name):
		return
	var min_gap: float = DEFS[name][0] if DEFS.has(name) else float(SfxCaster.GAPS.get(name, 0.08))
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last.get(name, 0.0)) < min_gap:
		return
	last[name] = now
	var pl: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	pl.stream = streams[name]
	pl.volume_db = linear_to_db(clampf(volume * vol, 0.01, 1.0))
	pl.pitch_scale = pitch
	pl.play()
