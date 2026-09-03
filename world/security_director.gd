class_name SecurityDirector
extends Node3D

signal security_alert(company_id: String, message: String, accent_color: Color, pressure_stage: int)
signal security_count_changed(alive_count: int, initial_count: int)

const SECURITY_AGENT_SCENE := preload("res://combat/security_agent.tscn")

var _agents_by_company: Dictionary = {}
var _alerted_equipment: Dictionary = {}
var _company_pressure: Dictionary = {}
var _company_alerted: Dictionary = {}
var _initial_agent_count := 0
var _simulation_enabled := true

func _ready() -> void:
	add_to_group("security_director")
	call_deferred("_setup_facilities")

func _setup_facilities() -> void:
	for facility_node in get_tree().get_nodes_in_group("company_facility"):
		var facility := facility_node as CompanyFacility
		if facility == null or facility.company == null:
			continue
		facility.equipment_attacked.connect(_on_equipment_attacked)
		_spawn_facility_security(facility)
	_initial_agent_count = get_alive_count()
	security_count_changed.emit(_initial_agent_count, _initial_agent_count)

func _spawn_facility_security(facility: CompanyFacility) -> void:
	var company_id := facility.company.company_id
	if not _agents_by_company.has(company_id):
		_agents_by_company[company_id] = []
	var company_agents: Array = _agents_by_company[company_id]
	var specs := facility.get_security_spawn_specs()
	for index in range(specs.size()):
		var spec: Dictionary = specs[index]
		var agent := SECURITY_AGENT_SCENE.instantiate() as SecurityAgent
		var world_position := facility.to_global(spec["position"])
		var world_axis: Vector3 = facility.global_transform.basis * (spec["patrol_axis"] as Vector3)
		agent.configure(company_id, facility.company.ticker, facility.company.accent_color, index, world_axis)
		agent.position = to_local(world_position)
		agent.player_spotted.connect(_on_agent_player_spotted)
		agent.died.connect(_on_agent_died)
		add_child(agent)
		company_agents.append(agent)
	_agents_by_company[company_id] = company_agents

func _on_equipment_attacked(company_id: String, equipment_id: String, world_position: Vector3) -> void:
	var event_key := "%s::%s" % [company_id, equipment_id]
	if _alerted_equipment.has(event_key):
		return
	_alerted_equipment[event_key] = true
	var pressure_stage := int(_company_pressure.get(company_id, 0)) + 1
	_company_pressure[company_id] = pressure_stage
	_company_alerted[company_id] = true
	_alert_company(company_id, world_position, pressure_stage)
	var company := _company_definition(company_id)
	if company != null:
		security_alert.emit(company_id, "%s SECURITY ALERT" % company.ticker, company.accent_color, pressure_stage)
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_world"):
		audio.play_world(&"security_alert", world_position + Vector3.UP * 0.8, 0.015)

func _on_agent_player_spotted(company_id: String, world_position: Vector3) -> void:
	var first_contact := not bool(_company_alerted.get(company_id, false))
	_company_alerted[company_id] = true
	_alert_company(company_id, world_position, int(_company_pressure.get(company_id, 0)))
	if first_contact:
		var company := _company_definition(company_id)
		if company != null:
			security_alert.emit(company_id, "%s SECURITY CONTACT" % company.ticker, company.accent_color, 0)

func _alert_company(company_id: String, world_position: Vector3, pressure_stage: int) -> void:
	for agent in get_company_agents(company_id):
		agent.raise_alert(world_position, pressure_stage)

func _on_agent_died(_agent: SecurityAgent) -> void:
	security_count_changed.emit(get_alive_count(), _initial_agent_count)

func set_security_enabled(enabled: bool) -> void:
	_simulation_enabled = enabled
	for company_id in _agents_by_company.keys():
		for agent in get_company_agents(company_id):
			agent.set_ai_enabled(enabled)

func is_security_enabled() -> bool:
	return _simulation_enabled

func is_company_alerted(company_id: String) -> bool:
	return bool(_company_alerted.get(company_id, false))

func get_alert_stage(company_id: String) -> int:
	return int(_company_pressure.get(company_id, 0))

func get_company_agents(company_id: String) -> Array[SecurityAgent]:
	var result: Array[SecurityAgent] = []
	for agent_value in _agents_by_company.get(company_id, []):
		if not is_instance_valid(agent_value):
			continue
		var agent := agent_value as SecurityAgent
		if agent != null and not agent.is_dead():
			result.append(agent)
	return result

func get_alive_count() -> int:
	var count := 0
	for company_id in _agents_by_company.keys():
		count += get_company_agents(company_id).size()
	return count

func get_initial_count() -> int:
	return _initial_agent_count

func _company_definition(company_id: String) -> CompanyDefinition:
	for facility_node in get_tree().get_nodes_in_group("company_facility"):
		var facility := facility_node as CompanyFacility
		if facility != null and facility.company != null and facility.company.company_id == company_id:
			return facility.company
	return null
