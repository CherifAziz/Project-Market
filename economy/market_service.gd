class_name MarketService
extends Node

signal market_updated
signal position_opened
signal operational_event(message: String, destroyed_count: int, total_count: int)
signal sabotage_resolved(destroyed_count: int, current_price: float, unrealized_pnl: float)

@export var company: CompanyDefinition
@export_range(1, 10000, 1) var default_short_shares := 300

var current_price := 0.0
var destroyed_equipment_count := 0
var short_position: ShortPosition

var _destroyed_equipment: Dictionary = {}
var _reaction_queue: Array[Dictionary] = []
var _processing_reactions := false
var _price_tween: Tween

func _ready() -> void:
	add_to_group("market_service")
	if company == null:
		push_error("MarketService requires a CompanyDefinition resource.")
		return
	current_price = company.price_after_sabotage(0)
	call_deferred("_emit_market_updated")

func open_short(share_count := -1) -> bool:
	if company == null or has_open_position():
		return false
	var resolved_share_count := default_short_shares if share_count <= 0 else share_count
	short_position = ShortPosition.new(current_price, resolved_share_count)
	position_opened.emit()
	market_updated.emit()
	return true

func register_sabotage(equipment_id: String) -> bool:
	if company == null or equipment_id.is_empty() or _destroyed_equipment.has(equipment_id):
		return false
	if destroyed_equipment_count >= company.sabotage_stage_count():
		return false

	_destroyed_equipment[equipment_id] = true
	destroyed_equipment_count += 1
	_reaction_queue.append({
		"destroyed_count": destroyed_equipment_count,
		"message": company.message_after_sabotage(destroyed_equipment_count),
		"target_price": company.price_after_sabotage(destroyed_equipment_count),
	})
	market_updated.emit()
	if not _processing_reactions:
		_process_reaction_queue()
	return true

func has_open_position() -> bool:
	return short_position != null

func get_entry_price() -> float:
	return short_position.entry_price if short_position else 0.0

func get_position_shares() -> int:
	return short_position.shares if short_position else 0

func get_unrealized_pnl() -> float:
	return short_position.unrealized_pnl() if short_position else 0.0

func get_variation_percent() -> float:
	if company == null or is_zero_approx(company.initial_price):
		return 0.0
	return ((current_price - company.initial_price) / company.initial_price) * 100.0

func _process_reaction_queue() -> void:
	_processing_reactions = true
	while not _reaction_queue.is_empty():
		var reaction: Dictionary = _reaction_queue.pop_front()
		var stage: int = reaction["destroyed_count"]
		operational_event.emit(reaction["message"], stage, company.sabotage_stage_count())
		await get_tree().create_timer(company.reaction_delay, true, false, true).timeout

		var target_price: float = reaction["target_price"]
		_price_tween = create_tween().set_ignore_time_scale(true)
		_price_tween.tween_method(_set_current_price, current_price, target_price, company.price_transition_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await _price_tween.finished
		_set_current_price(target_price)
		sabotage_resolved.emit(stage, current_price, get_unrealized_pnl())
		await get_tree().create_timer(0.12, true, false, true).timeout
	_processing_reactions = false

func _set_current_price(value: float) -> void:
	current_price = snappedf(value, 0.01)
	if short_position:
		short_position.update_current_price(current_price)
	market_updated.emit()

func _emit_market_updated() -> void:
	market_updated.emit()
