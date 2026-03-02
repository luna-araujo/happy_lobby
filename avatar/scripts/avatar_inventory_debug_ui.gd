class_name AvatarInventoryDebugUi
extends CanvasLayer

@export var inventory_path: NodePath = NodePath("../Inventory")
@export var toggle_action: StringName = &"inventory_debug_toggle"
@export var sample_item_data_path: String = "res://items/beretta/beretta_item_data.tres"
@export var sample_item_quantity: int = 1
@export var money_delta_amount: int = 10
@export var beretta_item_data_path: String = "res://items/beretta/beretta_item_data.tres"
@export var beretta_buy_price: int = 50

var inventory: Inventory
var avatar: Avatar
var _panel_root: PanelContainer
var _player_state_label: RichTextLabel
var _status_label: Label
var _is_active_for_local_player: bool = false


func _ready() -> void:
	layer = 120
	avatar = get_parent() as Avatar
	inventory = get_node_or_null(inventory_path) as Inventory
	_build_ui()
	if inventory != null:
		if not inventory.inventory_changed.is_connected(_refresh_view):
			inventory.inventory_changed.connect(_refresh_view)
		if not inventory.money_changed.is_connected(_on_money_changed):
			inventory.money_changed.connect(_on_money_changed)
	_refresh_view()


func _process(_delta: float) -> void:
	if not _is_panel_visible():
		return
	_refresh_player_state_view()


func _input(event: InputEvent) -> void:
	if not _can_toggle():
		return
	if event.is_action_pressed(toggle_action):
		_set_panel_visible(not _is_panel_visible())
		get_viewport().set_input_as_handled()

func set_local_player_active(active: bool) -> void:
	_is_active_for_local_player = active
	if not active:
		_set_panel_visible(false)


func _build_ui() -> void:
	_panel_root = PanelContainer.new()
	_panel_root.name = "CharacterDebugPanel"
	_panel_root.visible = false
	_panel_root.position = Vector2(24.0, 24.0)
	_panel_root.custom_minimum_size = Vector2(300.0, 280.0)
	add_child(_panel_root)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel_root.add_child(margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	var title: Label = Label.new()
	title.text = "Character Debug"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Status: idle"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_status_label)

	_player_state_label = RichTextLabel.new()
	_player_state_label.fit_content = true
	_player_state_label.scroll_active = false
	_player_state_label.custom_minimum_size = Vector2(270.0, 170.0)
	_player_state_label.text = "Player state: n/a"
	root_vbox.add_child(_player_state_label)

	var buttons_grid: GridContainer = GridContainer.new()
	buttons_grid.columns = 2
	buttons_grid.add_theme_constant_override("h_separation", 8)
	buttons_grid.add_theme_constant_override("v_separation", 8)
	root_vbox.add_child(buttons_grid)

	var add_item_button: Button = Button.new()
	add_item_button.text = "Add Sample Item"
	add_item_button.pressed.connect(_on_add_item_pressed)
	buttons_grid.add_child(add_item_button)

	var remove_item_button: Button = Button.new()
	remove_item_button.text = "Remove Sample Item"
	remove_item_button.pressed.connect(_on_remove_item_pressed)
	buttons_grid.add_child(remove_item_button)

	var add_money_button: Button = Button.new()
	add_money_button.text = "+Money"
	add_money_button.pressed.connect(_on_add_money_pressed)
	buttons_grid.add_child(add_money_button)

	var remove_money_button: Button = Button.new()
	remove_money_button.text = "-Money"
	remove_money_button.pressed.connect(_on_remove_money_pressed)
	buttons_grid.add_child(remove_money_button)

	var grant_beretta_button: Button = Button.new()
	grant_beretta_button.text = "Grant Beretta"
	grant_beretta_button.pressed.connect(_on_grant_beretta_pressed)
	buttons_grid.add_child(grant_beretta_button)

	var buy_beretta_button: Button = Button.new()
	buy_beretta_button.text = "Buy Beretta"
	buy_beretta_button.pressed.connect(_on_buy_beretta_pressed)
	buttons_grid.add_child(buy_beretta_button)

	var equip_beretta_button: Button = Button.new()
	equip_beretta_button.text = "Equip Beretta"
	equip_beretta_button.pressed.connect(_on_equip_beretta_pressed)
	buttons_grid.add_child(equip_beretta_button)

	var unequip_weapon_button: Button = Button.new()
	unequip_weapon_button.text = "Unequip Weapon"
	unequip_weapon_button.pressed.connect(_on_unequip_weapon_pressed)
	buttons_grid.add_child(unequip_weapon_button)

	var drop_beretta_button: Button = Button.new()
	drop_beretta_button.text = "Drop Beretta"
	drop_beretta_button.pressed.connect(_on_drop_beretta_pressed)
	buttons_grid.add_child(drop_beretta_button)


func _refresh_view() -> void:
	if inventory == null:
		if _player_state_label != null:
			_player_state_label.text = "Player state unavailable."
		return

	_refresh_player_state_view()


func _on_money_changed(_new_money: int) -> void:
	_refresh_view()


func _on_add_item_pressed() -> void:
	if inventory == null:
		_set_status("Inventory unavailable.")
		return
	if not _can_mutate_inventory():
		_set_status("Inventory authority denied.")
		return
	inventory.add_item(sample_item_data_path, sample_item_quantity)
	_set_status("Added %s x%d." % [sample_item_data_path, sample_item_quantity])
	_refresh_view()


func _on_remove_item_pressed() -> void:
	if inventory == null:
		_set_status("Inventory unavailable.")
		return
	if not _can_mutate_inventory():
		_set_status("Inventory authority denied.")
		return
	var removed: int = inventory.remove_item(sample_item_data_path, sample_item_quantity)
	_set_status("Removed %s x%d." % [sample_item_data_path, removed])
	_refresh_view()


func _on_add_money_pressed() -> void:
	if inventory == null:
		_set_status("Inventory unavailable.")
		return
	if not _can_mutate_inventory():
		_set_status("Inventory authority denied.")
		return
	var changed: bool = inventory.add_money(money_delta_amount)
	if changed:
		_set_status("Added %d money." % money_delta_amount)
	else:
		_set_status("Money unchanged.")
	_refresh_view()


func _on_remove_money_pressed() -> void:
	if inventory == null:
		_set_status("Inventory unavailable.")
		return
	if not _can_mutate_inventory():
		_set_status("Inventory authority denied.")
		return
	var spent: bool = inventory.spend_money(money_delta_amount)
	if spent:
		_set_status("Spent %d money." % money_delta_amount)
	else:
		_set_status("Not enough money.")
	_refresh_view()


func _on_grant_beretta_pressed() -> void:
	if inventory == null:
		_set_status("Inventory unavailable.")
		return
	if not _can_mutate_inventory():
		_set_status("Inventory authority denied.")
		return
	var granted: bool = inventory.try_grant_item(beretta_item_data_path, 1)
	if granted:
		_set_status("Granted Beretta.")
	else:
		_set_status("Failed to grant Beretta (inventory full?).")
	_refresh_view()


func _on_buy_beretta_pressed() -> void:
	if avatar == null:
		_set_status("Avatar unavailable.")
		return
	var bought: bool = avatar.try_buy_beretta(beretta_buy_price)
	if bought:
		_set_status("Bought Beretta for %d." % beretta_buy_price)
	else:
		_set_status("Buy failed (money/space/authority).")
	_refresh_view()


func _on_equip_beretta_pressed() -> void:
	if avatar == null:
		_set_status("Avatar unavailable.")
		return
	var equipped: bool = avatar.equip_beretta()
	if equipped:
		_set_status("Beretta equipped.")
	else:
		_set_status("Equip failed (missing item?).")
	_refresh_view()


func _on_unequip_weapon_pressed() -> void:
	if avatar == null:
		_set_status("Avatar unavailable.")
		return
	avatar.unequip_weapon()
	_set_status("Weapon unequipped.")
	_refresh_view()


func _on_drop_beretta_pressed() -> void:
	if avatar == null:
		_set_status("Avatar unavailable.")
		return
	var dropped: bool = avatar.try_drop_beretta()
	if dropped:
		_set_status("Dropped Beretta.")
	else:
		_set_status("Drop failed (not in inventory?).")
	_refresh_view()


func _is_panel_visible() -> bool:
	if _panel_root == null:
		return false
	return _panel_root.visible


func _set_panel_visible(is_visible: bool) -> void:
	if _panel_root == null:
		return
	_panel_root.visible = is_visible
	if is_visible:
		_refresh_view()


func _can_toggle() -> bool:
	if _is_active_for_local_player:
		return true
	if avatar == null:
		return false
	return avatar._is_local_controlled()


func _can_mutate_inventory() -> bool:
	if avatar == null:
		return false
	if avatar.multiplayer.is_server():
		return true
	return avatar._is_local_controlled()


func _set_status(message: String) -> void:
	if _status_label == null:
		return
	_status_label.text = "Status: %s" % message


func _refresh_player_state_view() -> void:
	if _player_state_label == null:
		return
	if avatar == null or not is_instance_valid(avatar):
		_player_state_label.text = "Player state unavailable."
		return

	var is_local: bool = avatar._is_local_controlled()
	var is_server: bool = avatar.multiplayer.is_server()
	var movement_auth: bool = false
	if avatar.movement_body != null and is_instance_valid(avatar.movement_body):
		movement_auth = avatar.movement_body.is_multiplayer_authority()

	var combat_state_name: String = "n/a"
	var hp_text: String = "n/a"
	var can_act_text: String = "n/a"
	var melee_state_text: String = "n/a"
	var parry_cd_text: String = "n/a"
	if avatar.combat != null:
		combat_state_name = _combat_state_name(avatar.combat.state)
		hp_text = "%d/%d" % [avatar.combat.hp, avatar.combat.max_hp]
		can_act_text = str(avatar.combat.can_act())
		melee_state_text = str(avatar.combat.is_melee_state())
		parry_cd_text = "%.2fs" % avatar.combat.get_parry_cooldown_remaining()

	var equipped_item_id: String = "n/a"
	var gun_aiming: String = "n/a"
	var aim_target_text: String = "n/a"
	if avatar.gun_controller != null:
		equipped_item_id = avatar.gun_controller.get_equipped_item_id()
		gun_aiming = str(avatar.gun_controller.is_aiming())
		aim_target_text = str(avatar.gun_controller.get_aim_target_position())

	_player_state_label.text = "\n".join([
		"Player State",
		"PlayerID: %d | Local: %s | Server: %s | MoveAuth: %s" % [avatar.player_id, str(is_local), str(is_server), str(movement_auth)],
		"Combat: %s | HP: %s | CanAct: %s | MeleeState: %s | ParryCD: %s" % [combat_state_name, hp_text, can_act_text, melee_state_text, parry_cd_text],
		"Gun: equipped=%s | aiming=%s" % [equipped_item_id, gun_aiming],
		"AimTarget: %s" % aim_target_text,
		"Sync: net_state=%s | net_hp=%d/%d | net_money=%d" % [
			_combat_state_name(avatar.network_combat_state),
			avatar.network_hp,
			avatar.network_max_hp,
			avatar.network_inventory_money
		],
		"Sync: slots_json_len=%d" % avatar.network_inventory_slots_json.length()
	])


func _combat_state_name(state_value: int) -> String:
	match state_value:
		CharacterCombat.CombatState.READY:
			return "READY"
		CharacterCombat.CombatState.QUICK_MELEE:
			return "QUICK_MELEE"
		CharacterCombat.CombatState.HEAVY_MELEE:
			return "HEAVY_MELEE"
		CharacterCombat.CombatState.PARRYING:
			return "PARRYING"
		CharacterCombat.CombatState.STUNNED:
			return "STUNNED"
		CharacterCombat.CombatState.DEAD:
			return "DEAD"
	return "UNKNOWN(%d)" % state_value
