class_name EquipmentVisualRegistry
extends RefCounted

## PATCH4 runtime visual registry.
## Chinese item families are the stable public identifiers used by saved items.
## Physical paths are intentionally static so runtime never depends on CSV/Python.

const ROOT := "res://assets/equipment_visuals"

const SLOT_DIRS := {
	"weapon": "Weapons",
	"armor": "Armor",
	"helmet": "Helmets",
	"pants": "Pants",
	"boots": "Boots",
	"accessory": "Accessories",
}

const ELEMENT_DIRS := {
	"metal": "Metal",
	"wood": "Wood",
	"water": "Water",
	"fire": "Fire",
	"earth": "Earth",
}

const FAMILY_TO_SLUG := {
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

const FAMILY_TO_SLOT := {
	"短剑": "weapon", "长剑": "weapon", "刺剑": "weapon", "巨剑": "weapon",
	"手斧": "weapon", "战斧": "weapon", "巨斧": "weapon",
	"猎弓": "weapon", "长弓": "weapon", "劲弩": "weapon",
	"布甲": "armor", "皮甲": "armor", "锁子甲": "armor", "板甲": "armor", "龙鳞甲": "armor",
	"皮帽": "helmet", "铁盔": "helmet", "战盔": "helmet", "骑士盔": "helmet", "龙首盔": "helmet",
	"布裤": "pants", "皮裤": "pants", "链甲裤": "pants", "板甲腿铠": "pants", "龙鳞腿甲": "pants",
	"草编鞋": "boots", "皮靴": "boots", "铁头靴": "boots", "疾风靴": "boots", "龙行靴": "boots",
	"木刻护符": "accessory", "铜纹戒指": "accessory", "银辉徽章": "accessory",
	"秘语契珠": "accessory", "圣辉遗物": "accessory",
}

const HAIR_MODES := {
	"皮帽": "CAP_PARTIAL",
	"铁盔": "CUSTOM_MASK",
	"战盔": "OPEN_HELM_PARTIAL",
	"骑士盔": "FULL_HIDE",
	"龙首盔": "FULL_HIDE",
}

const WEAPON_POSES := {
	"短剑": "ONE_HAND_SWORD",
	"长剑": "ONE_HAND_SWORD",
	"刺剑": "ONE_HAND_SWORD",
	"巨剑": "TWO_HAND_GREATSWORD",
	"手斧": "ONE_HAND_AXE",
	"战斧": "ONE_HAND_AXE",
	"巨斧": "TWO_HAND_AXE",
	"猎弓": "BOW_FROZEN",
	"长弓": "BOW_FROZEN",
	"劲弩": "CROSSBOW_PATCH4",
}

const SLOT_ORDER := ["pants", "boots", "armor", "helmet", "weapon", "accessory"]


static func family_of(item) -> String:
	if not (item is Dictionary):
		return ""
	var family := str(item.get("family", item.get("base", "")))
	if FAMILY_TO_SLUG.has(family):
		return family
	var catalog_id := str(item.get("catalog_id", item.get("id", "")))
	var split_at := catalog_id.find("_")
	if split_at >= 0:
		var from_id := catalog_id.substr(split_at + 1)
		if FAMILY_TO_SLUG.has(from_id):
			return from_id
	return ""


static func slug_for(item) -> String:
	return str(FAMILY_TO_SLUG.get(family_of(item), ""))


static func slot_for(item) -> String:
	var family := family_of(item)
	var registered := str(FAMILY_TO_SLOT.get(family, ""))
	if registered != "":
		return registered
	if item is Dictionary:
		return str(item.get("slot", ""))
	return ""


static func element_for(item) -> String:
	if not (item is Dictionary):
		return ""
	var element := str(item.get("element", ""))
	return element if ELEMENT_DIRS.has(element) else ""


static func is_visual_item(item) -> bool:
	return slug_for(item) != ""


static func base_icon_path(item) -> String:
	var slot := slot_for(item)
	var slug := slug_for(item)
	if slot == "" or slug == "":
		return ""
	return "%s/icons/base/%s/%s_base_20x20.png" % [ROOT, SLOT_DIRS[slot], slug]


static func final_icon_path(item) -> String:
	var element := element_for(item)
	var slug := slug_for(item)
	if element == "" or slug == "":
		return base_icon_path(item)
	return "%s/icons/final/%s/%s_%s_final_20x20.png" % [
		ROOT, ELEMENT_DIRS[element], element, slug,
	]


static func base_layer_path(item) -> String:
	var slot := slot_for(item)
	var slug := slug_for(item)
	if slot == "" or slug == "":
		return ""
	if slug == "heavy_crossbow":
		return "%s/hero/crossbow_revision/Crossbow_Weapon_40x208.png" % ROOT
	return "%s/layers/base/%s/%s_base_40x208.png" % [ROOT, SLOT_DIRS[slot], slug]


static func particle_layer_path(item) -> String:
	var element := element_for(item)
	var slug := slug_for(item)
	if element == "" or slug == "":
		return ""
	return "%s/layers/particles/%s/%s_%s_particles_40x208.png" % [
		ROOT, ELEMENT_DIRS[element], element, slug,
	]


static func hair_mode_for(item) -> String:
	return str(HAIR_MODES.get(family_of(item), "NONE"))


static func helmet_mask_path(item, mask_kind: String) -> String:
	var slug := slug_for(item)
	if slot_for(item) != "helmet" or slug == "":
		return ""
	var suffix := str({
		"allowed": "allowed_hair_mask",
		"forbidden": "forbidden_hair_mask",
		"coverage": "helmet_coverage_mask",
		"visible_hair": "visible_hair",
	}.get(mask_kind, mask_kind))
	return "%s/masks/helmets/%s_%s_40x208.png" % [ROOT, slug, suffix]


static func visible_hair_path(item) -> String:
	return helmet_mask_path(item, "visible_hair")


static func weapon_pose_for(item) -> String:
	return str(WEAPON_POSES.get(family_of(item), "NEUTRAL"))


static func ranged_arms_path(item) -> String:
	match slug_for(item):
		"hunting_bow":
			return "%s/hero/Ranged_Arm_Poses/hunting_bow_arms_combined_40x208.png" % ROOT
		"longbow":
			return "%s/hero/Ranged_Arm_Poses/longbow_arms_combined_40x208.png" % ROOT
		"heavy_crossbow":
			return "%s/hero/crossbow_revision/Crossbow_Arms_40x208.png" % ROOT
		_:
			return ""


static func crossbow_string_path(item) -> String:
	if slug_for(item) == "heavy_crossbow":
		return "%s/hero/crossbow_revision/Crossbow_String_Arrow_40x208.png" % ROOT
	return ""


static func all_families() -> Array:
	return FAMILY_TO_SLUG.keys()


static func all_elements() -> Array:
	return ELEMENT_DIRS.keys()
