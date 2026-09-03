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
	var definition := (load("res://data/vita_medical.tres") as CompanyDefinition).duplicate() as CompanyDefinition
	_check(definition.company_id == "vita_medical", "VITA is defined as reusable company data")
	_check(is_equal_approx(definition.price_after_sabotage(0), 42.0), "initial company price is $42")
	_check(is_equal_approx(definition.price_after_sabotage(1), 38.0), "first deterministic target is $38")
	_check(is_equal_approx(definition.price_after_sabotage(2), 32.0), "second deterministic target is $32")
	_check(is_equal_approx(definition.price_after_sabotage(3), 27.0), "third deterministic target is $27")

	var position := ShortPosition.new(42.0, 300)
	position.update_current_price(27.0)
	_check(is_equal_approx(position.unrealized_pnl(), 4500.0), "short P&L uses (entry - current) × shares")

	definition.reaction_delay = 0.01
	definition.price_transition_duration = 0.03
	var market := MarketService.new()
	market.company = definition
	root.add_child(market)
	await process_frame
	_check(is_equal_approx(market.current_price, 42.0), "market initializes from company data")
	_check(market.open_short(300), "one short position can be opened")
	_check(not market.open_short(300), "a second position is rejected")

	var expected_prices := [38.0, 32.0, 27.0]
	var expected_pnl := [1200.0, 3000.0, 4500.0]
	for index in range(3):
		_check(market.register_sabotage("machine_%d" % index), "new sabotage event %d is accepted" % (index + 1))
		await market.sabotage_resolved
		_check(is_equal_approx(market.current_price, expected_prices[index]), "price reaches deterministic stage %d" % (index + 1))
		_check(is_equal_approx(market.get_unrealized_pnl(), expected_pnl[index]), "P&L follows price at stage %d" % (index + 1))

	_check(not market.register_sabotage("machine_0"), "duplicate equipment events are ignored")
	market.queue_free()
	await process_frame
	print("Market logic test complete.")
	quit(1 if _failed else 0)
