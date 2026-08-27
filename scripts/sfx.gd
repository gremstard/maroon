class_name Sfx
# Procedural sound: every effect is synthesized into a small PCM buffer at
# first use — no audio files, matching the no-assets art rule. Recipes are
# noise bursts + sine sweeps with exponential decay; crude on paper, right
# at home next to flat-shaded boxes.

const RATE := 22050
static var _cache := {}

# recipe: {dur, noise (amp), lp (0..1 lowpass mix), sine [f0, f1, amp],
#          vib (Hz depth), decay (higher = snappier), fade_in}
static var RECIPES := {
	"chop":   {"dur": 0.09, "noise": 0.5, "lp": 0.35, "sine": [170.0, 120.0, 0.35], "decay": 7.0},
	"mine":   {"dur": 0.07, "noise": 0.45, "lp": 0.2, "sine": [1100.0, 700.0, 0.2], "decay": 9.0},
	"pickup": {"dur": 0.08, "noise": 0.0, "lp": 0.0, "sine": [760.0, 900.0, 0.35], "decay": 6.0},
	"whoosh": {"dur": 0.18, "noise": 0.22, "lp": 0.12, "decay": 3.0, "fade_in": 0.4},
	"thud":   {"dur": 0.12, "noise": 0.3, "lp": 0.5, "sine": [75.0, 55.0, 0.5], "decay": 6.0},
	"hurt":   {"dur": 0.28, "noise": 0.1, "lp": 0.4, "sine": [400.0, 140.0, 0.5], "decay": 3.5},
	"eat":    {"dur": 0.07, "noise": 0.35, "lp": 0.55, "decay": 8.0},
	"craft":  {"dur": 0.22, "noise": 0.0, "lp": 0.0, "sine": [660.0, 990.0, 0.4], "decay": 3.0},
	"place":  {"dur": 0.14, "noise": 0.35, "lp": 0.45, "sine": [95.0, 70.0, 0.45], "decay": 5.0},
	"chime":  {"dur": 0.5, "noise": 0.0, "lp": 0.0, "sine": [880.0, 880.0, 0.35], "vib": [6.0, 4.0], "decay": 2.5},
	"step":   {"dur": 0.035, "noise": 0.3, "lp": 0.5, "decay": 12.0},
	"howl":   {"dur": 0.9, "noise": 0.0, "lp": 0.0, "sine": [260.0, 430.0, 0.3], "vib": [5.0, 12.0], "decay": 1.4, "fade_in": 0.25},
	"roar":   {"dur": 1.1, "noise": 0.25, "lp": 0.7, "sine": [130.0, 55.0, 0.7], "vib": [3.0, 8.0], "decay": 1.2, "fade_in": 0.1},
	"wind":   {"dur": 2.5, "noise": 0.5, "lp": 0.85, "decay": 0.0, "loop": true},
	"thunder": {"dur": 1.4, "noise": 0.4, "lp": 0.8, "sine": [55.0, 30.0, 0.6], "vib": [4.0, 6.0], "decay": 1.8, "fade_in": 0.04},
}

static func stream(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var r: Dictionary = RECIPES[name]
	var n := int(r["dur"] * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = name.hash()
	var lp_state := 0.0
	var phase := 0.0
	var looping: bool = r.get("loop", false)
	var sine: Array = r.get("sine", [])
	var vib: Array = r.get("vib", [])
	for i in n:
		var t := float(i) / RATE
		var prog := float(i) / n
		var env := 1.0 if looping else exp(-float(r["decay"]) * prog * 3.0)
		var fade_in: float = r.get("fade_in", 0.0)
		if fade_in > 0.0 and prog < fade_in:
			env *= prog / fade_in
		var s := 0.0
		if r["noise"] > 0.0:
			var white := rng.randf_range(-1.0, 1.0)
			lp_state += (white - lp_state) * (1.0 - float(r["lp"]))
			s += lp_state * float(r["noise"])
		if sine.size() == 3:
			var f: float = lerpf(sine[0], sine[1], prog)
			if vib.size() == 2:
				f += sin(t * TAU * float(vib[0])) * float(vib[1])
			phase += f / RATE
			s += sin(phase * TAU) * float(sine[2])
		var v := int(clampf(s * env, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = n
	_cache[name] = wav
	return wav

# The menu theme: a slow Am–F–C–G swell, synthesized like everything else.
# Sixteen seconds, loops forever, sounds like being far from home.
static func theme() -> AudioStreamWAV:
	if _cache.has("__theme"):
		return _cache["__theme"]
	var chords := [
		[220.0, 261.63, 329.63],   # Am
		[174.61, 220.0, 261.63],   # F
		[261.63, 329.63, 392.0],   # C
		[196.0, 246.94, 293.66],   # G
	]
	var seg := 4.0
	var n := int(seg * chords.size() * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var ci := int(t / seg) % chords.size()
		var local := fmod(t, seg) / seg
		var env := sin(local * PI)
		env = env * env * 0.85 + 0.15
		var s := 0.0
		for f in chords[ci]:
			s += sin(t * TAU * f) * 0.09
			s += sin(t * TAU * (f + 0.4)) * 0.05      # slow beat-detune shimmer
		s += sin(t * TAU * chords[ci][0] * 0.5) * 0.08   # sub root
		var v := int(clampf(s * env, -1.0, 1.0) * 30000.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	_cache["__theme"] = wav
	return wav

# UI / self sounds (no position)
static func play(host: Node, name: String, volume_db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream(name)
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.92, 1.08)
	host.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

# world-positioned sounds
static func play_at(host: Node, pos: Vector3, name: String, volume_db := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(name)
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.92, 1.08)
	p.max_distance = 40.0
	host.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()

# looping ambient (returns the player so the caller can keep or kill it)
static func ambient(host: Node, name: String, volume_db := -20.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream(name)
	p.volume_db = volume_db
	host.add_child(p)
	p.play()
	return p
