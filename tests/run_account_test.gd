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
	var market := _new_market()
	_check(market.get_cash() == 10000.0 and market.get_total_realized_pnl() == 0.0, "account starts with $10,000 and no realized profit")
	_check(market.open_short("arc_energy", 300) and market.open_short("vita_medical", 300), "both short positions open independently")
	_check(market.get_cash() == 10000.0, "opening shorts does not create cash or debit notional")
	for equipment_id in ["transformer_bank", "switchgear_unit", "generator_set"]:
		market.register_sabotage("arc_energy", equipment_id)
		await market.sabotage_resolved
		await market.sabotage_resolved
	_check(market.get_total_unrealized_pnl() == 9900.0 and market.get_cash() == 10000.0, "stock drops create $9,900 unrealized, not cash")
	_check(market.close_short("arc_energy"), "manual ARC close succeeds")
	_check(market.get_cash() == 18700.0 and market.get_realized_pnl("arc_energy") == 8700.0, "manual close realizes ARC profit into cash")
	_check(market.has_open_position("vita_medical") and market.get_total_unrealized_pnl() == 1200.0, "ARC close leaves VITA open and unrealized")
	_check(not market.close_short("arc_energy") and not market.close_short("missing"), "duplicate and unknown closes cannot pay twice")
	var summary := market.settle_all_positions()
	_check(summary["cash"] == 19900.0 and summary["realized_pnl"] == 9900.0, "settlement includes prior realized profit plus remaining positions exactly once")
	_check(summary["unrealized_pnl"] == 0.0 and market.get_realized_pnl("vita_medical") == 1200.0, "settlement clears unrealized and preserves per-company breakdown")
	market.settle_all_positions()
	market.forfeit_run_profit()
	_check(market.get_cash() == 19900.0, "terminal settlement is idempotent and cannot later be forfeited")
	_check(not market.open_short("vita_medical") and not market.register_sabotage("vita_medical", "late_event"), "completed account rejects trading and late world events")
	summary["cash"] = 1.0
	_check(market.get_cash() == 19900.0, "UI summary is a detached snapshot")
	market.queue_free()
	await process_frame

	market = _new_market()
	market.open_short("vita_medical", 300)
	market._set_current_price("vita_medical", 45.0)
	market.close_short("vita_medical")
	_check(market.get_cash() == 9100.0 and market.get_realized_pnl("vita_medical") == -900.0, "negative short P&L reduces cash with the correct sign")
	market.open_short("vita_medical", 300)
	market._set_current_price("vita_medical", 44.0)
	market.close_short("vita_medical")
	_check(market.get_cash() == 9400.0 and market.get_realized_pnl("vita_medical") == -600.0, "reopened positions accumulate realized P&L without duplicating the old entry")
	market.queue_free()
	await process_frame

	market = _new_market()
	market.open_short("arc_energy", 300)
	market.open_short("vita_medical", 300)
	market.register_sabotage("arc_energy", "transformer_bank")
	await market.sabotage_resolved
	await market.sabotage_resolved
	market.close_short("arc_energy")
	_check(market.get_cash() == 12400.0 and market.get_total_unrealized_pnl() == 300.0, "loss fixture has both realized cash and an open profitable position")
	market.forfeit_run_profit()
	market.forfeit_run_profit()
	market.settle_all_positions()
	_check(market.get_cash() == 10000.0 and market.get_total_realized_pnl() == 0.0 and market.get_total_unrealized_pnl() == 0.0, "failed run forfeits closed and open gains and restores starting capital")
	_check(not market.has_open_position("vita_medical") and not market.has_open_position("arc_energy"), "failure discards all positions instead of realizing them")
	market.queue_free()
	await process_frame

	market = _new_market()
	market.reaction_time_scale = 0.5
	market.open_short("arc_energy", 300)
	market.open_short("vita_medical", 300)
	market.register_sabotage("arc_energy", "transformer_bank")
	await market.price_reaction_started
	await create_timer(0.07).timeout
	var exit_price := market.get_current_price("arc_energy")
	var exit_pnl := market.get_total_unrealized_pnl()
	_check(exit_price > 56.0 and exit_price < 64.0, "mid-reaction fixture is genuinely inside the price transition")
	market.settle_all_positions()
	await create_timer(1.2).timeout
	_check(market.get_current_price("arc_energy") == exit_price and market.get_current_price("vita_medical") == 42.0, "settlement cancels active and queued price reactions at the exit snapshot")
	_check(is_equal_approx(market.get_cash(), 10000.0 + exit_pnl), "mid-transition close uses displayed price rather than queued target")
	market.queue_free()
	await process_frame

	market = _new_market()
	_check(market.get_cash() == 10000.0 and market.get_total_realized_pnl() == 0.0 and market.is_trading_enabled(), "fresh account resets cash, realized P&L and trading")
	market.queue_free()
	await process_frame
	print("Run account test complete.")
	quit(1 if _failed else 0)

func _new_market() -> MarketService:
	var market := MarketService.new()
	market.companies.append(load("res://data/vita_medical.tres") as CompanyDefinition)
	market.companies.append(load("res://data/arc_energy.tres") as CompanyDefinition)
	market.dependencies.append(load("res://data/arc_powers_vita.tres") as MarketDependency)
	market.reaction_time_scale = 0.02
	root.add_child(market)
	return market
