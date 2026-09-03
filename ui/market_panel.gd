class_name MarketPanel
extends CanvasLayer

@onready var market_header: Label = %MarketHeader
@onready var company_name_label: Label = %CompanyName
@onready var ticker_label: Label = %Ticker
@onready var price_label: Label = %Price
@onready var variation_label: Label = %Variation
@onready var operations_label: Label = %Operations
@onready var position_title: Label = %PositionTitle
@onready var position_details: Label = %PositionDetails
@onready var position_pnl: Label = %PositionPnL
@onready var short_button: Button = %ShortButton

var _market: MarketService

func _ready() -> void:
	_market = get_tree().get_first_node_in_group("market_service") as MarketService
	short_button.pressed.connect(_on_short_pressed)
	if _market:
		_market.market_updated.connect(_refresh)
		_market.position_opened.connect(_refresh)
	_refresh()

func open_market() -> void:
	visible = true
	_refresh()
	short_button.grab_focus()

func close_market() -> void:
	visible = false
	short_button.release_focus()

func is_open() -> bool:
	return visible

func _on_short_pressed() -> void:
	if _market and _market.open_short(_market.default_short_shares):
		var audio := get_tree().get_first_node_in_group("audio_service")
		if audio and audio.has_method("play_ui"):
			audio.play_ui(&"market_confirm", 0.02)

func _refresh() -> void:
	if _market == null or _market.company == null:
		return
	var company := _market.company
	var accent := company.accent_color
	market_header.text = "MARKET  //  DETERMINISTIC PROTOTYPE"
	company_name_label.text = company.display_name
	ticker_label.text = company.ticker + "  /  MEDICAL MANUFACTURING"
	price_label.text = "$%.2f" % _market.current_price
	price_label.add_theme_color_override("font_color", accent.lightened(0.24))
	var variation := _market.get_variation_percent()
	variation_label.text = _signed_percent(variation)
	variation_label.add_theme_color_override("font_color", Color("c77c60") if variation < -0.005 else Color("d6cdbb"))
	operations_label.text = "CRITICAL SYSTEMS OFFLINE  %d / %d" % [
		_market.destroyed_equipment_count,
		company.sabotage_stage_count(),
	]

	if _market.has_open_position():
		position_title.text = "OPEN POSITION  //  SHORT ×%d" % _market.get_position_shares()
		position_details.text = "ENTRY  $%.2f      CURRENT  $%.2f" % [_market.get_entry_price(), _market.current_price]
		position_pnl.text = "UNREALIZED P&L   %s" % _format_pnl(_market.get_unrealized_pnl())
		position_pnl.add_theme_color_override("font_color", Color("9fc49f") if _market.get_unrealized_pnl() >= 0.0 else Color("c77c60"))
		short_button.disabled = true
		short_button.text = "SHORT POSITION OPEN"
	else:
		position_title.text = "NO OPEN POSITION"
		position_details.text = "ONE POSITION MAXIMUM IN THIS PROTOTYPE"
		position_pnl.text = ""
		short_button.disabled = false
		short_button.text = "SHORT %d SHARES" % _market.default_short_shares

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
