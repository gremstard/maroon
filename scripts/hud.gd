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
	inv_label.add_theme_font_size_override("font_size", 14)
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
	for i in Player.SLOTS.size():
		var pc := PanelContainer.new()
		var l := Label.new()
		l.text = "%d %s" % [i + 1, Player.SLOTS[i]]
		l.add_theme_font_size_override("font_size", 13)
		pc.add_child(l)
		hotbar.add_child(pc)

	# crafting panel (Tab)
	craft_panel = PanelContainer.new()
	craft_panel.set_anchors_preset(Control.PRESET_CENTER)
	craft_panel.visible = false
	root.add_child(craft_panel)
	var cv := VBoxContainer.new()
	cv.custom_minimum_size = Vector2(660, 0)
	craft_panel.add_child(cv)
	var ct := Label.new()
	ct.text = "CRAFTING  (Tab to close — anvil icon items need a forge nearby)"
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(ct)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	cv.add_child(grid)
	for recipe in GameItems.RECIPES:
		var b := Button.new()
		var prefix := "⚒ " if recipe in GameItems.FORGE_ONLY else ""
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

func toggle_craft() -> void:
	craft_panel.visible = not craft_panel.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if craft_panel.visible else Input.MOUSE_MODE_CAPTURED

var _dmg_overlay: ColorRect
var _was_night := false

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

	var inv_lines: PackedStringArray = []
	for item in player.inv:
		if player.inv[item] > 0:
			inv_lines.append("%s: %d" % [GameItems.nice(item), player.inv[item]])
	var tools: PackedStringArray = []
	for t in player.owned_tools:
		tools.append(GameItems.nice(t))
	var gear: PackedStringArray = []
	for gear_slot in player.equipment:
		gear.append(GameItems.nice(player.equipment[gear_slot]))
	var status := "\nArmor: %d%%   Carry: %d/%d%s" % [
		int(player.armor_total() * 100), player.carry_weight(), player.carry_cap(),
		"  (OVERLOADED — slowed)" if player.weight_mult() < 1.0 else ""]
	inv_label.text = "  ".join(inv_lines) \
		+ ("\nTools: " + ", ".join(tools) if tools.size() > 0 else "") \
		+ ("\nWearing: " + ", ".join(gear) if gear.size() > 0 else "") \
		+ status

	var w := _world()
	if w:
		var hh := int(w.time_of_day)
		var mm := int(fmod(w.time_of_day, 1.0) * 60.0)
		clock_label.text = "Day %d — %02d:%02d%s" % [w.day, hh, mm, "   << NIGHT — wolves hunt >>" if w.is_night() else ""]

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
		goal_label.text = "Scale-clad, iron-armed — and the monolith\nburning blue across the water. The islands are yours.\nWhat sleeps beneath the stone… comes next."

	for i in hotbar.get_child_count():
		hotbar.get_child(i).modulate = Color(1, 1, 0.5) if i == player.selected_slot else Color(1, 1, 1, 0.75)

	if msg_timer > 0.0:
		msg_timer -= delta
		if msg_timer <= 0.0:
			msg_label.text = ""
	if pickup_timer > 0.0:
		pickup_timer -= delta
		if pickup_timer <= 0.0:
			pickup_label.text = ""
