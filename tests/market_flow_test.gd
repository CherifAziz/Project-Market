extends SceneTree

var _failed := false
var _main_scene: PackedScene

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failed = true
		push_error("FAIL: " + message)

func _run() -> void:
	_main_scene = load("res://world/main.tscn") as PackedScene
	await _run_scenario_a()
	await _run_scenario_b()
	await _run_scenario_c()
	Engine.time_scale = 1.0
	print("Market flow test complete.")
	quit(1 if _failed else 0)

func _run_scenario_a() -> void:
	var main := await _spawn_fresh_main()
	var market := get_first_node_in_group("market_service") as MarketService
	var facility := get_first_node_in_group("company_facility") as CompanyFacility
	var player := get_first_node_in_group("player") as PlayerController
	var market_panel := main.get_node("MarketPanel") as MarketPanel
	var equipment := facility.get_equipment()
	_check(equipment.size() == 3, "scenario A: exactly three VITA machines exist")
	main._unhandled_input(_action_event("market"))
	_check(market_panel.is_open() and not player.is_gameplay_input_enabled(), "scenario A: M opens market and suspends combat input")
	market_panel.short_button.pressed.emit()
	_check(market.has_open_position(), "scenario A: market button opens the short")
	_check(is_equal_approx(market.get_entry_price(), 42.0), "scenario A: short entry is $42")
	main._unhandled_input(_action_event("market"))
	_check(not market_panel.is_open() and player.is_gameplay_input_enabled(), "scenario A: M closes market and restores combat input")

	var expected_prices := [38.0, 32.0, 27.0]
	var expected_pnl := [1200.0, 3000.0, 4500.0]
	for index in range(equipment.size()):
		var machine := equipment[index] as DestructibleEquipment
		machine.take_damage(machine.max_health * 0.5, machine.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
		_check(machine.operational_state == DestructibleEquipment.OperationalState.DAMAGED and not machine.is_destroyed(), "scenario A: machine %d exposes a real DAMAGED state" % (index + 1))
		machine.take_damage(machine.health, machine.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
		await market.sabotage_resolved
		_check(machine.is_destroyed(), "scenario A: machine %d enters its destroyed state" % (index + 1))
		_check(is_equal_approx(market.current_price, expected_prices[index]), "scenario A: world event moves VITA to stage %d" % (index + 1))
		_check(is_equal_approx(market.get_unrealized_pnl(), expected_pnl[index]), "scenario A: live short P&L is correct at stage %d" % (index + 1))
	_check(is_equal_approx(market.get_unrealized_pnl(), 4500.0), "scenario A: final short profit is +$4,500")
	var market_hud := main.get_node("MarketHUD") as MarketHUD
	_check(market_hud.price_label.text == "$27.00", "scenario A: gameplay HUD displays the final live price")
	_check(market_hud.variation_label.text == "-35.71%", "scenario A: gameplay HUD displays the final percentage variation")
	_check("4,500" in market_hud.pnl_label.text, "scenario A: gameplay HUD displays the calculated final P&L")
	await _remove_main(main)

func _run_scenario_b() -> void:
	var main := await _spawn_fresh_main()
	var market := get_first_node_in_group("market_service") as MarketService
	var facility := get_first_node_in_group("company_facility") as CompanyFacility
	for machine_value in facility.get_equipment():
		var machine := machine_value as DestructibleEquipment
		machine.take_damage(machine.max_health, machine.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
		await market.sabotage_resolved
	_check(is_equal_approx(market.current_price, 27.0), "scenario B: sabotage lowers price without a position")
	_check(not market.has_open_position(), "scenario B: sabotage does not create a position")
	_check(is_equal_approx(market.get_unrealized_pnl(), 0.0), "scenario B: no position means no P&L")
	await _remove_main(main)

func _run_scenario_c() -> void:
	var main := await _spawn_fresh_main()
	var market := get_first_node_in_group("market_service") as MarketService
	var facility := get_first_node_in_group("company_facility") as CompanyFacility
	var player := get_first_node_in_group("player") as PlayerController
	var market_hud := main.get_node("MarketHUD") as MarketHUD
	_check(is_equal_approx(market.current_price, 42.0), "scenario C: fresh scene resets VITA to $42")
	_check(not market.has_open_position(), "scenario C: fresh scene resets the short")
	_check(is_equal_approx(market.get_unrealized_pnl(), 0.0), "scenario C: fresh scene resets P&L")
	_check(facility.destroyed_count == 0, "scenario C: fresh scene resets sabotage events")
	_check(facility.get_equipment().all(func(machine: DestructibleEquipment) -> bool: return not machine.is_destroyed() and machine.operational_state == DestructibleEquipment.OperationalState.NOMINAL and is_equal_approx(machine.health, machine.max_health)), "scenario C: all three machines return nominal and at full health")
	_check(market_hud.price_label.text == "$42.00" and not market_hud.position_label.visible, "scenario C: HUD returns to its initial state")
	main._set_market_open(true)
	_check(not player.is_gameplay_input_enabled(), "market panel disables combat input")
	main._set_market_open(false)
	_check(player.is_gameplay_input_enabled(), "closing market restores combat input")
	await _remove_main(main)

func _spawn_fresh_main() -> Node3D:
	var main := _main_scene.instantiate() as Node3D
	root.add_child(main)
	await process_frame
	await physics_frame
	var market := get_first_node_in_group("market_service") as MarketService
	var fast_company := market.company.duplicate() as CompanyDefinition
	fast_company.reaction_delay = 0.01
	fast_company.price_transition_duration = 0.03
	market.company = fast_company
	return main

func _remove_main(main: Node3D) -> void:
	Engine.time_scale = 1.0
	main.queue_free()
	await process_frame
	await process_frame

func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
