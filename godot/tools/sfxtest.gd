extends SceneTree
## Prüft die Caster-Klänge: Länge, Spitzenwert, Anteil stiller Stellen, Rechenzeit. Aufruf: Godot --headless --path godot --script res://tools/sfxtest.gd
const SfxCaster := preload("res://scripts/sfx_caster.gd")

func _init() -> void:
	var total := 0
	for nm in SfxCaster.NAMES:
		var t0 := Time.get_ticks_msec()
		var b: PackedFloat32Array = SfxCaster.build(nm)
		var dt := Time.get_ticks_msec() - t0
		total += dt
		var peak := 0.0
		var rms := 0.0
		var nan := 0
		for v in b:
			if is_nan(v):
				nan += 1
			peak = maxf(peak, absf(v))
			rms += v * v
		rms = sqrt(rms / b.size())
		# Energie je Viertel (Verlauf)
		var q := []
		for k in 4:
			var e := 0.0
			var a := b.size() * k / 4
			var z := b.size() * (k + 1) / 4
			for i in range(a, z):
				e += b[i] * b[i]
			q.append("%.3f" % sqrt(e / (z - a)))
		if OS.get_cmdline_user_args().has("--wav"):
			var w := AudioStreamWAV.new()
			w.format = AudioStreamWAV.FORMAT_16_BITS
			w.mix_rate = 22050
			var bytes := PackedByteArray()
			bytes.resize(b.size() * 2)
			for i in b.size():
				bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
			w.data = bytes
			w.save_to_wav("../Caster-Sounds/%s.wav" % nm)
		print("%-20s %.2fs  peak %.2f  rms %.3f  nan %d  verlauf %s  (%d ms)" % [nm, b.size() / 22050.0, peak, rms, nan, str(q), dt])
	print("Gesamt Rechenzeit: %d ms" % total)
	quit()
