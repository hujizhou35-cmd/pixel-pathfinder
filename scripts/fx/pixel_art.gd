class_name PixelArt
extends RefCounted

# ============================================================
# 程序化像素美术（运行时生成 + 缓存）
# - hero_texture: 英雄整体外观随武器/护甲/饰品变化（4 帧竖排）
#   武器握在手中、护甲改变躯干样式与配色、饰品在胸前发光
# - enemy_texture / boss_texture: 高细节 2 帧怪物精灵（竖排）
# - item_icon: 100 件装备的像素图标（基底形状 × 元素配色）
# ============================================================

static var _cache: Dictionary = {}

# ---- 元素配色 ----
const ELEM_PAL = {
	"metal": { "p": Color("#e8c95a"), "d": Color("#8a6d1e") },
	"wood":  { "p": Color("#6fce62"), "d": Color("#2f6b24") },
	"water": { "p": Color("#5aa7e8"), "d": Color("#2b5a8a") },
	"fire":  { "p": Color("#ff7a3a"), "d": Color("#a8341e") },
	"earth": { "p": Color("#c49a6a"), "d": Color("#6e4a2a") },
	"":      { "p": Color("#9aa4bc"), "d": Color("#4e5468") },
}

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

# ============================================================
# 英雄：整体外观随装备变化
# 帧布局：0 待机A / 1 待机B / 2 攻击 / 3 受伤，竖排 22×26 ×4
# ============================================================
const HERO_W := 22
const HERO_H := 26

static func hero_frame_size() -> Vector2:
	return Vector2(HERO_W, HERO_H)

static func hero_texture(equipment: Dictionary) -> ImageTexture:
	var weapon = equipment.get("weapon")
	var armor = equipment.get("armor")
	var acc = equipment.get("accessory")
	var key = "hero|%s|%s|%s" % [
		_gear_sig(weapon), _gear_sig(armor), _gear_sig(acc),
	]
	if _cache.has(key):
		return _cache[key]
	var img = _img(HERO_W, HERO_H * 4)
	for f in range(4):
		_draw_hero_frame(img, f * HERO_H, f, weapon, armor, acc)
	var t = _tex(img)
	_cache[key] = t
	return t

static func _gear_sig(it) -> String:
	if it == null:
		return "-"
	return "%s/%s/%d/%d" % [str(it.get("family", it.get("key", ""))), str(it.get("element", "")), int(it.get("rarity", 0)), int(it.get("grade", 1))]

static func _draw_hero_frame(img: Image, oy: int, frame: int, weapon, armor, acc) -> void:
	var bob = 1 if frame == 1 else 0
	var lean = 1 if frame == 2 else (-1 if frame == 3 else 0)

	var skin = Color("#e8b88a")
	var skin_d = Color("#b8845a")
	var hair = Color("#5a3a22")
	var pants = Color("#2c3350")
	var boots = Color("#1c2236")

	# 护甲样式
	var afam = str(armor.get("family", "")) if armor else ""
	var agrade = int(armor.get("grade", 1)) if armor else 0
	var aelem = str(armor.get("element", "")) if armor else ""
	var arar = int(armor.get("rarity", 0)) if armor else 0
	var epal = ELEM_PAL.get(aelem, ELEM_PAL[""])
	var cloth = Color("#7a6a4e")          # 无甲布衣
	var amain: Color = cloth if armor == null else _c(epal.p).lerp(Color("#8d93a8"), 0.45)
	var adark: Color = _dark(amain)
	var trim: Color = GameData.get_rarity_color(arar) if armor else Color("#5a6278")

	var cx = 8 + lean      # 躯干左缘
	var ty = oy + 9 + bob  # 躯干顶部

	# ---- 腿与靴 ----
	_rect(img, cx + 1, ty + 9, 3, 5, pants)
	_rect(img, cx + 5, ty + 9, 3, 5, pants)
	_rect(img, cx + 0, ty + 13, 4, 3, boots)
	_rect(img, cx + 5, ty + 13, 4, 3, boots)

	# ---- 躯干（按护甲基底变化）----
	_rect(img, cx, ty, 9, 9, amain)
	_vline(img, cx, ty, 9, adark)
	_vline(img, cx + 8, ty, 9, adark)
	match afam:
		"皮甲":
			_hline(img, cx, ty + 5, 9, _dark(amain, 0.5))           # 腰带
			_px(img, cx + 4, ty + 5, Color("#e8c95a"))               # 带扣
		"锁子甲":
			for yy in range(1, 8):
				for xx in range(1, 8):
					if (xx + yy) % 2 == 0:
						_px(img, cx + xx, ty + yy, adark)            # 锁环网纹
		"板甲":
			_rect(img, cx - 1, ty, 3, 3, trim)                        # 左肩甲
			_rect(img, cx + 7, ty, 3, 3, trim)                        # 右肩甲
			_vline(img, cx + 4, ty + 1, 7, _light(amain))             # 胸中线
			_hline(img, cx + 1, ty + 7, 7, adark)
		"龙鳞甲":
			for yy in range(1, 9):
				for xx in range(1, 8):
					if yy % 2 == 0 and xx % 2 == (yy >> 1) % 2:
						_px(img, cx + xx, ty + yy, _light(amain, 0.25))  # 鳞片
			_px(img, cx - 1, ty, trim)                                # 肩刺
			_px(img, cx + 9, ty, trim)
		"布甲", "":
			_hline(img, cx, ty + 6, 9, adark)
	if armor != null and afam != "板甲" and afam != "龙鳞甲":
		_hline(img, cx, ty, 9, trim)                                  # 领口饰边

	# ---- 手臂 ----
	_rect(img, cx - 1, ty + 2, 2, 5, amain if armor else cloth)
	_rect(img, cx + 8, ty + 2, 2, 5, amain if armor else cloth)
	_px(img, cx - 1, ty + 7, skin)
	_px(img, cx + 9, ty + 7, skin)

	# ---- 头部 ----
	var hy = ty - 7
	_rect(img, cx + 1, hy, 7, 7, skin)
	_hline(img, cx + 1, hy + 6, 7, skin_d)
	# 头盔（按护甲品级）
	if agrade >= 4:
		_rect(img, cx + 1, hy - 1, 7, 4, amain)                       # 全盔
		_vline(img, cx + 1, hy, 7, adark)
		_vline(img, cx + 7, hy, 7, adark)
		_rect(img, cx + 3, hy - 3, 3, 3, GameData.get_rarity_color(arar))  # 盔缨
	elif agrade == 3:
		_rect(img, cx + 1, hy - 1, 7, 3, amain)                       # 半盔
		_hline(img, cx + 1, hy + 1, 7, adark)
	elif agrade == 2:
		_hline(img, cx + 1, hy - 1, 7, amain)                         # 软帽沿
		_hline(img, cx + 1, hy, 7, hair)
	else:
		_rect(img, cx + 1, hy - 1, 7, 2, hair)                        # 头发
	# 眼睛
	var eye = Color("#1c2236")
	if frame == 3:
		_hline(img, cx + 2, hy + 3, 2, eye)
		_hline(img, cx + 5, hy + 3, 2, eye)
	else:
		_px(img, cx + 2, hy + 3, eye)
		_px(img, cx + 5, hy + 3, eye)

	# ---- 饰品：胸前宝石 ----
	if acc != null:
		var gpal = ELEM_PAL.get(str(acc.get("element", "")), ELEM_PAL[""])
		_px(img, cx + 4, ty + 2, _c(gpal.p))
		_px(img, cx + 4, ty + 3, _light(_c(gpal.p), 0.6))

	# ---- 副手盾（重甲）----
	if agrade >= 4 and frame != 2:
		_rect(img, cx - 3, ty + 2, 3, 5, adark)
		_rect(img, cx - 2, ty + 3, 1, 3, trim)

	# ---- 武器（握在右手）----
	if weapon != null:
		_draw_hero_weapon(img, weapon, cx, ty, frame)

static func _draw_hero_weapon(img: Image, weapon, cx: int, ty: int, frame: int) -> void:
	var fam = str(weapon.get("family", "长剑"))
	var wpal = ELEM_PAL.get(str(weapon.get("element", "")), ELEM_PAL[""])
	var blade = Color("#cfd6e4").lerp(_c(wpal.p), 0.35)
	var blade_hi = _light(blade, 0.4)
	var grip = Color("#6e4a2a")
	var guard = _c(wpal.d)
	var hx = cx + 9            # 右手
	var hy = ty + 7
	var atk = frame == 2

	match fam:
		"短剑", "长剑", "刺剑", "巨剑":
			var lens = { "短剑": 6, "长剑": 9, "刺剑": 10, "巨剑": 11 }
			var wid = 2 if fam == "巨剑" else 1
			var l: int = lens.get(fam, 8)
			if atk:
				_hline(img, hx + 1, hy - 2, l, blade)                # 前刺
				if wid == 2:
					_hline(img, hx + 1, hy - 1, l, _dark(blade))
				_px(img, hx + l, hy - 2, blade_hi)
				_vline(img, hx + 1, hy - 3, 3, guard)
			else:
				_rect(img, hx, hy - l - 1, wid, l, blade)            # 竖持
				_px(img, hx, hy - l - 1, blade_hi)
				_hline(img, hx - 1, hy - 1, 3, guard)
				_px(img, hx, hy, grip)
		"手斧", "战斧", "巨斧":
			var hl = 7 if fam == "手斧" else 9
			if atk:
				_hline(img, hx, hy - 2, hl - 2, grip)
				_rect(img, hx + hl - 3, hy - 5, 3, 4, blade)
				_px(img, hx + hl - 1, hy - 5, blade_hi)
			else:
				_vline(img, hx, hy - hl, hl, grip)
				_rect(img, hx + 1, hy - hl, 3, 3, blade)             # 斧刃
				_px(img, hx + 1, hy - hl, blade_hi)
				if fam == "巨斧":
					_rect(img, hx - 3, hy - hl, 3, 3, _dark(blade)) # 双刃
		"猎弓", "长弓", "劲弩":
			if fam == "劲弩":
				_hline(img, hx, hy - 3, 6, grip)                     # 弩身
				_vline(img, hx + 1, hy - 5, 5, blade)                # 弩臂
				_px(img, hx + 5, hy - 3, blade_hi)                   # 箭头
			else:
				var bl = 8 if fam == "猎弓" else 10
				for i in range(bl):
					var off = 2 if (i > 1 and i < bl - 2) else (1 if (i > 0 and i < bl - 1) else 0)
					_px(img, hx + 1 + off, hy - bl + 1 + i, _c(wpal.d) if i % 3 == 0 else grip)
				_vline(img, hx + 1, hy - bl + 1, bl, Color(1, 1, 1, 0.55))  # 弦
				if atk:
					_hline(img, hx + 2, hy - bl / 2, 4, blade_hi)    # 搭箭
			# 背后箭袋
			_rect(img, cx - 2, ty + 1, 2, 4, Color("#4a3520"))
			_px(img, cx - 2, ty, _c(wpal.p))

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
		_draw_enemy(img, sprite_key, palette, f * size.y, f)
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
	# 高光
	_rect(img, 8, top + 2, 2, 2, _light(p, 0.55))
	_px(img, 10, top + 2, _light(p, 0.55))
	# 眼睛与嘴
	_rect(img, 9, top + 6, 2, 2, e)
	_rect(img, 14, top + 6, 2, 2, e)
	_hline(img, 11, top + 9, 3, d)
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
	_px(img, 0, by - 1, d)                     # 鼻
	_px(img, 3, by - 2, e)                     # 眼
	_px(img, 3, by - 4, d)                     # 耳
	_px(img, 6, by - 4, d)
	_hline(img, 1, by + 1, 2, _dark(p, 0.5))   # 咧嘴
	# 尾巴
	if f == 0:
		_rect(img, 21, by - 2, 4, 2, d)
		_px(img, 24, by - 3, d)
	else:
		_rect(img, 21, by, 4, 2, d)
	# 四肢
	var ly = by + 6
	for lx in [7, 11, 15, 19]:
		_rect(img, lx, ly, 2, 5 - bob, d)
		_px(img, lx, ly + 4 - bob, _dark(d, 0.7))

static func _draw_scorpion(img: Image, oy: int, f: int, p: Color, d: Color, e: Color) -> void:
	var by = oy + 9
	# 三节躯壳
	_rect(img, 8, by, 6, 5, p)
	_rect(img, 13, by + 1, 5, 4, _dark(p, 0.85))
	_rect(img, 17, by + 2, 4, 3, _dark(p, 0.75))
	_hline(img, 8, by, 6, _light(p, 0.25))
	# 头与眼
	_rect(img, 5, by + 1, 4, 4, p)
	_px(img, 6, by + 2, e)
	# 双螯
	var open = f == 1
	_rect(img, 2, by - 1, 3, 2, d)
	_rect(img, 1, by + (0 if open else 1), 2, 2, p)
	_rect(img, 2, by + 4, 3, 2, d)
	_rect(img, 1, by + (5 if open else 4), 2, 2, p)
	# 尾节上弯 + 毒针
	var tx = 20
	var ty0 = by + 1 - f
	_px(img, tx, ty0, d); _px(img, tx + 1, ty0 - 1, d)
	_px(img, tx + 2, ty0 - 2, p); _px(img, tx + 2, ty0 - 3, p)
	_px(img, tx + 1, ty0 - 4, e)               # 毒针尖
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
	else:
		_rect(img, 10, by + 7, 2, 2, e)                # 胸核
	_rect(img, 8, by + 4, 2, 2, d if not flame else Color("#2a1408"))
	_rect(img, 13, by + 4, 2, 2, d if not flame else Color("#2a1408"))

static func _draw_construct(img: Image, oy: int, f: int, p: Color, d: Color, e: Color) -> void:
	var by = oy + 4 + f
	# 浮空头块
	_rect(img, 9, by - 4, 8, 4, p)
	_hline(img, 9, by - 4, 8, _light(p, 0.3))
	_rect(img, 11, by - 3, 2, 2, e)
	_rect(img, 14, by - 3, 1, 2, e)
	# 躯干石块
	_rect(img, 7, by + 1, 12, 9, p)
	_vline(img, 7, by + 1, 9, d)
	_vline(img, 18, by + 1, 9, d)
	_hline(img, 7, by + 9, 12, d)
	# 胸口符文
	_px(img, 12, by + 3, e); _px(img, 13, by + 4, e)
	_px(img, 12, by + 5, e); _px(img, 11, by + 4, e)
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
	# 大块毛躯
	_rect(img, 6, by + 3, 14, 13, p)
	_hline(img, 6, by + 3, 14, _light(p, 0.3))
	# 毛发纹理
	for yy in range(4, 15, 3):
		for xx in range(7, 19, 4):
			_px(img, xx + (yy % 2), by + yy, d)
	# 脸部凹陷
	_rect(img, 9, by + 4, 8, 5, d)
	_rect(img, 10, by + 5, 2, 2, e)
	_rect(img, 14, by + 5, 2, 2, e)
	_hline(img, 11, by + 8, 4, _dark(d, 0.6))
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
		_draw_boss(img, region, palette, f * 30, f)
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
# 装备图标：基底形状 × 元素配色（14×14）
# ============================================================
static func item_icon(item: Dictionary) -> ImageTexture:
	var fam = str(item.get("family", item.get("key", "长剑")))
	var elem = str(item.get("element", ""))
	var key = "icon|%s|%s" % [fam, elem]
	if _cache.has(key):
		return _cache[key]
	var img = _img(14, 14)
	var pal = ELEM_PAL.get(elem, ELEM_PAL[""])
	var pc: Color = _c(pal.p)
	var dc: Color = _c(pal.d)
	_draw_icon(img, fam, pc, dc)
	var t = _tex(img)
	_cache[key] = t
	return t

static func _draw_icon(img: Image, fam: String, pc: Color, dc: Color) -> void:
	var steel = Color("#cfd6e4").lerp(pc, 0.4)
	var grip = Color("#6e4a2a")
	match fam:
		"短剑", "长剑", "刺剑", "巨剑":
			var l = { "短剑": 6, "长剑": 9, "刺剑": 10, "巨剑": 10 }.get(fam, 8)
			var wide = fam == "巨剑"
			for i in range(l):
				_px(img, 11 - i, 2 + i, steel)
				if wide:
					_px(img, 12 - i, 2 + i, _dark(steel, 0.75))
			_px(img, 11, 2, _light(steel, 0.5))
			_px(img, 12 - l, 3 + l - 1, dc)     # 护手
			_px(img, 13 - l, 2 + l, dc)
			_px(img, 11 - l, 4 + l - 1, grip)
			_px(img, 10 - l + (1 if l > 8 else 0), 5 + l - 1 - (1 if l > 8 else 0), grip)
		"手斧", "战斧", "巨斧":
			for i in range(8):
				_px(img, 4 + i, 11 - i, grip)
			_rect(img, 9, 1, 4, 4, steel)
			_px(img, 12, 1, _light(steel, 0.5))
			_px(img, 9, 4, dc)
			if fam == "巨斧":
				_rect(img, 5, 1, 3, 4, _dark(steel, 0.8))
			if fam == "手斧":
				_rect(img, 9, 1, 3, 3, steel)
		"猎弓", "长弓", "劲弩":
			if fam == "劲弩":
				_hline(img, 2, 7, 9, grip)
				_vline(img, 4, 3, 9, steel)
				_px(img, 3, 3, dc); _px(img, 3, 11, dc)
				_px(img, 11, 7, _light(steel, 0.6))
			else:
				for i in range(10):
					var off = 2 if (i > 2 and i < 7) else (1 if (i > 0 and i < 9) else 0)
					_px(img, 8 + off, 2 + i, dc if i % 3 == 0 else grip)
				_vline(img, 8, 2, 10, Color(1, 1, 1, 0.5))
				_hline(img, 4, 7, 5, steel)
				_px(img, 3, 7, _light(steel, 0.6))
		"布甲", "皮甲", "锁子甲", "板甲", "龙鳞甲":
			# 躯干轮廓
			_rect(img, 4, 3, 6, 8, pc)
			_rect(img, 2, 3, 2, 4, pc)
			_rect(img, 10, 3, 2, 4, pc)
			_vline(img, 4, 3, 8, dc)
			_vline(img, 9, 3, 8, dc)
			_hline(img, 4, 10, 6, dc)
			match fam:
				"皮甲":
					_hline(img, 4, 7, 6, dc)
					_px(img, 6, 7, Color("#e8c95a"))
				"锁子甲":
					for yy in range(4, 10):
						for xx in range(5, 9):
							if (xx + yy) % 2 == 0:
								_px(img, xx, yy, dc)
				"板甲":
					_vline(img, 6, 4, 6, _light(pc, 0.4))
					_hline(img, 2, 3, 3, _light(pc, 0.4))
					_hline(img, 9, 3, 3, _light(pc, 0.4))
				"龙鳞甲":
					for yy in range(4, 10, 2):
						for xx in range(5, 9, 2):
							_px(img, xx + (yy >> 1) % 2, yy, _light(pc, 0.35))
					_px(img, 3, 2, dc); _px(img, 10, 2, dc)
		"木刻护符":
			_vline(img, 6, 2, 3, grip)
			_rect(img, 4, 5, 5, 6, pc)
			_px(img, 6, 7, dc); _px(img, 6, 8, dc)
			_hline(img, 5, 9, 3, dc)
		"铜纹戒指":
			for t in range(16):
				var ang = TAU * t / 16.0
				_px(img, 7 + roundi(cos(ang) * 4), 7 + roundi(sin(ang) * 4), pc)
			_px(img, 7, 3, _light(pc, 0.6))
			_px(img, 7, 2, dc)
		"银辉徽章":
			_rect(img, 4, 3, 6, 6, pc)
			_px(img, 4, 3, _light(pc, 0.4)); _px(img, 9, 3, _light(pc, 0.4))
			_px(img, 5, 9, dc); _px(img, 7, 10, dc); _px(img, 8, 9, dc)
			_rect(img, 6, 5, 2, 2, _light(pc, 0.55))
		"秘语契珠":
			for t in range(20):
				var ang = TAU * t / 20.0
				_px(img, 7 + roundi(cos(ang) * 4.4), 7 + roundi(sin(ang) * 4.4), dc)
			_rect(img, 5, 5, 4, 4, pc)
			_px(img, 6, 6, _light(pc, 0.6))
			_px(img, 8, 8, _light(pc, 0.3))
		"圣辉遗物":
			_vline(img, 7, 2, 9, pc)
			_hline(img, 4, 5, 7, pc)
			_px(img, 7, 2, _light(pc, 0.5))
			_px(img, 4, 5, dc); _px(img, 10, 5, dc)
			_rect(img, 6, 11, 3, 2, dc)
		_:
			_rect(img, 4, 4, 6, 6, pc)
			_px(img, 5, 5, _light(pc, 0.4))

## 清空缓存（测试用）
static func clear_cache() -> void:
	_cache.clear()
