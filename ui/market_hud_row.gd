class_name MarketHUDRow
extends VBoxContainer

@onready var ticker_label: Label = %TickerLabel
@onready var price_label: Label = %PriceLabel
@onready var trend_label: Label = %TrendLabel
@onready var variation_label: Label = %VariationLabel
@onready var position_row: HBoxContainer = %PositionRow
@onready var position_label: Label = %PositionLabel
@onready var pnl_label: Label = %PnLLabel

var company_id := ""
var _market: MarketService
var _price_tween: Tween
var _pnl_tween: Tween

func bind(market: MarketService, id: String) -> void:
	_market = market
	company_id = id
	refresh()

func refresh() -> void:
	if _market == null:
		return
	var company := _market.get_company_definition(company_id)
	if company == null:
		return
	ticker_label.text = company.ticker
	ticker_label.add_theme_color_override("font_color", company.accent_color.lightened(0.34))
	price_label.text = "$%.2f" % _market.get_current_price(company_id)
	var variation := _market.get_variation_percent(company_id)
	trend_label.text = "▼" if variation < -0.005 else ""
	variation_label.text = "%.2f%%" % variation
	variation_label.add_theme_color_override("font_color", Color("c47d61") if variation < -0.005 else Color("aaa99f"))

	var has_position := _market.has_open_position(company_id)
	position_row.visible = has_position
	if has_position:
		position_label.text = "SHORT ×%d" % _market.get_position_shares(company_id)
		var pnl := _market.get_unrealized_pnl(company_id)
		pnl_label.text = "UNRL  %s" % MoneyFormat.pnl(pnl)
		pnl_label.add_theme_color_override("font_color", Color("9fc49f") if pnl >= 0.0 else Color("c77c60"))

func pulse_price() -> void:
	if _price_tween != null and _price_tween.is_valid():
		_price_tween.kill()
	price_label.pivot_offset = price_label.size * 0.5
	price_label.scale = Vector2(1.08, 1.08)
	price_label.add_theme_color_override("font_color", Color("d68d69"))
	_price_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_price_tween.tween_property(price_label, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_price_tween.tween_method(_set_price_color_blend, 0.0, 1.0, 0.72)

func pulse_pnl() -> void:
	if _pnl_tween != null and _pnl_tween.is_valid():
		_pnl_tween.kill()
	pnl_label.pivot_offset = pnl_label.size * 0.5
	pnl_label.scale = Vector2(1.08, 1.08)
	_pnl_tween = create_tween().set_ignore_time_scale(true)
	_pnl_tween.tween_property(pnl_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_price_color_blend(weight: float) -> void:
	price_label.add_theme_color_override("font_color", Color("d68d69").lerp(Color("eee8dc"), weight))
