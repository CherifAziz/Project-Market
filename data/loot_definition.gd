class_name LootDefinition
extends Resource

enum VisualKind { MEDICAL_CASE, LAB_INSTRUMENT, SAMPLE_CASE, ENERGY_MODULE, COPPER_SPOOL, POWER_COMPONENT }

@export var display_name := ""
@export var category := ""
@export var value := 0.0
@export var visual_kind: VisualKind = VisualKind.MEDICAL_CASE
@export var accent := Color("879b83")

func is_valid() -> bool:
	return not display_name.is_empty() and is_finite(value) and value >= 0.0

func manifest_entry(loot_id: String) -> Dictionary:
	return {"id": loot_id, "name": display_name, "value": value, "visual_kind": visual_kind, "accent": accent}
