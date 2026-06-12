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
var _cg_music: AudioStreamPlayer = null

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

	# CG 专属配乐（叙事感和弦琶音循环，与游戏内环境音区分）
	_cg_music = AudioStreamPlayer.new()
	_cg_music.stream = _make_cg_music_loop()
	_cg_music.volume_db = -13.0
	add_child(_cg_music)

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
		elif _cg_music == null or not _cg_music.playing:
			_ambient.play()
	if muted and _cg_music:
		_cg_music.stop()
	return muted

## CG 播放期间：停掉环境风声，播放叙事配乐
func start_cg_music() -> void:
	if _ambient:
		_ambient.stop()
	if muted:
		return
	if _cg_music and not _cg_music.playing:
		_cg_music.play()

## CG 结束：停配乐，恢复环境风声
func stop_cg_music() -> void:
	if _cg_music:
		_cg_music.stop()
	if _ambient and not muted:
		_ambient.play()

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

## CG 配乐：Am–F–C–G 和弦琶音 + 低音垫，8 秒无缝循环（缓慢、史诗叙事感）
func _make_cg_music_loop() -> AudioStreamWAV:
	var chords = [
		[220.00, 261.63, 329.63],   # Am: A3 C4 E4
		[174.61, 220.00, 261.63],   # F:  F3 A3 C4
		[196.00, 261.63, 329.63],   # C/G: G3 C4 E4
		[196.00, 246.94, 293.66],   # G:  G3 B3 D4
	]
	var beat := 0.5
	var total := 8.0
	var n = int(total * RATE)
	var samples = PackedFloat32Array()
	samples.resize(n)
	for ci in range(chords.size()):
		var ch = chords[ci]
		# 琶音：低-中-高-高八度，音尾互相重叠营造延音
		for bi in range(4):
			var note_f: float = ch[bi % 3] * (2.0 if bi == 3 else 1.0)
			var start = int((ci * 2.0 + bi * beat) * RATE)
			var len = int(beat * 1.7 * RATE)
			for i in range(len):
				var idx = start + i
				if idx >= n:
					break
				var t = float(i) / len
				var env = sin(PI * t) * (1.0 - t * 0.35)
				samples[idx] += sin(TAU * note_f * i / RATE) * 0.15 * env
		# 低音垫：和弦根音低八度铺底
		var bass_f: float = ch[0] / 2.0
		var bstart = int(ci * 2.0 * RATE)
		var blen = int(2.0 * RATE)
		for i in range(blen):
			var idx = bstart + i
			if idx >= n:
				break
			var t = float(i) / blen
			var benv = minf(1.0, t * 10.0) * minf(1.0, (1.0 - t) * 5.0)
			samples[idx] += sin(TAU * bass_f * i / RATE) * 0.10 * benv
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
