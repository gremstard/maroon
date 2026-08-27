class_name Hud extends CanvasLayer
# Health/hunger, hotbar, inventory readout, crafting panel, day clock,
# and the goal ladder — there is always a next goal.

var player: Player
var hp_bar: ColorRect
var hunger_bar: ColorRect
var inv_label: Label
var goal_label: Label
var clock_label: Label
var msg_label: Label
var pickup_label: Label
var hotbar: HBoxContainer
var craft_panel: PanelContainer
var msg_timer := 0.0
var pickup_timer := 0.0
var goals_done := 0

var goals: Array = []

func setup(p: Player) -> void:
	player = p
	goals = [
		["Pick up 2 fallen branches", func(): return player.total_gathered.get("branch", 0) >= 2],
		["Pull fiber from dry grass (4)", func(): return player.total_gathered.get("fiber", 0) >= 4],
		["Twist String, then craft a Crude Axe (Tab)", func(): return player.crafted.has("crude_axe")],
		["Chop 10 Wood", func(): return player.total_gathered.get("wood", 0) >= 10],
		["Craft a Crude Pick, mine 8 Stone", func(): return player.crafted.has("crude_pick") and player.total_gathered.get("stone", 0) >= 8],
		["Craft a Campfire; hunt a deer, cook its meat (E)", func(): return player.events.get("cooked", 0) >= 1],
		["Craft a Fishing Rod — cast into a pond or the sea", func(): return player.total_gathered.get("raw_fish", 0) + player.total_gathered.get("moonfin", 0) >= 1],
		["Weave fiber clothes (any piece)", func(): return player.equipment.size() >= 1],
		["Find the shipwreck on the coast — loot its crates", func(): return player.events.get("looted_wreck", 0) >= 1],
		["Build a Claim Totem — protect your home", func(): return player.crafted.has("totem")],
		["Feed the totem 10 wood (E on totem)", func(): return player.events.get("deposited", 0) >= 10],
		["Raise 4 walls inside your claim", func(): return player.events.get("wall_built", 0) >= 4],
		["Slay a night wolf", func(): return player.events.get("kill_wolf", 0) >= 1],
		["The journal speaks of a homestead inland —\n  take the Rusted Key from a wolf", func(): return player.total_gathered.get("rusted_key", 0) >= 1],
		["Find the Ruins — open the locked chest", func(): return player.events.get("opened_ruins", 0) >= 1],
		["Skin your kills — craft a Hide Coat", func(): return player.crafted.has("hide_coat")],
		["Mine 3 Iron Ore in the highlands (Stone Pick)", func(): return player.total_gathered.get("iron_ore", 0) >= 3],
		["Build a Forge (20 stone, 10 wood)", func(): return player.crafted.has("forge")],
		["Smelt an Iron Bar at the forge", func(): return player.crafted.has("iron_bar")],
		["Forge an iron weapon or tool", func(): return player.crafted.has("iron_spear") or player.crafted.has("iron_axe") or player.crafted.has("iron_pick")],
		["Craft a Torch (branch + 2 fiber)", func(): return player.crafted.has("torch")],
		["Find the Sea Cave beneath the far cliffs", func(): return player.events.get("entered_cave", 0) >= 1],
		["Mine a Moonstone — torchlight keeps the dweller back", func(): return player.total_gathered.get("moonstone", 0) >= 1],
		["Build a Raft — the moonstone guides you through the reef", func(): return player.crafted.has("raft")],
		["Sail beyond the reef to the Far Isle", func(): return player.events.get("entered_far_isle", 0) >= 1],
		["Awaken the Monolith (3 moonstones, E)", func(): return player.events.get("monolith_awakened", 0) >= 1],
		["Craft a Signal Beacon (the lens, iron, wood)", func(): return player.crafted.has("beacon")],
		["Light the beacon at the island's peak", func(): return player.events.get("beacon_lit", 0) >= 1],
		["Something circles the wreck.\n  Slay the Leviathan", func(): return player.events.get("kill_leviathan", 0) >= 1],
		["Forge Scale Armor from the Leviathan's hide", func(): return player.crafted.has("scale_chest")],
		["The monolith has opened the way.\n  Descend into the Depths", func(): return player.events.get("entered_depths", 0) >= 1],
		["Mine 3 Heartstone (iron pick, torches up)", func(): return player.total_gathered.get("heartstone", 0) >= 3],
		["Restore the Heart of the Island", func(): return player.events.get("heart_restored", 0) >= 1],
		["Survive to Day 3", func(): return _world() != null and _world().day >= 3],
	]
	_build()

func _world() -> World:
	return get_node_or_null("/root/Main/World") as World

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# crosshair
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.modulate = Color(1, 1, 1, 0.7)
	root.add_child(cross)

	# bottom-left: bars + inventory
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(16, -140)
	bl.add_theme_constant_override("separation", 6)
	root.add_child(bl)

	hp_bar = _bar(bl, "HP", Color(0.85, 0.25, 0.2))
	hunger_bar = _bar(bl, "Food", Color(0.9, 0.65, 0.2))
	inv_label = Label.new()
	inv_label.add_theme_font_size_override("font_size", 12)
	inv_label.modulate = Color(1, 1, 1, 0.8)
	bl.add_child(inv_label)

	# top-right: goal ladder
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-360, 12)
	tr.custom_minimum_size = Vector2(344, 0)
	root.add_child(tr)
	var gt := Label.new()
	gt.text = "— GOAL —"
	gt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gt.modulate = Color(1, 0.9, 0.5)
	tr.add_child(gt)
	goal_label = Label.new()
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tr.add_child(goal_label)

	# top-left: clock
	clock_label = Label.new()
	clock_label.position = Vector2(16, 12)
	root.add_child(clock_label)

	# center messages
	msg_label = Label.new()
	msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_label.position.y = 90
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(msg_label)

	_dmg_overlay = ColorRect.new()
	_dmg_overlay.color = Color(0.8, 0.05, 0.05, 0.0)
	_dmg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dmg_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dmg_overlay)

	pickup_label = Label.new()
	pickup_label.set_anchors_preset(Control.PRESET_CENTER)
	pickup_label.position.y = 40
	pickup_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pickup_label.modulate = Color(0.7, 1.0, 0.7)
	root.add_child(pickup_label)

	# bottom-center: hotbar
	hotbar = HBoxContainer.new()
	hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.position.y = -46
	hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 6)
	root.add_child(hotbar)
	for i in Player.HOTBAR_SLOTS:
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(120, 34)
		var l := Label.new()
		l.text = "%d —" % (i + 1)
		l.add_theme_font_size_override("font_size", 13)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pc.add_child(l)
		hotbar.add_child(pc)
		hotbar_labels.append(l)

	# pack + crafting screen (Tab)
	craft_panel = PanelContainer.new()
	craft_panel.set_anchors_preset(Control.PRESET_CENTER)
	craft_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	craft_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	craft_panel.visible = false
	root.add_child(craft_panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	craft_panel.add_child(columns)
	_build_pack_panel(columns)
	container_box = VBoxContainer.new()
	container_box.custom_minimum_size = Vector2(250, 0)
	container_box.add_theme_constant_override("separation", 6)
	container_box.visible = false
	columns.add_child(container_box)
	smelter_box = VBoxContainer.new()
	smelter_box.custom_minimum_size = Vector2(250, 0)
	smelter_box.add_theme_constant_override("separation", 6)
	smelter_box.visible = false
	columns.add_child(smelter_box)
	craft_list_box = VBoxContainer.new()
	craft_list_box.visible = false
	var cv := craft_list_box
	cv.custom_minimum_size = Vector2(560, 0)
	columns.add_child(cv)
	var ct := Label.new()
	ct.text = "CRAFTING  (C to toggle — ⚒ needs a forge, ⚙ a workbench)"
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(ct)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	cv.add_child(grid)
	for recipe in GameItems.RECIPES:
		var b := Button.new()
		var station := GameItems.station_for(recipe)
		var prefix := "⚒ " if station == "forge" else ("⚙ " if station == "workbench" else "")
		b.text = "%s%s  —  %s" % [prefix, GameItems.nice(recipe), GameItems.cost_text(recipe)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 13)
		if recipe in GameItems.CLOTHES:
			b.add_theme_color_override("font_color", GameItems.TIER_COLORS[GameItems.CLOTHES[recipe]["tier"]])
		b.pressed.connect(func() -> void: player.craft(recipe))
		grid.add_child(b)

func _bar(parent: Node, label_text: String, color: Color) -> ColorRect:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(44, 0)
	l.add_theme_font_size_override("font_size", 13)
	h.add_child(l)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.5)
	back.custom_minimum_size = Vector2(180, 14)
	h.add_child(back)
	var bar := ColorRect.new()
	bar.color = color
	bar.size = Vector2(180, 14)
	back.add_child(bar)
	return bar

# ---------------------------------------------------------------- pack grid UI

const CELL_PX := 56
var pack_grid_area: Control
var pack_hint: Label
var pack_hotbar_labels: Array[Label] = []
var _carry_idx := -1
var _pack_refresh := 0.0

func _build_pack_panel(parent: Node) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	parent.add_child(v)
	var t := Label.new()
	t.text = "YOUR PACK"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var craft_btn := Button.new()
	craft_btn.text = "Crafting  (C)"
	craft_btn.pressed.connect(toggle_craft_list)
	v.add_child(craft_btn)
	pack_grid_area = Control.new()
	pack_grid_area.custom_minimum_size = Vector2(Player.GRID_COLS * CELL_PX, 4 * CELL_PX)
	pack_grid_area.gui_input.connect(_on_pack_input)
	v.add_child(pack_grid_area)
	pack_hint = Label.new()
	pack_hint.add_theme_font_size_override("font_size", 11)
	pack_hint.modulate = Color(1, 1, 1, 0.55)
	pack_hint.text = "click: pick up a stack · click a cell: move it\nclick a hotbar slot: bind it (right-click slot: unbind)"
	v.add_child(pack_hint)
	var drop := Button.new()
	drop.text = "DROP carried stack"
	drop.pressed.connect(func() -> void:
		if _carry_idx >= 0 and _carry_idx < player.grid_stacks.size():
			var s: Dictionary = player.grid_stacks[_carry_idx]
			player.inv[s["item"]] = maxi(player.inv.get(s["item"], 0) - int(s["count"]), 0)
			player.reconcile_grid()
			_carry_idx = -1
			_refresh_pack())
	v.add_child(drop)
	var hb_row := HBoxContainer.new()
	hb_row.add_theme_constant_override("separation", 6)
	v.add_child(hb_row)
	for i in Player.HOTBAR_SLOTS:
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(104, 40)
		slot_btn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_LEFT and _carry_idx >= 0:
					var s2: Dictionary = player.grid_stacks[_carry_idx]
					player.set_hotbar(i, s2["item"])
					_carry_idx = -1
					_refresh_pack()
				elif ev.button_index == MOUSE_BUTTON_RIGHT:
					player.set_hotbar(i, "")
					_refresh_pack())
		hb_row.add_child(slot_btn)
		slot_btn.name = "hbslot_%d" % i
	_tool_chip_row(v)

func _tool_chip_row(v: VBoxContainer) -> void:
	# tools aren't stacks — bind them from this row
	var chips := HFlowContainer.new()
	chips.name = "ToolChips"
	v.add_child(chips)

func _refresh_pack() -> void:
	if pack_grid_area == null or player == null:
		return
	for c in pack_grid_area.get_children():
		c.queue_free()
	var rows := player.grid_rows()
	pack_grid_area.custom_minimum_size.y = rows * CELL_PX
	for y in rows:
		for x in Player.GRID_COLS:
			var cell := ColorRect.new()
			cell.color = Color(1, 1, 1, 0.06)
			cell.position = Vector2(x * CELL_PX + 1, y * CELL_PX + 1)
			cell.size = Vector2(CELL_PX - 2, CELL_PX - 2)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pack_grid_area.add_child(cell)
	var overflow_i := 0
	for i in player.grid_stacks.size():
		var s: Dictionary = player.grid_stacks[i]
		var tile := ColorRect.new()
		var c := GameItems.icon_color(s["item"])
		tile.color = c if i != _carry_idx else c.lightened(0.35)
		if s["x"] >= 0:
			tile.position = Vector2(s["x"] * CELL_PX + 3, s["y"] * CELL_PX + 3)
			tile.size = Vector2(s["w"] * CELL_PX - 6, s["h"] * CELL_PX - 6)
		else:
			tile.position = Vector2(overflow_i * CELL_PX + 3, rows * CELL_PX + 8)
			tile.size = Vector2(CELL_PX - 6, CELL_PX - 6)
			tile.color = Color(0.7, 0.2, 0.2)
			overflow_i += 1
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lab := Label.new()
		lab.text = "%s\n×%d" % [GameItems.nice(s["item"]), s["count"]]
		lab.add_theme_font_size_override("font_size", 10)
		lab.position = Vector2(4, 2)
		tile.add_child(lab)
		pack_grid_area.add_child(tile)
	# hotbar slot buttons + tool chips
	var panel_v := pack_grid_area.get_parent()
	for i in Player.HOTBAR_SLOTS:
		var btn: Button = panel_v.find_child("hbslot_%d" % i, true, false)
		if btn:
			var it: String = player.hotbar_items[i]
			btn.text = "%d %s" % [i + 1, GameItems.nice(it) if it != "" else "—"]
	var chips: HFlowContainer = panel_v.find_child("ToolChips", true, false)
	if chips:
		for c in chips.get_children():
			c.queue_free()
		var bindables: Array = player.owned_tools.keys()
		for extra in ["torch", "cooked_meat", "berries"]:
			if player.inv.get(extra, 0) > 0:
				bindables.append(extra)
		for tool in bindables:
			var chip := Button.new()
			chip.text = GameItems.nice(tool)
			chip.add_theme_font_size_override("font_size", 11)
			chip.pressed.connect(func() -> void:
				player._auto_hotbar(tool)
				_refresh_pack())
			chips.add_child(chip)

var ctx_menu: PanelContainer = null

func _stack_at(cell: Vector2i) -> int:
	for i in player.grid_stacks.size():
		var s: Dictionary = player.grid_stacks[i]
		if s["x"] >= 0 and cell.x >= s["x"] and cell.x < s["x"] + s["w"] \
				and cell.y >= s["y"] and cell.y < s["y"] + s["h"]:
			return i
	return -1

func _open_context(idx: int, at: Vector2) -> void:
	if ctx_menu:
		ctx_menu.queue_free()
	var s: Dictionary = player.grid_stacks[idx]
	var item: String = s["item"]
	ctx_menu = PanelContainer.new()
	ctx_menu.position = at + Vector2(8, -8)
	get_child(0).add_child(ctx_menu)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(230, 0)
	v.add_theme_constant_override("separation", 6)
	ctx_menu.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var swatch := ColorRect.new()
	swatch.color = GameItems.icon_color(item)
	swatch.custom_minimum_size = Vector2(42, 42)
	head.add_child(swatch)
	var nm := Label.new()
	nm.text = "%s  ×%d" % [GameItems.nice(item), s["count"]]
	head.add_child(nm)
	var desc := Label.new()
	desc.text = GameItems.describe(item)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(230, 0)
	desc.add_theme_font_size_override("font_size", 12)
	desc.modulate = Color(1, 1, 1, 0.7)
	v.add_child(desc)
	var close := func() -> void:
		if ctx_menu:
			ctx_menu.queue_free()
			ctx_menu = null
	if item in GameItems.CLOTHES:
		var wear := Button.new()
		wear.text = "Wear"
		wear.pressed.connect(func() -> void:
			player.equipment[GameItems.CLOTHES[item]["gear_slot"]] = item
			player.rx_equip.rpc(player.equipment)
			flash("Wearing %s." % GameItems.nice(item))
			close.call()
			_refresh_pack())
		v.add_child(wear)
	if item in GameItems.PLACEABLES or GameItems.hotbar_eligible(item) or item == "lock":
		var hold := Button.new()
		hold.text = "Hold"
		hold.pressed.connect(func() -> void:
			player.hold_item(item)
			close.call())
		v.add_child(hold)
	if GameItems.hotbar_eligible(item):
		var bind := Button.new()
		bind.text = "Bind to hotbar"
		bind.pressed.connect(func() -> void:
			player._auto_hotbar(item)
			close.call()
			_refresh_pack())
		v.add_child(bind)
	var drop := Button.new()
	drop.text = "Drop stack"
	drop.pressed.connect(func() -> void:
		player.inv[item] = maxi(player.inv.get(item, 0) - int(s["count"]), 0)
		player.reconcile_grid()
		close.call()
		_refresh_pack())
	v.add_child(drop)

func _on_pack_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed):
		return
	if ctx_menu:
		ctx_menu.queue_free()
		ctx_menu = null
	if ev.button_index == MOUSE_BUTTON_RIGHT:
		var rcell := Vector2i(int(ev.position.x / CELL_PX), int(ev.position.y / CELL_PX))
		var ridx := _stack_at(rcell)
		if ridx >= 0:
			_open_context(ridx, pack_grid_area.global_position + ev.position)
		return
	if ev.button_index != MOUSE_BUTTON_LEFT:
		return
	var cell := Vector2i(int(ev.position.x / CELL_PX), int(ev.position.y / CELL_PX))
	if container_open != "" and _container_node() != null and _carry_idx < 0:
		var sidx := _stack_at(cell)
		if sidx >= 0:
			_stash(sidx)
			return
	if _carry_idx >= 0 and _carry_idx < player.grid_stacks.size():
		var s: Dictionary = player.grid_stacks[_carry_idx]
		if player._cell_free(cell.x, cell.y, s["w"], s["h"], _carry_idx):
			s["x"] = cell.x
			s["y"] = cell.y
			_carry_idx = -1
		else:
			flash("That doesn't fit there.")
		_refresh_pack()
		return
	for i in player.grid_stacks.size():
		var s2: Dictionary = player.grid_stacks[i]
		if s2["x"] >= 0 and cell.x >= s2["x"] and cell.x < s2["x"] + s2["w"] \
				and cell.y >= s2["y"] and cell.y < s2["y"] + s2["h"]:
			_carry_idx = i
			_refresh_pack()
			return

var craft_list_box: VBoxContainer = null
var container_box: VBoxContainer = null
var container_open := ""

func open_container(sname: String) -> void:
	container_open = sname
	if not craft_panel.visible:
		toggle_craft()
	_refresh_container()

func _container_node() -> Node:
	var w := _world()
	if w == null or container_open == "" or not w.get_node("Structures").has_node(container_open):
		return null
	return w.get_node("Structures").get_node(container_open)

func _refresh_container() -> void:
	if container_box == null:
		return
	for c in container_box.get_children():
		c.queue_free()
	var node := _container_node()
	container_box.visible = node != null
	if node == null:
		return
	var kind: String = node.get_meta("kind")
	var store: Dictionary = node.get_meta("store")
	var cap: int = GameItems.CONTAINERS[kind] * 4
	var t := Label.new()
	t.text = "%s — %d/%d stacks" % [GameItems.nice(kind).to_upper(), _world().container_stacks_used(store), cap]
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container_box.add_child(t)
	var hint := Label.new()
	hint.text = "click your stacks to stash · click below to take"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.55)
	container_box.add_child(hint)
	if store.is_empty():
		var e := Label.new()
		e.text = "(empty)"
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.modulate = Color(1, 1, 1, 0.4)
		container_box.add_child(e)
	for item in store:
		var b := Button.new()
		b.text = "%s  ×%d   — take" % [GameItems.nice(item), store[item]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", GameItems.icon_color(item).lightened(0.4))
		var it := String(item)
		b.pressed.connect(func() -> void:
			_world().sv_container_take.rpc_id(1, container_open, it)
			Sfx.play(self, "pickup", -10.0))
		container_box.add_child(b)

func _stash(idx: int) -> void:
	var node := _container_node()
	if node == null:
		return
	var s: Dictionary = player.grid_stacks[idx]
	var kind: String = node.get_meta("kind")
	var store: Dictionary = node.get_meta("store")
	var after := store.duplicate()
	after[s["item"]] = int(after.get(s["item"], 0)) + int(s["count"])
	if _world().container_stacks_used(after) > GameItems.CONTAINERS[kind] * 4:
		flash("The %s is full." % GameItems.nice(kind))
		return
	player.inv[s["item"]] = maxi(player.inv.get(s["item"], 0) - int(s["count"]), 0)
	_world().sv_container_put.rpc_id(1, container_open, s["item"], int(s["count"]))
	player.reconcile_grid()
	Sfx.play(self, "place", -12.0)
	_refresh_pack()

var smelter_box: VBoxContainer = null
var smelter_open := ""

func open_smelter(sname: String) -> void:
	smelter_open = sname
	if not craft_panel.visible:
		toggle_craft()
	_refresh_smelter()

func _smelter_node() -> Node:
	var w := _world()
	if w == null or smelter_open == "" or not w.get_node("Structures").has_node(smelter_open):
		return null
	return w.get_node("Structures").get_node(smelter_open)

func _refresh_smelter() -> void:
	if smelter_box == null:
		return
	for c in smelter_box.get_children():
		c.queue_free()
	var node := _smelter_node()
	smelter_box.visible = node != null
	if node == null:
		return
	var kind: String = node.get_meta("kind")
	var fuel: int = node.get_meta("fuel", 0)
	var burning: bool = node.get_meta("burning", false)
	var ready_t: float = node.get_meta("ready_t", 0.0)
	var out: Dictionary = node.get_meta("out", {})
	var t := Label.new()
	t.text = "%s — fuel: %d wood" % [GameItems.nice(kind).to_upper(), fuel]
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	smelter_box.add_child(t)
	var load_btn := Button.new()
	var can_load: int = mini(player.inv.get("wood", 0), 10)
	load_btn.text = "Load %d wood" % can_load
	load_btn.disabled = can_load <= 0
	load_btn.pressed.connect(func() -> void:
		player.inv["wood"] -= can_load
		_world().sv_smelter_load.rpc_id(1, smelter_open, can_load)
		_refresh_smelter())
	smelter_box.add_child(load_btn)
	if kind == "furnace":
		var warn := Label.new()
		warn.text = "Watch it. Pull each batch or it's ash.\nEsc doesn't put fires out."
		warn.add_theme_font_size_override("font_size", 11)
		warn.modulate = Color(1, 0.8, 0.6)
		smelter_box.add_child(warn)
		if ready_t > 0.0:
			var pull := Button.new()
			pull.text = "⚠ PULL THE BATCH (%.1fs)" % ready_t
			pull.modulate = Color(1.0, 0.7, 0.3)
			pull.pressed.connect(func() -> void:
				_world().sv_furnace_pull.rpc_id(1, smelter_open)
				Sfx.play(self, "pickup", -4.0))
			smelter_box.add_child(pull)
		elif burning:
			var bar := ProgressBar.new()
			bar.min_value = 0
			bar.max_value = _world().BATCH_TIME
			bar.value = float(node.get_meta("batch_t", 0.0))
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 16)
			smelter_box.add_child(bar)
			var off := Button.new()
			off.text = "Put it out"
			off.pressed.connect(func() -> void:
				_world().sv_furnace_light.rpc_id(1, smelter_open, false))
			smelter_box.add_child(off)
		else:
			var light := Button.new()
			light.text = "Light it (2 wood/batch)"
			light.disabled = fuel < 2
			light.pressed.connect(func() -> void:
				_world().sv_furnace_light.rpc_id(1, smelter_open, true))
			smelter_box.add_child(light)
	else:   # range: set it and forget it
		var target: int = node.get_meta("target", 0)
		if target > 0:
			var cooking := Label.new()
			cooking.text = "Cooking… %d to go. Walk away, it's fine." % target
			cooking.add_theme_font_size_override("font_size", 12)
			smelter_box.add_child(cooking)
		else:
			for n in [2, 5, 10]:
				var go := Button.new()
				go.text = "Smelt %d (perfect, unattended)" % n
				go.disabled = fuel < n
				var nn: int = n
				go.pressed.connect(func() -> void:
					_world().sv_range_start.rpc_id(1, smelter_open, nn))
				smelter_box.add_child(go)
	if not out.is_empty():
		var parts: PackedStringArray = []
		for k in out:
			parts.append("%d %s" % [out[k], GameItems.nice(k)])
		var collect := Button.new()
		collect.text = "Collect: " + ", ".join(parts)
		collect.pressed.connect(func() -> void:
			_world().sv_smelter_collect.rpc_id(1, smelter_open)
			Sfx.play(self, "pickup", -6.0))
		smelter_box.add_child(collect)

func toggle_craft_list() -> void:
	if not craft_panel.visible:
		toggle_craft()
	craft_list_box.visible = not craft_list_box.visible

var _end_overlay: Control = null

func _big_overlay(bg: Color, title: String, sub: String) -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rect := ColorRect.new()
	rect.color = bg
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(rect)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	o.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := Label.new()
	s.text = sub
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.modulate = Color(1, 1, 1, 0.75)
	v.add_child(s)
	get_child(0).add_child(o)
	return o

func show_sealed() -> void:
	if _end_overlay:
		return
	_end_overlay = _big_overlay(Color(0.03, 0.02, 0.04, 0.93),
		"THE ISLAND TAKES BACK ITS OWN",
		"The last totem is ash. The way in is sealed.\nYour works remain — you will never see them again.\n\nThis world is over. (Esc → quit; the save stays as a tomb.)")

func show_the_end() -> void:
	if _end_overlay:
		return
	_end_overlay = _big_overlay(Color(0.35, 0.22, 0.05, 0.85),
		"T H E   E N D",
		"Seven trials. Every wave broken on your walls.\nThe island yields — truly, permanently peaceful.\nBuild. Sail. Fish. It's yours now.")
	Sfx.play(self, "chime", 4.0)
	var tw := create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(_end_overlay, "modulate:a", 0.0, 2.0)
	tw.tween_callback(func() -> void:
		if _end_overlay:
			_end_overlay.queue_free()
			_end_overlay = null)

var pause_panel: PanelContainer = null

func toggle_pause() -> void:
	if pause_panel == null:
		pause_panel = PanelContainer.new()
		pause_panel.set_anchors_preset(Control.PRESET_CENTER)
		get_child(0).add_child(pause_panel)
		var v := VBoxContainer.new()
		v.custom_minimum_size = Vector2(240, 0)
		v.add_theme_constant_override("separation", 8)
		pause_panel.add_child(v)
		var t := Label.new()
		t.text = "— PAUSED —\n(the island keeps going)"
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var resume := Button.new()
		resume.text = "Resume"
		resume.pressed.connect(toggle_pause)
		v.add_child(resume)
		var to_menu := Button.new()
		to_menu.text = "Save & Quit to Menu"
		to_menu.pressed.connect(func() -> void:
			var main: Node = _world().get_parent()
			pause_panel.visible = false
			main.return_to_menu())
		v.add_child(to_menu)
		var quit := Button.new()
		quit.text = "Save & Quit Game"
		quit.pressed.connect(func() -> void:
			var w: World = _world()
			w.save_now()
			for p in w.get_node("Players").get_children():
				p.save_local()
			get_tree().quit())
		v.add_child(quit)
		pause_panel.visible = false
	pause_panel.visible = not pause_panel.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause_panel.visible else Input.MOUSE_MODE_CAPTURED
	if craft_panel.visible and pause_panel.visible:
		craft_panel.visible = false

func toggle_craft() -> void:
	craft_panel.visible = not craft_panel.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if craft_panel.visible else Input.MOUSE_MODE_CAPTURED
	_carry_idx = -1
	if craft_panel.visible:
		player.reconcile_grid()
		_refresh_pack()
	else:
		container_open = ""
		if container_box:
			container_box.visible = false
		smelter_open = ""
		if smelter_box:
			smelter_box.visible = false

var _dmg_overlay: ColorRect
var _was_night := false
var hotbar_labels: Array[Label] = []

func _slot_status(item: String) -> Array:
	# [available: bool, extra_text: String] — the hotbar never lies about
	# what you actually have.
	if item == "":
		return [true, ""]
	if GameItems.TOOL_STATS.has(item) or item == "hammer":
		return [player.owned_tools.has(item), ""]
	var c: int = player.inv.get(item, 0)
	return [c > 0, " ×%d" % c if c > 0 else ""]

func damage_flash() -> void:
	if _dmg_overlay == null:
		return
	_dmg_overlay.color.a = 0.32
	var tw := create_tween()
	tw.tween_property(_dmg_overlay, "color:a", 0.0, 0.45)

func flash(text: String, pickup := false) -> void:
	if pickup:
		pickup_label.text = text
		pickup_timer = 1.5
	else:
		msg_label.text = text
		msg_timer = 3.5

func _process(delta: float) -> void:
	if player == null:
		return
	hp_bar.size.x = 180.0 * clampf(player.hp / 100.0, 0, 1)
	hunger_bar.size.x = 180.0 * clampf(player.hunger / 100.0, 0, 1)

	for i in hotbar_labels.size():
		var item: String = player.hotbar_items[i]
		var st := _slot_status(item)
		hotbar_labels[i].text = "%d %s%s" % [i + 1, GameItems.nice(item) if item != "" else "—", st[1]]
		var col := Color(1, 1, 0.5) if i == player.selected_slot else Color(1, 1, 1)
		hotbar_labels[i].modulate = col if st[0] else Color(col.r, col.g, col.b, 0.32)

	_pack_refresh += delta
	if craft_panel.visible and _pack_refresh >= 0.4:
		_pack_refresh = 0.0
		_refresh_pack()
		if container_open != "":
			var cn := _container_node()
			if cn == null or cn.global_position.distance_to(player.global_position) > 5.0:
				container_open = ""
				container_box.visible = false
			else:
				_refresh_container()
		if smelter_open != "":
			var sn := _smelter_node()
			if sn == null or sn.global_position.distance_to(player.global_position) > 5.0:
				smelter_open = ""
				smelter_box.visible = false
			else:
				_refresh_smelter()

	# compact status: essentials only — the pack (Tab) holds the details
	var key_res: PackedStringArray = []
	for item in ["wood", "stone", "fiber", "string", "berries"]:
		if player.inv.get(item, 0) > 0:
			key_res.append("%s %d" % [GameItems.nice(item), player.inv[item]])
	var over := player.weight_mult() < 1.0
	var line2 := "Armor %d%% · Carry %d/%d%s" % [
		int(player.armor_total() * 100), player.carry_weight(), player.carry_cap(),
		" · OVERLOADED" if over else ""]
	var build_line := ""
	if player.held_item() == "hammer" and player.owned_tools.has("hammer"):
		var piece := player.build_piece_name()
		build_line = "\n%s — %d wood · scroll piece · R rotate · E repair · X demolish" % [
			GameItems.nice(piece), GameItems.BUILD_PIECES[piece]["wood"]]
	elif player.temp_held != "":
		build_line = "\nHolding: %s" % GameItems.nice(player.temp_held)
	inv_label.text = " · ".join(key_res) + ("\n" if key_res.size() > 0 else "") + line2 + build_line
	inv_label.modulate = Color(1, 0.75, 0.5) if over else Color(1, 1, 1, 0.8)

	var w := _world()
	if w:
		var hh := int(w.time_of_day)
		var mm := int(fmod(w.time_of_day, 1.0) * 60.0)
		var wx: String = {"clear": "", "overcast": "  ☁ overcast", "rain": "  🌧 rain", "storm": "  ⛈ STORM", "fog": "  🌫 fog"}.get(w.weather, "")
		var night_tag := ""
		if w.is_night():
			night_tag = "   ☮ peaceful night" if w.peaceful else "   << NIGHT — wolves hunt >>"
		elif w.peaceful:
			night_tag = "   ☮"
		var mode_tag := ""
		match w.game_mode:
			"hard":
				mode_tag = "   ☠ HARD — night %d/%d survived" % [w.hard_nights, w.HARD_NIGHTS_TO_HARDCORE]
			"hardcore":
				mode_tag = "   ☠☠ TRIAL %d/%d" % [w.hardcore_rounds, w.HARDCORE_ROUNDS_TO_END]
				if w.is_night() and w.hc_goal.has("desc"):
					mode_tag += " — " + String(w.hc_goal["desc"])
		clock_label.text = "Day %d — %02d:%02d%s%s%s" % [w.day, hh, mm, wx, mode_tag, night_tag]

	if w:
		var night_now := w.is_night()
		if night_now and not _was_night:
			Sfx.play(self, "howl", -8.0)   # dusk: the wolves wake
		_was_night = night_now

	while goals_done < goals.size() and goals[goals_done][1].call():
		flash("GOAL COMPLETE: %s" % goals[goals_done][0])
		Sfx.play(self, "chime", -8.0)
		goals_done += 1
	if goals_done < goals.size():
		goal_label.text = goals[goals_done][0]
	else:
		goal_label.text = "THE HEART BEATS. The wolves grow calm,\nthe rot forgets your walls. Every chain is closed —\nthe island is truly, finally yours. Build.\n(The Long Game — hard mode — comes next.)"

	if msg_timer > 0.0:
		msg_timer -= delta
		if msg_timer <= 0.0:
			msg_label.text = ""
	if pickup_timer > 0.0:
		pickup_timer -= delta
		if pickup_timer <= 0.0:
			pickup_label.text = ""
