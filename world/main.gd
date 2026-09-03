extends Node3D

enum RunState { ACTIVE, EXTRACTED, FAILED }

var run_state: RunState = RunState.ACTIVE

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var player: PlayerController = $Player
@onready var market_service: MarketService = $MarketService
@onready var market_panel: MarketPanel = $MarketPanel
@onready var security_director: SecurityDirector = $SecurityDirector
@onready var extraction: ExtractionPoint = $ExtractionPoint
@onready var run_results: RunResults = $RunResults
@onready var inventory: RunInventory = $RunInventory
@onready var loot_interactor: LootInteractor = $LootInteractor
@onready var inventory_hud: InventoryHUD = $InventoryHUD

func _ready() -> void:
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_setup_environment()
	player.died.connect(_on_player_died)
	extraction.extraction_completed.connect(_on_extraction_completed)
	run_results.restart_requested.connect(_restart_run)
	loot_interactor.pickup_requested.connect(_on_loot_pickup_requested)
	inventory_hud.bind(inventory, loot_interactor, player)
	for facility_node in get_tree().get_nodes_in_group("company_facility"):
		var facility := facility_node as CompanyFacility
		if facility != null:
			facility.equipment_destroyed.connect(_on_facility_equipment_destroyed)
			facility.equipment_attacked.connect(_on_facility_equipment_attacked)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_restart_run()
	elif event.is_action_pressed("market"):
		_set_market_open(not market_panel.is_open())
	elif event.is_action_pressed("ui_cancel"):
		if market_panel.is_open():
			_set_market_open(false)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN else Input.MOUSE_MODE_HIDDEN

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _on_facility_equipment_destroyed(company_id: String, equipment_id: String, _destroyed_count: int, _total_count: int) -> void:
	market_service.register_sabotage(company_id, equipment_id)

func _set_market_open(open: bool) -> void:
	if run_state != RunState.ACTIVE or not player.is_alive():
		return
	extraction.cancel_interaction()
	if open:
		market_panel.open_market()
	else:
		market_panel.close_market()
	player.set_gameplay_input_enabled(not open)
	# A field terminal, not a pause menu: security and damage continue normally.
	$MarketHUD.visible = not open
	inventory_hud.set_market_open(open)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_HIDDEN

func _on_player_died() -> void:
	if run_state != RunState.ACTIVE:
		return
	run_state = RunState.FAILED
	inventory.finish_run()
	_finish_run(false, market_service.forfeit_run_profit())

func _on_facility_equipment_attacked(_company_id: String, _equipment_id: String, _hit_position: Vector3) -> void:
	if run_state == RunState.ACTIVE:
		extraction.unlock()

func _on_extraction_completed() -> void:
	if run_state != RunState.ACTIVE or not player.is_alive():
		return
	run_state = RunState.EXTRACTED
	var summary := market_service.settle_all_positions(inventory.get_items())
	inventory.finish_run()
	_finish_run(true, summary)

func _finish_run(success: bool, summary: Dictionary) -> void:
	market_panel.close_market()
	player.set_gameplay_input_enabled(false)
	player.set_damage_enabled(false)
	security_director.set_security_enabled(false)
	extraction.end_run()
	$HUD.visible = false
	$MarketHUD.visible = false
	inventory_hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	run_results.present(success, summary)

func _on_loot_pickup_requested(pickup: LootPickup, replace_index := -1) -> void:
	if run_state != RunState.ACTIVE or not loot_interactor.can_reach(pickup):
		return
	if replace_index >= 0 and (not loot_interactor.is_full() or not loot_interactor.is_aiming_at(pickup)):
		return
	var result := inventory.collect(pickup.loot_id, pickup.definition, replace_index)
	if not result["accepted"]:
		return
	var slot := replace_index if replace_index >= 0 else inventory.get_used_slots() - 1
	inventory_hud.animate_pickup(pickup, slot)
	pickup.collect_from_world(player.global_position)
	if not result["dropped"].is_empty():
		# Exchange at the same reachable location, no separate drop action or extra rule.
		_place_dropped_loot(result["dropped"], pickup.global_position)
	$Audio.play_ui(&"market_confirm", 0.025, -5.0)

func _place_dropped_loot(item: Dictionary, at: Vector3) -> void:
	for node in get_tree().get_nodes_in_group("loot_pickups"):
		var pickup := node as LootPickup
		if pickup.loot_id == item["id"]:
			pickup.place_in_world(at)
			return

func _restart_run() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _setup_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6f8fa1")
	sky_material.sky_horizon_color = Color("efcba5")
	sky_material.ground_bottom_color = Color("6d665c")
	sky_material.ground_horizon_color = Color("d9b993")
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.09
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 0.72
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color("c4d0d0")
	environment.ambient_light_energy = 0.68
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.95
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	environment.glow_bloom = 0.015
	environment.ssao_enabled = true
	environment.ssao_radius = 1.8
	environment.ssao_intensity = 1.15
	environment.volumetric_fog_enabled = false
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.03
	environment.adjustment_saturation = 0.9
	world_environment.environment = environment
