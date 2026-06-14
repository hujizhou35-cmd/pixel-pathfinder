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

## 环形最短路径 hue 偏移（避免线性插值绕错半圈把红变绿）
static func _hue_toward(h: float, target: float, step: float) -> float:
	var diff = target - h
	if diff > 0.5: diff -= 1.0
	elif diff < -0.5: diff += 1.0
	return fposmod(h + clampf(diff, -step, step), 1.0)

## 受光色：提亮 + 降饱和 + 色相微偏暖黄（专业像素的冷暗暖亮配色法）
static func _hi(c: Color, amt: float = 0.24) -> Color:
	if c.a < 0.5:
		return c
	var v = clampf(c.v + amt * 0.85, 0.0, 1.0)
	var s = clampf(c.s - amt * 0.30, 0.0, 1.0)
	var h = _hue_toward(c.h, 0.13, amt * 0.10) if c.s > 0.04 else c.h
	return Color.from_hsv(h, s, v, c.a)

## 背光色：压暗 + 升饱和 + 色相微偏冷紫
static func _sh(c: Color, amt: float = 0.22) -> Color:
	if c.a < 0.5:
		return c
	var v = clampf(c.v - amt * 0.95, 0.0, 1.0)
	var s = clampf(c.s + amt * 0.22, 0.0, 1.0)
	var h = _hue_toward(c.h, 0.66, amt * 0.12) if c.s > 0.04 else c.h
	return Color.from_hsv(h, s, v, c.a)

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
	var weapon = equipment.get("weapon")
	var armor = equipment.get("armor")
	var helmet = equipment.get("helmet")
	var pants = equipment.get("pants")
	var boots = equipment.get("boots")
	var acc = equipment.get("accessory")
	var key = "hero|%s|%s|%s|%s|%s|%s" % [
		_gear_sig(weapon), _gear_sig(armor), _gear_sig(helmet),
		_gear_sig(pants), _gear_sig(boots), _gear_sig(acc),
	]
	if _cache.has(key):
		return _cache[key]
	var img = _img(HERO_W, HERO_H * 4)
	for f in range(4):
		# 逐帧绘制 → 描边 → 拼合（避免轮廓跨帧渗透）
		var frame = _img(HERO_W, HERO_H)
		_draw_hero_frame(frame, 0, f, equipment)
		_apply_outline(frame, OUTLINE)
		img.blit_rect(frame, Rect2i(0, 0, HERO_W, HERO_H), Vector2i(0, f * HERO_H))
	var t = _tex(img)
	_cache[key] = t
	return t

static func _gear_sig(it) -> String:
	if it == null:
		return "-"
	return "%s/%s/%d/%d" % [str(it.get("family", it.get("key", ""))), str(it.get("element", "")), int(it.get("rarity", 0)), int(it.get("grade", 1))]

## 装备主色：元素配色与铁灰混合，稀有度越高越鲜亮
static func _gear_main(it, fallback: Color) -> Color:
	if it == null:
		return fallback
	var pal = ELEM_PAL.get(str(it.get("element", "")), ELEM_PAL[""])
	var mix = 0.40 + 0.06 * int(it.get("rarity", 0))
	return Color("#8d93a8").lerp(_c(pal.p), mix)

static func _draw_hero_frame(img: Image, oy: int, frame: int, eq: Dictionary) -> void:
	var weapon = eq.get("weapon")
	var armor = eq.get("armor")
	var helmet = eq.get("helmet")
	var pants_it = eq.get("pants")
	var boots_it = eq.get("boots")
	var acc = eq.get("accessory")

	var bob = 1 if frame == 1 else 0
	var lean = 1 if frame == 2 else (-1 if frame == 3 else 0)

	var skin = Color("#f2c08a")
	var skin_hi = Color("#fbd9ac")
	var skin_d = Color("#c88a58")
	var hair = Color("#6a4427")
	var hair_hi = Color("#8a5e38")

	# 各部位主色
	var cloth = Color("#8a7654")
	var amain: Color = _gear_main(armor, cloth)
	var adark: Color = _dark(amain)
	var ahi: Color = _light(amain, 0.3)
	var trim: Color = GameData.get_rarity_color(int(armor.get("rarity", 0))) if armor else Color("#5a6278")
	var pmain: Color = _gear_main(pants_it, Color("#34406a"))
	var pdark: Color = _dark(pmain)
	var bmain: Color = _gear_main(boots_it, Color("#2a3146"))
	var bdark: Color = _dark(bmain, 0.55)
	var gold = Color("#f2cf5e")
	var steel_hi = Color("#d8e0f0")

	var afam = str(armor.get("family", "")) if armor else ""
	var hfam = str(helmet.get("family", "")) if helmet else ""
	var pfam = str(pants_it.get("family", "")) if pants_it else ""
	var bfam = str(boots_it.get("family", "")) if boots_it else ""
	var agrade = int(armor.get("grade", 1)) if armor else 0

	# 战士骨架（写实比例）：头 11×10（约体高 1/4.5）/ 躯干 14×14 / 腿 10 / 靴 9
	var hx0 = 15 + lean       # 头部左缘（宽 11）
	var hy0 = oy + 4 + bob    # 头部顶
	var cx = 13 + lean        # 躯干左缘（宽 14）
	var ty = oy + 15 + bob    # 躯干顶部（14 高）

	# ============ 腿部（裤子：双腿分明，y ty+14..ty+23） ============
	var ly = ty + 14
	for i in range(2):
		var leg_x = cx + 1 + i * 7    # 左腿 cx+1..cx+5 / 右腿 cx+8..cx+12（5 宽）
		_rect(img, leg_x, ly, 5, 10, pmain)
		_vline(img, leg_x + 4, ly, 10, pdark)               # 内/背光侧
		_vline(img, leg_x, ly, 10, _light(pmain, 0.15))     # 受光侧
		_hline(img, leg_x, ly + 9, 5, pdark)
	match pfam:
		"布裤":
			_rect(img, cx + 9, ly + 4, 2, 2, pdark)          # 补丁
		"皮裤":
			_vline(img, cx + 3, ly + 1, 8, pdark)            # 皮革缝线
			_vline(img, cx + 10, ly + 1, 8, pdark)
			_hline(img, cx + 1, ly + 7, 5, pdark)            # 绑带
			_hline(img, cx + 8, ly + 7, 5, pdark)
		"链甲裤":
			for yy in range(1, 9):
				for xx in [1, 3, 8, 10, 12]:
					if (xx + yy) % 2 == 0:
						_px(img, cx + xx, ly + yy, pdark)
		"板甲腿铠":
			_rect(img, cx + 1, ly + 2, 5, 3, _light(pmain, 0.4))    # 膝甲板
			_rect(img, cx + 8, ly + 2, 5, 3, _light(pmain, 0.4))
			_hline(img, cx + 1, ly + 4, 5, pdark)
			_hline(img, cx + 8, ly + 4, 5, pdark)
			_vline(img, cx + 2, ly + 6, 4, _light(pmain, 0.25))     # 胫甲反光
			_vline(img, cx + 9, ly + 6, 4, _light(pmain, 0.25))
		"龙鳞腿甲":
			for yy in range(1, 9, 2):
				for xx in [1, 3, 8, 10]:
					_px(img, cx + xx + (yy >> 1) % 2, ly + yy, _light(pmain, 0.32))
			_px(img, cx + 1, ly + 2, trim)                   # 膝刺
			_px(img, cx + 12, ly + 2, trim)

	# ============ 鞋（靴筒 + 脚掌，y ty+24..ty+32） ============
	var by = ly + 10
	for i in range(2):
		var bx = cx + 1 + i * 7
		var toe = (-2 if i == 0 else 5)                      # 鞋尖朝外
		_rect(img, bx, by, 5, 5, bmain)                      # 靴筒
		_vline(img, bx, by, 5, _light(bmain, 0.25))
		_vline(img, bx + 4, by, 5, bdark)
		_rect(img, bx + (toe if i == 0 else 0), by + 5, 7, 3, bmain)  # 脚掌
		_hline(img, bx + (toe if i == 0 else 0), by + 7, 7, bdark)    # 鞋底
		_px(img, bx + (toe if i == 0 else 6), by + 5, _light(bmain, 0.3))  # 鞋尖受光
	match bfam:
		"草编鞋":
			for yy in [by + 1, by + 3]:
				_px(img, cx + 2, yy, bdark)
				_px(img, cx + 10, yy, bdark)
			_hline(img, cx + 1, by, 5, _dark(bmain, 0.5))    # 编织口
			_hline(img, cx + 8, by, 5, _dark(bmain, 0.5))
		"皮靴":
			_hline(img, cx + 1, by + 1, 5, _dark(bmain, 0.5))   # 翻折靴口
			_hline(img, cx + 8, by + 1, 5, _dark(bmain, 0.5))
			_px(img, cx + 3, by + 3, gold)                   # 靴扣
			_px(img, cx + 10, by + 3, gold)
		"铁头靴":
			_rect(img, cx - 1, by + 5, 2, 2, steel_hi)       # 铁鞋头
			_rect(img, cx + 12, by + 5, 2, 2, steel_hi)
			_hline(img, cx + 1, by, 5, steel_hi)             # 铁护胫缘
			_hline(img, cx + 8, by, 5, steel_hi)
		"疾风靴":
			_px(img, cx, by + 1, Color("#eef4ff"))           # 踝部翼羽
			_px(img, cx - 1, by, Color("#eef4ff"))
			_px(img, cx - 2, by - 1, Color("#eef4ff"))
			_px(img, cx + 12, by + 1, Color("#eef4ff"))
			_px(img, cx + 13, by, Color("#eef4ff"))
			_px(img, cx + 14, by - 1, Color("#eef4ff"))
		"龙行靴":
			for xx in [2, 4, 9, 11]:
				_px(img, cx + xx, by + 1, _light(bmain, 0.4))   # 鳞列
				_px(img, cx + xx, by + 3, _light(bmain, 0.4))
			_px(img, cx - 2, by + 6, trim)                   # 爪尖
			_px(img, cx + 13, by + 6, trim)

	# ============ 腰带（裤腰，分隔躯干与腿） ============
	_hline(img, cx + 1, ly - 1, 12, _dark(pmain, 0.42))
	_rect(img, cx + 6, ly - 1, 2, 1, gold)                   # 带扣

	# ============ 躯干（铠甲：14×14 大画布做真实甲胄结构） ============
	_rect(img, cx, ty, 14, 14, amain)
	_vline(img, cx + 13, ty, 14, adark)                      # 背光缘
	_vline(img, cx, ty, 14, ahi)                             # 受光缘
	_hline(img, cx + 1, ty, 12, ahi)
	_hline(img, cx, ty + 13, 14, adark)
	match afam:
		"布甲", "":
			# 布衣：V 领衣襟 + 腰绳 + 褶皱
			_px(img, cx + 6, ty + 1, adark); _px(img, cx + 7, ty + 1, adark)
			_px(img, cx + 5, ty, adark); _px(img, cx + 8, ty, adark)
			_vline(img, cx + 6, ty + 2, 9, _dark(amain, 0.8))
			_hline(img, cx + 1, ty + 9, 12, _dark(amain, 0.6))   # 腰绳
			_vline(img, cx + 3, ty + 10, 3, _dark(amain, 0.8))   # 垂褶
			_vline(img, cx + 10, ty + 10, 3, _dark(amain, 0.8))
		"皮甲":
			# 皮甲：斜挎剑带 + 双层皮片 + 铆钉
			for i in range(12):
				_px(img, cx + 1 + i, ty + 1 + i / 2, _dark(amain, 0.55))   # 斜挎带
			_hline(img, cx + 1, ty + 6, 12, _dark(amain, 0.6))   # 上皮片缘
			_hline(img, cx + 1, ty + 10, 12, _dark(amain, 0.6))  # 下皮片缘
			for xx in [2, 6, 11]:
				_px(img, cx + xx, ty + 7, gold)               # 铆钉排
			_px(img, cx + 4, ty + 2, gold)                    # 剑带扣
		"锁子甲":
			# 锁子甲：满身环锁 + 护颈锁圈 + 下摆
			for yy in range(2, 13):
				for xx in range(1, 13):
					if (xx + yy) % 2 == 0:
						_px(img, cx + xx, ty + yy, adark)
			_hline(img, cx + 1, ty + 1, 12, _dark(amain, 0.5))   # 锁甲护颈缘
			_hline(img, cx, ty + 12, 14, _dark(amain, 0.5))      # 锁甲下摆
		"板甲":
			# 板甲：护喉 + 大肩甲 + 分块胸甲 + 腹甲裙
			_hline(img, cx + 4, ty, 6, trim)                  # 护喉
			_rect(img, cx - 3, ty, 5, 5, trim)                # 左大肩甲
			_rect(img, cx + 12, ty, 5, 5, trim)               # 右大肩甲
			_hline(img, cx - 3, ty, 5, _light(trim, 0.45))
			_hline(img, cx + 12, ty, 5, _light(trim, 0.45))
			_hline(img, cx - 3, ty + 4, 5, _dark(trim, 0.6))
			_hline(img, cx + 12, ty + 4, 5, _dark(trim, 0.6))
			_vline(img, cx + 6, ty + 2, 7, _light(amain, 0.5))    # 胸甲中脊
			_vline(img, cx + 7, ty + 2, 7, _light(amain, 0.2))
			_hline(img, cx + 2, ty + 5, 10, _light(amain, 0.18))  # 胸肌甲弧线
			_hline(img, cx + 1, ty + 9, 12, adark)            # 胸/腹甲分界
			_hline(img, cx + 1, ty + 11, 12, _dark(amain, 0.75))  # 腹甲叠片
			_px(img, cx + 2, ty + 2, gold); _px(img, cx + 11, ty + 2, gold)  # 铆钉
		"龙鳞甲":
			# 龙鳞甲：弧形鳞排 + 肩部龙刺 + 鳞缘
			for yy in range(2, 13, 2):
				for xx in range(1, 13, 3):
					var sx = cx + xx + ((yy >> 1) % 2)
					_px(img, sx, ty + yy, _light(amain, 0.32))
					_px(img, sx + 1, ty + yy, _light(amain, 0.18))
					_px(img, sx, ty + yy + 1, _dark(amain, 0.8))
			_px(img, cx - 1, ty, trim); _px(img, cx - 2, ty - 1, trim)        # 左肩龙刺
			_px(img, cx - 2, ty - 2, _light(trim, 0.4))
			_px(img, cx + 14, ty, trim); _px(img, cx + 15, ty - 1, trim)      # 右肩龙刺
			_px(img, cx + 15, ty - 2, _light(trim, 0.4))
			_hline(img, cx + 1, ty + 1, 12, trim)             # 鳞甲领缘
	if armor != null and afam in ["布甲", "皮甲", "锁子甲"]:
		_hline(img, cx, ty, 14, trim)                          # 领口饰边

	# ============ 手臂（带肩部结构） ============
	var sleeve = amain if armor else cloth
	for i in range(2):
		var ax = (cx - 3) if i == 0 else (cx + 14)
		_rect(img, ax, ty + 1, 3, 10, sleeve)
		_vline(img, ax + (2 if i == 0 else 0), ty + 1, 10, _dark(sleeve, 0.72))
		_vline(img, ax + (0 if i == 0 else 2), ty + 1, 10, _light(sleeve, 0.18))
		# 手（拳）
		_rect(img, ax, ty + 11, 3, 2, skin)
		_px(img, ax + (2 if i == 0 else 0), ty + 12, skin_d)
		# 护腕
		_hline(img, ax, ty + 9, 3, _dark(sleeve, 0.55))

	# ============ 头部（写实小头：11 宽 × 10 高） ============
	_rect(img, hx0, hy0 + 1, 11, 9, skin)
	_hline(img, hx0 + 1, hy0 + 1, 9, skin_hi)                # 额头受光
	_hline(img, hx0, hy0 + 9, 11, skin_d)                    # 下颌阴影
	_vline(img, hx0 + 10, hy0 + 2, 7, skin_d)
	# 颈部
	_rect(img, hx0 + 3, hy0 + 10, 5, 1, skin_d)
	# 眼睛（冷静的战士眼神；受伤帧闭眼）
	var eye = Color("#1a2236")
	var ey = hy0 + 5
	if frame == 3:
		_hline(img, hx0 + 2, ey + 1, 2, eye)
		_hline(img, hx0 + 7, ey + 1, 2, eye)
	else:
		_hline(img, hx0 + 2, ey, 2, eye)
		_hline(img, hx0 + 7, ey, 2, eye)
		_px(img, hx0 + 2, ey - 1, _dark(hair, 0.8))          # 眉
		_px(img, hx0 + 3, ey - 1, _dark(hair, 0.8))
		_px(img, hx0 + 7, ey - 1, _dark(hair, 0.8))
		_px(img, hx0 + 8, ey - 1, _dark(hair, 0.8))
	# 嘴（抿紧）
	_hline(img, hx0 + 4, hy0 + 8, 3, skin_d)

	# ============ 头盔（真实盔形设计；无盔=利落短发） ============
	var hmain: Color = _gear_main(helmet, hair)
	var hdark: Color = _dark(hmain)
	var hhi: Color = _light(hmain, 0.38)
	var htrim: Color = GameData.get_rarity_color(int(helmet.get("rarity", 0))) if helmet else hair
	match hfam:
		"":
			# 利落短发：层次分明 + 鬓角
			_rect(img, hx0, hy0 - 1, 11, 3, hair)
			_hline(img, hx0 + 1, hy0 - 1, 7, hair_hi)
			_px(img, hx0 + 9, hy0 + 2, hair)
			_px(img, hx0, hy0 + 2, hair)
			_px(img, hx0, hy0 + 3, hair)                       # 左鬓角
			_px(img, hx0 + 10, hy0 + 3, hair)                  # 右鬓角
		"皮帽":
			# 游侠皮帽：斜檐 + 束带 + 翎羽
			_rect(img, hx0 - 1, hy0 - 1, 13, 3, hmain)
			_hline(img, hx0, hy0 - 1, 9, hhi)
			_hline(img, hx0 - 2, hy0 + 1, 6, hdark)            # 左斜檐压低
			_hline(img, hx0 - 1, hy0 + 2, 3, hdark)
			_px(img, hx0 + 11, hy0 - 2, htrim)                 # 翎羽
			_px(img, hx0 + 12, hy0 - 3, htrim)
			_px(img, hx0 + 12, hy0 - 4, _light(htrim, 0.4))
		"铁盔":
			# 维京式护鼻盔：圆顶 + 包边 + 护鼻条
			_rect(img, hx0, hy0 - 2, 11, 4, hmain)
			_px(img, hx0 + 1, hy0 - 3, hmain); _hline(img, hx0 + 2, hy0 - 3, 7, hmain)
			_hline(img, hx0 + 2, hy0 - 3, 5, hhi)              # 顶部受光
			_hline(img, hx0, hy0 + 1, 11, hdark)               # 盔缘包边
			_vline(img, hx0 + 5, hy0 + 2, 4, hmain)            # 护鼻条
			_vline(img, hx0 + 5, hy0 + 2, 2, hhi)
			_px(img, hx0 + 1, hy0 - 1, gold)                   # 缘饰铆钉
			_px(img, hx0 + 9, hy0 - 1, gold)
		"战盔":
			# 军团战盔：横向冠脊 + 护颊 + 护颈
			_rect(img, hx0, hy0 - 2, 11, 4, hmain)
			_hline(img, hx0 + 1, hy0 - 2, 8, hhi)
			_hline(img, hx0 - 1, hy0 - 3, 13, htrim)           # 横冠脊
			_px(img, hx0 - 1, hy0 - 2, htrim)
			_px(img, hx0 + 11, hy0 - 2, htrim)
			_rect(img, hx0, hy0 + 2, 2, 6, hmain)              # 左护颊
			_rect(img, hx0 + 9, hy0 + 2, 2, 6, hmain)          # 右护颊
			_vline(img, hx0, hy0 + 2, 6, hdark)
			_vline(img, hx0 + 10, hy0 + 2, 6, hdark)
			_hline(img, hx0 + 3, hy0 + 10, 5, hdark)           # 护颈缘
		"骑士盔":
			# 全覆面巨盔：面甲观察缝 + 呼吸孔 + 高马尾盔缨
			_rect(img, hx0, hy0 - 2, 11, 12, hmain)            # 整盔覆面
			_vline(img, hx0, hy0 - 2, 12, hhi)
			_vline(img, hx0 + 10, hy0 - 2, 12, hdark)
			_hline(img, hx0 + 1, hy0 - 2, 9, hhi)
			_hline(img, hx0 + 1, hy0 + 4, 9, Color("#0c101e"))  # 观察缝
			_px(img, hx0 + 2, hy0 + 4, Color("#7fd8ff"))        # 缝中目光
			_px(img, hx0 + 7, hy0 + 4, Color("#7fd8ff"))
			for xx in [3, 5, 7]:
				_px(img, hx0 + xx, hy0 + 7, hdark)              # 呼吸孔
			_hline(img, hx0 + 2, hy0 + 1, 7, hdark)             # 面甲铰线
			_vline(img, hx0 + 5, hy0 - 5, 3, htrim)             # 盔缨杆
			_px(img, hx0 + 6, hy0 - 4, htrim)                   # 缨羽后飘
			_px(img, hx0 + 7, hy0 - 3, htrim)
			_px(img, hx0 + 8, hy0 - 3, _dark(htrim, 0.7))
			_px(img, hx0 + 5, hy0 - 5, _light(htrim, 0.45))
		"龙首盔":
			# 龙首盔：上颌面甲 + 双弯角 + 颈鬃
			_rect(img, hx0, hy0 - 2, 11, 5, hmain)             # 龙颅顶
			_hline(img, hx0 + 1, hy0 - 2, 8, hhi)
			_rect(img, hx0 - 1, hy0 + 2, 4, 2, hmain)          # 上颌左凸（龙吻）
			_rect(img, hx0 + 8, hy0 + 2, 4, 2, hmain)
			_px(img, hx0 - 1, hy0 + 3, _dark(hmain, 0.6))      # 龙齿阴影
			_px(img, hx0 + 11, hy0 + 3, _dark(hmain, 0.6))
			# 双弯角（向上外扬，角尖亮色）
			_px(img, hx0 + 1, hy0 - 3, hmain)
			_px(img, hx0, hy0 - 4, htrim)
			_px(img, hx0 - 1, hy0 - 5, htrim)
			_px(img, hx0 - 1, hy0 - 6, _light(htrim, 0.45))
			_px(img, hx0 + 9, hy0 - 3, hmain)
			_px(img, hx0 + 10, hy0 - 4, htrim)
			_px(img, hx0 + 11, hy0 - 5, htrim)
			_px(img, hx0 + 11, hy0 - 6, _light(htrim, 0.45))
			_px(img, hx0 + 5, hy0 - 3, htrim)                  # 眉脊
			_rect(img, hx0 + 4, hy0 - 1, 3, 1, _dark(hmain, 0.7))  # 鼻梁甲

	# ============ 饰品：胸前项链宝石 ============
	if acc != null:
		var gpal = ELEM_PAL.get(str(acc.get("element", "")), ELEM_PAL[""])
		var gem = _c(gpal.p)
		_px(img, cx + 5, ty + 2, _dark(gem, 0.6))              # 链
		_px(img, cx + 8, ty + 2, _dark(gem, 0.6))
		_px(img, cx + 6, ty + 3, gem)
		_px(img, cx + 7, ty + 3, _light(gem, 0.55))
		_px(img, cx + 6, ty + 4, _dark(gem, 0.75))
		_px(img, cx + 7, ty + 4, gem)

	# ============ 副手鸢盾（重甲 4 级以上，攻击帧收起） ============
	if agrade >= 4 and frame != 2:
		_rect(img, cx - 7, ty + 3, 5, 8, adark)
		_px(img, cx - 6, ty + 11, adark)                       # 盾尖
		_px(img, cx - 5, ty + 11, adark)
		_px(img, cx - 5, ty + 12, _dark(adark, 0.7))
		_vline(img, cx - 5, ty + 4, 7, trim)                   # 盾面纹章
		_hline(img, cx - 6, ty + 6, 3, trim)
		_hline(img, cx - 7, ty + 3, 5, _light(adark, 0.35))

	# ============ 武器（握在右手） ============
	if weapon != null:
		_draw_hero_weapon(img, weapon, cx, ty, frame)

static func _draw_hero_weapon(img: Image, weapon, cx: int, ty: int, frame: int) -> void:
	var fam = str(weapon.get("family", "长剑"))
	var wpal = ELEM_PAL.get(str(weapon.get("element", "")), ELEM_PAL[""])
	var blade = Color("#d8dfec").lerp(_c(wpal.p), 0.38)
	var blade_hi = _light(blade, 0.5)
	var blade_d = _dark(blade, 0.7)
	var grip = Color("#7a5430")
	var guard = _c(wpal.d)
	var gold = Color("#f2cf5e")
	var atk = frame == 2
	var hx = cx + 17 + (2 if atk else 0)   # 右手外侧（攻击帧前送）
	var hy = ty + 11
	var streak = Color(1, 1, 1, 0.35)      # 攻击残影

	match fam:
		"短剑", "长剑", "刺剑", "巨剑":
			# 真实剑形：短剑宽短 / 长剑十字血槽 / 刺剑细长杯护手 / 巨剑三宽巨刃
			var lens = { "短剑": 9, "长剑": 14, "刺剑": 16, "巨剑": 18 }
			var wid = 3 if fam == "巨剑" else (1 if fam == "刺剑" else 2)
			var l: int = lens.get(fam, 13)
			var bx = hx
			var btop = hy - 2 - l
			_rect(img, bx, btop, wid, l, blade)                 # 刃身
			_vline(img, bx, btop + 2, l - 4, blade_hi)          # 受光刃面
			if wid >= 2:
				_vline(img, bx + wid - 1, btop + 2, l - 4, blade_d)
			if fam in ["长剑", "巨剑"]:
				_vline(img, bx + wid / 2, btop + 3, l - 6, blade_d)  # 血槽
			# 剑尖收锋
			_px(img, bx, btop - 1, blade_hi)
			if wid >= 2:
				_px(img, bx + 1, btop, blade)
			match fam:
				"短剑":
					_hline(img, bx - 2, hy - 2, 6, guard)
					_px(img, bx - 2, hy - 2, _light(guard, 0.3))
				"长剑":
					_hline(img, bx - 3, hy - 2, 8, guard)        # 十字护手
					_px(img, bx - 3, hy - 3, guard)
					_px(img, bx + 4, hy - 3, guard)
					_px(img, bx - 3, hy - 2, _light(guard, 0.3))
				"刺剑":
					_rect(img, bx - 2, hy - 4, 5, 3, guard)      # 杯形护手
					_px(img, bx - 2, hy - 5, guard)
					_px(img, bx + 2, hy - 5, guard)
					_px(img, bx - 1, hy - 4, _light(guard, 0.35))
				"巨剑":
					_hline(img, bx - 3, hy - 2, 9, guard)        # 厚重宽护手
					_hline(img, bx - 3, hy - 3, 9, _dark(guard, 0.7))
					_px(img, bx - 3, hy - 4, guard)
					_px(img, bx + 5, hy - 4, guard)
			_vline(img, bx + wid / 2, hy - 1, 3, grip)           # 握柄
			_px(img, bx + wid / 2, hy + 2, gold)                 # 配重球
			if atk:
				_vline(img, bx - 3, btop + 3, l - 5, streak)     # 挥击残影
				_px(img, bx - 4, btop + 5, streak)
		"手斧", "战斧", "巨斧":
			# 真实斧形：手斧短柄单刃 / 战斧长柄大刃背刺 / 巨斧双月刃
			var hl = 10 if fam == "手斧" else 14
			var sx = hx + 1
			_vline(img, sx, hy - hl + 2, hl + 1, grip)           # 斧柄
			_px(img, sx, hy - hl / 2, _dark(grip, 0.65))         # 缠绳
			_px(img, sx, hy - hl / 2 + 2, _dark(grip, 0.65))
			_px(img, sx, hy + 2, gold)                           # 柄尾箍
			var bly = hy - hl + 2                                # 刃部基准
			match fam:
				"手斧":
					_rect(img, sx + 1, bly, 4, 4, blade)
					_vline(img, sx + 4, bly, 4, blade_hi)        # 弧刃口
					_px(img, sx + 5, bly + 1, blade_hi)
					_px(img, sx + 1, bly + 3, blade_d)
				"战斧":
					_rect(img, sx + 1, bly, 5, 6, blade)         # 大斧刃
					_vline(img, sx + 5, bly, 6, blade_hi)
					_px(img, sx + 6, bly + 1, blade_hi)          # 弧形外刃
					_px(img, sx + 6, bly + 4, blade_hi)
					_px(img, sx + 1, bly + 5, blade_d)
					_rect(img, sx - 2, bly + 1, 2, 2, blade_d)   # 背刺锤头
					_px(img, sx - 3, bly + 1, _dark(blade_d, 0.8))
				"巨斧":
					# 对称双月刃 + 顶刺（最具压迫感的剪影）
					_rect(img, sx + 1, bly, 5, 6, blade)
					_vline(img, sx + 5, bly, 6, blade_hi)
					_px(img, sx + 6, bly + 1, blade_hi)
					_px(img, sx + 6, bly + 4, blade_hi)
					_rect(img, sx - 5, bly, 5, 6, blade_d)
					_vline(img, sx - 5, bly, 6, _dark(blade_d, 0.8))
					_px(img, sx - 6, bly + 1, _dark(blade_d, 0.8))
					_px(img, sx - 6, bly + 4, _dark(blade_d, 0.8))
					_px(img, sx, bly - 2, gold)                  # 顶刺
					_px(img, sx, bly - 1, gold)
			if atk:
				_vline(img, sx - 3 if fam != "巨斧" else sx - 8, bly + 1, 4, streak)
		"猎弓", "长弓", "劲弩":
			if fam == "劲弩":
				# 横持重弩：弩床 + 钢弩臂 + 绞盘 + 上弦箭
				_hline(img, hx - 3, hy - 4, 11, grip)            # 弩床
				_hline(img, hx - 3, hy - 3, 8, _dark(grip, 0.7))
				_vline(img, hx, hy - 8, 9, blade)                # 钢弩臂
				_px(img, hx, hy - 8, blade_hi)
				_px(img, hx, hy, blade_hi)
				_px(img, hx + 1, hy - 7, blade_d)
				_px(img, hx + 1, hy - 1, blade_d)
				_vline(img, hx + 1, hy - 6, 5, Color(1, 1, 1, 0.5))  # 弦
				_px(img, hx - 2, hy - 5, gold)                   # 绞盘
				_px(img, hx + 8, hy - 4, gold)                   # 箭头
			else:
				# 竖持弓：猎弓短圆 / 长弓高大反曲（弓梢外翻）
				var bl = 13 if fam == "猎弓" else 18
				for i in range(bl):
					var t = float(i) / float(bl - 1)
					var off = roundi(sin(t * PI) * (3.0 if fam == "猎弓" else 4.0))
					var col = grip
					if i % 4 == 0:
						col = _c(wpal.d)                          # 缠藤段
					if absi(i - bl / 2) <= 1:
						col = _dark(grip, 0.6)                    # 握柄段
					_px(img, hx + off, hy - bl + 5 + i, col)
					_px(img, hx + off + 1, hy - bl + 5 + i, _dark(grip, 0.8))
				_vline(img, hx, hy - bl + 5, bl, Color(1, 1, 1, 0.5))  # 弦
				if fam == "长弓":
					_px(img, hx - 1, hy - bl + 4, gold)           # 反曲弓梢
					_px(img, hx - 1, hy + 5, gold)
				if atk:
					_hline(img, hx + 1, hy - bl / 2 + 5, 7, blade_hi)   # 搭箭
					_px(img, hx + 8, hy - bl / 2 + 5, Color("#ffe9a0"))
			# 背后箭袋（斜挎）
			_rect(img, cx - 3, ty + 1, 2, 6, Color("#54421f"))
			_px(img, cx - 3, ty, _c(wpal.p))
			_px(img, cx - 2, ty, _light(_c(wpal.p), 0.4))
			_px(img, cx - 2, ty - 1, _c(wpal.p))

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
# 装备图标：基底形状 × 元素配色（14×14）
# ============================================================
static func item_icon(item: Dictionary) -> ImageTexture:
	var fam = str(item.get("family", item.get("key", "长剑")))
	var elem = str(item.get("element", ""))
	var key = "icon|%s|%s" % [fam, elem]
	if _cache.has(key):
		return _cache[key]
	var img = _img(20, 20)
	var pal = ELEM_PAL.get(elem, ELEM_PAL[""])
	var pc: Color = _c(pal.p)
	var dc: Color = _c(pal.d)
	_draw_icon(img, fam, pc, dc)
	_apply_outline(img, OUTLINE)
	_enrich_detail(img)        # 冷暗暖亮立体光影
	_icon_glint(img)           # 金属高光点，让图标更有质感不死板
	var t = _tex(img)
	_cache[key] = t
	return t

## 在图标最上方的受光像素上点一抹近白高光，营造金属/宝石反光
static func _icon_glint(img: Image) -> void:
	var w = img.get_width()
	var h = img.get_height()
	for y in range(h):
		for x in range(w):
			var c = img.get_pixel(x, y)
			if c.a > 0.5 and not c.is_equal_approx(OUTLINE) and c.v > 0.35:
				img.set_pixel(x, y, c.lerp(Color.WHITE, 0.6))
				if x + 1 < w:
					var c2 = img.get_pixel(x + 1, y)
					if c2.a > 0.5 and not c2.is_equal_approx(OUTLINE):
						img.set_pixel(x + 1, y, c2.lerp(Color.WHITE, 0.3))
				return

## 20×20 装备图标：统一左上光源三调（受光/本体/背光）+ 锋刃高光 + 元素染色护手/宝石
static func _draw_icon(img: Image, fam: String, pc: Color, dc: Color) -> void:
	var steel = Color("#c6cedd").lerp(pc, 0.42)
	var steel_hi = _light(steel, 0.55)
	var steel_dk = _dark(steel, 0.58)
	var edge = _light(steel, 0.9)
	var grip = Color("#6e4a2a")
	var grip_hi = _light(grip, 0.35)
	var grip_dk = _dark(grip, 0.62)
	var gold = Color("#e8c45a").lerp(pc, 0.25)
	var gold_hi = _light(gold, 0.5)
	var gold_dk = _dark(gold, 0.7)
	var gem = _light(pc, 0.2)
	var gem_hi = _light(pc, 0.7)
	var pcl = _light(pc, 0.38)
	var pdk = _dark(pc, 0.66)
	match fam:
		"短剑", "长剑", "刺剑", "巨剑":
			var top_y: int = { "短剑": 7, "长剑": 3, "刺剑": 3, "巨剑": 4 }.get(fam, 4)
			var half: int = 2 if fam == "巨剑" else (0 if fam == "刺剑" else 1)
			var cx = 10
			for y in range(top_y, 14):
				_hline(img, cx - half, y, half * 2 + 1, steel)
				_px(img, cx - half, y, edge)             # 左缘锋刃
				_px(img, cx + half, y, steel_dk)         # 右缘背光
				if half > 0:
					_px(img, cx, y, steel_hi)            # 中线血槽提亮
			_px(img, cx, top_y - 1, edge)                # 剑尖
			if half == 2:
				_px(img, cx - 1, top_y, edge); _px(img, cx + 1, top_y, steel_dk)
			_hline(img, cx - 4, 14, 9, gold)             # 护手（元素金）
			_hline(img, cx - 4, 15, 9, gold_dk)
			_px(img, cx - 4, 14, gold_hi)
			_rect(img, cx - 1, 16, 2, 2, grip); _px(img, cx - 1, 16, grip_hi)  # 握柄
			_rect(img, cx - 1, 18, 2, 1, gem); _px(img, cx, 18, gem_hi)        # 柄首宝石
		"手斧", "战斧", "巨斧":
			_rect(img, 9, 3, 2, 16, grip)                # 竖直木柄
			_vline(img, 9, 3, 16, grip_hi); _vline(img, 10, 3, 16, grip_dk)
			var hy = 4
			var hh: int = 7 if fam == "手斧" else 10
			for y in range(hy, hy + hh):                 # 右刃月牙
				var t = float(y - hy) / float(hh - 1)
				var w = int(round(sin(t * PI) * 4.5)) + 2
				_hline(img, 11, y, w, steel)
				_px(img, 11 + w - 1, y, edge); _px(img, 11, y, steel_dk)
			if fam == "巨斧":
				for y in range(hy, hy + hh):             # 双刃斧左刃
					var t2 = float(y - hy) / float(hh - 1)
					var w2 = int(round(sin(t2 * PI) * 3.5)) + 2
					_hline(img, 9 - w2, y, w2, steel)
					_px(img, 9 - w2, y, edge)
			_rect(img, 9, 2, 2, 1, gem); _px(img, 9, 2, gem_hi)   # 顶端宝石
		"猎弓", "长弓", "劲弩":
			if fam == "劲弩":
				_hline(img, 4, 10, 12, grip); _hline(img, 4, 11, 12, grip_dk)
				_px(img, 4, 10, grip_hi)
				_vline(img, 14, 5, 11, steel)            # 弓臂
				_px(img, 14, 5, edge); _px(img, 14, 15, edge)
				_hline(img, 6, 9, 9, steel_hi)           # 弩箭
				_px(img, 15, 9, edge); _px(img, 14, 8, steel); _px(img, 14, 10, steel)
				_px(img, 5, 9, gem)
			else:
				var span: int = 15 if fam == "长弓" else 12
				var y0: int = 3 if fam == "长弓" else 4
				for k in range(span):                    # 弓臂左凸弧
					var t = float(k) / float(span - 1)
					var bx = 12 - int(round(sin(t * PI) * 7.0))
					_px(img, bx, y0 + k, grip)
					_px(img, bx - 1, y0 + k, grip_dk)
					if k % 4 == 0:
						_px(img, bx, y0 + k, grip_hi)
				_vline(img, 13, y0, span, Color(1, 1, 1, 0.5))   # 弓弦
				var my = y0 + span / 2
				_hline(img, 5, my, 11, steel_hi)         # 搭箭
				_px(img, 16, my, edge); _px(img, 15, my - 1, steel); _px(img, 15, my + 1, steel)
				_px(img, 4, my, gem)
		"布甲", "皮甲", "锁子甲", "板甲", "龙鳞甲":
			_rect(img, 6, 5, 8, 9, pc)                   # 胸甲
			_rect(img, 4, 5, 3, 4, pc); _rect(img, 13, 5, 3, 4, pc)   # 双肩
			_hline(img, 6, 5, 8, pcl); _vline(img, 6, 5, 9, pcl)
			_vline(img, 13, 5, 9, pdk); _hline(img, 6, 13, 8, pdk)
			_rect(img, 9, 5, 2, 2, dc)                   # 领口
			match fam:
				"皮甲":
					_hline(img, 6, 9, 8, dc); _px(img, 9, 9, gold)
				"锁子甲":
					for yy in range(7, 13):
						for xx in range(7, 13):
							if (xx + yy) % 2 == 0:
								_px(img, xx, yy, _dark(pc, 0.78))
				"板甲":
					_vline(img, 10, 6, 7, _light(pc, 0.5))
					_hline(img, 4, 5, 3, _light(pc, 0.5)); _hline(img, 13, 5, 3, _light(pc, 0.5))
					_hline(img, 7, 9, 6, pdk)
				"龙鳞甲":
					for yy in range(6, 13, 2):
						for xx in range(6, 14, 2):
							_px(img, xx + ((yy >> 1) & 1), yy, _light(pc, 0.4))
					_px(img, 4, 5, dc); _px(img, 15, 5, dc)
				"布甲":
					_hline(img, 7, 8, 6, pdk); _hline(img, 7, 11, 6, pdk)
		"皮帽", "铁盔", "战盔", "骑士盔", "龙首盔":
			_rect(img, 6, 5, 8, 6, pc); _hline(img, 7, 4, 6, pc)   # 穹顶
			_hline(img, 6, 5, 8, pcl); _vline(img, 6, 5, 6, pcl); _vline(img, 13, 5, 6, pdk)
			_hline(img, 5, 11, 10, dc)                   # 帽檐
			match fam:
				"皮帽":
					_hline(img, 6, 8, 8, dc)
				"铁盔":
					_rect(img, 9, 3, 2, 2, steel); _px(img, 9, 3, edge)   # 顶钉
				"战盔":
					_vline(img, 6, 11, 3, pc); _vline(img, 13, 11, 3, pc) # 护颊
					_hline(img, 8, 9, 4, dc)
				"骑士盔":
					_vline(img, 6, 11, 4, pc); _vline(img, 13, 11, 4, pc)
					_hline(img, 8, 9, 4, dc)             # 面甲缝
					_rect(img, 9, 2, 2, 3, Color("#d8434a")); _px(img, 9, 2, Color("#f08088"))  # 红盔缨
				"龙首盔":
					_px(img, 5, 4, dc); _px(img, 4, 3, dc); _px(img, 4, 2, dc)     # 双角
					_px(img, 14, 4, dc); _px(img, 15, 3, dc); _px(img, 15, 2, dc)
					_vline(img, 6, 11, 3, pc); _vline(img, 13, 11, 3, pc)
					_rect(img, 9, 7, 2, 2, gem); _px(img, 9, 7, gem_hi)            # 额宝石
		"布裤", "皮裤", "链甲裤", "板甲腿铠", "龙鳞腿甲":
			_rect(img, 6, 4, 8, 4, pc); _hline(img, 6, 4, 8, pcl)   # 腰
			_rect(img, 6, 8, 3, 8, pc); _rect(img, 11, 8, 3, 8, pc) # 双腿
			_vline(img, 6, 8, 8, pcl); _vline(img, 13, 8, 8, pdk); _vline(img, 9, 8, 8, dc)
			match fam:
				"皮裤":
					_hline(img, 6, 7, 8, dc)
				"链甲裤":
					for yy in range(8, 16, 2):
						_px(img, 7, yy, dc); _px(img, 12, yy + 1, dc)
				"板甲腿铠":
					_rect(img, 6, 9, 3, 2, _light(pc, 0.5)); _rect(img, 11, 9, 3, 2, _light(pc, 0.5))
				"龙鳞腿甲":
					for yy in range(8, 16, 2):
						_px(img, 7, yy, _light(pc, 0.4)); _px(img, 12, yy, _light(pc, 0.4))
				"布裤":
					_hline(img, 6, 12, 3, pdk); _hline(img, 11, 12, 3, pdk)
		"草编鞋", "皮靴", "铁头靴", "疾风靴", "龙行靴":
			_rect(img, 6, 5, 4, 9, pc)                   # 靴筒
			_rect(img, 6, 13, 9, 3, pc)                  # 鞋身
			_hline(img, 6, 16, 10, dc)                   # 鞋底
			_vline(img, 6, 5, 9, pcl); _hline(img, 6, 5, 4, pcl); _px(img, 14, 13, pcl)
			match fam:
				"草编鞋":
					for yy in range(6, 13, 2):
						_hline(img, 6, yy, 4, dc)
				"皮靴":
					_hline(img, 6, 9, 4, dc)
				"铁头靴":
					_rect(img, 12, 13, 3, 3, steel); _px(img, 14, 13, edge)
				"疾风靴":
					_px(img, 4, 6, _light(pc, 0.7)); _px(img, 3, 5, _light(pc, 0.7)); _px(img, 4, 8, _light(pc, 0.6))
				"龙行靴":
					_px(img, 6, 4, dc); _px(img, 8, 4, dc)
					_px(img, 15, 15, dc); _px(img, 16, 14, dc)
		"木刻护符":
			_vline(img, 10, 3, 3, grip)                  # 绳
			_rect(img, 7, 6, 7, 8, pc); _hline(img, 7, 6, 7, pcl)
			_vline(img, 7, 6, 8, pcl); _vline(img, 13, 6, 8, pdk)
			_rect(img, 9, 9, 3, 3, dc); _px(img, 10, 10, gem)        # 雕纹
		"铜纹戒指":
			for t in range(24):
				var ang = TAU * t / 24.0
				var rx = 10 + roundi(cos(ang) * 5)
				var ry = 12 + roundi(sin(ang) * 5)
				_px(img, rx, ry, pc)
				if sin(ang) < -0.3 or cos(ang) < -0.3:
					_px(img, rx, ry, pcl)
				elif sin(ang) > 0.3:
					_px(img, rx, ry, pdk)
			_rect(img, 9, 3, 3, 3, gem); _px(img, 9, 3, gem_hi)      # 宝石
		"银辉徽章":
			_rect(img, 6, 4, 8, 6, pc)
			for k in range(4):
				_hline(img, 7 + k, 10 + k, maxi(1, 6 - 2 * k), pc)   # 盾底收尖
			_hline(img, 6, 4, 8, pcl); _vline(img, 6, 4, 6, pcl); _vline(img, 13, 4, 6, pdk)
			_rect(img, 8, 6, 4, 3, _light(pc, 0.55)); _px(img, 9, 7, gem_hi)
		"秘语契珠":
			for yy in range(-5, 6):                      # 球体
				var rr = int(round(sqrt(maxf(0.0, 25.0 - yy * yy))))
				_hline(img, 10 - rr, 10 + yy, rr * 2, pc)
				_px(img, 10 - rr, 10 + yy, pdk); _px(img, 10 + rr - 1, 10 + yy, pdk)
			_rect(img, 7, 7, 3, 3, _light(pc, 0.6)); _px(img, 7, 7, gem_hi)   # 高光
			_px(img, 4, 10, gem); _px(img, 16, 10, gem); _px(img, 10, 4, gem); _px(img, 10, 16, gem)  # 符环
		"圣辉遗物":
			_vline(img, 9, 3, 13, pc); _vline(img, 10, 3, 13, pcl)   # 十字圣物
			_hline(img, 5, 8, 11, pc); _hline(img, 5, 9, 11, pdk)
			_px(img, 9, 3, gem_hi)
			_rect(img, 8, 13, 3, 3, gold); _px(img, 8, 13, gold_hi)  # 底座
		_:
			_rect(img, 6, 6, 8, 8, pc); _hline(img, 6, 6, 8, pcl)
			_rect(img, 8, 8, 3, 3, _light(pc, 0.5))

## 清空缓存（测试用）
static func clear_cache() -> void:
	_cache.clear()
