extends SceneTree
## Baut Vorschläge für den Tank-Schockwellen-Sound aus CC0-Material: ein Explosions-Schlag (SamsterBirdies, CC0) plus selbst
## berechnetes Steinknistern und Grollen. Schreibt zwei Varianten nach Sounds/ (nur lokal).
## Aufruf: Godot --headless --path godot --script res://tools/mix_tank_q.gd
const SfxCaster := preload("res://scripts/sfx_caster.gd")
const OUT := 44100


func _init() -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../Sounds")
	var src_path := ""
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("745549"):
			src_path = dir.path_join(f)
	if src_path == "":
		print("FEHLER: Explosions-Datei (745549...) nicht in Sounds/ gefunden")
		quit()
		return
	var expl := _read_mono(src_path)                  # erste Explosion
	var hit: PackedFloat32Array = expl.slice(0, int(1.3 * OUT))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	# Schicht 1: dumpfer Schlag (Explosion tiefpassgefiltert) und scharfer Anfang (Original, nur die ersten 0,08 s)
	var thud := _lowpass(hit, 650.0)
	var crack := PackedFloat32Array()
	crack.resize(hit.size())
	for i in int(0.09 * OUT):
		crack[i] = hit[i] * (1.0 - float(i) / (0.09 * OUT))
	# Schicht 2: Steine und Geröll (eigenes Knistern, mit Tiefpass weicher gemacht), startet kurz nach dem Schlag
	var debris := _up(SfxCaster._crackle(rng, 1.3, 90.0, 12.0, 1.6))
	debris = _lowpass(debris, 2200.0)
	var rumble := _up(SfxCaster._rumble(rng, 1.4, 140.0, 0.01, 2.2))
	var low_boom := _up(SfxCaster._boom(0.9, 70.0, 32.0, 3.5))
	# Schlag am Anfang: Original-Explosion ungefiltert (erste 0,3 s, schnell abklingend) und ein kurzer, harter Rauschstoß
	var punch := PackedFloat32Array()
	punch.resize(int(0.3 * OUT))
	for i in punch.size():
		punch[i] = hit[i] * exp(-9.0 * float(i) / (0.3 * OUT))
	var snap := _up(SfxCaster._noise(rng, 0.09, 3200.0, 450.0, 0.5, 0.0005, 5.0))
	var variants := {"C-weniger-Geroell-mehr-Impact": [1.0, 1.2, 1.0, 0.28, 0.35]}
	for name in variants:
		var v: Array = variants[name]                 # [thud, crack, boom, debris, rumble]
		var buf := PackedFloat32Array()
		buf.resize(int(1.7 * OUT))
		_add(buf, thud, 0.0, v[0])
		_add(buf, crack, 0.0, v[1])
		_add(buf, low_boom, 0.0, v[2])
		_add(buf, debris, 0.12, v[3])
		_add(buf, rumble, 0.05, v[4])
		_add(buf, punch, 0.0, 1.4)
		_add(buf, snap, 0.0, 0.9)
		var peak := 0.0001
		for s in buf:
			peak = maxf(peak, absf(s))
		var n := buf.size()
		for i in n:
			var x := buf[i] / peak * 1.0
			var fade := 1.0
			if i > n - int(0.45 * OUT):
				fade = float(n - 1 - i) / (0.45 * OUT)
			buf[i] = tanh(x * 1.3) / tanh(1.3) * 0.95 * fade
		_save(dir.path_join("Vorschlag-Tank-Schockwelle-%s.wav" % name), buf)
		_save(ProjectSettings.globalize_path("res://assets/sounds/tank_q.wav"), buf)      # Spiel nutzt diese Fassung
		print("geschrieben: Vorschlag-Tank-Schockwelle-%s.wav" % name)
	quit()


func _read_mono(path: String) -> PackedFloat32Array:
	var b := FileAccess.get_file_as_bytes(path)
	var pos := 12
	var ch := 2
	var rate := 44100
	var out := PackedFloat32Array()
	while pos + 8 <= b.size():
		var id := b.slice(pos, pos + 4).get_string_from_ascii()
		var sz := int(b.decode_u32(pos + 4))
		if id == "fmt ":
			ch = int(b.decode_u16(pos + 10))
			rate = int(b.decode_u32(pos + 12))
		elif id == "data":
			var frames := sz / (2 * ch)
			out.resize(frames)
			for i in frames:
				var a := 0.0
				for c in ch:
					a += float(b.decode_s16(pos + 8 + (i * ch + c) * 2)) / 32768.0
				out[i] = a / ch
			break
		pos += 8 + sz + (sz % 2)
	return out


func _up(a: PackedFloat32Array) -> PackedFloat32Array:
	## 22050 -> 44100 Hz (lineare Zwischenwerte)
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
