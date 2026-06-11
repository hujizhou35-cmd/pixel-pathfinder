class_name WeatherFX
extends Control

# ============================================================
# 天气粒子层 - 每个生物群系不同的氛围粒子
# 0 翠林:落叶+萤火  1 荒漠:沙尘  2 雪岭:雪花
# 3 火山:余烬上飘   4 遗迹:神秘光尘
# ============================================================

var biome: int = 0
var _parts: Array = []

const COUNTS := [26, 30, 46, 30, 24]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_biome(0)

func set_biome(b: int) -> void:
	biome = clampi(b, 0, 4)
	_parts.clear()
	var n = COUNTS[biome]
	for i in range(n):
		_parts.append(_spawn(true))
	queue_redraw()

func _spawn(anywhere: bool) -> Dictionary:
	var p = {
		"x": randf_range(0, 1280.0),
		"y": randf_range(0, 720.0) if anywhere else -10.0,
		"vx": 0.0, "vy": 0.0,
		"size": 2.0, "phase": randf() * TAU,
		"alpha": randf_range(0.4, 0.9),
		"kind": 0,
	}
	match biome:
		0: # 落叶 + 萤火虫
			if randf() < 0.6:
				p.kind = 0 # 叶
				p.vy = randf_range(18, 36)
				p.vx = randf_range(-12, 12)
				p.size = randf_range(2, 4)
			else:
				p.kind = 1 # 萤火
				p.y = randf_range(300, 680)
				p.vy = randf_range(-6, 6)
				p.vx = randf_range(-8, 8)
				p.size = randf_range(1.5, 2.5)
		1: # 沙尘:横向
			p.vx = randf_range(60, 140)
			p.vy = randf_range(-6, 10)
			p.size = randf_range(1.5, 3)
			p.x = randf_range(-30, 1280.0) if anywhere else -10.0
			p.y = randf_range(80, 700)
		2: # 雪花
			p.vy = randf_range(26, 60)
			p.vx = randf_range(-18, 18)
			p.size = randf_range(1.5, 3.5)
		3: # 余烬:向上
			p.y = randf_range(0, 720.0) if anywhere else 730.0
			p.vy = randf_range(-50, -22)
			p.vx = randf_range(-10, 10)
			p.size = randf_range(1.5, 3)
		4: # 光尘:缓慢漂浮
			p.vy = randf_range(-10, 10)
			p.vx = randf_range(-10, 10)
			p.size = randf_range(1.5, 3)
	return p

func _process(delta: float) -> void:
	if not visible:
		return
	for i in range(_parts.size()):
		var p = _parts[i]
		p.phase += delta * 2.0
		p.x += (p.vx + sin(p.phase) * 14.0) * delta
		p.y += p.vy * delta
		var off = p.x < -20 or p.x > 1310 or p.y < -20 or p.y > 740
		if off:
			_parts[i] = _spawn(false)
			match biome:
				1: _parts[i].x = -10.0
				3: _parts[i].y = 730.0
	queue_redraw()

func _draw() -> void:
	for p in _parts:
		var a = p.alpha
		match biome:
			0:
				if p.kind == 0:
					draw_rect(Rect2(p.x, p.y, p.size * 1.6, p.size), Color(0.65, 0.52, 0.25, a * 0.8))
				else:
					var tw = 0.5 + 0.5 * sin(p.phase * 3.0)
					draw_circle(Vector2(p.x, p.y), p.size, Color(1.0, 0.95, 0.5, a * tw))
			1:
				draw_rect(Rect2(p.x, p.y, p.size * 2.2, p.size * 0.8), Color(0.85, 0.7, 0.45, a * 0.5))
			2:
				draw_rect(Rect2(p.x, p.y, p.size, p.size), Color(0.95, 0.97, 1.0, a * 0.9))
			3:
				var tw3 = 0.6 + 0.4 * sin(p.phase * 4.0)
				draw_rect(Rect2(p.x, p.y, p.size, p.size), Color(1.0, 0.55, 0.2, a * tw3))
			4:
				var tw4 = 0.5 + 0.5 * sin(p.phase * 2.0)
				draw_circle(Vector2(p.x, p.y), p.size, Color(0.75, 0.65, 1.0, a * 0.6 * tw4))
