class_name MarketCompanyCard
extends PanelContainer

signal short_requested(company_id: String)

@onready var company_name_label: Label = %CompanyName
@onready var ticker_label: Label = %Ticker
@onready var price_label: Label = %Price
@onready var variation_label: Label = %Variation
@onready var operations_label: Label = %Operations
@onready var position_title: Label = %PositionTitle
@onready var position_details: Label = %PositionDetails
@onready var position_pnl: Label = %PositionPnL
@onready var short_button: Button = %ShortButton

var company_id := ""
var _market: MarketService

func _ready() -> void:
	short_button.pressed.connect(func() -> void: short_requested.emit(company_id))

func bind(market: MarketService, id: String) -> void:
	_market = market
	company_id = id
	_apply_company_accent()
	refresh()

func refresh() -> void:
	if _market == null:
		return
	var company := _market.get_company_definition(company_id)
	if company == null:
		return
	company_name_label.text = company.display_name
	ticker_label.text = "%s  /  %s" % [company.ticker, company.market_category]
	price_label.text = "$%.2f" % _market.get_current_price(company_id)
	price_label.add_theme_color_override("font_color", company.accent_color.lightened(0.3))
	var variation := _market.get_variation_percent(company_id)
	variation_label.text = _signed_percent(variation)
	variation_label.add_theme_color_override("font_color", Color("c77c60") if variation < -0.005 else Color("d6cdbb"))
	operations_label.text = "CRITICAL SYSTEMS OFFLINE  %d / %d" % [
		_market.get_destroyed_equipment_count(company_id),
		_market.get_equipment_total(company_id),
	]

	if _market.has_open_position(company_id):
		position_title.text = "OPEN POSITION  //  SHORT ×%d" % _market.get_position_shares(company_id)
		position_details.text = "ENTRY  $%.2f      CURRENT  $%.2f" % [
			_market.get_position_entry_price(company_id),
			_market.get_current_price(company_id),
		]
		var pnl := _market.get_unrealized_pnl(company_id)
		position_pnl.text = "UNREALIZED P&L   %s" % _format_pnl(pnl)
		position_pnl.add_theme_color_override("font_color", Color("9fc49f") if pnl >= 0.0 else Color("c77c60"))
		short_button.disabled = true
		short_button.text = "%s SHORT OPEN" % company.ticker
	else:
		position_title.text = "NO OPEN POSITION"
		position_details.text = "INDEPENDENT COMPANY POSITION"
		position_pnl.text = ""
		short_button.disabled = false
		short_button.text = "SHORT %s  //  %d SHARES" % [company.ticker, _market.default_short_shares]

func _apply_company_accent() -> void:
	if _market == null:
		return
	var company := _market.get_company_definition(company_id)
	if company == null:
		return
	var panel_style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel_style.border_color = Color(company.accent_color, 0.85)
	add_theme_stylebox_override("panel", panel_style)

func _signed_percent(value: float) -> String:
	var sign := "+" if value > 0.005 else ""
	return "%s%.2f%%" % [sign, value]

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
