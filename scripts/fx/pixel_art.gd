class_name PixelArt
extends RefCounted

# ============================================================
# 像素美术运行时入口（静态 PATCH4 资源合成 + 缓存）
# - hero_texture: 由冻结主角、穿戴层、头发遮罩和稀疏元素粒子合成（4 帧竖排）
# - enemy_texture / boss_texture: 高细节 2 帧怪物精灵（竖排）
# - item_icon: 35 个主体 × 5 元素的确定性 20×20 图标
# ============================================================

static var _cache: Dictionary = {}


# ============================================================
# 基础绘图工具
# ============================================================
static func _img(w: int, h: int) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)

static func _hline(img: Image, x: int, y: int, w: int, c: Color) -> void:
	_rect(img, x, y, w, 1, c)

static func _vline(img: Image, x: int, y: int, h: int, c: Color) -> void:
	_rect(img, x, y, 1, h, c)

static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

static func _c(v) -> Color:
	if v is Color:
		return v
	return Color(str(v))

static func _dark(c: Color, f: float = 0.65) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)

static func _light(c: Color, f: float = 0.35) -> Color:
	return c.lerp(Color.WHITE, f)

## 描边后处理：给精灵的剪影包一圈深色轮廓（元气骑士式清晰外形）
## 对单帧图像调用（多帧需逐帧处理后拼合，避免轮廓跨帧渗透）
static func _apply_outline(img: Image, col: Color = Color("#141828")) -> void:
	var w = img.get_width()
	var h = img.get_height()
	var src = img.duplicate()
	for y in range(h):
		for x in range(w):
			if src.get_pixel(x, y).a > 0.05:
				continue
			var edge = false
			if x > 0 and src.get_pixel(x - 1, y).a > 0.45:
				edge = true
			elif x < w - 1 and src.get_pixel(x + 1, y).a > 0.45:
				edge = true
			elif y > 0 and src.get_pixel(x, y - 1).a > 0.45:
				edge = true
			elif y < h - 1 and src.get_pixel(x, y + 1).a > 0.45:
				edge = true
			if edge:
				img.set_pixel(x, y, col)

# ============================================================
# 英雄：整体外观随六件装备变化（装备展示型写实比例重绘）
# 帧布局：0 待机A / 1 待机B / 2 攻击 / 3 受伤，竖排 40×52 ×4
# 美术原则：写实头身比（头约 1/4.5，像盔甲展架一样突出装备）、
#           每件装备有真实的结构设计（盔形/甲片/束带/鞋型）、
#           整体深色描边、统一左上光源、暗部色相偏冷
# ============================================================
const HERO_W := 40
const HERO_H := 52

const OUTLINE := Color("#141828")     # 轮廓（冷色深）

static func _is_void_or_edge(src: Image, x: int, y: int, outline: Color) -> bool:
	if x < 0 or y < 0 or x >= src.get_width() or y >= src.get_height():
		return true
	var c = src.get_pixel(x, y)
	return c.a < 0.5 or c.is_equal_approx(outline)

## 细节强化后处理：统一左上方向光（冷暗暖亮 hue-shift）——
## 受光边缘提亮偏暖、背光边缘压暗偏冷，让每个程序化精灵都有体积感与勾勒感
## （在描边之后逐帧调用）
static func _enrich_detail(img: Image, outline: Color = OUTLINE) -> void:
	var w = img.get_width()
	var h = img.get_height()
	var src = img.duplicate()
	for y in range(h):
		for x in range(w):
			var c = src.get_pixel(x, y)
			if c.a < 0.5 or c.is_equal_approx(outline):
				continue
			var lit = _is_void_or_edge(src, x, y - 1, outline) or _is_void_or_edge(src, x - 1, y, outline)
			var shade = _is_void_or_edge(src, x, y + 1, outline) or _is_void_or_edge(src, x + 1, y, outline)
			# 保色阴影：仅调明度（不改色相），受光边提亮、背光边压暗 → 既有体积感又保留原色
			if lit and not shade:
				img.set_pixel(x, y, _light(c, 0.22))
			elif shade and not lit:
				img.set_pixel(x, y, _dark(c, 0.80))

static func hero_frame_size() -> Vector2:
	return Vector2(HERO_W, HERO_H)

static func hero_texture(equipment: Dictionary) -> ImageTexture:
	var key := "hero_patch4|%s" % EquipmentVisualCompositor.visual_signature(equipment)
	if _cache.has(key):
		return _cache[key]
	var img := EquipmentVisualCompositor.compose_hero(equipment)
	var t = _tex(img)
	_cache[key] = t
	return t


# ============================================================
# 怪物精灵：高细节 2 帧（竖排）
# ============================================================
static func enemy_texture(sprite_key: String, palette: Dictionary) -> ImageTexture:
	var key = "enemy|%s" % sprite_key
	if _cache.has(key):
		return _cache[key]
	var size = _enemy_canvas(sprite_key)
	var img = _img(size.x, size.y * 2)
	for f in range(2):
		# 逐帧绘制 → 描边 → 拼合（与英雄统一的描边风格）
		var frame = _img(size.x, size.y)
		_draw_enemy(frame, sprite_key, palette, 0, f)
		_apply_outline(frame, OUTLINE)
		_enrich_detail(frame)
		img.blit_rect(frame, Rect2i(0, 0, size.x, size.y), Vector2i(0, f * size.y))
	var t = _tex(img)
	_cache[key] = t
	return t

static func _enemy_canvas(sprite_key: String) -> Vector2i:
	match sprite_key:
		"slime", "lavablob": return Vector2i(24, 18)
		"wolf", "wolf2": return Vector2i(28, 20)
		"scorpion", "scorpion2": return Vector2i(28, 18)
		"spirit", "elemental", "spirit2": return Vector2i(22, 24)
		"construct", "yeti": return Vector2i(26, 26)
		_: return Vector2i(20, 26)   # human 类

static func _draw_enemy(img: Image, key: String, pal: Dictionary, oy: int, f: int) -> void:
	var p = _c(pal.get("p", "#888"))
	var d = _c(pal.get("d", "#444"))
	var e = _c(pal.get("e", "#fff"))
	var a = _c(pal.get("a", pal.get("d", "#444")))
	match key:
		"slime", "lavablob": _draw_slime(img, oy, f, p, d, e, key == "lavablob")
		"wolf", "wolf2": _draw_wolf(img, oy, f, p, d, e)
		"scorpion", "scorpion2": _draw_scorpion(img, oy, f, p, d, e)
		"spirit", "elemental", "spirit2": _draw_ghost(img, oy, f, p, d, e, key == "elemental")
		"construct": _draw_construct(img, oy, f, p, d, e)
		"yeti": _draw_yeti(img, oy, f, p, d, e)
		"bandit": _draw_human(img, oy, f, p, d, e, a, "bandit")
		"bandit2": _draw_human(img, oy, f, p, d, e, a, "bandit2")
		"mummy": _draw_human(img, oy, f, p, d, e, a, "mummy")
		"guardian": _draw_human(img, oy, f, p, d, e, a, "guardian")
		_: _draw_human(img, oy, f, p, d, e, a, "")

static func _draw_slime(img: Image, oy: int, f: int, p: Color, d: Color, e: Color, lava: bool) -> void:
	# 半圆胶体 + 高光 + 滴落；帧 2 压扁
	var squash = f == 1
	var top = oy + (5 if squash else 3)
	var h = 12 if squash else 14
	var w = 20 if squash else 18
	var x0 = 12 - w / 2
	for yy in range(h):
		var t = float(yy) / h
		var rw = int(w * (0.45 + 0.55 * sqrt(minf(1.0, t * 1.6))))
		var lx = 12 - rw / 2
		_hline(img, lx, top + yy, rw, p if yy > 1 else _light(p, 0.3))
		_px(img, lx, top + yy, d)
		_px(img, lx + rw - 1, top + yy, d)
	_hline(img, x0 + 1, top + h - 1, w - 2, d)
	# 高光（玻璃质感：一大块柔光 + 一点高光点）
	_rect(img, 8, top + 2, 3, 2, _light(p, 0.5))
	_px(img, 9, top + 1, _light(p, 0.75))
	_px(img, 8, top + 3, _light(p, 0.35))
	# 眼睛与嘴（带瞳点反光）
	_rect(img, 9, top + 6, 2, 2, e)
	_rect(img, 14, top + 6, 2, 2, e)
	_px(img, 9, top + 6, _light(e, 0.6)); _px(img, 14, top + 6, _light(e, 0.6))
	_px(img, 10, top + 7, d); _px(img, 15, top + 7, d)   # 瞳
	_hline(img, 11, top + 9, 3, d)
	_px(img, 11, top + 10, _dark(p, 0.85))               # 下唇阴影
	# 体内悬浮物 / 熔岩裂纹
	if lava:
		_hline(img, 7, top + 8, 3, e)
		_hline(img, 14, top + 10, 4, e)
		_px(img, 12, top + 4, e)
	else:
		_px(img, 7, top + 9, d)
		_px(img, 16, top + 8, d)
	# 滴落
	if not squash:
		_px(img, 5, top + h, _dark(p, 0.8))
		_px(img, 19, top + h - 1, _dark(p, 0.8))

static func _draw_wolf(img: Image, oy: int, f: int, p: Color, d: Color, e: Color) -> void:
	var bob = f
	var by = oy + 7 + bob
	# 躯干
	_rect(img, 6, by, 15, 6, p)
	_hline(img, 6, by, 15, _light(p, 0.2))
	_hline(img, 6, by + 5, 15, d)
	# 背部鬃毛
	for i in range(4):
		_px(img, 8 + i * 3, by - 1, d)
	# 头（朝左）
	_rect(img, 2, by - 3, 6, 5, p)
	_rect(img, 0, by - 1, 3, 2, p)            # 吻部
	_px(img, 0, by - 1, Color("#1b1b22"))      # 黑鼻头
	_px(img, 3, by - 2, Color("#ffd23a"))      # 凶光金眼
	_px(img, 4, by - 2, _dark(Color("#ffd23a"), 0.6))
	# 竖耳（尖立，内耳暗）
	_px(img, 3, by - 5, p); _px(img, 3, by - 4, p); _px(img, 3, by - 4, _dark(d, 0.6))
	_px(img, 6, by - 5, p); _px(img, 6, by - 4, p); _px(img, 6, by - 4, _dark(d, 0.6))
	# 咧嘴獠牙
	_hline(img, 1, by + 1, 3, _dark(p, 0.45))
	_px(img, 1, by + 2, Color("#f4f0e4")); _px(img, 3, by + 2, Color("#f4f0e4"))
	# 背部鬃毛尖（更利落）
	for i in range(4):
		_px(img, 8 + i * 3, by - 2, _dark(p, 0.7))
	# 尾巴（蓬起带尖）
	if f == 0:
		_rect(img, 21, by - 2, 4, 2, d)
		_px(img, 24, by - 3, d); _px(img, 25, by - 4, _dark(d, 0.7))
	else:
		_rect(img, 21, by, 4, 2, d); _px(img, 25, by - 1, _dark(d, 0.7))
	# 四肢 + 爪
	var ly = by + 6
	for lx in [7, 11, 15, 19]:
		_rect(img, lx, ly, 2, 5 - bob, d)
		_px(img, lx, ly + 4 - bob, Color("#e7e2d2"))   # 爪尖

static func _draw_scorpion(img: Image, oy: int, f: int, p: Color, d: Color, e: Color) -> void:
	var by = oy + 9
	# 三节躯壳
	_rect(img, 8, by, 6, 5, p)
	_rect(img, 13, by + 1, 5, 4, _dark(p, 0.85))
	_rect(img, 17, by + 2, 4, 3, _dark(p, 0.75))
	_hline(img, 8, by, 6, _light(p, 0.25))
	# 甲壳分节高光（金属反光脊）
	_px(img, 9, by + 1, _light(p, 0.5)); _px(img, 14, by + 2, _light(p, 0.45)); _px(img, 18, by + 3, _light(p, 0.4))
	# 头与眼（一对凶红复眼）
	_rect(img, 5, by + 1, 4, 4, p)
	_px(img, 6, by + 2, Color("#ff5a4a")); _px(img, 7, by + 3, Color("#ff5a4a"))
	# 双螯（带利钳尖）
	var open = f == 1
	_rect(img, 2, by - 1, 3, 2, d)
	_rect(img, 1, by + (0 if open else 1), 2, 2, p)
	_px(img, 0, by + (0 if open else 1), _dark(d, 0.7))
	_rect(img, 2, by + 4, 3, 2, d)
	_rect(img, 1, by + (5 if open else 4), 2, 2, p)
	_px(img, 0, by + (5 if open else 4), _dark(d, 0.7))
	# 尾节上弯 + 毒针 + 毒液滴
	var tx = 20
	var ty0 = by + 1 - f
	_px(img, tx, ty0, d); _px(img, tx + 1, ty0 - 1, d)
	_px(img, tx + 2, ty0 - 2, p); _px(img, tx + 2, ty0 - 3, p)
	_px(img, tx + 1, ty0 - 4, _light(p, 0.4))  # 针根
	_px(img, tx + 1, ty0 - 5, Color("#1b1b22")) # 针尖
	_px(img, tx + 2, ty0 - 3, Color("#9bffa0")) # 滴落毒液
	# 足
	for i in range(3):
		_px(img, 9 + i * 3, by + 5, d)
		_px(img, 9 + i * 3 + (1 if f == 1 else 0), by + 6, d)

static func _draw_ghost(img: Image, oy: int, f: int, p: Color, d: Color, e: Color, flame: bool) -> void:
	var by = oy + 3 + (1 - f)
	# 主体
	for yy in range(14):
		var t = float(yy) / 14.0
		var rw = int(14 * (0.5 + 0.5 * sqrt(minf(1.0, t * 2.2))))
		if yy > 9:
			rw = 14
		var lx = 11 - rw / 2
		var col = p if yy > 1 else _light(p, 0.4)
		_hline(img, lx, by + yy, rw, Color(col.r, col.g, col.b, 0.92))
		_px(img, lx, by + yy, d)
		_px(img, lx + rw - 1, by + yy, d)
	# 下摆飘动须
	for i in range(3):
		var wx = 6 + i * 4 + (1 if (f + i) % 2 == 0 else 0)
		_px(img, wx, by + 14, p)
		_px(img, wx, by + 15, Color(d.r, d.g, d.b, 0.7))
	# 核心 / 眼
	if flame:
		_rect(img, 9, by + 4, 4, 5, _light(e, 0.2))   # 焰心
		_px(img, 10, by + 2 - f, e)                    # 火苗
		_px(img, 12, by + 1 + f, e)
		_px(img, 11, by + 3, _light(e, 0.6))           # 焰心高光
	else:
		_rect(img, 10, by + 7, 2, 2, e)                # 胸核
		_px(img, 10, by + 7, _light(e, 0.6))
	# 空洞鬼眼（深陷 + 内里幽光）
	var socket = Color("#120a1e") if not flame else Color("#2a1408")
	var glowcol = _light(e, 0.5) if not flame else Color("#ffd089")
	_rect(img, 8, by + 4, 2, 3, socket)
	_rect(img, 13, by + 4, 2, 3, socket)
	_px(img, 8, by + 5, glowcol); _px(img, 14, by + 5, glowcol)

static func _draw_construct(img: Image, oy: int, f: int, p: Color, d: Color, e: Color) -> void:
	var by = oy + 4 + f
	# 浮空头块（发光单眼）
	_rect(img, 9, by - 4, 8, 4, p)
	_hline(img, 9, by - 4, 8, _light(p, 0.3))
	_rect(img, 11, by - 3, 4, 2, _dark(p, 0.5))
	_rect(img, 12, by - 3, 2, 2, e)
	_px(img, 12, by - 3, _light(e, 0.6))
	# 躯干石块
	_rect(img, 7, by + 1, 12, 9, p)
	_vline(img, 7, by + 1, 9, d)
	_vline(img, 18, by + 1, 9, d)
	_hline(img, 7, by + 9, 12, d)
	# 石砌接缝（方块感）
	_hline(img, 8, by + 4, 10, _dark(p, 0.78))
	_vline(img, 12, by + 1, 9, _dark(p, 0.8))
	# 胸口符文（菱形脉动核）
	_px(img, 12, by + 3, _light(e, 0.5)); _px(img, 13, by + 4, e)
	_px(img, 12, by + 5, _light(e, 0.5)); _px(img, 11, by + 4, e); _px(img, 12, by + 4, _light(e, 0.7))
	# 悬浮肩臂
	_rect(img, 3, by + 2 - f, 3, 5, _dark(p, 0.85))
	_rect(img, 20, by + 2 + f, 3, 5, _dark(p, 0.85))
	# 石腿
	_rect(img, 9, by + 11, 3, 4, d)
	_rect(img, 14, by + 11, 3, 4, d)
	# 裂纹
	_px(img, 9, by + 6, d); _px(img, 10, by + 7, d)
	_px(img, 16, by + 2, d); _px(img, 17, by + 3, d)

static func _draw_yeti(img: Image, oy: int, f: int, p: Color, d: Color, e: Color) -> void:
	var by = oy + 3 + f
	# 一对弯角（兽王威压）
	_px(img, 6, by + 1, Color("#e7ddc4")); _px(img, 5, by, Color("#e7ddc4")); _px(img, 5, by - 1, Color("#cdbf9e"))
	_px(img, 19, by + 1, Color("#e7ddc4")); _px(img, 20, by, Color("#e7ddc4")); _px(img, 20, by - 1, Color("#cdbf9e"))
	# 大块毛躯
	_rect(img, 6, by + 3, 14, 13, p)
	_hline(img, 6, by + 3, 14, _light(p, 0.3))
	# 毛发纹理（交错短簇）
	for yy in range(4, 15, 3):
		for xx in range(7, 19, 4):
			_px(img, xx + (yy % 2), by + yy, d)
			_px(img, xx + (yy % 2), by + yy - 1, _light(p, 0.25))
	# 脸部凹陷 + 浓眉
	_rect(img, 9, by + 4, 8, 5, d)
	_hline(img, 9, by + 4, 8, _dark(d, 0.5))        # 怒眉
	_rect(img, 10, by + 5, 2, 2, Color("#7ad9ff"))  # 冰蓝眼
	_rect(img, 14, by + 5, 2, 2, Color("#7ad9ff"))
	_px(img, 10, by + 5, _light(Color("#7ad9ff"), 0.5)); _px(img, 14, by + 5, _light(Color("#7ad9ff"), 0.5))
	# 咧口獠牙
	_hline(img, 11, by + 8, 4, _dark(d, 0.6))
	_px(img, 11, by + 8, Color("#f4f0e4")); _px(img, 14, by + 8, Color("#f4f0e4"))
	# 长臂
	_rect(img, 3, by + 5, 3, 9 + f, p)
	_rect(img, 20, by + 5, 3, 9 - f, p)
	_hline(img, 3, by + 13 + f, 3, d)
	_hline(img, 20, by + 13 - f, 3, d)
	# 腿
	_rect(img, 9, by + 16, 3, 4, _dark(p, 0.8))
	_rect(img, 14, by + 16, 3, 4, _dark(p, 0.8))

static func _draw_human(img: Image, oy: int, f: int, p: Color, d: Color, e: Color, a: Color, variant: String) -> void:
	var bob = f
	var cx = 6
	var ty = oy + 10 + bob
	# 腿
	_rect(img, cx + 1, ty + 8, 3, 5, d)
	_rect(img, cx + 5, ty + 8, 3, 5, d)
	_rect(img, cx + 0, ty + 12, 4, 2, _dark(d, 0.7))
	_rect(img, cx + 5, ty + 12, 4, 2, _dark(d, 0.7))
	# 躯干
	_rect(img, cx, ty, 9, 8, p)
	_vline(img, cx, ty, 8, d)
	_vline(img, cx + 8, ty, 8, d)
	# 头
	var hy = ty - 7
	_rect(img, cx + 1, hy, 7, 7, p)
	match variant:
		"bandit":
			_rect(img, cx + 1, hy, 7, 2, a)            # 红头巾
			_px(img, cx + 8, hy + 1, a)
			_px(img, cx + 2, hy + 3, e); _px(img, cx + 5, hy + 3, e)
			_hline(img, cx, ty + 4, 9, _dark(a, 0.8))   # 腰带
			# 短刀
			_vline(img, cx + 10, ty - 1, 4, Color("#cfd6e4"))
			_px(img, cx + 10, ty + 3, Color("#6e4a2a"))
		"bandit2":
			_rect(img, cx + 1, hy, 7, 2, a)            # 蓝头巾
			_rect(img, cx + 1, hy + 4, 7, 3, a)        # 面巾
			_px(img, cx + 2, hy + 3, e); _px(img, cx + 5, hy + 3, e)
			# 弯刀
			_px(img, cx + 10, ty - 2, Color("#cfd6e4"))
			_px(img, cx + 11, ty - 1, Color("#cfd6e4"))
			_px(img, cx + 11, ty, Color("#cfd6e4"))
			_px(img, cx + 10, ty + 1, Color("#cfd6e4"))
		"mummy":
			for yy in range(0, 7, 2):                   # 绷带横纹
				_hline(img, cx + 1, hy + yy, 7, d)
			for yy in range(1, 8, 2):
				_hline(img, cx, ty + yy, 9, d)
			_px(img, cx + 2, hy + 3, e); _px(img, cx + 5, hy + 3, e)  # 幽蓝眼火
			_px(img, cx + 9, ty + 2, p)                 # 垂落绷带
			_px(img, cx + 9, ty + 3, d)
		"guardian":
			_rect(img, cx + 1, hy - 1, 7, 3, a)         # 头盔
			_px(img, cx + 4, hy - 3, e)                 # 盔缨
			_px(img, cx + 4, hy - 2, e)
			_rect(img, cx + 1, hy + 3, 7, 2, _dark(a, 0.5))  # 面甲缝
			_px(img, cx + 2, hy + 3, e); _px(img, cx + 5, hy + 3, e)
			_rect(img, cx - 1, ty, 2, 3, a)             # 肩甲
			_rect(img, cx + 8, ty, 2, 3, a)
			_vline(img, cx + 4, ty + 1, 6, _light(p, 0.3))
			# 长剑与盾
			_vline(img, cx + 10, ty - 4, 7, Color("#cfd6e4"))
			_rect(img, cx - 3, ty + 1, 2, 4, _dark(a, 0.8))
		_:
			_rect(img, cx + 1, hy - 1, 7, 2, d)         # 头发
			_px(img, cx + 2, hy + 3, e); _px(img, cx + 5, hy + 3, e)
	# 手臂
	_rect(img, cx - 1, ty + 1, 2, 5 + bob, _dark(p, 0.85))
	_rect(img, cx + 8, ty + 1, 2, 5 - bob, _dark(p, 0.85))

# ============================================================
# 首领精灵（按区域）
# ============================================================
static func boss_texture(region: int, palette: Dictionary) -> ImageTexture:
	var key = "boss|%d" % region
	if _cache.has(key):
		return _cache[key]
	var img = _img(30, 30 * 2)
	for f in range(2):
		var frame = _img(30, 30)
		_draw_boss(frame, region, palette, 0, f)
		_apply_outline(frame, OUTLINE)
		_enrich_detail(frame)
		img.blit_rect(frame, Rect2i(0, 0, 30, 30), Vector2i(0, f * 30))
	var t = _tex(img)
	_cache[key] = t
	return t

static func _draw_boss(img: Image, region: int, pal: Dictionary, oy: int, f: int) -> void:
	var p = _c(pal.get("p", "#888"))
	var d = _c(pal.get("d", "#444"))
	var e = _c(pal.get("e", "#fff"))
	var a = _c(pal.get("a", "#999"))
	match region:
		0: _draw_boss_tree(img, oy, f, p, d, e, a)
		1: _draw_boss_pharaoh(img, oy, f, p, d, e, a)
		2: _draw_boss_icegolem(img, oy, f, p, d, e, a)
		3: _draw_boss_lavatitan(img, oy, f, p, d, e, a)
		_: _draw_boss_arcane(img, oy, f, p, d, e, a)

static func _draw_boss_tree(img: Image, oy: int, f: int, p: Color, d: Color, e: Color, a: Color) -> void:
	var by = oy + 4 + f
	# 树冠
	_rect(img, 6, by - 3, 18, 6, p)
	_rect(img, 8, by - 5, 14, 3, p)
	_hline(img, 8, by - 5, 14, _light(p, 0.25))
	for i in range(5):
		_px(img, 8 + i * 3, by - 2 + (i % 2), d)
	# 躯干
	_rect(img, 10, by + 3, 10, 14, a)
	_vline(img, 10, by + 3, 14, _dark(a))
	_vline(img, 19, by + 3, 14, _dark(a))
	_vline(img, 14, by + 5, 10, _dark(a, 0.8))       # 树皮纹
	# 树洞脸
	_rect(img, 12, by + 5, 6, 4, _dark(a, 0.45))
	_px(img, 13, by + 6, e); _px(img, 16, by + 6, e)
	_hline(img, 13, by + 8, 4, _dark(a, 0.3))
	# 枝条手臂
	_rect(img, 4, by + 4 - f, 6, 2, a)
	_px(img, 3, by + 3 - f, a); _px(img, 2, by + 2 - f, d)
	_rect(img, 20, by + 6 + f, 6, 2, a)
	_px(img, 26, by + 5 + f, a); _px(img, 27, by + 4 + f, d)
	# 根脚
	_rect(img, 10, by + 17, 4, 4, _dark(a, 0.8))
	_rect(img, 16, by + 17, 4, 4, _dark(a, 0.8))
	_px(img, 8, by + 20, _dark(a, 0.8))
	_px(img, 21, by + 20, _dark(a, 0.8))

static func _draw_boss_pharaoh(img: Image, oy: int, f: int, p: Color, d: Color, e: Color, a: Color) -> void:
	var by = oy + 9 + f
	# 黄金头饰
	_rect(img, 9, by - 8, 12, 3, a)
	_rect(img, 8, by - 6, 3, 7, a)
	_rect(img, 19, by - 6, 3, 7, a)
	_px(img, 14, by - 9, e); _px(img, 15, by - 9, e)
	# 脸
	_rect(img, 11, by - 5, 8, 6, p)
	_px(img, 12, by - 3, e); _px(img, 16, by - 3, e)
	_hline(img, 13, by - 1, 4, d)
	# 绷带躯干
	_rect(img, 10, by + 1, 10, 11, p)
	for yy in range(2, 11, 2):
		_hline(img, 10, by + yy, 10, d)
	_vline(img, 10, by + 1, 11, d)
	_vline(img, 19, by + 1, 11, d)
	# 黄金胸饰
	_rect(img, 12, by + 2, 6, 2, a)
	_px(img, 14, by + 4, e)
	# 权杖（圣甲虫宝石）
	_vline(img, 23, by - 6 + f, 14, a)
	_rect(img, 22, by - 8 + f, 3, 2, e)
	_px(img, 23, by - 9 + f, _light(e, 0.5))
	# 左臂
	_rect(img, 7, by + 2, 3, 6 - f, p)
	_hline(img, 7, by + 4, 3, d)
	# 裙摆与足
	_rect(img, 10, by + 12, 10, 3, a)
	_rect(img, 11, by + 15, 3, 3, d)
	_rect(img, 16, by + 15, 3, 3, d)

static func _draw_boss_icegolem(img: Image, oy: int, f: int, p: Color, d: Color, e: Color, a: Color) -> void:
	var by = oy + 4 + f
	# 冰晶头
	_rect(img, 11, by, 8, 6, a)
	_px(img, 12, by - 1, a); _px(img, 17, by - 1, a)
	_px(img, 14, by - 2, _light(a, 0.5))
	_rect(img, 12, by + 2, 2, 2, e)
	_rect(img, 16, by + 2, 2, 2, e)
	# 躯干
	_rect(img, 8, by + 6, 14, 12, p)
	_vline(img, 8, by + 6, 12, d)
	_vline(img, 21, by + 6, 12, d)
	# 冰面反光斜线
	for i in range(4):
		_px(img, 10 + i, by + 8 + i, _light(p, 0.45))
	# 跳动的心脏
	var hb = f == 1
	_rect(img, 13, by + 10, 4 if hb else 3, 4 if hb else 3, e)
	_px(img, 14, by + 11, _light(e, 0.6))
	# 冰锥肩
	_px(img, 8, by + 5, _light(p, 0.3)); _px(img, 7, by + 4, _light(p, 0.3))
	_px(img, 21, by + 5, _light(p, 0.3)); _px(img, 22, by + 4, _light(p, 0.3))
	# 巨臂
	_rect(img, 4, by + 7, 4, 9 + f, d)
	_rect(img, 22, by + 7, 4, 9 - f, d)
	# 腿
	_rect(img, 10, by + 18, 4, 5, d)
	_rect(img, 16, by + 18, 4, 5, d)

static func _draw_boss_lavatitan(img: Image, oy: int, f: int, p: Color, d: Color, e: Color, a: Color) -> void:
	var by = oy + 5
	# 火焰头冠
	_px(img, 12, by - 3 + f, a); _px(img, 15, by - 4 + (1 - f), a); _px(img, 18, by - 3 + f, a)
	_px(img, 13, by - 2, e); _px(img, 16, by - 2, e)
	# 头
	_rect(img, 11, by - 1, 8, 5, p)
	_rect(img, 12, by + 1, 2, 2, e)
	_rect(img, 16, by + 1, 2, 2, e)
	# 岩壳躯干
	_rect(img, 8, by + 4, 14, 12, p)
	_vline(img, 8, by + 4, 12, d)
	_vline(img, 21, by + 4, 12, d)
	# 熔岩裂纹（脉动）
	var glow = e if f == 0 else _light(e, 0.4)
	_vline(img, 12, by + 6, 5, glow)
	_px(img, 13, by + 9, glow)
	_hline(img, 15, by + 8, 4, glow)
	_px(img, 17, by + 12, glow)
	# 岩拳
	_rect(img, 3, by + 6, 5, 8 + f, d)
	_rect(img, 22, by + 6, 5, 8 - f, d)
	_hline(img, 3, by + 10, 5, e)
	_hline(img, 22, by + 10, 5, e)
	# 腿
	_rect(img, 10, by + 16, 4, 6, d)
	_rect(img, 16, by + 16, 4, 6, d)
	_hline(img, 9, by + 22, 6, a)
	_hline(img, 15, by + 22, 6, a)

static func _draw_boss_arcane(img: Image, oy: int, f: int, p: Color, d: Color, e: Color, a: Color) -> void:
	var by = oy + 6 + f
	# 悬浮王冠
	_rect(img, 11, by - 5, 8, 2, a)
	_px(img, 11, by - 6, a); _px(img, 15, by - 7, a); _px(img, 18, by - 6, a)
	# 头核
	_rect(img, 12, by - 2, 6, 5, p)
	_rect(img, 13, by - 1, 2, 2, e)
	_rect(img, 16, by - 1, 1, 2, e)
	# 躯干（分离悬浮块）
	_rect(img, 9, by + 4, 12, 9, p)
	_vline(img, 9, by + 4, 9, d)
	_vline(img, 20, by + 4, 9, d)
	_rect(img, 13, by + 6, 4, 4, _dark(p, 0.6))
	_px(img, 14, by + 7, e); _px(img, 15, by + 8, e)
	# 环绕符文
	var orbit = [Vector2i(5, by + 2), Vector2i(24, by + 6), Vector2i(4, by + 10), Vector2i(25, by - 1)]
	for i in range(orbit.size()):
		var o = orbit[(i + f) % orbit.size()]
		_px(img, o.x, o.y, e)
		_px(img, o.x + 1, o.y, _light(e, 0.5))
	# 悬浮肩
	_rect(img, 5, by + 4 - f, 3, 4, a)
	_rect(img, 22, by + 4 + f, 3, 4, a)
	# 下浮尾椎
	_rect(img, 12, by + 14, 6, 2, d)
	_rect(img, 14, by + 17, 3, 2, _dark(d, 0.8))

# ============================================================
# 周目大 Boss 精灵（48×48 大画布，独特剪影，2 帧呼吸）
# ============================================================
static func cycle_boss_texture(sprite_key: String, palette: Dictionary) -> ImageTexture:
	var key = "cycleboss|%s" % sprite_key
	if _cache.has(key):
		return _cache[key]
	var sz := Vector2i(48, 48)
	var img = _img(sz.x, sz.y * 2)
	for f in range(2):
		var frame = _img(sz.x, sz.y)
		_draw_cycle_boss(frame, sprite_key, palette, 0, f)
		_apply_outline(frame, OUTLINE)
		_enrich_detail(frame)
		img.blit_rect(frame, Rect2i(0, 0, sz.x, sz.y), Vector2i(0, f * sz.y))
	var t = _tex(img)
	_cache[key] = t
	return t

static func _draw_cycle_boss(img: Image, key: String, pal: Dictionary, oy: int, f: int) -> void:
	var p = _c(pal.get("p", "#888"))
	var d = _c(pal.get("d", "#444"))
	var e = _c(pal.get("e", "#fff"))
	var a = _c(pal.get("a", "#999"))
	match key:
		"orochi": _draw_cb_orochi(img, oy, f, p, d, e, a)
		"kitsune": _draw_cb_kitsune(img, oy, f, p, d, e, a)
		"colossus": _draw_cb_colossus(img, oy, f, p, d, e, a)
		_: _draw_cb_voidbeast(img, oy, f, p, d, e, a)

static func _draw_cb_orochi(img: Image, oy: int, f: int, p: Color, d: Color, e: Color, a: Color) -> void:
	# 盘踞身躯
	for yy in range(30, 47):
		var t = float(yy - 30) / 17.0
		var w = int(12 + 11 * t)
		var col = p if int(yy) % 2 == 0 else _dark(p, 0.82)
		_hline(img, 24 - w, oy + yy, w * 2, col)
	_hline(img, 11, oy + 46, 26, d)
	for i in range(7):
		_px(img, 12 + i * 4, oy + 38 + (i % 2), _dark(p, 0.6))
	# 盘身鳞甲高光脊线 + 腹甲横纹（细化）
	for yy in range(32, 46, 2):
		_px(img, 24, oy + yy, _light(p, 0.4))
	for yy in range(40, 47):
		_hline(img, 21, oy + yy, 6, _light(p, 0.18) if yy % 2 == 0 else _dark(p, 0.7))
	# 五条蛇颈（八岐之首）
	var necks = [[9, 17, -1], [16, 25, 1], [24, 30, 0], [32, 25, 1], [39, 17, -1]]
	for n in necks:
		var bx: int = n[0]
		var nh: int = n[1]
		var dir: int = n[2]
		var hx := bx
		var hy := oy + 31
		for k in range(nh):
			var yy = oy + 31 - k
			var off = int(round(sin(k * 0.35 + f * 0.6) * 2.2)) * dir
			var cx = bx + off
			_px(img, cx, yy, p)
			_px(img, cx + 1, yy, p)
			_px(img, cx - 1, yy, _dark(p, 0.78))
			hx = cx
			hy = yy
		# 蛇头
		_rect(img, hx - 2, hy - 3, 6, 4, p)
		_hline(img, hx - 2, hy - 3, 6, _light(p, 0.25))
		_px(img, hx - 1, hy - 1, e)
		_px(img, hx + 3, hy - 1, e)
		_px(img, hx - 1, hy - 1, _light(e, 0.6))
		_hline(img, hx - 1, hy + 1, 4, a)
		# 信子（红色分叉吐舌）+ 角脊
		_px(img, hx + 1, hy + 2, Color("#e0556a"))
		_px(img, hx, hy + 3, Color("#e0556a")); _px(img, hx + 2, hy + 3, Color("#e0556a"))
		_px(img, hx - 2, hy - 4, _light(p, 0.3)); _px(img, hx + 3, hy - 4, _light(p, 0.3))

static func _draw_cb_kitsune(img: Image, oy: int, f: int, p: Color, d: Color, e: Color, a: Color) -> void:
	var sway = 1 if f == 1 else 0
	var tipcol = _light(e, 0.5)
	# 九条灵尾（背后扇形展开，橙身白尖、带弧度飘动）
	var tails = 9
	for i in range(tails):
		var ang = lerpf(-1.28, 1.28, float(i) / float(tails - 1))
		var tlen = 22
		for k in range(tlen):
			var curve = sin(float(k) / float(tlen) * PI) * 2.6
			var tx = 24 + int(round(sin(ang) * k + cos(ang) * curve))
			var ty = oy + 33 - int(round(cos(ang) * k)) + (sway if k > 14 else 0)
			var col = p
			if k >= tlen - 5:
				col = tipcol
			elif k % 6 == 0:
				col = _light(p, 0.2)
			_px(img, tx, ty, col)
			_px(img, tx + 1, ty, _dark(p, 0.82))
	# 坐姿身躯（上窄下收，倒水滴）
	for yy in range(28, 45):
		var t = float(yy - 28) / 17.0
		var w = maxi(4, int(9 - 3 * t + 2 * sin(t * PI)))
		_hline(img, 24 - w, oy + yy, w * 2, p if int(yy) % 2 == 0 else _dark(p, 0.9))
	# 白胸
	_rect(img, 21, oy + 31, 6, 10, _light(e, 0.4))
	# 头盖
	_rect(img, 18, oy + 18, 12, 9, p)
	_hline(img, 18, oy + 18, 12, _light(p, 0.2))
	# 两只三角耳
	for r in range(6):
		_hline(img, 18, oy + 12 + r, r + 1, p)
		_hline(img, 29 - r, oy + 12 + r, r + 1, p)
	_px(img, 19, oy + 16, a); _px(img, 28, oy + 16, a)
	# 内耳粉 + 额心火纹（细化）
	_px(img, 20, oy + 15, Color("#ff9bb0")); _px(img, 27, oy + 15, Color("#ff9bb0"))
	_px(img, 23, oy + 19, _light(e, 0.5)); _px(img, 24, oy + 20, _light(e, 0.5))
	# 尖白吻
	_rect(img, 21, oy + 25, 6, 4, _light(e, 0.45))
	_rect(img, 22, oy + 28, 4, 2, _light(e, 0.45))
	_px(img, 23, oy + 29, d); _px(img, 24, oy + 29, d)
	_px(img, 23, oy + 27, Color("#3a2630")); _px(img, 24, oy + 27, Color("#3a2630"))   # 鼻头
	# 狐眼（金色细长，带描边 + 高光）
	_px(img, 20, oy + 22, e); _px(img, 21, oy + 22, e)
	_px(img, 27, oy + 22, e); _px(img, 26, oy + 22, e)
	_px(img, 20, oy + 22, _light(e, 0.6)); _px(img, 27, oy + 22, _light(e, 0.6))
	_px(img, 20, oy + 23, d); _px(img, 27, oy + 23, d)
	# 颊侧白毛簇
	_px(img, 17, oy + 24, _light(e, 0.4)); _px(img, 30, oy + 24, _light(e, 0.4))
	# 前爪
	_rect(img, 19, oy + 42, 3, 4, _light(e, 0.3))
	_rect(img, 26, oy + 42, 3, 4, _light(e, 0.3))

static func _draw_cb_colossus(img: Image, oy: int, f: int, p: Color, d: Color, e: Color, a: Color) -> void:
	var by = oy + 6
	var glow = e if f == 0 else _light(e, 0.4)
	# 宽肩躯干
	_rect(img, 10, by + 12, 28, 22, p)
	_vline(img, 10, by + 12, 22, d)
	_vline(img, 37, by + 12, 22, d)
	for yy in range(14, 34, 4):
		_hline(img, 11, by + yy, 26, _dark(p, 0.72))
	for xx in range(16, 38, 8):
		_vline(img, xx, by + 12, 22, _dark(p, 0.72))
	# 胸口符文（脉动）
	_rect(img, 21, by + 20, 6, 6, _dark(p, 0.5))
	_px(img, 23, by + 22, glow); _px(img, 24, by + 23, glow); _px(img, 23, by + 24, glow)
	# 躯体发光裂纹（细化：能量从符文向外延伸）
	_px(img, 20, by + 18, glow); _px(img, 19, by + 16, _dark(glow, 0.8))
	_px(img, 28, by + 23, glow); _px(img, 30, by + 26, _dark(glow, 0.8))
	_px(img, 24, by + 28, glow); _px(img, 24, by + 31, _dark(glow, 0.8))
	# 三头：中央高、两侧低
	_rect(img, 19, by - 4, 10, 10, p)
	_hline(img, 19, by - 4, 10, _light(p, 0.2))
	_px(img, 21, by, glow); _px(img, 26, by, glow)
	_hline(img, 21, by + 3, 6, d)
	_rect(img, 9, by + 2, 8, 8, p)
	_px(img, 11, by + 5, glow); _px(img, 14, by + 5, glow)
	_rect(img, 31, by + 2, 8, 8, p)
	_px(img, 33, by + 5, glow); _px(img, 36, by + 5, glow)
	# 巨臂
	_rect(img, 3, by + 14, 6, 16, p)
	_vline(img, 3, by + 14, 16, d)
	_rect(img, 39, by + 14, 6, 16, p)
	_vline(img, 44, by + 14, 16, d)
	_rect(img, 2, by + 30, 8, 6, _dark(p, 0.85))
	_rect(img, 38, by + 30, 8, 6, _dark(p, 0.85))
	# 腿基座
	_rect(img, 14, by + 34, 8, 8, _dark(p, 0.9))
	_rect(img, 26, by + 34, 8, 8, _dark(p, 0.9))

static func _draw_cb_voidbeast(img: Image, oy: int, f: int, p: Color, d: Color, e: Color, a: Color) -> void:
	var cx = 24
	var cy = oy + 22
	var core = e if f == 0 else _light(e, 0.35)
	# 核心团块
	for yy in range(-12, 13):
		var rr = int(round(sqrt(maxf(0.0, 144.0 - yy * yy)) * 0.92))
		rr = clampi(rr, 0, 15)
		var col = p if (yy + 24) % 2 == 0 else _dark(p, 0.8)
		_hline(img, cx - rr, cy + yy, rr * 2, col)
	# 虚空内核（脉动）
	_rect(img, cx - 4, cy - 4, 8, 8, _dark(p, 0.4))
	_rect(img, cx - 2, cy - 2, 4, 4, core)
	_px(img, cx, cy, _light(core, 0.5))
	# 体内星屑（细化：核团内漂浮的微光点）
	_px(img, cx - 7, cy + 2, _light(core, 0.6)); _px(img, cx + 6, cy - 5, _light(core, 0.6))
	_px(img, cx + 4, cy + 6, e); _px(img, cx - 5, cy - 6, e); _px(img, cx + 8, cy + 1, _light(core, 0.4))
	# 多眼
	var eyes = [[16, oy + 14], [32, oy + 15], [18, oy + 28], [30, oy + 27], [24, oy + 10]]
	for ey in eyes:
		_px(img, ey[0], ey[1], core)
		_px(img, ey[0] + 1, ey[1], a)
	# 触须
	var arms = [[10, 1], [16, -1], [24, 1], [32, -1], [38, 1]]
	for arm in arms:
		var bx: int = arm[0]
		var dir: int = arm[1]
		for k in range(14):
			var yy = oy + 30 + k
			var off = int(round(sin(k * 0.5 + f) * 3.0)) * dir
			var tx = bx + off
			_px(img, tx, yy, p if k < 10 else a)
			_px(img, tx + dir, yy, _dark(p, 0.8))
	# 上方虚空角
	_px(img, 18, oy + 6, a); _px(img, 17, oy + 4, a)
	_px(img, 30, oy + 6, a); _px(img, 31, oy + 4, a)

# ============================================================
# 装备图标：PATCH4 20×20 确定性资源（主体 + 稀疏元素粒子）
# ============================================================
static func item_icon(item: Dictionary) -> ImageTexture:
	var fam := EquipmentVisualRegistry.family_of(item)
	var elem := EquipmentVisualRegistry.element_for(item)
	var key := "icon_patch4|%s|%s" % [fam, elem]
	if _cache.has(key):
		return _cache[key]
	var img := EquipmentVisualCompositor.compose_icon(item)
	var t = _tex(img)
	_cache[key] = t
	return t


## 清空缓存（测试用）
static func clear_cache() -> void:
	_cache.clear()
