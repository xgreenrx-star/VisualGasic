# =============================================================================
# Shop.gd — between-wave shop UI (GDScript CanvasLayer on main scene)
# =============================================================================
# Main.vg shows this after wave_ended. Calls GameManager autoload methods
# (roll_shop_weapons, add_weapon, combine_weapons, etc.). VG scripts use
# PascalCase; GDScript here uses snake_case Godot bindings to the same autoload.
#
# Tabs: weapons (buy/sell/combine), body upgrades, random accessories.
# continue_pressed → Main.OnShopContinue via Connect in Main._Ready.
# =============================================================================
extends CanvasLayer

signal continue_pressed

@onready var wave_label:   Label         = $Panel/VBox/WaveLabel
@onready var mats_label:   Label         = $Panel/VBox/MatsLabel
@onready var tab_weapon_btn: Button      = $Panel/VBox/Tabs/TabWeaponBtn
@onready var tab_body_btn: Button        = $Panel/VBox/Tabs/TabBodyBtn
@onready var tab_item_btn: Button        = $Panel/VBox/Tabs/TabItemBtn
@onready var weapon_section: ScrollContainer = $Panel/VBox/Content/WeaponSection
@onready var body_section: ScrollContainer = $Panel/VBox/Content/BodySection
@onready var item_section: ScrollContainer = $Panel/VBox/Content/ItemSection
@onready var slots_grid:        GridContainer = $Panel/VBox/Content/WeaponSection/WeaponVBox/SlotsGrid
@onready var slots_label:       Label         = $Panel/VBox/Content/WeaponSection/WeaponVBox/SlotsLabel
@onready var shop_weapons_grid: GridContainer = $Panel/VBox/Content/WeaponSection/WeaponVBox/ShopWeaponsGrid
@onready var body_grid:    GridContainer = $Panel/VBox/Content/BodySection/BodyGrid
@onready var item_grid:    GridContainer = $Panel/VBox/Content/ItemSection/ItemGrid
@onready var continue_btn: Button        = $Panel/VBox/Footer/ContinueBtn

const RARITY_COLORS := [
	Color(0.75, 0.75, 0.75),
	Color(0.4, 0.8, 0.4),
	Color(0.4, 0.6, 1.0),
	Color(0.85, 0.5, 1.0),
]

var _current_tab := "weapon"
# Plain Array — VG autoload returns untyped Array, not Array[Dictionary]
var _item_pool: Array = []
var _weapon_offers: Array = []

func _make_icon(path: String, size: int = 40) -> TextureRect:
	var rect := TextureRect.new()
	if path != "" and ResourceLoader.exists(path):
		rect.texture = load(path)
	rect.custom_minimum_size = Vector2(size, size)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rect

func open_shop() -> void:
	mats_label.text = "Materials: %d" % int(GameManager.player_stats["materials"])
	wave_label.text = "Wave %d cleared!" % GameManager.wave
	_build_item_pool()
	_build_weapon_offers()
	_build_body_grid()
	_build_item_grid()
	_build_slots_grid()
	_build_shop_weapons_grid()
	_switch_tab("weapon")
	show()

# --- Tab: Weapons ---
func _build_weapon_offers() -> void:
	_weapon_offers = GameManager.roll_shop_weapons(GameManager.WEAPONS_IN_SHOP)

func _build_slots_grid() -> void:
	for c in slots_grid.get_children(): c.queue_free()
	slots_label.text = "Your weapons (%d / %d)" % [GameManager.player_weapons.size(), GameManager.MAX_WEAPON_SLOTS]
	for i in range(GameManager.MAX_WEAPON_SLOTS):
		if i < GameManager.player_weapons.size():
			_add_owned_slot_card(i, GameManager.player_weapons[i])
		else:
			_add_empty_slot_card()

func _add_owned_slot_card(slot_index: int, weapon: Dictionary) -> void:
	var def: Dictionary = GameManager.get_weapon_def(String(weapon["def_id"]))
	var tier := int(weapon["tier"])
	var tier_color: Color = GameManager.TIER_COLORS[clampi(tier - 1, 0, 3)]
	var eff: Dictionary = GameManager.get_weapon_effective_stats(weapon)

	var card := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(220, 0)

	vbox.add_child(_make_icon(String(def.get("icon", "")), 40))

	var name_lbl := Label.new()
	name_lbl.text = String(def.get("name", "?"))
	name_lbl.add_theme_color_override("font_color", tier_color)
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var tier_lbl := Label.new()
	tier_lbl.text = "Tier %s" % GameManager.TIER_NAMES[tier - 1]
	tier_lbl.add_theme_color_override("font_color", tier_color)
	tier_lbl.add_theme_font_size_override("font_size", 20)
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var stats_lbl := Label.new()
	stats_lbl.text = "%.0f dmg · %.2fs · %dpx" % [
		float(eff.get("damage", 0.0)),
		float(eff.get("cooldown", 0.0)),
		int(eff.get("range", 0.0)),
	]
	stats_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	stats_lbl.add_theme_font_size_override("font_size", 18)

	var combine_btn := Button.new()
	var can_comb: bool = GameManager.can_combine(String(weapon["def_id"]), tier)
	combine_btn.text = "Merge -> Tier %s" % (GameManager.TIER_NAMES[tier] if tier < GameManager.MAX_TIER else "MAX")
	combine_btn.disabled = not can_comb
	combine_btn.pressed.connect(_on_combine_weapon.bind(String(weapon["def_id"]), tier))

	var sell_btn := Button.new()
	var refund: int = GameManager.get_weapon_sell_price(weapon)
	sell_btn.text = "Sell (+%d)" % refund
	sell_btn.pressed.connect(_on_sell_weapon.bind(slot_index))

	vbox.add_child(name_lbl)
	vbox.add_child(tier_lbl)
	vbox.add_child(stats_lbl)
	vbox.add_child(combine_btn)
	vbox.add_child(sell_btn)
	card.add_child(vbox)
	slots_grid.add_child(card)

func _add_empty_slot_card() -> void:
	var card := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(220, 150)
	var lbl := Label.new()
	lbl.text = "— empty —"
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(lbl)
	card.add_child(vbox)
	slots_grid.add_child(card)

func _build_shop_weapons_grid() -> void:
	for c in shop_weapons_grid.get_children(): c.queue_free()
	for offer in _weapon_offers:
		_add_weapon_offer_card(offer)

func _add_weapon_offer_card(offer: Dictionary) -> void:
	var def: Dictionary = GameManager.get_weapon_def(String(offer["def_id"]))
	var tier := int(offer["tier"])
	var tier_color: Color = GameManager.TIER_COLORS[clampi(tier - 1, 0, 3)]
	var cost := int(offer["cost"])

	var card := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(240, 0)

	vbox.add_child(_make_icon(String(def.get("icon", "")), 40))

	var name_lbl := Label.new()
	name_lbl.text = "%s · Tier %s" % [String(def.get("name", "?")), GameManager.TIER_NAMES[tier - 1]]
	name_lbl.add_theme_color_override("font_color", tier_color)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Preview effective stats at this tier
	var preview_eff: Dictionary = GameManager.get_weapon_effective_stats({"def_id": String(def["id"]), "tier": tier})
	var stats_lbl := Label.new()
	stats_lbl.text = "%.0f dmg · %.2fs · %dpx" % [
		float(preview_eff.get("damage", 0.0)),
		float(preview_eff.get("cooldown", 0.0)),
		int(preview_eff.get("range", 0.0)),
	]
	stats_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	stats_lbl.add_theme_font_size_override("font_size", 20)

	var pat_lbl := Label.new()
	pat_lbl.text = "Pattern: %s" % String(def.get("pattern", "?"))
	pat_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	pat_lbl.add_theme_font_size_override("font_size", 18)

	var cost_lbl := Label.new()
	cost_lbl.text = "Price: %d" % cost
	cost_lbl.add_theme_font_size_override("font_size", 20)

	var btn := Button.new()
	btn.text = "Buy"
	var slots_full: bool = GameManager.player_weapons.size() >= GameManager.MAX_WEAPON_SLOTS
	var too_expensive: bool = int(GameManager.player_stats["materials"]) < cost
	if slots_full:
		btn.text = "No slots"
		btn.disabled = true
	elif too_expensive:
		btn.disabled = true
	btn.pressed.connect(_on_buy_weapon.bind(offer, btn))

	vbox.add_child(name_lbl)
	vbox.add_child(pat_lbl)
	vbox.add_child(stats_lbl)
	vbox.add_child(cost_lbl)
	vbox.add_child(btn)
	card.add_child(vbox)
	shop_weapons_grid.add_child(card)

func _on_buy_weapon(offer: Dictionary, _btn: Button) -> void:
	if GameManager.player_weapons.size() >= GameManager.MAX_WEAPON_SLOTS:
		return
	var cost := int(offer["cost"])
	if int(GameManager.player_stats["materials"]) < cost:
		return
	GameManager.player_stats["materials"] -= cost
	GameManager.add_weapon(String(offer["def_id"]), int(offer["tier"]))
	_weapon_offers.erase(offer)
	_refresh_weapon_ui()
	_refresh_body_btns()
	AudioBus.play("buy")

func _on_sell_weapon(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameManager.player_weapons.size():
		return
	var weapon: Dictionary = GameManager.player_weapons[slot_index]
	var refund: int = GameManager.get_weapon_sell_price(weapon)
	GameManager.remove_weapon(slot_index)
	GameManager.player_stats["materials"] += refund
	_refresh_weapon_ui()
	_refresh_body_btns()
	AudioBus.play("buy")

func _on_combine_weapon(def_id: String, tier: int) -> void:
	if not GameManager.combine_weapons(def_id, tier):
		return
	_refresh_weapon_ui()
	AudioBus.play("combine")

func _refresh_weapon_ui() -> void:
	_build_slots_grid()
	_build_shop_weapons_grid()
	mats_label.text = "Materials: %d" % int(GameManager.player_stats["materials"])

# --- Tab: Body upgrades ---
func _build_body_grid() -> void:
	for c in body_grid.get_children(): c.queue_free()
	for upg in GameManager.BODY_UPGRADES:
		_add_body_card(upg)

func _add_body_card(upg: Dictionary) -> void:
	var lvl: int = GameManager.get_body_upgrade_level(upg["id"])
	var maxed: bool = lvl >= int(upg["max_level"])
	var cost_now: int = int(upg["cost"]) + int(lvl * int(upg["cost"]) / 3.0)

	var card := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(220, 0)

	vbox.add_child(_make_icon(String(upg.get("icon", "")), 40))

	var icon_lbl := Label.new()
	icon_lbl.text = upg["name"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 26)

	var desc_lbl := Label.new()
	desc_lbl.text = upg["desc"]
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc_lbl.add_theme_font_size_override("font_size", 20)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD

	var lvl_lbl := Label.new()
	lvl_lbl.text = "Lv. %d / %d" % [lvl, upg["max_level"]]
	lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lvl_lbl.add_theme_font_size_override("font_size", 20)

	var cost_lbl := Label.new()
	cost_lbl.text = "Price: %d" % cost_now if not maxed else "MAX"
	cost_lbl.add_theme_font_size_override("font_size", 20)

	var btn := Button.new()
	btn.text = "Upgrade" if not maxed else "Maxed"
	btn.disabled = maxed or int(GameManager.player_stats["materials"]) < cost_now
	btn.pressed.connect(_on_buy_body.bind(upg, btn, lvl_lbl, cost_lbl))

	vbox.add_child(icon_lbl)
	vbox.add_child(desc_lbl)
	vbox.add_child(lvl_lbl)
	vbox.add_child(cost_lbl)
	vbox.add_child(btn)
	card.add_child(vbox)
	body_grid.add_child(card)

func _on_buy_body(upg: Dictionary, btn: Button, lvl_lbl: Label, cost_lbl: Label) -> void:
	var lvl: int = GameManager.get_body_upgrade_level(upg["id"])
	var cost_now: int = int(upg["cost"]) + int(lvl * int(upg["cost"]) / 3.0)
	if int(GameManager.player_stats["materials"]) < cost_now:
		return
	GameManager.player_stats["materials"] -= cost_now
	GameManager.apply_body_upgrade(upg)
	var new_lvl: int = GameManager.get_body_upgrade_level(upg["id"])
	var maxed: bool = new_lvl >= int(upg["max_level"])
	var new_cost: int = int(upg["cost"]) + int(new_lvl * int(upg["cost"]) / 3.0)
	lvl_lbl.text = "Lv. %d / %d" % [new_lvl, upg["max_level"]]
	cost_lbl.text = "Price: %d" % new_cost if not maxed else "MAX"
	btn.text = "Upgrade" if not maxed else "Maxed"
	btn.disabled = maxed or int(GameManager.player_stats["materials"]) < new_cost
	mats_label.text = "Materials: %d" % int(GameManager.player_stats["materials"])
	_refresh_body_btns()
	# Weapon slot previews may change after damage_pct / range buffs
	_build_slots_grid()
	_build_shop_weapons_grid()
	AudioBus.play("buy")

func _refresh_body_btns() -> void:
	var children := body_grid.get_children()
	var n: int = min(children.size(), GameManager.BODY_UPGRADES.size())
	for i in range(n):
		var card := children[i] as PanelContainer
		if card == null:
			continue
		var vbox := card.get_child(0)
		if vbox == null:
			continue
		var btn := vbox.get_child(vbox.get_child_count() - 1) as Button
		if btn == null:
			continue
		var upg: Dictionary = GameManager.BODY_UPGRADES[i]
		var lvl: int = GameManager.get_body_upgrade_level(upg["id"])
		var cost_now: int = int(upg["cost"]) + int(lvl * int(upg["cost"]) / 3.0)
		var maxed: bool = lvl >= int(upg["max_level"])
		btn.disabled = maxed or int(GameManager.player_stats["materials"]) < cost_now

# --- Tab: Items ---
func _build_item_pool() -> void:
	_item_pool = []
	var pool: Array = []
	for it in GameManager.SHOP_ITEMS:
		if String(it.get("type", "")) == "accessory":
			pool.append(it)
	pool.shuffle()
	var shown := pool.slice(0, 4)
	for item in shown:
		_item_pool.append(item)

func _build_item_grid() -> void:
	for c in item_grid.get_children(): c.queue_free()
	for item in _item_pool:
		_add_item_card(item)

func _add_item_card(item: Dictionary) -> void:
	var rarity: int = item.get("rarity", 0)
	var rarity_color: Color = RARITY_COLORS[clamp(rarity, 0, 3)]

	var card := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(240, 0)

	vbox.add_child(_make_icon(String(item.get("icon", "")), 40))

	var type_lbl := Label.new()
	type_lbl.text = "[Accessory]"
	type_lbl.add_theme_color_override("font_color", rarity_color)
	type_lbl.add_theme_font_size_override("font_size", 18)

	var name_lbl := Label.new()
	name_lbl.text = item["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", rarity_color)
	name_lbl.add_theme_font_size_override("font_size", 26)

	var desc_lbl := Label.new()
	desc_lbl.text = item["desc"]
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc_lbl.add_theme_font_size_override("font_size", 20)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD

	var cost_lbl := Label.new()
	cost_lbl.text = "Price: %d" % int(item["cost"])
	cost_lbl.add_theme_font_size_override("font_size", 20)

	var btn := Button.new()
	btn.text = "Buy"
	btn.disabled = int(GameManager.player_stats["materials"]) < int(item["cost"])
	btn.pressed.connect(_on_buy_item.bind(item, btn))

	vbox.add_child(type_lbl)
	vbox.add_child(name_lbl)
	vbox.add_child(desc_lbl)
	vbox.add_child(cost_lbl)
	vbox.add_child(btn)
	card.add_child(vbox)
	item_grid.add_child(card)

func _on_buy_item(item: Dictionary, btn: Button) -> void:
	var cost: int = int(item["cost"])
	if int(GameManager.player_stats["materials"]) < cost:
		return
	GameManager.player_stats["materials"] -= cost
	GameManager.apply_shop_item(item)
	btn.text = "Purchased"
	btn.disabled = true
	mats_label.text = "Materials: %d" % int(GameManager.player_stats["materials"])
	_refresh_body_btns()
	# Accessories can change max_hp, damage_pct, etc. — refresh weapon previews
	_build_slots_grid()
	_build_shop_weapons_grid()
	AudioBus.play("buy")

# --- Tabs ---
func _switch_tab(tab: String) -> void:
	_current_tab = tab
	weapon_section.visible = (tab == "weapon")
	body_section.visible   = (tab == "body")
	item_section.visible   = (tab == "item")
	tab_weapon_btn.modulate = Color.WHITE if tab == "weapon" else Color(0.6, 0.6, 0.6)
	tab_body_btn.modulate   = Color.WHITE if tab == "body"   else Color(0.6, 0.6, 0.6)
	tab_item_btn.modulate   = Color.WHITE if tab == "item"   else Color(0.6, 0.6, 0.6)

func _on_tab_weapon() -> void:
	_switch_tab("weapon")

func _on_tab_body() -> void:
	_switch_tab("body")

func _on_tab_item() -> void:
	_switch_tab("item")

func _on_continue_pressed() -> void:
	hide()
	continue_pressed.emit()
