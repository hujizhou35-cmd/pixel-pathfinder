extends Node

## PATCH4 visual-integration gate.
## Run:
##   Godot_v4.3-stable_win64.exe --headless --path . res://test/visual_integration_test.tscn
## Exit code is 0 only when every visual contract below passes.

const HERO_W := 40
const HERO_FRAME_H := 52
const HERO_SHEET_H := 208
const EQUIPMENT_SLOTS := ["weapon", "armor", "helmet", "pants", "boots", "accessory"]
const ELEMENTS := ["metal", "wood", "water", "fire", "earth"]

const EXPECTED_FAMILIES := {
	"短剑": "short_sword",
	"长剑": "long_sword",
	"刺剑": "rapier",
	"巨剑": "great_sword",
	"手斧": "hand_axe",
	"战斧": "battle_axe",
	"巨斧": "great_axe",
	"猎弓": "hunting_bow",
	"长弓": "longbow",
	"劲弩": "heavy_crossbow",
	"布甲": "cloth_armor",
	"皮甲": "leather_armor",
	"锁子甲": "chainmail_armor",
	"板甲": "plate_armor",
	"龙鳞甲": "dragon_scale_armor",
	"皮帽": "leather_cap",
	"铁盔": "iron_helmet",
	"战盔": "battle_helmet",
	"骑士盔": "knight_helmet",
	"龙首盔": "dragon_head_helmet",
	"布裤": "cloth_pants",
	"皮裤": "leather_pants",
	"链甲裤": "chainmail_pants",
	"板甲腿铠": "plate_greaves",
	"龙鳞腿甲": "dragon_scale_legs",
	"草编鞋": "straw_sandals",
	"皮靴": "leather_boots",
	"铁头靴": "iron_toe_boots",
	"疾风靴": "wind_boots",
	"龙行靴": "dragon_walk_boots",
	"木刻护符": "carved_wood_amulet",
	"铜纹戒指": "engraved_copper_ring",
	"银辉徽章": "silver_badge",
	"秘语契珠": "whisper_orb",
	"圣辉遗物": "sacred_relic",
}

const HELMETS := ["皮帽", "铁盔", "战盔", "骑士盔", "龙首盔"]
const BOOTS := ["草编鞋", "皮靴", "铁头靴", "疾风靴", "龙行靴"]

var _failures: Array[String] = []
var _assertion_count := 0


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	PixelArt.clear_cache()
	EquipmentVisualCompositor.clear_cache()
	print("=== PATCH4 VISUAL INTEGRATION TEST ===")

	var sections := [
		["35 family mappings", Callable(self, "_test_family_mappings")],
		["175 paths, textures, dimensions and four frames", Callable(self, "_test_resource_matrix")],
		["neutral frozen hero equality", Callable(self, "_test_neutral_hero")],
		["rarity, prefix and affix invariance", Callable(self, "_test_metadata_invariance")],
		["element changes particles only", Callable(self, "_test_element_policy")],
		["helmet hair modes, masks and silhouettes", Callable(self, "_test_helmets")],
		["boots remain two-foot silhouettes", Callable(self, "_test_boots")],
		["short and long weapon layers differ", Callable(self, "_test_weapon_distinction")],
	]

	for section in sections:
		var before := _failures.size()
		var test_callable: Callable = section[1]
		test_callable.call()
		if _failures.size() == before:
			print("[PASS] ", section[0])
		else:
			print("[FAIL] ", section[0], " (+", _failures.size() - before, ")")

	if _failures.is_empty():
		print("VISUAL_INTEGRATION_TEST: PASS (", _assertion_count, " assertions)")
		_quit_cleanly(0)
		return

	print("VISUAL_INTEGRATION_TEST: FAIL (", _failures.size(), " failures / ", _assertion_count, " assertions)")
	for failure in _failures:
		print("  - ", failure)
	_quit_cleanly(1)


func _quit_cleanly(exit_code: int) -> void:
	PixelArt.clear_cache()
	EquipmentVisualCompositor.clear_cache()
	get_tree().quit(exit_code)


func _test_family_mappings() -> void:
	_require(EquipmentVisualRegistry.FAMILY_TO_SLUG.size() == 35, "registry must contain exactly 35 families")
	_require(EquipmentVisualRegistry.FAMILY_TO_SLOT.size() == 35, "slot registry must contain exactly 35 families")

	var unique_slugs := {}
	var slot_counts := {
		"weapon": 0,
		"armor": 0,
		"helmet": 0,
		"pants": 0,
		"boots": 0,
		"accessory": 0,
	}
	for family in EXPECTED_FAMILIES:
		var expected_slug: String = EXPECTED_FAMILIES[family]
		_require(
			str(EquipmentVisualRegistry.FAMILY_TO_SLUG.get(family, "")) == expected_slug,
			"family mapping mismatch: %s -> %s" % [family, expected_slug]
		)
		var item := _item(family, "metal")
		var slot := EquipmentVisualRegistry.slot_for(item)
		_require(slot_counts.has(slot), "family has invalid slot: %s -> %s" % [family, slot])
		if slot_counts.has(slot):
			slot_counts[slot] += 1
		unique_slugs[expected_slug] = true

	_require(unique_slugs.size() == 35, "all 35 family slugs must be unique")
	_require(slot_counts["weapon"] == 10, "weapon family count must be 10")
	for slot in ["armor", "helmet", "pants", "boots", "accessory"]:
		_require(slot_counts[slot] == 5, "%s family count must be 5" % slot)

	var registered_elements := EquipmentVisualRegistry.all_elements()
	_require(registered_elements.size() == 5, "element registry must contain exactly 5 elements")
	for element in ELEMENTS:
		_require(element in registered_elements, "missing element mapping: %s" % element)


func _test_resource_matrix() -> void:
	var family_count := 0
	var matrix_count := 0
	for family in EXPECTED_FAMILIES:
		family_count += 1
		var base_item := _item(family, "")
		var base_icon_path := EquipmentVisualRegistry.base_icon_path(base_item)
		var base_layer_path := EquipmentVisualRegistry.base_layer_path(base_item)
		_require(base_icon_path.begins_with("res://"), "base icon path is not res://: %s" % base_icon_path)
		_require(base_layer_path.begins_with("res://"), "base layer path is not res://: %s" % base_layer_path)

		var base_icon := _load_image(base_icon_path)
		var base_layer := _load_image(base_layer_path)
		_require(_is_size(base_icon, 20, 20), "base icon must be 20x20: %s" % base_icon_path)
		_require(_is_size(base_layer, HERO_W, HERO_SHEET_H), "base layer must be 40x208: %s" % base_layer_path)
		if base_icon != null:
			_require(_alpha_count(base_icon) > 0, "base icon is empty: %s" % base_icon_path)
		if base_layer != null:
			for frame in range(4):
				_require(
					_alpha_count_rect(base_layer, Rect2i(0, frame * HERO_FRAME_H, HERO_W, HERO_FRAME_H)) > 0,
					"base layer frame %d is empty: %s" % [frame, base_layer_path]
				)

		for element in ELEMENTS:
			matrix_count += 1
			var item := _item(family, element)
			var icon_path := EquipmentVisualRegistry.final_icon_path(item)
			var particles_path := EquipmentVisualRegistry.particle_layer_path(item)
			_require(icon_path.begins_with("res://"), "final icon path is not res://: %s" % icon_path)
			_require(particles_path.begins_with("res://"), "particle path is not res://: %s" % particles_path)

			var icon := _load_image(icon_path)
			var particles := _load_image(particles_path)
			_require(_is_size(icon, 20, 20), "final icon must be 20x20: %s" % icon_path)
			_require(_is_size(particles, HERO_W, HERO_SHEET_H), "particle layer must be 40x208: %s" % particles_path)
			if icon != null:
				_require(_alpha_count(icon) > 0, "final icon is empty: %s" % icon_path)
			if particles != null:
				for frame in range(4):
					_require(
						_alpha_count_rect(particles, Rect2i(0, frame * HERO_FRAME_H, HERO_W, HERO_FRAME_H)) > 0,
						"particle layer frame %d is empty: %s" % [frame, particles_path]
					)

			var runtime_icon = PixelArt.item_icon(item)
			_require(runtime_icon is ImageTexture, "PixelArt.item_icon must return ImageTexture: %s/%s" % [family, element])
			if runtime_icon is Texture2D:
				_require(
					runtime_icon.get_width() == 20 and runtime_icon.get_height() == 20,
					"runtime item icon must be 20x20: %s/%s" % [family, element]
				)

		var equipment := _empty_equipment()
		equipment[EquipmentVisualRegistry.slot_for(base_item)] = _item(family, "metal")
		var runtime_hero = PixelArt.hero_texture(equipment)
		_require(runtime_hero is ImageTexture, "PixelArt.hero_texture must return ImageTexture: %s" % family)
		if runtime_hero is Texture2D:
			_require(
				runtime_hero.get_width() == HERO_W and runtime_hero.get_height() == HERO_SHEET_H,
				"runtime hero must be 40x208 for family: %s" % family
			)

	_require(family_count == 35, "resource loop must cover 35 families")
	_require(matrix_count == 175, "resource loop must cover 175 family x element variants")


func _test_neutral_hero() -> void:
	PixelArt.clear_cache()
	var neutral_texture = PixelArt.hero_texture(_empty_equipment())
	_require(neutral_texture is ImageTexture, "neutral hero API must return ImageTexture")
	if not (neutral_texture is Texture2D):
		return
	var neutral: Image = neutral_texture.get_image()
	var frozen := _load_image(EquipmentVisualCompositor.NEUTRAL_COMPOSITE)
	_require(_is_size(neutral, HERO_W, HERO_SHEET_H), "neutral runtime hero must be 40x208")
	_require(_is_size(frozen, HERO_W, HERO_SHEET_H), "frozen neutral resource must be 40x208")
	if neutral != null and frozen != null:
		_require(_image_hash(neutral) == _image_hash(frozen), "neutral runtime hero must equal frozen resource pixel-for-pixel")
		for frame in range(4):
			_require(
				_alpha_count_rect(neutral, Rect2i(0, frame * HERO_FRAME_H, HERO_W, HERO_FRAME_H)) > 0,
				"neutral runtime frame %d must be nonempty" % frame
			)


func _test_metadata_invariance() -> void:
	var icon_base := _item("短剑", "fire")
	var icon_hash := _fresh_icon_hash(icon_base)
	for rarity in range(4):
		var rarity_item := icon_base.duplicate(true)
		rarity_item["rarity"] = rarity
		rarity_item["grade"] = rarity + 1
		_require(_fresh_icon_hash(rarity_item) == icon_hash, "rarity changed icon pixels at rarity %d" % rarity)

	var prefix_item := icon_base.duplicate(true)
	prefix_item["prefix"] = "测试前缀"
	prefix_item["set_prefix"] = "测试套装"
	_require(_fresh_icon_hash(prefix_item) == icon_hash, "prefix changed icon pixels")

	var affix_item := icon_base.duplicate(true)
	affix_item["affixes"] = [{"id": "visual_test", "tier": 99, "value": 12345}]
	affix_item["affix_levels"] = {"visual_test": 99}
	_require(_fresh_icon_hash(affix_item) == icon_hash, "affix changed icon pixels")

	var equipment := _full_equipment("fire")
	var hero_hash := _fresh_hero_hash(equipment)
	for rarity in range(4):
		var rarity_equipment: Dictionary = equipment.duplicate(true)
		for slot in EQUIPMENT_SLOTS:
			rarity_equipment[slot]["rarity"] = rarity
			rarity_equipment[slot]["grade"] = rarity + 1
		_require(
			_fresh_hero_hash(rarity_equipment) == hero_hash,
			"rarity changed hero pixels at rarity %d" % rarity
		)

	var prefix_equipment: Dictionary = equipment.duplicate(true)
	prefix_equipment["armor"]["prefix"] = "测试前缀"
	prefix_equipment["armor"]["set_prefix"] = "测试套装"
	_require(_fresh_hero_hash(prefix_equipment) == hero_hash, "prefix changed hero pixels")

	var affix_equipment: Dictionary = equipment.duplicate(true)
	affix_equipment["weapon"]["affixes"] = [{"id": "visual_test", "tier": 99, "value": 12345}]
	affix_equipment["helmet"]["affix_levels"] = {"visual_test": 99}
	_require(_fresh_hero_hash(affix_equipment) == hero_hash, "affix changed hero pixels")


func _test_element_policy() -> void:
	for family in EXPECTED_FAMILIES:
		var base_paths := {}
		var base_hashes := {}
		var particle_paths := {}
		var particle_hashes := {}
		for element in ELEMENTS:
			var item := _item(family, element)
			var base_path := EquipmentVisualRegistry.base_layer_path(item)
			var particle_path := EquipmentVisualRegistry.particle_layer_path(item)
			base_paths[base_path] = true
			particle_paths[particle_path] = true
			var base_image := _load_image(base_path)
			var particle_image := _load_image(particle_path)
			if base_image != null:
				base_hashes[_image_hash(base_image)] = true
			if particle_image != null:
				particle_hashes[_image_hash(particle_image)] = true

		_require(base_paths.size() == 1, "element changed base layer path: %s" % family)
		_require(base_hashes.size() == 1, "element changed base layer pixels: %s" % family)
		_require(particle_paths.size() == 5, "element particle paths are not distinct: %s" % family)
		_require(particle_hashes.size() == 5, "element particle pixels are not distinct: %s" % family)


func _test_helmets() -> void:
	var modes := {}
	var silhouette_hashes := {}
	for family in HELMETS:
		var item := _item(family, "metal")
		var mode := EquipmentVisualRegistry.hair_mode_for(item)
		modes[mode] = true
		_require(mode in [
			HeroLayerPolicy.CAP_PARTIAL,
			HeroLayerPolicy.OPEN_HELM_PARTIAL,
			HeroLayerPolicy.FULL_HIDE,
			HeroLayerPolicy.CUSTOM_MASK,
		], "helmet has invalid hair mode: %s -> %s" % [family, mode])

		var helmet_layer := _load_image(EquipmentVisualRegistry.base_layer_path(item))
		if helmet_layer != null:
			var silhouette := _alpha_silhouette(helmet_layer)
			silhouette_hashes[_image_hash(silhouette)] = true

		var visible_path := EquipmentVisualRegistry.visible_hair_path(item)
		var forbidden_path := EquipmentVisualRegistry.helmet_mask_path(item, "forbidden")
		var visible_hair := _load_image(visible_path)
		var forbidden := _load_image(forbidden_path)
		_require(_is_size(visible_hair, HERO_W, HERO_SHEET_H), "visible-hair mask must be 40x208: %s" % visible_path)
		_require(_is_size(forbidden, HERO_W, HERO_SHEET_H), "forbidden-hair mask must be 40x208: %s" % forbidden_path)
		if visible_hair != null and forbidden != null:
			_require(_alpha_count(forbidden) > 0, "forbidden-hair mask must contain coverage: %s" % family)
			if mode == HeroLayerPolicy.FULL_HIDE:
				_require(_alpha_count(visible_hair) == 0, "FULL_HIDE helmet must not retain visible hair: %s" % family)
			else:
				_require(_alpha_count(visible_hair) > 0, "partial/custom helmet must retain an intentional hair region: %s" % family)
			_require(
				_alpha_intersection_count(visible_hair, forbidden) == 0,
				"visible_hair intersects forbidden region: %s" % family
			)

	_require(modes.size() >= 2, "five helmets must not all use the same hair strategy")
	_require(modes.size() == 4, "PATCH4 helmet policy should exercise all four hair strategies")
	_require(silhouette_hashes.size() == 5, "all five helmet silhouettes must be unique without color")


func _test_boots() -> void:
	for family in BOOTS:
		var item := _item(family, "metal")
		var layer := _load_image(EquipmentVisualRegistry.base_layer_path(item))
		_require(_is_size(layer, HERO_W, HERO_SHEET_H), "boot layer must be 40x208: %s" % family)
		if layer == null:
			continue
		for frame in range(4):
			_require(
				not _boot_has_cross_foot_component(layer, frame),
				"boot frame forms a connected horizontal pedestal: %s frame %d" % [family, frame]
			)


func _test_weapon_distinction() -> void:
	var short_item := _item("短剑", "metal")
	var long_item := _item("长剑", "metal")
	var short_path := EquipmentVisualRegistry.base_layer_path(short_item)
	var long_path := EquipmentVisualRegistry.base_layer_path(long_item)
	var short_layer := _load_image(short_path)
	var long_layer := _load_image(long_path)
	_require(short_path != long_path, "short and long weapon paths must differ")
	_require(short_layer != null and long_layer != null, "short and long weapon layers must load")
	if short_layer != null and long_layer != null:
		_require(_image_hash(short_layer) != _image_hash(long_layer), "short and long weapon layer hashes must differ")


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


func _full_equipment(element: String) -> Dictionary:
	return {
		"weapon": _item("短剑", element),
		"armor": _item("布甲", element),
		"helmet": _item("皮帽", element),
		"pants": _item("布裤", element),
		"boots": _item("草编鞋", element),
		"accessory": _item("木刻护符", element),
	}


func _load_image(path: String) -> Image:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	if not (resource is Texture2D):
		return null
	var image: Image = resource.get_image()
	if image == null:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


func _is_size(image, width: int, height: int) -> bool:
	return image is Image and image.get_width() == width and image.get_height() == height


func _alpha_count(image: Image) -> int:
	return _alpha_count_rect(image, Rect2i(Vector2i.ZERO, image.get_size()))


func _alpha_count_rect(image: Image, region: Rect2i) -> int:
	var count := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a > 0.01:
				count += 1
	return count


func _alpha_intersection_count(first: Image, second: Image) -> int:
	if first.get_size() != second.get_size():
		return -1
	var count := 0
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			if first.get_pixel(x, y).a > 0.01 and second.get_pixel(x, y).a > 0.01:
				count += 1
	return count


func _alpha_silhouette(source: Image) -> Image:
	var result := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	result.fill(Color(0, 0, 0, 0))
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			if source.get_pixel(x, y).a > 0.01:
				result.set_pixel(x, y, Color.WHITE)
	return result


func _image_hash(image: Image) -> String:
	var copy := image.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(copy.get_data())
	return context.finish().hex_encode()


func _fresh_icon_hash(item: Dictionary) -> String:
	PixelArt.clear_cache()
	var texture = PixelArt.item_icon(item)
	if not (texture is Texture2D):
		return ""
	return _image_hash(texture.get_image())


func _fresh_hero_hash(equipment: Dictionary) -> String:
	PixelArt.clear_cache()
	EquipmentVisualCompositor.clear_cache()
	var texture = PixelArt.hero_texture(equipment)
	if not (texture is Texture2D):
		return ""
	return _image_hash(texture.get_image())


func _boot_has_cross_foot_component(sheet: Image, frame: int) -> bool:
	# Pose frames may stagger the feet vertically, so a valid row can contain
	# only one foot. Reject an actual long horizontal base, then require exactly
	# two four-neighbour alpha components across the complete footwear region.
	var frame_y := frame * HERO_FRAME_H
	for local_y in range(38, HERO_FRAME_H):
		var run_length := 0
		for x in range(HERO_W):
			var opaque := sheet.get_pixel(x, frame_y + local_y).a > 0.01
			run_length = run_length + 1 if opaque else 0
			if run_length >= 9:
				return true

	var region_height := HERO_FRAME_H - 38
	var visited := PackedByteArray()
	visited.resize(HERO_W * region_height)
	visited.fill(0)
	var components := 0
	for local_y in range(38, HERO_FRAME_H):
		for x in range(HERO_W):
			var index := (local_y - 38) * HERO_W + x
			if visited[index] != 0 or sheet.get_pixel(x, frame_y + local_y).a <= 0.01:
				continue
			components += 1
			var queue: Array[Vector2i] = [Vector2i(x, local_y)]
			visited[index] = 1
			var head := 0
			while head < queue.size():
				var point: Vector2i = queue[head]
				head += 1
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var candidate: Vector2i = point + direction
					if candidate.x < 0 or candidate.x >= HERO_W or candidate.y < 38 or candidate.y >= HERO_FRAME_H:
						continue
					var candidate_index: int = (candidate.y - 38) * HERO_W + candidate.x
					if visited[candidate_index] != 0:
						continue
					if sheet.get_pixel(candidate.x, frame_y + candidate.y).a <= 0.01:
						continue
					visited[candidate_index] = 1
					queue.append(candidate)
	return components != 2


func _require(condition: bool, message: String) -> void:
	_assertion_count += 1
	if condition:
		return
	_failures.append(message)
	printerr("[ASSERT FAIL] ", message)
