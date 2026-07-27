class_name HeroLayerPolicy
extends RefCounted

const CAP_PARTIAL := "CAP_PARTIAL"
const OPEN_HELM_PARTIAL := "OPEN_HELM_PARTIAL"
const FULL_HIDE := "FULL_HIDE"
const CUSTOM_MASK := "CUSTOM_MASK"

const LAYER_ORDER := [
	"neutral_body",
	"pants",
	"boots",
	"armor",
	"face",
	"hair_after_mask",
	"helmet",
	"arms",
	"weapon",
	"crossbow_string",
	"accessory",
	"element_particles",
]


static func hair_mode(helmet) -> String:
	return EquipmentVisualRegistry.hair_mode_for(helmet)


static func uses_special_ranged_arms(weapon) -> bool:
	return EquipmentVisualRegistry.ranged_arms_path(weapon) != ""


static func use_neutral_arms(_armor, weapon) -> bool:
	return not uses_special_ranged_arms(weapon)


static func layer_order() -> Array:
	return LAYER_ORDER.duplicate()
