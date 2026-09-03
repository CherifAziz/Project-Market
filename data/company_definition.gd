class_name CompanyDefinition
extends Resource

@export_group("Identity")
@export var company_id := "company"
@export var ticker := "COMP"
@export var display_name := "Company"
@export var accent_color := Color("66806e")

@export_group("Market")
@export_range(0.01, 10000.0, 0.01) var initial_price := 42.0
@export var sabotage_price_multipliers := PackedFloat32Array([1.0, 0.9, 0.75, 0.65])
@export_range(0.0, 2.0, 0.01) var reaction_delay := 0.35
@export_range(0.1, 2.0, 0.01) var price_transition_duration := 0.85

@export_group("Operations")
@export var sabotage_messages := PackedStringArray([
	"OPERATIONS IMPAIRED",
	"SUPPLY DISRUPTION",
	"CRITICAL PRODUCTION OUTAGE",
])

func price_after_sabotage(destroyed_count: int) -> float:
	if sabotage_price_multipliers.is_empty():
		return snappedf(initial_price, 0.01)
	var index := clampi(destroyed_count, 0, sabotage_price_multipliers.size() - 1)
	return snappedf(initial_price * sabotage_price_multipliers[index], 0.01)

func message_after_sabotage(destroyed_count: int) -> String:
	if sabotage_messages.is_empty():
		return "OPERATIONS UPDATE"
	var index := clampi(destroyed_count - 1, 0, sabotage_messages.size() - 1)
	return sabotage_messages[index]

func sabotage_stage_count() -> int:
	return maxi(sabotage_price_multipliers.size() - 1, 0)
