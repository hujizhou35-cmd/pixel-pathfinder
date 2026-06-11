extends Node

# ============================================================
# Sfx - 程序化音效系统 (Autoload)
# 启动时合成所有音效为 AudioStreamWAV，零外部音频资源
# ============================================================

const RATE := 22050

var muted: bool = false
var _streams: Dictionary = {}
var _pool: Array = []
var _pool_idx: int = 0
var _ambient: AudioStreamPlayer = null

func _ready() -> void:
	_build_all()
	for i in range(10):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	# 环境底噪（轻柔风声循环）
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = _make_wind_loop()
	_ambient.volume_db = -26.0
	add_child(_ambient)
	_ambient.play()

func play(key: String) -> void:
	if muted:
		return
	if not _streams.has(key):
		return
	var p: AudioStreamPlayer = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _pool.size()
	p.stream = _streams[key]
	p.volume_db = -6.0
	p.play()

func toggle_mute() -> bool:
	muted = not muted
	if _ambient:
		if muted:
			_ambient.stop()
		else:
			_ambient.play()
	return muted

# ------------------------------------------------------------
# 合成器
# ------------------------------------------------------------
func _build_all() -> void:
	_streams["click"]   = _wav(_tone(880, 660, 0.05, "square", 0.25))
	_streams["attack"]  = _wav(_mix([_tone(420, 120, 0.12, "saw", 0.5), _noise_burst(0.08, 0.25)]))
	_streams["crit"]    = _wav(_mix([_tone(660, 180, 0.16, "saw", 0.55), _tone(1320, 440, 0.16, "square", 0.3), _noise_burst(0.1, 0.3)]))
	_streams["hurt"]    = _wav(_mix([_tone(200, 70, 0.18, "square", 0.5), _noise_burst(0.12, 0.3)]))
	_streams["shield"]  = _wav(_tone(300, 560, 0.16, "tri", 0.45))
	_streams["heal"]    = _wav(_seq([[523, 0.07], [659, 0.07], [784, 0.12]], "tri", 0.4))
	_streams["coin"]    = _wav(_seq([[988, 0.05], [1319, 0.09]], "square", 0.3))
	_streams["equip"]   = _wav(_seq([[392, 0.06], [523, 0.1]], "tri", 0.4))
	_streams["upgrade"] = _wav(_seq([[523, 0.06], [659, 0.06], [880, 0.12]], "square", 0.32))
	_streams["chest"]   = _wav(_seq([[330, 0.07], [415, 0.07], [554, 0.07], [659, 0.12]], "tri", 0.4))
	_streams["skill"]   = _wav(_mix([_tone(240, 700, 0.2, "saw", 0.45), _noise_burst(0.1, 0.2)]))
	_streams["boss"]    = _wav(_mix([_tone(110, 55, 0.5, "saw", 0.55), _tone(112, 56, 0.5, "square", 0.3)]))
	_streams["victory"] = _wav(_seq([[523, 0.12], [659, 0.12], [784, 0.12], [1047, 0.3]], "square", 0.32))
	_streams["defeat"]  = _wav(_seq([[392, 0.18], [330, 0.18], [262, 0.18], [196, 0.4]], "tri", 0.45))

func _tone(f0: float, f1: float, dur: float, shape: String, vol: float) -> PackedFloat32Array:
	var n = int(dur * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t = float(i) / n
		var f = lerpf(f0, f1, t)
		phase += f / RATE
		var s := 0.0
		match shape:
			"sine":   s = sin(TAU * phase)
			"square": s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"tri":    s = 4.0 * absf(fmod(phase, 1.0) - 0.5) - 1.0
			"saw":    s = 2.0 * fmod(phase, 1.0) - 1.0
		var env = (1.0 - t) * minf(1.0, t * 30.0)
		out[i] = s * vol * env
	return out

func _noise_burst(dur: float, vol: float) -> PackedFloat32Array:
	var n = int(dur * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t = float(i) / n
		out[i] = randf_range(-1.0, 1.0) * vol * (1.0 - t) * (1.0 - t)
	return out

func _seq(notes: Array, shape: String, vol: float) -> PackedFloat32Array:
	var out = PackedFloat32Array()
	for nt in notes:
		out.append_array(_tone(nt[0], nt[0], nt[1], shape, vol))
	return out

func _mix(parts: Array) -> PackedFloat32Array:
	var n = 0
	for p in parts:
		n = maxi(n, p.size())
	var out = PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in range(p.size()):
			out[i] += p[i]
	return out

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v = int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav

func _make_wind_loop() -> AudioStreamWAV:
	var dur := 3.0
	var n = int(dur * RATE)
	var samples = PackedFloat32Array()
	samples.resize(n)
	var brown := 0.0
	for i in range(n):
		brown = clampf(brown + randf_range(-0.02, 0.02), -0.5, 0.5)
		var lfo = 0.6 + 0.4 * sin(TAU * float(i) / n * 2.0)
		samples[i] = brown * 0.5 * lfo
	# 首尾淡入淡出避免循环爆音
	var fade = int(0.05 * RATE)
	for i in range(fade):
		var k = float(i) / fade
		samples[i] *= k
		samples[n - 1 - i] *= k
	var wav = _wav(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav
