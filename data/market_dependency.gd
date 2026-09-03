class_name MarketDependency
extends Resource

@export var dependency_id := "dependency"
@export var source_company_id := "source"
@export var target_company_id := "target"
@export var source_stage_price_multipliers := PackedFloat32Array([1.0])
@export var disruption_messages := PackedStringArray(["SUPPLY DISRUPTION"])
@export_range(0.0, 2.0, 0.01) var reaction_delay := 0.28
@export_range(0.05, 3.0, 0.05) var price_transition_duration := 0.65

func multiplier_after_source_sabotage(source_destroyed_count: int) -> float:
	if source_stage_price_multipliers.is_empty():
		return 1.0
	var index := clampi(source_destroyed_count, 0, source_stage_price_multipliers.size() - 1)
	return source_stage_price_multipliers[index]

func message_after_source_sabotage(source_destroyed_count: int) -> String:
	if disruption_messages.is_empty():
		return "SUPPLY DISRUPTION"
	var index := clampi(source_destroyed_count - 1, 0, disruption_messages.size() - 1)
	return disruption_messages[index]

func stage_count() -> int:
	return maxi(source_stage_price_multipliers.size() - 1, 0)
