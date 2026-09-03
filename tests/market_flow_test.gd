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
	await _run_vita_direct_scenario()
	await _run_arc_dependency_scenario()
	await _run_no_position_scenario()
	await _run_reset_scenario()
	Engine.time_scale = 1.0
	print("Market flow test complete.")
	quit(1 if _failed else 0)

func _run_vita_direct_scenario() -> void:
	var main := await _spawn_fresh_main()
	var market := get_first_node_in_group("market_service") as MarketService
	var facility := main.get_node("VITAFacility") as CompanyFacility
	var player := get_first_node_in_group("player") as PlayerController
	var market_panel := main.get_node("MarketPanel") as MarketPanel
	var equipment := facility.get_equipment()
	_check(equipment.size() == 3, "VITA direct: exactly three VITA machines exist")
	main._unhandled_input(_action_event("market"))
	_check(market_panel.is_open() and not player.is_gameplay_input_enabled(), "VITA direct: M opens market and suspends combat input")
	_check(market_panel.open_short_for("vita_medical"), "VITA direct: VITA card opens the short")
	_check(market.has_open_position("vita_medical") and not market.has_open_position("arc_energy"), "VITA direct: position is company-specific")
	_check(is_equal_approx(market.get_position_entry_price("vita_medical"), 42.0), "VITA direct: short entry is $42")
	main._unhandled_input(_action_event("market"))
	_check(not market_panel.is_open() and player.is_gameplay_input_enabled(), "VITA direct: M closes market and restores combat input")

	var expected_prices := [38.0, 32.0, 27.0]
	var expected_pnl := [1200.0, 3000.0, 4500.0]
	for index in range(equipment.size()):
		var machine := equipment[index] as DestructibleEquipment
		machine.take_damage(machine.max_health * 0.5, machine.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
		_check(machine.operational_state == DestructibleEquipment.OperationalState.DAMAGED and not machine.is_destroyed(), "VITA direct: machine %d exposes DAMAGED" % (index + 1))
		machine.take_damage(machine.health, machine.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
		await market.sabotage_resolved
		_check(machine.is_destroyed(), "VITA direct: machine %d enters OFFLINE" % (index + 1))
		_check(is_equal_approx(market.get_current_price("vita_medical"), expected_prices[index]), "VITA direct: price reaches stage %d" % (index + 1))
		_check(is_equal_approx(market.get_unrealized_pnl("vita_medical"), expected_pnl[index]), "VITA direct: P&L is correct at stage %d" % (index + 1))
	_check(is_equal_approx(market.get_unrealized_pnl("vita_medical"), 4500.0), "VITA direct: final short profit remains +$4,500")
	var market_hud := main.get_node("MarketHUD") as MarketHUD
	var vita_row := market_hud.get_company_row("vita_medical")
	_check(vita_row.price_label.text == "$27.00", "VITA direct: HUD displays the final live price")
	_check(vita_row.variation_label.text == "-35.71%", "VITA direct: HUD displays the final variation")
	_check("4,500" in vita_row.pnl_label.text, "VITA direct: HUD displays the final P&L")
	await _remove_main(main)

func _run_arc_dependency_scenario() -> void:
	var main := await _spawn_fresh_main()
	var market := get_first_node_in_group("market_service") as MarketService
	var arc_facility := main.get_node("ARCFacility") as CompanyFacility
	var market_panel := main.get_node("MarketPanel") as MarketPanel
	var market_hud := main.get_node("MarketHUD") as MarketHUD
	var dependency_events: Array[String] = []
	market.operational_event.connect(
		func(company_id: String, message: String, _stage: int, _total: int, cause_company_id: String) -> void:
			if company_id != cause_company_id:
				dependency_events.append("%s:%s:%s" % [cause_company_id, company_id, message])
	)

	_check(market_panel.get_company_card("vita_medical") != null and market_panel.get_company_card("arc_energy") != null, "ARC dependency: market panel exposes both company cards")
	_check(market_panel.open_short_for("arc_energy"), "ARC dependency: ARC short opens")
	_check(market_panel.open_short_for("vita_medical"), "ARC dependency: VITA short opens independently")
	var equipment := arc_facility.get_equipment()
	_check(equipment.size() == 3 and equipment.all(func(machine: DestructibleEquipment) -> bool: return machine.owner_company_id == "arc_energy"), "ARC dependency: three physical ARC grid assets exist")

	var transformer := equipment[0] as DestructibleEquipment
	transformer.take_damage(transformer.max_health, transformer.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
	var direct_resolution: Array = await market.sabotage_resolved
	var propagated_resolution: Array = await market.sabotage_resolved
	_check(direct_resolution[0] == "arc_energy" and propagated_resolution[0] == "vita_medical", "ARC dependency: direct ARC move resolves before VITA propagation")
	_check(is_equal_approx(market.get_current_price("arc_energy"), 56.0), "ARC dependency: transformer loss moves ARC strongly to $56")
	_check(is_equal_approx(market.get_current_price("vita_medical"), 41.0), "ARC dependency: power disruption moves VITA lightly to $41")
	_check(market.get_unrealized_pnl("arc_energy") > 0.0 and market.get_unrealized_pnl("vita_medical") > 0.0, "ARC dependency: SHORT ARC + SHORT VITA yields two positive P&Ls")
	_check(dependency_events.size() == 1 and dependency_events[0].begins_with("arc_energy:vita_medical:") and "POWER SUPPLY" in dependency_events[0], "ARC dependency: causal power-supply notification identifies ARC → VITA")
	_check(not market.register_sabotage("arc_energy", transformer.equipment_id), "ARC dependency: repeated transformer event cannot apply twice")
	_check(market.get_destroyed_equipment_count("arc_energy") == 1 and market.get_destroyed_equipment_count("vita_medical") == 0, "ARC dependency: propagated move does not increment VITA sabotage")

	for index in range(1, equipment.size()):
		var machine := equipment[index] as DestructibleEquipment
		machine.take_damage(machine.max_health, machine.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
		await market.sabotage_resolved
		await market.sabotage_resolved
	_check(is_equal_approx(market.get_current_price("arc_energy"), 35.0), "ARC dependency: full ARC sabotage ends at $35")
	_check(is_equal_approx(market.get_current_price("vita_medical"), 38.0), "ARC dependency: full energy propagation ends VITA at $38")
	_check(is_equal_approx(market.get_unrealized_pnl("arc_energy"), 8700.0), "ARC dependency: ARC P&L ends at +$8,700")
	_check(is_equal_approx(market.get_unrealized_pnl("vita_medical"), 1200.0), "ARC dependency: propagated VITA P&L ends at +$1,200")
	_check("8,700" in market_hud.get_company_row("arc_energy").pnl_label.text and "1,200" in market_hud.get_company_row("vita_medical").pnl_label.text, "ARC dependency: both live HUD rows retain their own P&L")
	await _remove_main(main)

func _run_no_position_scenario() -> void:
	var main := await _spawn_fresh_main()
	var market := get_first_node_in_group("market_service") as MarketService
	var facility := main.get_node("VITAFacility") as CompanyFacility
	for machine_value in facility.get_equipment():
		var machine := machine_value as DestructibleEquipment
		machine.take_damage(machine.max_health, machine.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
		await market.sabotage_resolved
	_check(is_equal_approx(market.get_current_price("vita_medical"), 27.0), "no position: sabotage still lowers VITA")
	_check(not market.has_open_position("vita_medical") and not market.has_open_position("arc_energy"), "no position: sabotage creates no implicit positions")
	_check(is_equal_approx(market.get_total_unrealized_pnl(), 0.0), "no position: aggregate P&L remains zero")
	await _remove_main(main)

func _run_reset_scenario() -> void:
	var main := await _spawn_fresh_main()
	var market := get_first_node_in_group("market_service") as MarketService
	var vita_facility := main.get_node("VITAFacility") as CompanyFacility
	var arc_facility := main.get_node("ARCFacility") as CompanyFacility
	var player := get_first_node_in_group("player") as PlayerController
	var market_hud := main.get_node("MarketHUD") as MarketHUD
	_check(is_equal_approx(market.get_current_price("vita_medical"), 42.0) and is_equal_approx(market.get_current_price("arc_energy"), 64.0), "reset: both companies return to initial prices")
	_check(not market.has_open_position("vita_medical") and not market.has_open_position("arc_energy"), "reset: both independent positions are cleared")
	_check(is_equal_approx(market.get_total_unrealized_pnl(), 0.0), "reset: all P&L is cleared")
	_check(vita_facility.destroyed_count == 0 and arc_facility.destroyed_count == 0, "reset: both facility event counts are cleared")
	var all_equipment := vita_facility.get_equipment() + arc_facility.get_equipment()
	_check(all_equipment.all(func(machine: DestructibleEquipment) -> bool: return not machine.is_destroyed() and machine.operational_state == DestructibleEquipment.OperationalState.NOMINAL and is_equal_approx(machine.health, machine.max_health)), "reset: all six machines return nominal and full health")
	_check(market_hud.get_company_row("vita_medical").price_label.text == "$42.00" and market_hud.get_company_row("arc_energy").price_label.text == "$64.00", "reset: both HUD rows return to initial state")
	main._set_market_open(true)
	_check(not player.is_gameplay_input_enabled(), "reset: market panel disables combat input")
	main._set_market_open(false)
	_check(player.is_gameplay_input_enabled(), "reset: closing market restores combat input")
	await _remove_main(main)

func _spawn_fresh_main() -> Node3D:
	var main := _main_scene.instantiate() as Node3D
	root.add_child(main)
	await process_frame
	await physics_frame
	var market := get_first_node_in_group("market_service") as MarketService
	market.reaction_time_scale = 0.02
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
