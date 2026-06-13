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
var _cg_music_tense: AudioStreamPlayer = null      # 周目 Boss 遇见：紧张低沉
var _cg_music_triumph: AudioStreamPlayer = null    # 周目 Boss 战胜：慷慨激昂
var _cg_active: AudioStreamPlayer = null           # 当前播放中的 CG 配乐

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
	# 周目大 Boss 终局 CG 配乐：比叙事乐更响（约 -6dB），区分遇见/战胜两种情绪
	_cg_music_tense = AudioStreamPlayer.new()
	_cg_music_tense.stream = _make_cg_music_tense()
	_cg_music_tense.volume_db = -6.0
	add_child(_cg_music_tense)
	_cg_music_triumph = AudioStreamPlayer.new()
	_cg_music_triumph.stream = _make_cg_music_triumph()
	_cg_music_triumph.volume_db = -5.0
	add_child(_cg_music_triumph)

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
	if muted:
		_stop_cg_players()
	return muted

func _stop_cg_players() -> void:
	if _cg_music: _cg_music.stop()
	if _cg_music_tense: _cg_music_tense.stop()
	if _cg_music_triumph: _cg_music_triumph.stop()
	_cg_active = null

## CG 播放期间：停掉环境风声，按情绪播放配乐
## mood: "narrative"(默认叙事) / "tense"(周目 Boss 遇见) / "triumph"(周目 Boss 战胜)
func start_cg_music(mood: String = "narrative") -> void:
	if _ambient:
		_ambient.stop()
	_stop_cg_players()
	if muted:
		return
	match mood:
		"tense": _cg_active = _cg_music_tense
		"triumph": _cg_active = _cg_music_triumph
		_: _cg_active = _cg_music
	if _cg_active:
		_cg_active.play()

## CG 结束：停配乐，恢复环境风声
func stop_cg_music() -> void:
	_stop_cg_players()
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

## 周目 Boss 遇见配乐：低沉不安的小调 drone + 缓慢琶音 + 颤音（紧张气氛）
func _make_cg_music_tense() -> AudioStreamWAV:
	var chords = [
		[146.83, 174.61, 220.00],   # Dm
		[138.59, 174.61, 207.65],   # 张力和弦
		[146.83, 185.00, 220.00],   # Dm(#)
		[130.81, 164.81, 196.00],   # 下行
	]
	var total := 8.0
	var n = int(total * RATE)
	var samples = PackedFloat32Array()
	samples.resize(n)
	for ci in range(chords.size()):
		var ch = chords[ci]
		var cstart = int(ci * 2.0 * RATE)
		# 低音持续 drone（缓慢颤音）
		var drone_f: float = ch[0] / 2.0
		var dlen = int(2.0 * RATE)
		for i in range(dlen):
			var idx = cstart + i
			if idx >= n:
				break
			var t = float(i) / dlen
			var env = minf(1.0, t * 6.0) * minf(1.0, (1.0 - t) * 4.0)
			var trem = 0.85 + 0.15 * sin(TAU * 5.0 * i / RATE)
			samples[idx] += sin(TAU * drone_f * i / RATE) * 0.17 * env * trem
		# 缓慢上行琶音（拖长尾音）
		for bi in range(3):
			var note_f: float = ch[bi]
			var start = int((ci * 2.0 + bi * 0.6) * RATE)
			var len = int(0.9 * RATE)
			for i in range(len):
				var idx = start + i
				if idx >= n:
					break
				var t = float(i) / len
				var env = sin(PI * t) * (1.0 - t * 0.3)
				samples[idx] += sin(TAU * note_f * i / RATE) * 0.10 * env
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

## 周目 Boss 战胜配乐：明亮大调号角进行 C–G–Am–F + 推进低音（慷慨激昂）
func _make_cg_music_triumph() -> AudioStreamWAV:
	var chords = [
		[261.63, 329.63, 392.00],   # C
		[246.94, 293.66, 392.00],   # G
		[220.00, 261.63, 329.63],   # Am
		[174.61, 261.63, 349.23],   # F
	]
	var beat := 0.5
	var total := 8.0
	var n = int(total * RATE)
	var samples = PackedFloat32Array()
	samples.resize(n)
	for ci in range(chords.size()):
		var ch = chords[ci]
		# 号角和弦：叠加泛音 → 铜管般明亮
		for bi in range(4):
			var note_f: float = ch[bi % 3] * (2.0 if bi == 3 else 1.0)
			var start = int((ci * 2.0 + bi * beat) * RATE)
			var len = int(beat * 1.6 * RATE)
			for i in range(len):
				var idx = start + i
				if idx >= n:
					break
				var t = float(i) / len
				var env = minf(1.0, t * 12.0) * (1.0 - t * 0.5)
				var s = sin(TAU * note_f * i / RATE)
				s += 0.5 * sin(TAU * note_f * 2.0 * i / RATE)
				s += 0.22 * sin(TAU * note_f * 3.0 * i / RATE)
				samples[idx] += s * 0.06 * env
		# 推进低音（每拍点奏）
		var bass_f: float = ch[0] / 2.0
		for bb in range(4):
			var bstart = int((ci * 2.0 + bb * beat) * RATE)
			var blen = int(0.4 * RATE)
			for i in range(blen):
				var idx = bstart + i
				if idx >= n:
					break
				var t = float(i) / blen
				var benv = minf(1.0, t * 12.0) * minf(1.0, (1.0 - t) * 3.0)
				samples[idx] += sin(TAU * bass_f * i / RATE) * 0.12 * benv
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
