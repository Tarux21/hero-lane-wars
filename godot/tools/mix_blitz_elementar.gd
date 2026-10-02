extends SceneTree
## Baut den Sound für das Rufen des Blitz-Elementars: der Blitzeinschlag aus "lightning strike" (parnellij, CC0) wird bewusst
## unrealistisch gemacht (Donnergrollen entfernt, höher gestimmt, Ringmodulation, Sättigung) und mit selbst berechnetem
## Aufladen, Zaps und Knistern gemischt. Schreibt nach godot/assets/sounds/summon_lightning.wav (und Sounds/ zum Anhören).
## Aufruf: Godot --headless --path godot --script res://tools/mix_blitz_elementar.gd
const SfxCaster := preload("res://scripts/sfx_caster.gd")
const OUT := 44100
const STRIKE_AT := 0.6                           # Sekunden: Einschlag passend zum Aufleuchten des Zauberkreises


func _init() -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../Sounds")
	var src_path := ""
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("74892"):
			src_path = dir.path_join(f)
	if src_path == "":
		print("FEHLER: Datei 74892... nicht in Sounds/ gefunden")
		quit()
		return
	var raw := _read_mono(src_path)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	# Einschlag: ab 1,25 s, 1,1 s lang
	var seg: PackedFloat32Array = raw.slice(int(1.25 * OUT), int(2.35 * OUT))
	var hp := _highpass(seg, 450.0)                # Donnergrollen weg, nur Knall und Zischen bleiben
	var shifted := _lowpass(_lowpass(_resample(hp, 1.12), 5200.0), 7000.0)             # höher gestimmt, kürzer, weniger natürlich
	var ringed := PackedFloat32Array()
	ringed.resize(shifted.size())
	for i in shifted.size():                        # Ringmodulation: metallisch-elektrischer Charakter
		var m := sin(TAU * 92.0 * float(i) / OUT)
		ringed[i] = shifted[i] * (0.55 + 0.45 * m)
	var strike := PackedFloat32Array()
	strike.resize(ringed.size())
	for i in ringed.size():
		var env := exp(-2.4 * float(i) / ringed.size())
		strike[i] = tanh(ringed[i] * 3.0) * env      # starke Sättigung = hart, synthetisch
	# synthetische Schichten
	var charge := _up(SfxCaster._noise(rng, 0.6, 250.0, 2600.0, 0.6, 0.5, 0.6))                  # Aufladen: steigendes Rauschen
	var hum := _up(SfxCaster._tone(1.3, 100.0, 140.0, "sawtooth", 0.7, 1.6, 0.0, 0.0, 42.0, 0.6))   # Brummen mit Zittern
	var arcs := _up(SfxCaster._crackle(rng, 1.2, 130.0, 25.0, 1.8))
	var zap := _up(SfxCaster._noise(rng, 0.12, 3200.0, 600.0, 0.6, 0.002, 5.0))
	var thump := _up(SfxCaster._boom(0.5, 115.0, 48.0, 6.0))
	var buf := PackedFloat32Array()
	buf.resize(int(2.0 * OUT))
	_add(buf, charge, 0.0, 0.3)
	_add(buf, hum, 0.0, 0.2)
	_add(buf, arcs, STRIKE_AT - 0.05, _arc_vol())
	_add(buf, strike, STRIKE_AT, 1.0)
	_add(buf, thump, STRIKE_AT, 0.55)
	for i in 3:
		_add(buf, zap, STRIKE_AT + 0.05 + i * 0.11, 0.35)
	var peak := 0.0001
	for s in buf:
		peak = maxf(peak, absf(s))
	var n := buf.size()
	for i in n:
		var x := buf[i] / peak
		var fade := 1.0
		if i > n - int(0.5 * OUT):
			fade = float(n - 1 - i) / (0.5 * OUT)
		buf[i] = tanh(x * 1.2) / tanh(1.2) * 0.9 * fade
	_save(dir.path_join("Vorschlag-Blitz-Elementar-aus-parnellij.wav"), buf)
	_save(ProjectSettings.globalize_path("res://assets/sounds/summon_lightning.wav"), buf)
	print("geschrieben: summon_lightning.wav (%.2f s)" % (n / float(OUT)))
	quit()


func _arc_vol() -> float:
	return 0.25


func _read_mono(path: String) -> PackedFloat32Array:
	var b := FileAccess.get_file_as_bytes(path)
	var pos := 12
	var ch := 1
	var out := PackedFloat32Array()
	while pos + 8 <= b.size():
		var id := b.slice(pos, pos + 4).get_string_from_ascii()
		var sz := int(b.decode_u32(pos + 4))
		if id == "fmt ":
			ch = int(b.decode_u16(pos + 10))
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
	for i in a.size():
		y += k * (a[i] - y)
		o[i] = y
	return o


func _highpass(a: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var lp := _lowpass(_lowpass(a, fc), fc)
	var o := PackedFloat32Array()
	o.resize(a.size())
	for i in a.size():
		o[i] = a[i] - lp[i]
	return o


func _resample(a: PackedFloat32Array, factor: float) -> PackedFloat32Array:
	## factor > 1: schneller abgespielt = höher und kürzer
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
