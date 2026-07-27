extends Node

## Headless-capable PATCH4 runtime contact-sheet generator.
## Every equipment subject is obtained from PixelArt.hero_texture(equipment)
## or PixelArt.item_icon(item). Image operations are integer-only and all
## enlargement uses nearest-neighbour interpolation.
##
## Run shot_test first because outputs 14-16 deliberately re-save explicit
## real-game screenshots; a missing source is a hard failure.
##
##   Godot_v4.3-stable_win64.exe --headless --path . res://tests/shot_test.tscn
##   Godot_v4.3-stable_win64.exe --headless --path . res://tests/equipment_visual_lab.tscn

const HERO_W := 40
const HERO_FRAME_H := 52
const HERO_SHEET_H := 208
const OUTPUT_DIR := "res://tests/shots_equipment_runtime"
const ELEMENTS := ["metal", "wood", "water", "fire", "earth"]
const EQUIPMENT_SLOTS := ["weapon", "armor", "helmet", "pants", "boots", "accessory"]

const SLOT_FAMILIES := {
	"weapon": ["短剑", "长剑", "刺剑", "巨剑", "手斧", "战斧", "巨斧", "猎弓", "长弓", "劲弩"],
	"armor": ["布甲", "皮甲", "锁子甲", "板甲", "龙鳞甲"],
	"helmet": ["皮帽", "铁盔", "战盔", "骑士盔", "龙首盔"],
	"pants": ["布裤", "皮裤", "链甲裤", "板甲腿铠", "龙鳞腿甲"],
	"boots": ["草编鞋", "皮靴", "铁头靴", "疾风靴", "龙行靴"],
	"accessory": ["木刻护符", "铜纹戒指", "银辉徽章", "秘语契珠", "圣辉遗物"],
}

const OUTPUT_NAMES := [
	"00_neutral_hero_runtime.png",
	"01_all_icons_175_runtime_1x.png",
	"02_all_icons_175_runtime_4x.png",
	"03_weapons_10x4frames_runtime.png",
	"04_armor_5x4frames_runtime.png",
	"05_helmets_5x4frames_runtime.png",
	"06_helmets_silhouette_runtime.png",
	"07_helmet_hair_leak_debug.png",
	"08_pants_5x4frames_runtime.png",
	"09_boots_5x4frames_runtime.png",
	"10_accessories_5x4frames_runtime.png",
	"11_full_sets_runtime.png",
	"12_elements_runtime.png",
	"13_rarity_visual_invariance.png",
	"14_inventory_actual_ui.png",
	"15_codex_actual_ui.png",
	"16_combat_actual_runtime.png",
]

const ACTUAL_UI_SOURCES := {
	"14_inventory_actual_ui.png": "res://tests/shots/09b_bag_clothes_filter.png",
	"15_codex_actual_ui.png": "res://tests/shots/10_codex_equip100.png",
	"16_combat_actual_runtime.png": "res://tests/shots/05_combat_sword_plate.png",
}

const DARK_BACKGROUND := Color("#101522")
const ALT_BACKGROUND := Color("#182033")
const WHITE_BACKGROUND := Color("#f4f5f8")

var _failures: Array[String] = []
var _saved_count := 0
var _runtime_icon_calls := 0
var _runtime_hero_calls := 0
var _output_dir_absolute := ""


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	print("=== PATCH4 EQUIPMENT VISUAL LAB ===")
	PixelArt.clear_cache()
	EquipmentVisualCompositor.clear_cache()
	_prepare_output_directory()

	_save_output("00_neutral_hero_runtime.png", _runtime_hero(_empty_equipment(), "neutral hero"))
	_save_output("01_all_icons_175_runtime_1x.png", _all_icons_grid(1))
	_save_output("02_all_icons_175_runtime_4x.png", _all_icons_grid(4))
	_save_output("03_weapons_10x4frames_runtime.png", _slot_runtime_grid("weapon"))
	_save_output("04_armor_5x4frames_runtime.png", _slot_runtime_grid("armor"))
	_save_output("05_helmets_5x4frames_runtime.png", _slot_runtime_grid("helmet"))
	_save_output("06_helmets_silhouette_runtime.png", _helmet_silhouette_grid())
	_save_output("07_helmet_hair_leak_debug.png", _helmet_hair_debug_grid())
	_save_output("08_pants_5x4frames_runtime.png", _slot_runtime_grid("pants"))
	_save_output("09_boots_5x4frames_runtime.png", _slot_runtime_grid("boots"))
	_save_output("10_accessories_5x4frames_runtime.png", _slot_runtime_grid("accessory"))
	_save_output("11_full_sets_runtime.png", _full_sets_grid())
	_save_output("12_elements_runtime.png", _elements_grid())
	_save_output("13_rarity_visual_invariance.png", _rarity_grid())

	for destination in ACTUAL_UI_SOURCES:
		_resave_actual_runtime_shot(ACTUAL_UI_SOURCES[destination], destination)

	if _runtime_icon_calls < 350:
		_fail("lab did not call PixelArt.item_icon for both 175-icon sheets")
	if _runtime_hero_calls < 49:
		_fail("lab did not exercise the expected runtime hero variants")
	if _saved_count != OUTPUT_NAMES.size():
		_fail("expected %d outputs, saved %d" % [OUTPUT_NAMES.size(), _saved_count])

	if _failures.is_empty():
		print("EQUIPMENT_VISUAL_LAB: PASS (", _saved_count, " PNG files)")
		print("Output: ", _output_dir_absolute)
		_quit_cleanly(0)
		return

	print("EQUIPMENT_VISUAL_LAB: FAIL (", _failures.size(), " failures)")
	for failure in _failures:
		print("  - ", failure)
	_quit_cleanly(1)


func _quit_cleanly(exit_code: int) -> void:
	PixelArt.clear_cache()
	EquipmentVisualCompositor.clear_cache()
	get_tree().quit(exit_code)


func _prepare_output_directory() -> void:
	_output_dir_absolute = ProjectSettings.globalize_path(OUTPUT_DIR)
	var err := DirAccess.make_dir_recursive_absolute(_output_dir_absolute)
	if err != OK:
		_fail("cannot create output directory: %s (error %d)" % [_output_dir_absolute, err])
		return

	# Named outputs are removed first so a failed source copy cannot be mistaken
	# for a fresh result from this run.
	for output_name in OUTPUT_NAMES:
		var target := _output_dir_absolute.path_join(output_name)
		if FileAccess.file_exists(target):
			var remove_err := DirAccess.remove_absolute(target)
			if remove_err != OK:
				_fail("cannot remove stale output: %s (error %d)" % [target, remove_err])


func _all_icons_grid(scale: int) -> Image:
	var families := _all_families()
	var padding := 1 if scale == 1 else 4
	var icon_side := 20 * scale
	var cell_side := icon_side + padding * 2
	var canvas := _canvas(ELEMENTS.size() * cell_side, families.size() * cell_side, DARK_BACKGROUND)
	for row in range(families.size()):
		for column in range(ELEMENTS.size()):
			var family: String = families[row]
			var element: String = ELEMENTS[column]
			var icon := _runtime_icon(_item(family, element), "%s/%s icon" % [family, element])
			_place_scaled(
				canvas,
				icon,
				Vector2i(column * cell_side + padding, row * cell_side + padding),
				scale
			)
	return canvas


func _slot_runtime_grid(slot: String) -> Image:
	var equipment_rows: Array = []
	for family in SLOT_FAMILIES[slot]:
		var equipment := _empty_equipment()
		equipment[slot] = _item(family, "metal")
		equipment_rows.append(equipment)
	return _hero_grid(equipment_rows, 4, DARK_BACKGROUND)


func _full_sets_grid() -> Image:
	var equipment_rows: Array = []
	for index in range(5):
		equipment_rows.append(_full_set(index, "metal"))
	return _hero_grid(equipment_rows, 4, DARK_BACKGROUND)


func _elements_grid() -> Image:
	var equipment_rows: Array = []
	for element in ELEMENTS:
		equipment_rows.append(_full_set(4, element))
	return _hero_grid(equipment_rows, 4, DARK_BACKGROUND)


func _rarity_grid() -> Image:
	var equipment_rows: Array = []
	for rarity in range(4):
		var equipment := _full_set(3, "fire")
		for slot in EQUIPMENT_SLOTS:
			equipment[slot]["rarity"] = rarity
			equipment[slot]["grade"] = rarity + 1
			equipment[slot]["prefix"] = "rarity_test_%d" % rarity
			equipment[slot]["affixes"] = [{"id": "rarity_test", "tier": rarity}]
		equipment_rows.append(equipment)
	return _hero_grid(equipment_rows, 4, DARK_BACKGROUND)


func _hero_grid(equipment_rows: Array, scale: int, background: Color) -> Image:
	var padding := 4
	var cell_width := HERO_W * scale + padding * 2
	var cell_height := HERO_FRAME_H * scale + padding * 2
	var canvas := _canvas(4 * cell_width, equipment_rows.size() * cell_height, background)
	for row in range(equipment_rows.size()):
		var sheet := _runtime_hero(equipment_rows[row], "hero grid row %d" % row)
		for frame in range(4):
			var frame_image := _hero_frame(sheet, frame)
			_place_scaled(
				canvas,
				frame_image,
				Vector2i(frame * cell_width + padding, row * cell_height + padding),
				scale
			)
	return canvas


func _helmet_silhouette_grid() -> Image:
	# Deliberately contains no labels or text: shape alone must identify helmets.
	var scale := 4
	var padding := 4
	var cell_width := HERO_W * scale + padding * 2
	var cell_height := HERO_FRAME_H * scale + padding * 2
	var helmets: Array = SLOT_FAMILIES["helmet"]
	var canvas := _canvas(4 * cell_width, helmets.size() * cell_height, WHITE_BACKGROUND)
	for row in range(helmets.size()):
		var item := _item(helmets[row], "metal")
		var layer := _load_resource_image(
			EquipmentVisualRegistry.base_layer_path(item),
			"%s helmet silhouette source" % helmets[row]
		)
		var silhouette := _black_silhouette(layer)
		for frame in range(4):
			_place_scaled(
				canvas,
				_hero_frame(silhouette, frame),
				Vector2i(frame * cell_width + padding, row * cell_height + padding),
				scale
			)
	return canvas


func _helmet_hair_debug_grid() -> Image:
	var scale := 4
	var padding := 4
	var cell_width := HERO_W * scale + padding * 2
	var cell_height := HERO_FRAME_H * scale + padding * 2
	var helmets: Array = SLOT_FAMILIES["helmet"]
	var canvas := _canvas(4 * cell_width, helmets.size() * cell_height, DARK_BACKGROUND)

	for row in range(helmets.size()):
		var family: String = helmets[row]
		var item := _item(family, "metal")
		var equipment := _empty_equipment()
		equipment["helmet"] = item
		var hero := _runtime_hero(equipment, "%s hair debug hero" % family)
		var visible_hair := _load_resource_image(
			EquipmentVisualRegistry.visible_hair_path(item),
			"%s visible-hair mask" % family
		)
		var forbidden := _load_resource_image(
			EquipmentVisualRegistry.helmet_mask_path(item, "forbidden"),
			"%s forbidden-hair mask" % family
		)

		for frame in range(4):
			var debug_frame := _hero_frame(hero, frame)
			var visible_frame := _hero_frame(visible_hair, frame)
			var forbidden_frame := _hero_frame(forbidden, frame)
			for y in range(HERO_FRAME_H):
				for x in range(HERO_W):
					var visible := visible_frame.get_pixel(x, y).a > 0.01
					var blocked := forbidden_frame.get_pixel(x, y).a > 0.01
					if visible and blocked:
						debug_frame.set_pixel(x, y, Color("#ff00ff"))
					elif visible:
						debug_frame.set_pixel(x, y, Color("#30ff78"))
					elif blocked:
						var original := debug_frame.get_pixel(x, y)
						debug_frame.set_pixel(x, y, original.lerp(Color("#ff354b"), 0.58))
			_place_scaled(
				canvas,
				debug_frame,
				Vector2i(frame * cell_width + padding, row * cell_height + padding),
				scale
			)
	return canvas


func _runtime_icon(item: Dictionary, context: String) -> Image:
	_runtime_icon_calls += 1
	var texture = PixelArt.item_icon(item)
	if not (texture is ImageTexture):
		_fail("PixelArt.item_icon did not return ImageTexture: %s" % context)
		return _blank_icon()
	var image: Image = texture.get_image()
	if image == null or image.get_width() != 20 or image.get_height() != 20:
		_fail("PixelArt.item_icon did not return 20x20 pixels: %s" % context)
		return _blank_icon()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _runtime_hero(equipment: Dictionary, context: String) -> Image:
	_runtime_hero_calls += 1
	var texture = PixelArt.hero_texture(equipment)
	if not (texture is ImageTexture):
		_fail("PixelArt.hero_texture did not return ImageTexture: %s" % context)
		return _blank_hero()
	var image: Image = texture.get_image()
	if image == null or image.get_width() != HERO_W or image.get_height() != HERO_SHEET_H:
		_fail("PixelArt.hero_texture did not return 40x208 pixels: %s" % context)
		return _blank_hero()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _load_resource_image(path: String, context: String) -> Image:
	if path == "" or not ResourceLoader.exists(path):
		_fail("required resource is missing: %s (%s)" % [path, context])
		return _blank_hero()
	var resource = load(path)
	if not (resource is Texture2D):
		_fail("required resource is not Texture2D: %s (%s)" % [path, context])
		return _blank_hero()
	var image: Image = resource.get_image()
	if image == null or image.get_width() != HERO_W or image.get_height() != HERO_SHEET_H:
		_fail("required resource is not 40x208: %s (%s)" % [path, context])
		return _blank_hero()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _resave_actual_runtime_shot(source_path: String, destination_name: String) -> void:
	var absolute_source := ProjectSettings.globalize_path(source_path)
	if not FileAccess.file_exists(absolute_source):
		_fail("actual UI source shot is missing; run shot_test first: %s" % source_path)
		return
	var image := Image.new()
	var load_err := image.load(absolute_source)
	if load_err != OK:
		_fail("cannot load actual UI source shot: %s (error %d)" % [source_path, load_err])
		return
	_save_output(destination_name, image)


func _save_output(filename: String, image: Image) -> void:
	if image == null or image.is_empty():
		_fail("refusing to save empty image: %s" % filename)
		return
	if _output_dir_absolute == "":
		_fail("output directory is unavailable for: %s" % filename)
		return
	var absolute_target := _output_dir_absolute.path_join(filename)
	var err := image.save_png(absolute_target)
	if err != OK:
		_fail("save_png failed: %s (error %d)" % [absolute_target, err])
		return
	_saved_count += 1
	print("[shot] ", filename, " ", image.get_width(), "x", image.get_height())


func _item(family: String, element: String) -> Dictionary:
	return {
		"family": family,
		"slot": str(EquipmentVisualRegistry.FAMILY_TO_SLOT.get(family, "")),
		"element": element,
		"catalog_id": "%s_%s" % [element, family],
		"name": family,
		"rarity": 0,
		"grade": 1,
		"prefix": "",
		"affixes": [],
	}


func _empty_equipment() -> Dictionary:
	return {
		"weapon": null,
		"armor": null,
		"helmet": null,
		"pants": null,
		"boots": null,
		"accessory": null,
	}


func _full_set(index: int, element: String) -> Dictionary:
	return {
		"weapon": _item(SLOT_FAMILIES["weapon"][index], element),
		"armor": _item(SLOT_FAMILIES["armor"][index], element),
		"helmet": _item(SLOT_FAMILIES["helmet"][index], element),
		"pants": _item(SLOT_FAMILIES["pants"][index], element),
		"boots": _item(SLOT_FAMILIES["boots"][index], element),
		"accessory": _item(SLOT_FAMILIES["accessory"][index], element),
	}


func _all_families() -> Array:
	var result: Array = []
	for slot in EQUIPMENT_SLOTS:
		result.append_array(SLOT_FAMILIES[slot])
	return result


func _canvas(width: int, height: int, color: Color) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image


func _blank_icon() -> Image:
	var image := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image


func _blank_hero() -> Image:
	var image := Image.create(HERO_W, HERO_SHEET_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image


func _hero_frame(sheet: Image, frame: int) -> Image:
	if sheet == null or sheet.get_width() != HERO_W or sheet.get_height() != HERO_SHEET_H:
		return _canvas(HERO_W, HERO_FRAME_H, Color(0, 0, 0, 0))
	return sheet.get_region(Rect2i(0, frame * HERO_FRAME_H, HERO_W, HERO_FRAME_H))


func _place_scaled(target: Image, source: Image, position: Vector2i, scale: int) -> void:
	if source == null or source.is_empty():
		return
	var placed := source.duplicate()
	if scale != 1:
		placed.resize(source.get_width() * scale, source.get_height() * scale, Image.INTERPOLATE_NEAREST)
	target.blend_rect(placed, Rect2i(Vector2i.ZERO, placed.get_size()), position)


func _black_silhouette(source: Image) -> Image:
	var result := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	result.fill(Color(0, 0, 0, 0))
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			if source.get_pixel(x, y).a > 0.01:
				result.set_pixel(x, y, Color.BLACK)
	return result


func _fail(message: String) -> void:
	_failures.append(message)
	printerr("[LAB FAIL] ", message)
