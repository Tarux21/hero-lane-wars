extends SceneTree
## Prüft eine Sounddatei aus assets/sounds: Dauer, Kanäle, Spitze, Verlauf. Aufruf: Godot --headless --path godot --script res://tools/wavcheck.gd -- frost_cast
const SfxLib := preload("res://scripts/sfx.gd")

func _init() -> void:
	var name := "frost_cast"
	for a in OS.get_cmdline_user_args():
		name = a
	var host := Node.new()
	root.add_child(host)
	var s = SfxLib.new(host)
	var w: AudioStreamWAV = s.streams[name]
	var n := w.data.size() / 2
	var peak := 0.0
	var env := []
	var win := int(w.mix_rate / 4.0)
	var acc := 0.0
	for i in n:
		var v := absf(float(w.data.decode_s16(i * 2)) / 32768.0)
		peak = maxf(peak, v)
		acc += v * v
		if (i + 1) % win == 0:
			env.append("%.2f" % sqrt(acc / win))
			acc = 0.0
	print("%s: %.2f s, %d Hz, %s, Spitze %.2f" % [name, n / float(w.mix_rate) / (2.0 if w.stereo else 1.0), w.mix_rate, "Stereo" if w.stereo else "Mono", peak])
	print("Lautstärke je 0,25 s: ", " ".join(env))
	quit()
