class_name LootDefinition
extends Resource

enum VisualKind { MEDICAL_CASE, LAB_INSTRUMENT, SAMPLE_CASE, ENERGY_MODULE, COPPER_SPOOL, POWER_COMPONENT }

@export var display_name := ""
@export var category := ""
@export var value := 0.0
@export var weight_kg := 1.0
@export_range(1, 3, 1) var slots := 1
@export var visual_kind: VisualKind = VisualKind.MEDICAL_CASE
@export var accent := Color("879b83")

func is_valid() -> bool:
	return not display_name.is_empty() and value >= 0.0 and weight_kg > 0.0 and slots >= 1 and slots <= 3

func manifest_entry(loot_id: String) -> Dictionary:
	return {"id": loot_id, "name": display_name, "category": category, "value": value, "weight_kg": weight_kg, "slots": slots}
