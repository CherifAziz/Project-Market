extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failed = true
		push_error("FAIL: " + message)

func _run() -> void:
	var vita := (load("res://data/vita_medical.tres") as CompanyDefinition).duplicate() as CompanyDefinition
	var arc := (load("res://data/arc_energy.tres") as CompanyDefinition).duplicate() as CompanyDefinition
	var dependency := (load("res://data/arc_powers_vita.tres") as MarketDependency).duplicate() as MarketDependency
	vita.reaction_delay = 0.01
	vita.price_transition_duration = 0.02
	arc.reaction_delay = 0.01
	arc.price_transition_duration = 0.02
	dependency.reaction_delay = 0.01
	dependency.price_transition_duration = 0.02

	_check(vita.company_id == "vita_medical" and arc.company_id == "arc_energy", "multiple companies are reusable data resources")
	_check(is_equal_approx(vita.price_after_sabotage(0), 42.0), "VITA initial company price is $42")
	_check(is_equal_approx(vita.price_after_sabotage(1), 38.0), "VITA direct sabotage stage one remains $38")
	_check(is_equal_approx(vita.price_after_sabotage(2), 32.0), "VITA direct sabotage stage two remains $32")
	_check(is_equal_approx(vita.price_after_sabotage(3), 27.0), "VITA direct sabotage stage three remains $27")
	_check(is_equal_approx(arc.price_after_sabotage(1), 56.0) and is_equal_approx(arc.price_after_sabotage(3), 35.0), "ARC has a deterministic stronger direct price curve")

	var position := ShortPosition.new(42.0, 300)
	position.update_current_price(27.0)
	_check(is_equal_approx(position.unrealized_pnl(), 4500.0), "short P&L still uses (entry - current) × shares")

	var market := MarketService.new()
	market.companies.append(vita)
	market.companies.append(arc)
	market.dependencies.append(dependency)
	root.add_child(market)
	await process_frame
	_check(market.get_company_ids().size() == 2, "one market service registers two companies")
	_check(is_equal_approx(market.get_current_price("vita_medical"), 42.0), "VITA initializes independently")
	_check(is_equal_approx(market.get_current_price("arc_energy"), 64.0), "ARC initializes independently")
	_check(market.open_short("arc_energy", 300), "ARC short position opens")
	_check(market.open_short("vita_medical", 300), "VITA short position opens independently")
	_check(not market.open_short("arc_energy", 300), "a second ARC position is rejected without blocking VITA")
	_check(market.get_position_entry_price("arc_energy") == 64.0 and market.get_position_entry_price("vita_medical") == 42.0, "independent positions retain their own entries")

	var operational_events: Array[Dictionary] = []
	market.operational_event.connect(
		func(company_id: String, message: String, stage: int, total: int, cause_company_id: String) -> void:
			operational_events.append({
				"company_id": company_id,
				"message": message,
				"stage": stage,
				"total": total,
				"cause": cause_company_id,
			})
	)

	_check(market.register_sabotage("arc_energy", "transformer_bank"), "new ARC sabotage is accepted")
	_check(not market.register_sabotage("arc_energy", "transformer_bank"), "duplicate ARC world event is rejected before propagation")
	var first_resolution: Array = await market.sabotage_resolved
	var second_resolution: Array = await market.sabotage_resolved
	_check(first_resolution[0] == "arc_energy" and second_resolution[0] == "vita_medical", "ARC resolves before its downstream VITA reaction")
	_check(is_equal_approx(market.get_current_price("arc_energy"), 56.0), "ARC transformer sabotage drops ARC strongly")
	_check(is_equal_approx(market.get_current_price("vita_medical"), 41.0), "ARC transformer sabotage propagates a smaller VITA drop")
	_check(is_equal_approx(market.get_unrealized_pnl("arc_energy"), 2400.0), "ARC short profits from the direct move")
	_check(is_equal_approx(market.get_unrealized_pnl("vita_medical"), 300.0), "VITA short profits independently from dependency propagation")
	_check(operational_events.size() == 2, "one ARC event produces exactly one direct and one dependency reaction")
	_check(operational_events[1]["company_id"] == "vita_medical" and operational_events[1]["cause"] == "arc_energy" and "POWER SUPPLY" in operational_events[1]["message"], "dependency reaction carries an explicit ARC cause and clear VITA power message")
	_check(market.get_destroyed_equipment_count("arc_energy") == 1 and market.get_destroyed_equipment_count("vita_medical") == 0, "propagation does not masquerade as direct VITA sabotage")

	for equipment_id in ["switchgear_unit", "generator_set"]:
		_check(market.register_sabotage("arc_energy", equipment_id), "ARC sabotage %s is accepted" % equipment_id)
		await market.sabotage_resolved
		await market.sabotage_resolved
	_check(is_equal_approx(market.get_current_price("arc_energy"), 35.0), "full ARC sabotage resolves to $35")
	_check(is_equal_approx(market.get_current_price("vita_medical"), 38.0), "full ARC outage resolves VITA dependency impact to $38")
	_check(is_equal_approx(market.get_unrealized_pnl("arc_energy"), 8700.0), "full ARC short P&L is +$8,700")
	_check(is_equal_approx(market.get_unrealized_pnl("vita_medical"), 1200.0), "full propagated VITA short P&L is +$1,200")
	_check(operational_events.size() == 6, "three ARC events apply exactly six ordered market reactions")
	market.queue_free()
	await process_frame

	var direct_market := MarketService.new()
	var direct_vita := vita.duplicate() as CompanyDefinition
	direct_market.companies.append(direct_vita)
	root.add_child(direct_market)
	await process_frame
	_check(direct_market.open_short("vita_medical", 300), "direct VITA scenario opens its own short")
	_check(direct_market.register_sabotage("vita_medical", "filtration_unit"), "direct VITA sabotage remains accepted")
	await direct_market.sabotage_resolved
	_check(is_equal_approx(direct_market.get_current_price("vita_medical"), 38.0), "direct VITA sabotage remains unchanged at $38")
	_check(is_equal_approx(direct_market.get_unrealized_pnl("vita_medical"), 1200.0), "direct VITA P&L remains unchanged")
	direct_market.queue_free()
	await process_frame

	print("Market logic test complete.")
	quit(1 if _failed else 0)
