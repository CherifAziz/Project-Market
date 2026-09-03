class_name MarketHUD
extends CanvasLayer

const MARKET_ROW_SCENE := preload("res://ui/market_hud_row.tscn")

@onready var market_rows: VBoxContainer = %MarketRows
@onready var notification_panel: PanelContainer = %NotificationPanel
@onready var notification_label: Label = %NotificationLabel
@onready var profit_label: Label = %ProfitLabel

var _market: MarketService
var _rows: Dictionary = {}
var _notification_tween: Tween
var _profit_tween: Tween

func _ready() -> void:
	_market = get_tree().get_first_node_in_group("market_service") as MarketService
	if _market != null:
		_populate_rows()
		_market.market_updated.connect(_on_market_updated)
		_market.operational_event.connect(_on_operational_event)
		_market.price_reaction_started.connect(_on_price_reaction_started)
		_market.sabotage_resolved.connect(_on_sabotage_resolved)
	_refresh_all()

func get_company_row(company_id: String) -> MarketHUDRow:
	return _rows.get(company_id) as MarketHUDRow

func _populate_rows() -> void:
	for child in market_rows.get_children():
		child.queue_free()
	_rows.clear()
	for company_id in _market.get_company_ids():
		var row := MARKET_ROW_SCENE.instantiate() as MarketHUDRow
		market_rows.add_child(row)
		row.bind(_market, company_id)
		_rows[company_id] = row

func _on_market_updated(company_id: String) -> void:
	var row := get_company_row(company_id)
	if row != null:
		row.refresh()

func _refresh_all() -> void:
	for row_value in _rows.values():
		(row_value as MarketHUDRow).refresh()

func _on_operational_event(company_id: String, message: String, stage: int, total: int, cause_company_id: String) -> void:
	if _notification_tween != null and _notification_tween.is_valid():
		_notification_tween.kill()
	var notification_text := "%02d / %02d   %s" % [stage, total, message]
	if company_id != cause_company_id:
		var source := _market.get_company_definition(cause_company_id)
		if source != null:
			notification_text = "%s  →  %s" % [source.ticker, message]
	notification_label.text = notification_text
	notification_panel.visible = true
	notification_panel.modulate.a = 0.0
	notification_panel.position.y = -8.0
	_notification_tween = create_tween().set_ignore_time_scale(true)
	_notification_tween.set_parallel(true)
	_notification_tween.tween_property(notification_panel, "modulate:a", 1.0, 0.14)
	_notification_tween.tween_property(notification_panel, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_notification_tween.set_parallel(false)
	_notification_tween.tween_interval(1.35)
	_notification_tween.tween_property(notification_panel, "modulate:a", 0.0, 0.35)
	_notification_tween.finished.connect(func() -> void: notification_panel.visible = false)

func _on_price_reaction_started(company_id: String, _target_price: float, _cause_company_id: String) -> void:
	var row := get_company_row(company_id)
	if row != null:
		row.pulse_price()
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_ui"):
		audio.play_ui(&"market_drop", 0.018)

func _on_sabotage_resolved(company_id: String, _current_price: float, unrealized_pnl: float, _cause_company_id: String, is_final_stage: bool) -> void:
	if _market == null or not _market.has_open_position(company_id):
		return
	var row := get_company_row(company_id)
	if row != null:
		row.pulse_pnl()
	_show_profit_payoff(company_id, unrealized_pnl, is_final_stage)
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_ui"):
		audio.play_ui(&"profit_final" if is_final_stage else &"profit_tick", 0.012)

func _show_profit_payoff(company_id: String, unrealized_pnl: float, is_final: bool) -> void:
	if _profit_tween != null and _profit_tween.is_valid():
		_profit_tween.kill()
	var company := _market.get_company_definition(company_id)
	var ticker := company.ticker if company != null else company_id.to_upper()
	profit_label.text = "%s  %s" % [ticker, _format_pnl(unrealized_pnl)]
	profit_label.add_theme_font_size_override("font_size", 40 if is_final else 27)
	profit_label.visible = true
	profit_label.modulate = Color(0.65, 0.8, 0.65, 0.0)
	profit_label.scale = Vector2(0.82, 0.82) if is_final else Vector2(0.92, 0.92)
	profit_label.pivot_offset = profit_label.size * 0.5
	_profit_tween = create_tween().set_ignore_time_scale(true)
	_profit_tween.set_parallel(true)
	_profit_tween.tween_property(profit_label, "modulate:a", 1.0, 0.13)
	_profit_tween.tween_property(profit_label, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_profit_tween.set_parallel(false)
	_profit_tween.tween_interval(1.65 if is_final else 0.7)
	_profit_tween.tween_property(profit_label, "modulate:a", 0.0, 0.4)
	_profit_tween.finished.connect(func() -> void: profit_label.visible = false)

func _format_pnl(value: float) -> String:
	var rounded_value := int(round(value))
	if rounded_value > 0:
		return "+$%s" % _with_thousands(rounded_value)
	if rounded_value < 0:
		return "-$%s" % _with_thousands(absi(rounded_value))
	return "$0"

func _with_thousands(value: int) -> String:
	var digits := str(value)
	var result := ""
	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result
