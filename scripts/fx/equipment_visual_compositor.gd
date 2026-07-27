class_name EquipmentVisualCompositor
extends RefCounted

const HERO_W := 40
const HERO_H := 52
const HERO_SHEET_H := HERO_H * 4

const NEUTRAL_COMPOSITE := "res://assets/equipment_visuals/hero/Hero_Neutral_Base_Composite_40x208.png"
const NEUTRAL_BODY := "res://assets/equipment_visuals/hero/Hero_Neutral_Body_40x208.png"
const NEUTRAL_FACE := "res://assets/equipment_visuals/hero/Hero_Neutral_Face_40x208.png"
const NEUTRAL_HAIR := "res://assets/equipment_visuals/hero/Hero_Neutral_HeadHair_40x208.png"
const NEUTRAL_ARMS := "res://assets/equipment_visuals/hero/Hero_Neutral_Arms_40x208.png"

static var _image_cache: Dictionary = {}


static func visual_signature(equipment: Dictionary) -> String:
	var parts: Array[String] = []
	for slot in ["weapon", "armor", "helmet", "pants", "boots", "accessory"]:
		var item = equipment.get(slot)
		parts.append("%s:%s/%s" % [
			slot,
			EquipmentVisualRegistry.family_of(item),
			EquipmentVisualRegistry.element_for(item),
		])
	return "|".join(parts)


static func compose_icon(item: Dictionary) -> Image:
	var path := EquipmentVisualRegistry.final_icon_path(item)
	var image: Image = _load_image(path)
	if image == null and path != EquipmentVisualRegistry.base_icon_path(item):
		image = _load_image(EquipmentVisualRegistry.base_icon_path(item))
	if image == null:
		return Image.create(20, 20, false, Image.FORMAT_RGBA8)
	return image.duplicate()


static func compose_hero(equipment: Dictionary) -> Image:
	if not _has_registered_equipment(equipment):
		var frozen: Image = _load_image(NEUTRAL_COMPOSITE)
		return frozen.duplicate() if frozen != null else _blank_hero()

	var body: Image = _load_image(NEUTRAL_BODY)
	var result: Image = body.duplicate() if body != null else _blank_hero()
	var weapon = equipment.get("weapon")
	var armor = equipment.get("armor")
	var helmet = equipment.get("helmet")

	# Replaceable clothing regions are covered by fitted PATCH4 layers.
	for slot in ["pants", "boots", "armor"]:
		_blit_path(result, EquipmentVisualRegistry.base_layer_path(equipment.get(slot)))

	_blit_path(result, NEUTRAL_FACE)

	if EquipmentVisualRegistry.is_visual_item(helmet):
		var visible_hair := EquipmentVisualRegistry.visible_hair_path(helmet)
		if visible_hair != "" and ResourceLoader.exists(visible_hair):
			_blit_path(result, visible_hair)
		_blit_path(result, EquipmentVisualRegistry.base_layer_path(helmet))
	else:
		_blit_path(result, NEUTRAL_HAIR)

	var ranged_arms := EquipmentVisualRegistry.ranged_arms_path(weapon)
	if ranged_arms != "":
		_blit_path(result, ranged_arms)
	elif HeroLayerPolicy.use_neutral_arms(armor, weapon):
		_blit_path(result, NEUTRAL_ARMS)

	_blit_path(result, EquipmentVisualRegistry.base_layer_path(weapon))
	_blit_path(result, EquipmentVisualRegistry.crossbow_string_path(weapon))
	_blit_path(result, EquipmentVisualRegistry.base_layer_path(equipment.get("accessory")))

	# Element identity is a sparse particle overlay only; it never recolors the subject.
	for slot in ["weapon", "armor", "helmet", "pants", "boots", "accessory"]:
		_blit_path(result, EquipmentVisualRegistry.particle_layer_path(equipment.get(slot)))
	return result


static func image_hash(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()


static func clear_cache() -> void:
	_image_cache.clear()


static func _has_registered_equipment(equipment: Dictionary) -> bool:
	for slot in ["weapon", "armor", "helmet", "pants", "boots", "accessory"]:
		if EquipmentVisualRegistry.is_visual_item(equipment.get(slot)):
			return true
	return false


static func _blank_hero() -> Image:
	var image := Image.create(HERO_W, HERO_SHEET_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image


static func _load_image(path: String) -> Image:
	if path == "":
		return null
	if _image_cache.has(path):
		return _image_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var texture: Resource = load(path)
	if not (texture is Texture2D):
		return null
	var image: Image = texture.get_image()
	if image == null:
		return null
	image.convert(Image.FORMAT_RGBA8)
	_image_cache[path] = image
	return image


static func _blit_path(target: Image, path: String) -> void:
	var overlay: Image = _load_image(path)
	if overlay == null:
		return
	if overlay.get_width() != HERO_W or overlay.get_height() != HERO_SHEET_H:
		push_error("Equipment visual has invalid size: %s (%dx%d)" % [
			path, overlay.get_width(), overlay.get_height(),
		])
		return
	target.blend_rect(overlay, Rect2i(0, 0, HERO_W, HERO_SHEET_H), Vector2i.ZERO)
