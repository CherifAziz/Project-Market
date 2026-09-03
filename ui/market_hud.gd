class_name MarketHUD
extends CanvasLayer

@onready var ticker_label: Label = %TickerLabel
@onready var price_label: Label = %PriceLabel
@onready var trend_label: Label = %TrendLabel
@onready var variation_label: Label = %VariationLabel
@onready var position_label: Label = %PositionLabel
@onready var pnl_label: Label = %PnLLabel
@onready var notification_panel: PanelContainer = %NotificationPanel
@onready var notification_label: Label = %NotificationLabel
@onready var profit_label: Label = %ProfitLabel

var _market: MarketService
var _notification_tween: Tween
var _profit_tween: Tween
var _price_tween: Tween

func _ready() -> void:
	_market = get_tree().get_first_node_in_group("market_service") as MarketService
	if _market:
		_market.market_updated.connect(_refresh)
		_market.operational_event.connect(_on_operational_event)
		_market.price_reaction_started.connect(_on_price_reaction_started)
		_market.sabotage_resolved.connect(_on_sabotage_resolved)
	_refresh()

func _refresh() -> void:
	if _market == null or _market.company == null:
		return
	ticker_label.text = _market.company.ticker
	price_label.text = "$%.2f" % _market.current_price
	var is_down := _market.current_price < _market.company.initial_price - 0.005
	trend_label.text = "▼" if is_down else ""
	trend_label.modulate = Color("c47d61")
	var variation := _market.get_variation_percent()
	variation_label.text = "%.2f%%" % variation
	variation_label.add_theme_color_override("font_color", Color("c47d61") if variation < -0.005 else Color("aaa99f"))

	var has_position := _market.has_open_position()
	position_label.visible = has_position
	pnl_label.visible = has_position
	if has_position:
		position_label.text = "SHORT ×%d" % _market.get_position_shares()
		pnl_label.text = "P&L  %s" % _format_pnl(_market.get_unrealized_pnl())
		pnl_label.add_theme_color_override("font_color", Color("9fc49f") if _market.get_unrealized_pnl() >= 0.0 else Color("c77c60"))

func _on_operational_event(message: String, destroyed_count: int, total_count: int) -> void:
	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()
	notification_label.text = "%02d / %02d   %s" % [destroyed_count, total_count, message]
	notification_panel.visible = true
	notification_panel.modulate.a = 0.0
	notification_panel.position.y = -8.0
	_notification_tween = create_tween().set_ignore_time_scale(true)
	_notification_tween.set_parallel(true)
	_notification_tween.tween_property(notification_panel, "modulate:a", 1.0, 0.14)
	_notification_tween.tween_property(notification_panel, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_notification_tween.set_parallel(false)
	_notification_tween.tween_interval(1.3)
	_notification_tween.tween_property(notification_panel, "modulate:a", 0.0, 0.35)
	_notification_tween.finished.connect(func() -> void: notification_panel.visible = false)

func _on_price_reaction_started(_destroyed_count: int, _target_price: float) -> void:
	if _price_tween and _price_tween.is_valid():
		_price_tween.kill()
	price_label.pivot_offset = price_label.size * 0.5
	price_label.scale = Vector2(1.08, 1.08)
	price_label.add_theme_color_override("font_color", Color("d68d69"))
	_price_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_price_tween.tween_property(price_label, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_price_tween.tween_method(_set_price_color_blend, 0.0, 1.0, 0.72)
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio and audio.has_method("play_ui"):
		audio.play_ui(&"market_drop", 0.018)

func _set_price_color_blend(weight: float) -> void:
	price_label.add_theme_color_override("font_color", Color("d68d69").lerp(Color("eee8dc"), weight))

func _on_sabotage_resolved(destroyed_count: int, _current_price: float, unrealized_pnl: float) -> void:
	if _market == null or not _market.has_open_position():
		return
	var is_final := destroyed_count >= _market.company.sabotage_stage_count()
	_show_profit_payoff(unrealized_pnl, is_final)
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio and audio.has_method("play_ui"):
		audio.play_ui(&"profit_final" if is_final else &"profit_tick", 0.012)

func _show_profit_payoff(unrealized_pnl: float, is_final: bool) -> void:
	if _profit_tween and _profit_tween.is_valid():
		_profit_tween.kill()
	profit_label.text = _format_pnl(unrealized_pnl) if is_final else "P&L  " + _format_pnl(unrealized_pnl)
	profit_label.add_theme_font_size_override("font_size", 42 if is_final else 28)
	profit_label.visible = true
	profit_label.modulate = Color(0.65, 0.8, 0.65, 0.0)
	profit_label.scale = Vector2(0.82, 0.82) if is_final else Vector2(0.92, 0.92)
	profit_label.pivot_offset = profit_label.size * 0.5
	_profit_tween = create_tween().set_ignore_time_scale(true)
	_profit_tween.set_parallel(true)
	_profit_tween.tween_property(profit_label, "modulate:a", 1.0, 0.13)
	_profit_tween.tween_property(profit_label, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_profit_tween.tween_property(pnl_label, "scale", Vector2(1.07, 1.07), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_profit_tween.set_parallel(false)
	_profit_tween.tween_property(pnl_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
