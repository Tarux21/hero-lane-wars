extends SceneTree
## Titanenstoß-Sound des Tanks (Erdbeben-Kegel):
## 1) CC0-Mix (für das Spiel): zweite Explosion aus "Beefy Explosions" (SamsterBirdies, CC0) gedämpft + selbst berechnetes
##    Zischen, langes Grollen, Steinknistern. Schreibt godot/assets/sounds/tank_r.wav und Sounds/Vorschlag-Titanenstoss-CC0-Mix.wav.
## 2) Nur zum Vergleich anhören (NICHT im Spiel, Lizenz unklar): der Artninja-Sound, in die Länge gezogen (langsamer + Hall).
##    Schreibt Sounds/Vorschau-Artninja-Titanstoss-gestreckt.wav.
## Aufruf: Godot --headless --path godot --script res://tools/mix_tank_r.gd
const SfxCaster := preload("res://scripts/sfx_caster.gd")
const OUT := 44100


func _init() -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../Sounds")
	var samster := ""
	var artninja := ""
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("745549"):
			samster = dir.path_join(f)
		if f.begins_with("833371"):
			artninja = dir.path_join(f)
	if samster == "":
		print("FEHLER: Explosions-Datei 745549... fehlt in Sounds/")
		quit()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 9753
	# --- CC0-Mix
	var raw := _read_mono(samster)
	var expl: PackedFloat32Array = raw.slice(int(3.95 * OUT), int(6.2 * OUT))        # zweite Explosion
	var thud := _lowpass(expl, 600.0)
	var punch := PackedFloat32Array()
	punch.resize(int(0.3 * OUT))
	for i in punch.size():
		punch[i] = expl[i] * exp(-8.0 * float(i) / (0.3 * OUT))
	var whoosh := _up(SfxCaster._noise(rng, 1.4, 350.0, 2400.0, 0.55, 0.35, 1.4))             # steigend, dann ausklingend
	var rumble := _up(SfxCaster._rumble(rng, 2.8, 110.0, 0.02, 1.6))                           # langes Beben
	var boom := _up(SfxCaster._boom(1.4, 75.0, 28.0, 2.6))
	var debris := _lowpass(_up(SfxCaster._crackle(rng, 2.2, 55.0, 10.0, 1.2)), 1800.0)
	var buf := PackedFloat32Array()
	buf.resize(int(3.0 * OUT))
	var t0 := 0.12
	_add(buf, whoosh, 0.0, 0.45)
	_add(buf, thud, t0, 0.9)
	_add(buf, punch, t0, 1.1)
	_add(buf, boom, t0, 0.9)
	_add(buf, rumble, t0, 0.6)
	_add(buf, debris, t0 + 0.2, 0.3)
	_finish(buf, 0.7)
	_save(dir.path_join("Vorschlag-Titanenstoss-CC0-Mix.wav"), buf)
	_save(ProjectSettings.globalize_path("res://assets/sounds/tank_r.wav"), buf)
	print("geschrieben: tank_r.wav (CC0-Mix, %.2f s)" % (buf.size() / float(OUT)))
	# --- Vergleichsvorschau Artninja (nur lokal)
	if artninja != "":
		var a := _read_mono(artninja).slice(int(0.05 * OUT), int(1.0 * OUT))
		var slow := _resample(a, 0.7)                                               # langsamer = länger und tiefer
		var out := PackedFloat32Array()
		out.resize(int(3.2 * OUT))
		for i in slow.size():
			out[i] += slow[i]
		for d in [[0.043, 0.5], [0.071, 0.42], [0.097, 0.36], [0.133, 0.3]]:        # einfacher Hall zum Verlängern
			var delay := int(float(d[0]) * OUT)
			var fb := float(d[1])
			for i in range(delay, out.size()):
				out[i] += out[i - delay] * fb * 0.6
		_finish(out, 0.85)
		_save(dir.path_join("Vorschau-Artninja-Titanstoss-gestreckt.wav"), out)
		print("geschrieben: Vorschau-Artninja-Titanstoss-gestreckt.wav (nur zum Anhören)")
	quit()


func _finish(buf: PackedFloat32Array, fade_s: float) -> void:
	var peak := 0.0001
	for s in buf:
		peak = maxf(peak, absf(s))
	var n := buf.size()
	for i in n:
		var x := buf[i] / peak
		var fade := 1.0
		if i > n - int(fade_s * OUT):
			fade = float(n - 1 - i) / (fade_s * OUT)
		buf[i] = tanh(x * 1.2) / tanh(1.2) * 0.92 * fade


func _read_mono(path: String) -> PackedFloat32Array:
	var b := FileAccess.get_file_as_bytes(path)
	var pos := 12
	var ch := 2
	var bits := 16
	var out := PackedFloat32Array()
	while pos + 8 <= b.size():
		var id := b.slice(pos, pos + 4).get_string_from_ascii()
		var sz := int(b.decode_u32(pos + 4))
		if id == "fmt ":
			ch = int(b.decode_u16(pos + 10))
			bits = int(b.decode_u16(pos + 22))
		elif id == "data":
			var bps := bits / 8
			var frames := sz / (bps * ch)
			out.resize(frames)
			for i in frames:
				var a := 0.0
				for c in ch:
					var o := pos + 8 + (i * ch + c) * bps
					var v := 0.0
					if bits == 16:
						v = float(b.decode_s16(o)) / 32768.0
					elif bits == 24:
						var u := int(b[o]) | (int(b[o + 1]) << 8) | (int(b[o + 2]) << 16)
						if u >= 8388608:
							u -= 16777216
						v = float(u) / 8388608.0
					elif bits == 32:
						v = float(b.decode_s32(o)) / 2147483648.0
					a += v
				out[i] = a / ch
			break
		pos += 8 + sz + (sz % 2)
	return out


func _up(a: PackedFloat32Array) -> PackedFloat32Array:
	var o := PackedFloat32Array()
	o.resize(a.size() * 2)
	for i in a.size():
		var nx := a[mini(i + 1, a.size() - 1)]
		o[i * 2] = a[i]
		o[i * 2 + 1] = (a[i] + nx) * 0.5
	return o


func _lowpass(a: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var k := 1.0 - exp(-TAU * fc / OUT)
	var o := PackedFloat32Array()
	o.resize(a.size())
	var y := 0.0
	var y2 := 0.0
	for i in a.size():
		y += k * (a[i] - y)
		y2 += k * (y - y2)
		o[i] = y2
	return o


func _resample(a: PackedFloat32Array, factor: float) -> PackedFloat32Array:
	var n := int(a.size() / factor)
	var o := PackedFloat32Array()
	o.resize(n)
	for i in n:
		var p := float(i) * factor
		var i0 := int(p)
		var f := p - i0
		o[i] = a[i0] * (1.0 - f) + a[mini(i0 + 1, a.size() - 1)] * f
	return o


func _add(buf: PackedFloat32Array, layer: PackedFloat32Array, start_s: float, vol: float) -> void:
	var peak := 0.0001
	for s in layer:
		peak = maxf(peak, absf(s))
	var st := int(start_s * OUT)
	for i in layer.size():
		if st + i >= buf.size():
			break
		buf[st + i] += layer[i] / peak * vol


func _save(path: String, buf: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + bytes.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(OUT)
	f.store_32(OUT * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(bytes.size())
	f.store_buffer(bytes)
	f.close()
