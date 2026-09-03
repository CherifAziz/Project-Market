class_name MarketService
extends Node

signal market_updated(company_id: String)
signal position_opened(company_id: String)
signal operational_event(company_id: String, message: String, stage: int, total: int, cause_company_id: String)
signal price_reaction_started(company_id: String, target_price: float, cause_company_id: String)
signal sabotage_resolved(company_id: String, current_price: float, unrealized_pnl: float, cause_company_id: String, is_final_stage: bool)

@export var companies: Array[CompanyDefinition] = []
@export var dependencies: Array[MarketDependency] = []
@export_range(1, 10000, 1) var default_short_shares := 300
@export_range(0.01, 2.0, 0.01) var reaction_time_scale := 1.0

var _states: Dictionary = {}
var _company_order: Array[String] = []
var _dependency_applied_stages: Dictionary = {}
var _processed_world_events: Dictionary = {}
var _reaction_queue: Array[Dictionary] = []
var _processing_queue := false

func _ready() -> void:
	add_to_group("market_service")
	_initialize_market()
	call_deferred("_emit_initial_state")

func _initialize_market() -> void:
	_states.clear()
	_company_order.clear()
	_dependency_applied_stages.clear()
	_processed_world_events.clear()
	_reaction_queue.clear()
	_processing_queue = false

	for definition in companies:
		if definition == null or definition.company_id.is_empty():
			continue
		if _states.has(definition.company_id):
			push_warning("Duplicate company id ignored: %s" % definition.company_id)
			continue
		_company_order.append(definition.company_id)
		_states[definition.company_id] = {
			"definition": definition,
			"current_price": definition.initial_price,
			"registered_direct_stage": 0,
			"applied_direct_stage": 0,
			"destroyed_equipment": {},
			"position": null,
		}

	for dependency in dependencies:
		if dependency == null or dependency.dependency_id.is_empty():
			continue
		_dependency_applied_stages[dependency.dependency_id] = 0

func _emit_initial_state() -> void:
	for company_id in _company_order:
		market_updated.emit(company_id)

func get_company_ids() -> Array[String]:
	return _company_order.duplicate()

func get_company_definition(company_id: String) -> CompanyDefinition:
	if not _states.has(company_id):
		return null
	return _states[company_id]["definition"] as CompanyDefinition

func get_current_price(company_id: String) -> float:
	if not _states.has(company_id):
		return 0.0
	return float(_states[company_id]["current_price"])

func get_initial_price(company_id: String) -> float:
	var definition := get_company_definition(company_id)
	return definition.initial_price if definition != null else 0.0

func get_variation_percent(company_id: String) -> float:
	var initial := get_initial_price(company_id)
	if is_zero_approx(initial):
		return 0.0
	return (get_current_price(company_id) / initial - 1.0) * 100.0

func get_destroyed_equipment_count(company_id: String) -> int:
	if not _states.has(company_id):
		return 0
	return int(_states[company_id]["registered_direct_stage"])

func get_equipment_total(company_id: String) -> int:
	var definition := get_company_definition(company_id)
	return definition.sabotage_stage_count() if definition != null else 0

func open_short(company_id: String, share_count := -1) -> bool:
	if not _states.has(company_id):
		return false
	var state: Dictionary = _states[company_id]
	if state["position"] != null:
		return false
	var resolved_share_count := default_short_shares if share_count <= 0 else share_count
	state["position"] = ShortPosition.new(get_current_price(company_id), resolved_share_count)
	_states[company_id] = state
	position_opened.emit(company_id)
	market_updated.emit(company_id)
	return true

func has_open_position(company_id: String) -> bool:
	return _states.has(company_id) and _states[company_id]["position"] != null

func get_position_entry_price(company_id: String) -> float:
	var position := _get_position(company_id)
	return position.entry_price if position != null else 0.0

func get_position_shares(company_id: String) -> int:
	var position := _get_position(company_id)
	return position.shares if position != null else 0

func get_unrealized_pnl(company_id: String) -> float:
	var position := _get_position(company_id)
	return position.unrealized_pnl() if position != null else 0.0

func get_total_unrealized_pnl() -> float:
	var total := 0.0
	for company_id in _company_order:
		total += get_unrealized_pnl(company_id)
	return total

func register_sabotage(company_id: String, equipment_id: String) -> bool:
	if not _states.has(company_id) or equipment_id.is_empty():
		return false
	var world_event_key := "%s::%s" % [company_id, equipment_id]
	if _processed_world_events.has(world_event_key):
		return false

	var definition := get_company_definition(company_id)
	var state: Dictionary = _states[company_id]
	var next_stage := int(state["registered_direct_stage"]) + 1
	if next_stage > definition.sabotage_stage_count():
		return false

	_processed_world_events[world_event_key] = true
	var destroyed_equipment: Dictionary = state["destroyed_equipment"]
	destroyed_equipment[equipment_id] = true
	state["destroyed_equipment"] = destroyed_equipment
	state["registered_direct_stage"] = next_stage
	_states[company_id] = state

	_reaction_queue.append({
		"kind": "direct",
		"company_id": company_id,
		"stage": next_stage,
		"message": definition.message_after_sabotage(next_stage),
		"cause_company_id": company_id,
		"is_final": next_stage >= definition.sabotage_stage_count(),
	})

	for dependency in dependencies:
		if dependency == null or dependency.source_company_id != company_id:
			continue
		if not _states.has(dependency.target_company_id):
			continue
		_reaction_queue.append({
			"kind": "dependency",
			"company_id": dependency.target_company_id,
			"dependency_id": dependency.dependency_id,
			"stage": next_stage,
			"message": dependency.message_after_source_sabotage(next_stage),
			"cause_company_id": company_id,
			"is_final": next_stage >= dependency.stage_count(),
		})

	market_updated.emit(company_id)
	if not _processing_queue:
		_process_reaction_queue()
	return true

func _process_reaction_queue() -> void:
	_processing_queue = true
	while not _reaction_queue.is_empty():
		var reaction: Dictionary = _reaction_queue.pop_front()
		var company_id: String = reaction["company_id"]
		if not _states.has(company_id):
			continue
		var stage := int(reaction["stage"])
		var cause_company_id: String = reaction["cause_company_id"]
		operational_event.emit(
			company_id,
			String(reaction["message"]),
			stage,
			_reaction_total(reaction),
			cause_company_id
		)

		var delay := _reaction_delay(reaction) * reaction_time_scale
		if delay > 0.0:
			await get_tree().create_timer(delay, true, false, true).timeout

		_apply_reaction_stage(reaction)
		var target_price := _calculate_target_price(company_id)
		price_reaction_started.emit(company_id, target_price, cause_company_id)
		var start_price := get_current_price(company_id)
		var duration := maxf(_reaction_duration(reaction) * reaction_time_scale, 0.01)
		var tween := create_tween().set_ignore_time_scale(true)
		tween.tween_method(
			func(value: float) -> void: _set_current_price(company_id, value),
			start_price,
			target_price,
			duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		_set_current_price(company_id, target_price)
		sabotage_resolved.emit(
			company_id,
			target_price,
			get_unrealized_pnl(company_id),
			cause_company_id,
			bool(reaction["is_final"])
		)
		await get_tree().create_timer(0.08 * reaction_time_scale, true, false, true).timeout
	_processing_queue = false

func _apply_reaction_stage(reaction: Dictionary) -> void:
	var stage := int(reaction["stage"])
	if reaction["kind"] == "direct":
		var company_id: String = reaction["company_id"]
		var state: Dictionary = _states[company_id]
		state["applied_direct_stage"] = maxi(int(state["applied_direct_stage"]), stage)
		_states[company_id] = state
	else:
		var dependency_id: String = reaction["dependency_id"]
		_dependency_applied_stages[dependency_id] = maxi(
			int(_dependency_applied_stages.get(dependency_id, 0)),
			stage
		)

func _calculate_target_price(company_id: String) -> float:
	var state: Dictionary = _states[company_id]
	var definition: CompanyDefinition = state["definition"]
	var price := definition.initial_price * definition.sabotage_multiplier(int(state["applied_direct_stage"]))
	for dependency in dependencies:
		if dependency == null or dependency.target_company_id != company_id:
			continue
		var applied_stage := int(_dependency_applied_stages.get(dependency.dependency_id, 0))
		price *= dependency.multiplier_after_source_sabotage(applied_stage)
	return snappedf(price, 0.01)

func _set_current_price(company_id: String, value: float) -> void:
	if not _states.has(company_id):
		return
	var state: Dictionary = _states[company_id]
	state["current_price"] = snappedf(value, 0.01)
	var position: ShortPosition = state["position"]
	if position != null:
		position.update_current_price(float(state["current_price"]))
	_states[company_id] = state
	market_updated.emit(company_id)

func _reaction_total(reaction: Dictionary) -> int:
	if reaction["kind"] == "direct":
		var definition := get_company_definition(reaction["company_id"])
		return definition.sabotage_stage_count() if definition != null else 0
	var dependency := _get_dependency(reaction["dependency_id"])
	return dependency.stage_count() if dependency != null else 0

func _reaction_delay(reaction: Dictionary) -> float:
	if reaction["kind"] == "direct":
		var definition := get_company_definition(reaction["company_id"])
		return definition.reaction_delay if definition != null else 0.0
	var dependency := _get_dependency(reaction["dependency_id"])
	return dependency.reaction_delay if dependency != null else 0.0

func _reaction_duration(reaction: Dictionary) -> float:
	if reaction["kind"] == "direct":
		var definition := get_company_definition(reaction["company_id"])
		return definition.price_transition_duration if definition != null else 0.05
	var dependency := _get_dependency(reaction["dependency_id"])
	return dependency.price_transition_duration if dependency != null else 0.05

func _get_position(company_id: String) -> ShortPosition:
	if not _states.has(company_id):
		return null
	return _states[company_id]["position"] as ShortPosition

func _get_dependency(dependency_id: String) -> MarketDependency:
	for dependency in dependencies:
		if dependency != null and dependency.dependency_id == dependency_id:
			return dependency
	return null
