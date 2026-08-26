extends Node
# Entry point: main menu, network session management, player spawning.

const PORT := 27455
const MAX_PLAYERS := 8

var world_seed: int = 0
var world: World = null
var dedicated := false

var menu: CanvasLayer
var status_label: Label
var seed_edit: LineEdit
var ip_edit: LineEdit

# identity & accounts
var profile: Dictionary = {}
var fb: Firebase
var preview_player: Player = null
var auth_status: Label = null
var email_edit: LineEdit
var pass_edit: LineEdit

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)   # so we can save on window close
	profile = Profile.load_profile()
	fb = Firebase.new()
	add_child(fb)
	_register_inputs()
	_build_menu()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		dedicated = true
		world_seed = randi() % 1000000
		for a in args:
			if a.begins_with("--seed="):
				world_seed = int(a.substr(7))
		print("[maroon] dedicated server, seed=%d, port=%d" % [world_seed, PORT])
		_host()
	elif "--shot-menu" in args:
		await get_tree().create_timer(2.0).timeout
		preview_player.rotation.y = PI - 0.3
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://shot.png")
		print("[maroon] screenshot saved: ", ProjectSettings.globalize_path("user://shot.png"))
		get_tree().quit()
	elif "--smoke" in args:
		world_seed = 42
		DirAccess.remove_absolute("user://saves/world_42.json")
		DirAccess.remove_absolute("user://saves/player_42.json")
		_host()
		_run_smoke_test()
	elif "--shot" in args:
		world_seed = 42
		_host()
		await get_tree().create_timer(2.5).timeout
		var pl: Player = world.get_node("Players/1")
		print("[maroon] player at ", pl.global_position, " floor=", pl.is_on_floor(), " terrain_h=", world.height_at(pl.global_position.x, pl.global_position.z))
		pl.head.rotation.x = -0.1
		pl.owned_tools["crude_axe"] = true
		pl.set_hotbar(0, "crude_axe")
		pl.selected_slot = 0   # show the axe viewmodel
		if "--shot-crew" in args:
			# shoo wildlife out of frame, then stage two geared survivors
			for a in world.get_node("Animals").get_children():
				if a.global_position.distance_to(pl.global_position) < 15.0:
					a.queue_free()
			var fits: Array = [
				{"torso": "shirt_yellow", "legs": "pants_red"},
				{"head": "hide_hood", "torso": "shirt_red", "legs": "pants_black", "back": "hide_pack"},
				{"head": "scale_helm", "torso": "scale_chest", "legs": "pants_yellow", "back": "woven_pack"},
			]
			for i in fits.size():
				_spawn_player(900 + i)
				var buddy: Player = world.get_node("Players/%d" % (900 + i))
				var fwd: Vector3 = -pl.head.global_transform.basis.z
				fwd.y = 0
				fwd = fwd.normalized()
				var side: Vector3 = fwd.cross(Vector3.UP)
				var bpos: Vector3 = pl.global_position + fwd * 3.4 + side * ((i - 1) * 1.5)
				buddy.global_position = Vector3(bpos.x, world.height_at(bpos.x, bpos.z) + 0.1, bpos.z)
				buddy.rotation.y = pl.rotation.y + PI
				buddy.equipment = fits[i]
				buddy._refresh_gear_visuals()
			await get_tree().create_timer(0.4).timeout
		if "--shot-cave" in args:
			var out := Vector3(cos(atan2(world.cave_pos.z, world.cave_pos.x)), 0, sin(atan2(world.cave_pos.z, world.cave_pos.x)))
			world.sv_place_structure("torch", world.cave_pos + out * 5.0, 0.0)
			var vantage: Vector3 = world.cave_pos + out * 14.0
			pl.global_position = Vector3(vantage.x, world.height_at(vantage.x, vantage.z) + 1.2, vantage.z)
			pl.rotation.y = atan2(out.x, out.z)
			pl.head.rotation.x = 0.03
			await get_tree().create_timer(0.5).timeout
		if "--shot-raft" in args:
			pl.owned_tools["raft"] = true
			var toward := Vector3(world.far_center.x, 0, world.far_center.y).normalized()
			var sea := toward * 115.0
			pl.global_position = Vector3(sea.x, 0.4, sea.z)
			pl.rotation.y = atan2(-toward.x, -toward.z)
			pl.head.rotation.x = 0.06
			pl._set_sailing(true)
			await get_tree().create_timer(0.5).timeout
		if "--shot-build" in args:
			for a in world.get_node("Animals").get_children():
				if a.global_position.distance_to(pl.global_position) < 18.0:
					a.queue_free()
			var fwd2: Vector3 = -pl.head.global_transform.basis.z
			fwd2.y = 0
			fwd2 = fwd2.normalized()
			var bp := pl.global_position + fwd2 * 7.0
			bp = Vector3(roundf(bp.x / 3.0) * 3.0, 0, roundf(bp.z / 3.0) * 3.0)
			var top := world.height_at(bp.x, bp.z) + 0.3
			bp.y = top
			world.sv_place_structure("foundation", bp, 0.0)
			world.sv_place_structure("wall", bp + Vector3(-1.5, 0, 0), PI / 2)
			world.sv_place_structure("wall", bp + Vector3(1.5, 0, 0), PI / 2)
			world.sv_place_structure("wall", bp + Vector3(0, 0, 1.5), 0.0)
			world.sv_place_structure("window", bp + Vector3(1.5, 0, 0), PI / 2)
			world.sv_place_structure("doorway", bp + Vector3(0, 0, -1.5), 0.0)
			world.sv_place_structure("hatched", bp + Vector3(0, 2.6, 0), 0.0)
			await get_tree().create_timer(0.3).timeout
			for s in world.get_node("Structures").get_children():
				if s.get_meta("kind") == "doorway":
					world.sv_place_structure("door", s.global_position + s.global_transform.basis.x * -0.6, 0.0)
			pl.owned_tools["hammer"] = true
			pl.set_hotbar(1, "hammer")
			pl.inv["wood"] = 40
			pl.selected_slot = 1   # build mode, ghost visible
			await get_tree().create_timer(0.5).timeout
		if "--shot-pack" in args:
			pl.inv["wood"] = 34
			pl.inv["stone"] = 12
			pl.inv["fiber"] = 7
			pl.inv["branch"] = 3
			pl.inv["berries"] = 6
			pl.inv["torch"] = 4
			pl.inv["cooked_meat"] = 3
			pl.owned_tools["hammer"] = true
			pl.owned_tools["stone_pick"] = true
			pl.set_hotbar(1, "hammer")
			pl.set_hotbar(2, "torch")
			pl.set_hotbar(3, "cooked_meat")
			pl.reconcile_grid()
			world.sv_place_structure("chest", pl.global_position + Vector3(1.5, 0, -1), 0.0)
			await get_tree().create_timer(0.3).timeout
			for s in world.get_node("Structures").get_children():
				if s.get_meta("kind") == "chest":
					world.sv_container_put(s.name, "iron_ore", 9)
					world.sv_container_put(s.name, "hide", 5)
					world.sv_container_put(s.name, "charcoal", 6)
					await get_tree().create_timer(0.2).timeout
					pl.hud.open_container(String(s.name))
			await get_tree().create_timer(0.5).timeout
		if "--shot-fish" in args:
			pl.owned_tools["fishing_rod"] = true
			pl.set_hotbar(2, "fishing_rod")
			pl.selected_slot = 2
			var pond: Vector2 = world.pond_centers[0]
			var pdir := Vector2(1, 0.3).normalized()
			var edge := pond + pdir * 8.0
			while world.height_at(edge.x, edge.y) < 0.4:
				edge += pdir * 1.5   # back up onto dry rim
			pl.global_position = Vector3(edge.x, world.height_at(edge.x, edge.y) + 1.0, edge.y)
			var to_pond := Vector2(pond.x - edge.x, pond.y - edge.y).normalized()
			pl.rotation.y = atan2(-to_pond.x, -to_pond.y)
			pl.head.rotation.x = -0.35
			await get_tree().create_timer(0.4).timeout
			pl._try_fish()
			await get_tree().create_timer(0.4).timeout
		if "--shot-wave" in args:
			var tw := pl.global_position + Vector3(6, 0, -4)
			world.sv_place_structure("totem", tw, 0.0)
			world.sv_place_structure("wall", Vector3(roundf(tw.x / 3.0) * 3.0 + 1.5, tw.y, roundf(tw.z / 3.0) * 3.0), PI / 2)
			await get_tree().create_timer(0.3).timeout
			world.time_of_day = 22.5
			world.rx_mode("hard", 2, 0)
			world.game_mode = "hard"
			world.hard_nights = 2
			world._spawn_wave()
			pl.owned_tools["iron_spear"] = true
			pl.set_hotbar(1, "iron_spear")
			pl.selected_slot = 1
			var to_t: Vector3 = tw - pl.global_position
			pl.rotation.y = atan2(-to_t.x, -to_t.z)
			await get_tree().create_timer(2.5).timeout
		if "--shot-depths" in args:
			world.rx_monolith_awakened()
			world.sv_place_structure("torch", world.depths_center + Vector3(6, 0, 3), 0.0)
			pl.global_position = world.depths_center + Vector3(11, 1.2, 5)
			var to_altar: Vector3 = world.depths_center - pl.global_position
			pl.rotation.y = atan2(-to_altar.x, -to_altar.z)
			pl.head.rotation.x = -0.05
			pl.inv["torch"] = 3
			pl.set_hotbar(2, "torch")
			pl.selected_slot = 2
			await get_tree().create_timer(0.8).timeout
		if "--shot-stilt" in args:
			var wdir := Vector3(pl.global_position.x, 0, pl.global_position.z).normalized()
			var wp := Vector3.ZERO
			for r in range(6, 90, 3):
				var cand: Vector3 = pl.global_position + wdir * r
				if world.height_at(cand.x, cand.z) < -0.8:
					wp = Vector3(roundf(cand.x / 3.0) * 3.0, 1.5, roundf(cand.z / 3.0) * 3.0)
					break
			world.sv_place_structure("foundation", wp, 0.0)
			world.sv_place_structure("wall", wp + Vector3(-1.5, 0, 0), PI / 2)
			world.sv_place_structure("wall", wp + Vector3(0, 0, 1.5), 0.0)
			world.sv_place_structure("doorway", wp + Vector3(1.5, 0, 0), PI / 2)
			world.sv_place_structure("hatched", wp + Vector3(0, 2.6, 0), 0.0)
			world.sv_place_structure("ladder", wp + Vector3(0, 0, -1.42), 0.0)
			await get_tree().create_timer(0.4).timeout
			var back := wp + Vector3(wdir.x, 0, wdir.z) * -12.0
			pl.global_position = Vector3(back.x, world.height_at(back.x, back.z) + 1.2, back.z)
			var to_hut: Vector3 = wp - pl.global_position
			pl.rotation.y = atan2(-to_hut.x, -to_hut.z)
			pl.head.rotation.x = 0.06
			await get_tree().create_timer(0.4).timeout
		if "--shot-storm" in args:
			world.rx_weather("storm")
			pl.rotation.y += 2.5   # face the treeline
			await get_tree().create_timer(1.2).timeout
		if "--shot-isle" in args:
			pl.global_position = Vector3(0, 165, 120)
			pl.velocity = Vector3.ZERO
			pl.rotation.y = 0.0
			pl.head.rotation.x = -0.95
			await get_tree().process_frame
			await get_tree().process_frame
		if "--shot-lev" in args:
			world._summon_leviathan()
			await get_tree().create_timer(4.0).timeout
			var lev: Leviathan = world.get_node("Lev")
			var beach: Vector3 = lev.anchor.normalized() * (Vector2(lev.anchor.x, lev.anchor.z).length() - 22.0)
			pl.global_position = Vector3(beach.x, world.height_at(beach.x, beach.z) + 1.2, beach.z)
			var to_lev: Vector3 = lev.global_position - pl.global_position
			pl.rotation.y = atan2(-to_lev.x, -to_lev.z)
			pl.head.rotation.x = 0.02
			await get_tree().create_timer(0.3).timeout
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://shot.png")
		print("[maroon] screenshot saved: ", ProjectSettings.globalize_path("user://shot.png"))
		get_tree().quit()
	else:
		for a in args:
			if a.begins_with("--client="):
				ip_edit.text = a.substr(9)
				_on_join_pressed()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if world:
			world.save_now()
			for p in world.get_node("Players").get_children():
				p.save_local()
		get_tree().quit()

# ---------------------------------------------------------------- input map

func _register_inputs() -> void:
	var keys := {
		"mv_fwd": KEY_W, "mv_back": KEY_S, "mv_left": KEY_A, "mv_right": KEY_D,
		"jump": KEY_SPACE, "sprint": KEY_SHIFT, "interact": KEY_E,
		"craft_menu": KEY_TAB,
		"slot_1": KEY_1, "slot_2": KEY_2, "slot_3": KEY_3, "slot_4": KEY_4,
		"slot_5": KEY_5, "slot_6": KEY_6, "slot_7": KEY_7, "slot_8": KEY_8,
		"slot_9": KEY_9, "slot_10": KEY_0,
		"build_rotate": KEY_R, "demolish": KEY_X, "toggle_crafting": KEY_C,
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = keys[action]
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mb)

# ---------------------------------------------------------------- menu UI

func _build_menu() -> void:
	menu = CanvasLayer.new()
	menu.name = "Menu"
	add_child(menu)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.10, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 56)
	center.add_child(columns)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 8)
	columns.add_child(box)
	_build_character_panel(columns)

	var emblem := TextureRect.new()
	emblem.texture = load("res://icon.png")
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.custom_minimum_size = Vector2(0, 130)
	box.add_child(emblem)

	var title := Label.new()
	title.text = "M A R O O N"
	title.add_theme_font_size_override("font_size", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "you, your friends, and the wilderness"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.55)
	box.add_child(sub)

	var byline := Label.new()
	byline.text = "BRAIN DUMP INNERACTIVE"
	byline.add_theme_font_size_override("font_size", 11)
	byline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	byline.modulate = Color(1, 1, 1, 0.3)
	box.add_child(byline)

	box.add_child(HSeparator.new())

	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "world seed (blank = random)"
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "host's IP address"

	var nav := {
		"New World": func() -> void: _show_ctx("new"),
		"Continue": func() -> void: _continue_latest(),
		"My Worlds": func() -> void: _show_ctx("worlds"),
		"Join a World": func() -> void: _show_ctx("join"),
		"Added Worlds": func() -> void: _show_ctx("added"),
		"Controls": func() -> void: _show_ctx("controls"),
	}
	for label in nav:
		var b := Button.new()
		b.text = label
		b.pressed.connect(nav[label])
		box.add_child(b)
		if label == "Continue":
			b.disabled = _list_worlds().is_empty()

	ctx_box = VBoxContainer.new()
	ctx_box.add_theme_constant_override("separation", 6)
	box.add_child(ctx_box)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.modulate = Color(1, 0.85, 0.6)
	box.add_child(status_label)

# ------------------------------------------------- menu context panels

var ctx_box: VBoxContainer

func _clear_ctx() -> void:
	for c in ctx_box.get_children():
		ctx_box.remove_child(c)
		if c != seed_edit and c != ip_edit:
			c.queue_free()

func _show_ctx(mode: String) -> void:
	_clear_ctx()
	match mode:
		"new":
			ctx_box.add_child(seed_edit)
			var go := Button.new()
			go.text = "Create & Host"
			go.pressed.connect(_on_host_pressed)
			ctx_box.add_child(go)
		"worlds":
			var worlds := _list_worlds()
			if worlds.is_empty():
				_ctx_note("No worlds yet — make one with New World.")
			for w in worlds:
				var b := Button.new()
				if w["sealed"]:
					b.text = "Seed %d  —  ⳼ SEALED (Day %d)" % [w["seed"], w["day"]]
					b.disabled = true
					b.tooltip_text = "The island took this one back. The save remains as a tomb."
				else:
					b.text = "Seed %d  —  Day %d" % [w["seed"], w["day"]]
					b.pressed.connect(func() -> void:
						seed_edit.text = str(w["seed"])
						_on_host_pressed())
				ctx_box.add_child(b)
		"join":
			ctx_box.add_child(ip_edit)
			var jb := Button.new()
			jb.text = "Join"
			jb.pressed.connect(_on_join_pressed)
			ctx_box.add_child(jb)
		"controls":
			var cl := Label.new()
			cl.text = CONTROLS_TEXT
			cl.add_theme_font_size_override("font_size", 12)
			cl.modulate = Color(1, 1, 1, 0.75)
			ctx_box.add_child(cl)
		"added":
			var servers := _list_servers()
			if servers.is_empty():
				_ctx_note("Worlds you join get remembered here.")
			for ip in servers:
				var b := Button.new()
				b.text = ip
				b.pressed.connect(func() -> void:
					ip_edit.text = ip
					_on_join_pressed())
				ctx_box.add_child(b)

const CONTROLS_TEXT := """WASD · Space · Shift — move · jump · sprint
Left click — swing / place / eat what you hold
1–4 — hotbar   ·   E — interact / doors / cook / feed totem
Tab — pack   ·   C — crafting   ·   right-click a stack — options
Hammer held: scroll piece · R rotate · click place · E repair · X demolish
Esc — pause"""

func _ctx_note(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate = Color(1, 1, 1, 0.4)
	l.add_theme_font_size_override("font_size", 12)
	ctx_box.add_child(l)

func _list_worlds() -> Array:
	var out: Array = []
	var dir := DirAccess.open("user://saves")
	if dir == null:
		return out
	for f in dir.get_files():
		if f.begins_with("world_") and f.ends_with(".json"):
			var entry := {"seed": int(f.trim_prefix("world_").trim_suffix(".json")), "day": 1, "sealed": false, "mtime": FileAccess.get_modified_time("user://saves/" + f)}
			var data: Variant = JSON.parse_string(FileAccess.open("user://saves/" + f, FileAccess.READ).get_as_text())
			if data is Dictionary:
				entry["day"] = int(data.get("day", 1))
				entry["sealed"] = data.get("sealed", false)
			out.append(entry)
	out.sort_custom(func(a, b): return a["mtime"] > b["mtime"])
	return out

func _continue_latest() -> void:
	for w in _list_worlds():
		if not w["sealed"]:
			seed_edit.text = str(w["seed"])
			_on_host_pressed()
			return
	_set_status("Every world here is sealed. New World awaits.")

func _list_servers() -> Array:
	if not FileAccess.file_exists("user://servers.json"):
		return []
	var data: Variant = JSON.parse_string(FileAccess.open("user://servers.json", FileAccess.READ).get_as_text())
	return data if data is Array else []

func remember_server(ip: String) -> void:
	var servers := _list_servers()
	if ip in servers:
		return
	servers.append(ip)
	var f := FileAccess.open("user://servers.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(servers))
	f.close()

func return_to_menu() -> void:
	if world:
		world.save_now()
		for p in world.get_node("Players").get_children():
			p.save_local()
		world.queue_free()
		world = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.visible = true
	_set_status("")

func _build_character_panel(parent: Node) -> void:
	var you := VBoxContainer.new()
	you.custom_minimum_size = Vector2(300, 0)
	you.add_theme_constant_override("separation", 8)
	parent.add_child(you)

	var t := Label.new()
	t.text = "YOUR SURVIVOR"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	you.add_child(t)

	# live 3D preview
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(300, 260)
	svc.stretch = true
	you.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	svc.add_child(sv)
	var pcam := Camera3D.new()
	pcam.position = Vector3(0, 1.35, 2.4)
	pcam.rotation_degrees.x = -6
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.9)
	env.ambient_light_energy = 0.7
	pcam.environment = env
	sv.add_child(pcam)
	var plight := DirectionalLight3D.new()
	plight.rotation_degrees = Vector3(-35, 25, 0)
	plight.light_energy = 1.2
	sv.add_child(plight)
	preview_player = Player.new()
	preview_player.peer_id = 0
	sv.add_child(preview_player)
	preview_player.rotation.y = PI   # face the camera
	_refresh_preview()

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "your name"
	name_edit.max_length = 20
	name_edit.text = profile.get("name", "survivor")
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.text_changed.connect(func(txt: String) -> void:
		profile["name"] = txt
		_save_and_preview())
	you.add_child(name_edit)

	_opt_row(you, "Skin", "skin", Player.SKIN_TONES.size())
	_opt_row(you, "Hair color", "hair_color", Player.HAIR_COLORS.size())
	_opt_row(you, "Hair style", "hair_style", Profile.HAIR_STYLES.size(), Profile.HAIR_STYLES)
	var beard_btn := Button.new()
	beard_btn.text = "Beard: " + ("yes" if profile.get("beard", false) else "no")
	beard_btn.pressed.connect(func() -> void:
		profile["beard"] = not profile.get("beard", false)
		beard_btn.text = "Beard: " + ("yes" if profile["beard"] else "no")
		_save_and_preview())
	you.add_child(beard_btn)

	# cloud account
	you.add_child(HSeparator.new())
	if fb.configured():
		email_edit = LineEdit.new()
		email_edit.placeholder_text = "email"
		you.add_child(email_edit)
		pass_edit = LineEdit.new()
		pass_edit.placeholder_text = "password"
		pass_edit.secret = true
		you.add_child(pass_edit)
		var auth_row := HBoxContainer.new()
		auth_row.add_theme_constant_override("separation", 8)
		you.add_child(auth_row)
		var sign_in := Button.new()
		sign_in.text = "Sign In"
		sign_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sign_in.pressed.connect(func() -> void: _do_auth(false))
		auth_row.add_child(sign_in)
		var register := Button.new()
		register.text = "Register"
		register.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		register.pressed.connect(func() -> void: _do_auth(true))
		auth_row.add_child(register)
		auth_status = Label.new()
		auth_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		auth_status.modulate = Color(1, 0.85, 0.6)
		var saved_auth: Dictionary = profile.get("auth", {})
		auth_status.text = "signed in as %s" % saved_auth["email"] if saved_auth.has("email") else "not signed in"
		you.add_child(auth_status)
	else:
		var off := Label.new()
		off.text = "Cloud accounts off — add firebase_config.json\n(api_key + project_id) to enable. See README."
		off.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		off.modulate = Color(1, 1, 1, 0.4)
		off.add_theme_font_size_override("font_size", 12)
		you.add_child(off)

func _opt_row(parent: Node, label: String, key: String, count: int, names: Array = []) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var value := Label.new()
	value.custom_minimum_size = Vector2(60, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var show_value := func() -> void:
		var i := int(profile.get(key, 0)) % count
		value.text = String(names[i]) if names.size() > 0 else str(i + 1)
	show_value.call()
	var step := func(delta: int) -> void:
		profile[key] = (int(profile.get(key, 0)) + delta + count) % count
		show_value.call()
		_save_and_preview()
	var prev := Button.new()
	prev.text = "<"
	prev.pressed.connect(func() -> void: step.call(-1))
	row.add_child(prev)
	row.add_child(value)
	var next := Button.new()
	next.text = ">"
	next.pressed.connect(func() -> void: step.call(1))
	row.add_child(next)

func _save_and_preview() -> void:
	Profile.save_profile(profile)
	_refresh_preview()

func _refresh_preview() -> void:
	if preview_player:
		preview_player.apply_appearance(Profile.appearance_of(profile))

func _do_auth(register: bool) -> void:
	auth_status.text = "…"
	var err: String = await fb.auth_email(email_edit.text.strip_edges(), pass_edit.text, register)
	if err != "":
		auth_status.text = err
		return
	profile["auth"] = {"uid": fb.uid, "email": fb.email}
	var cloud := await fb.pull_profile()
	if cloud.is_empty():
		await fb.push_profile(Profile.appearance_of(profile))
		auth_status.text = "registered — profile saved to cloud" if register else "signed in — profile uploaded"
	else:
		for k in cloud:
			profile[k] = cloud[k]
		auth_status.text = "signed in — profile restored from cloud"
	Profile.save_profile(profile)
	_refresh_preview()

func _process(delta: float) -> void:
	if preview_player and is_instance_valid(preview_player) and menu.visible:
		preview_player.rotation.y += delta * 0.45

func _set_status(t: String) -> void:
	if status_label:
		status_label.text = t
	print("[maroon] ", t)

# ---------------------------------------------------------------- host / join

func _on_host_pressed() -> void:
	var s := seed_edit.text.strip_edges()
	if s.is_empty():
		world_seed = randi() % 1000000
	elif s.is_valid_int():
		world_seed = int(s)
	else:
		world_seed = s.hash()
	_host()

func _host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		_set_status("Couldn't open port %d (already hosting?)" % PORT)
		return
	multiplayer.multiplayer_peer = peer
	_start_world(world_seed)
	if not dedicated:
		_spawn_player(1)
		menu.visible = false

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip_edit.text.strip_edges(), PORT)
	if err != OK:
		_set_status("Bad address.")
		return
	multiplayer.multiplayer_peer = peer
	_set_status("Connecting to %s..." % ip_edit.text)

func _on_connected_to_server() -> void:
	_set_status("Connected. Receiving island...")
	remember_server(ip_edit.text.strip_edges())

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	_set_status("Couldn't reach that island.")

func _on_server_disconnected() -> void:
	get_tree().reload_current_scene()

# ---------------------------------------------------------------- session flow

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		var existing: Array = []
		if world and world.has_node("Players"):
			for p in world.get_node("Players").get_children():
				existing.append(int(String(p.name)))
		rx_world_info.rpc_id(id, world_seed, existing)

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		rx_despawn_player.rpc(id)

@rpc("authority", "call_remote", "reliable")
func rx_world_info(s: int, existing_players: Array) -> void:
	world_seed = s
	_start_world(s)
	for pid in existing_players:
		_spawn_player(pid)
	menu.visible = false
	sv_client_ready.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func sv_client_ready() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	rx_spawn_player.rpc(id)
	_spawn_player(id)
	if world:
		world.sync_to(id)

@rpc("authority", "call_remote", "reliable")
func rx_spawn_player(id: int) -> void:
	_spawn_player(id)

@rpc("authority", "call_local", "reliable")
func rx_despawn_player(id: int) -> void:
	if world and world.has_node("Players/" + str(id)):
		world.get_node("Players/" + str(id)).queue_free()

# ---------------------------------------------------------------- spawning

func _start_world(s: int) -> void:
	if world:
		world.queue_free()
	world = World.new()
	world.name = "World"
	add_child(world)
	world.setup(s)
	if not dedicated:
		Sfx.ambient(world, "wind", -24.0)   # sea wind, always there

func _spawn_player(id: int) -> void:
	if world.get_node("Players").has_node(str(id)):
		return
	var p := Player.new()
	p.name = str(id)
	p.peer_id = id
	p.set_multiplayer_authority(id)
	world.get_node("Players").add_child(p)
	p.global_position = world.get_spawn_pos(id)
	p.rotation.y = atan2(p.global_position.x, p.global_position.z)  # face inland

# ---------------------------------------------------------------- smoke test

func _run_smoke_test() -> void:
	# Headless self-check of the core loops. Run: godot --headless -- --smoke
	await get_tree().create_timer(1.0).timeout
	var p: Player = world.get_node("Players/1")
	var ok := true

	# forage chain: branch + grass -> string -> crude axe -> chop a tree
	for kind in ["branch", "grass", "grass", "branch"]:
		var picks := world.get_node("Resources").get_children().filter(
			func(r): return r.get_meta("kind") == kind and float(r.get_meta("hp")) > 0.0)
		world.sv_hit_resource(picks[0].name, 1.0)
	await get_tree().create_timer(0.2).timeout
	print("[smoke] foraged: branch=%d fiber=%d" % [p.inv.get("branch", 0), p.inv.get("fiber", 0)])
	ok = ok and p.inv.get("branch", 0) >= 2 and p.inv.get("fiber", 0) >= 4
	p.inv["stone"] = p.inv.get("stone", 0) + 2
	p.craft("string")
	p.craft("crude_axe")
	ok = ok and p.owned_tools.has("crude_axe")
	var trees := world.get_node("Resources").get_children().filter(
		func(r): return r.get_meta("kind") == "tree")
	world.sv_hit_resource(trees[0].name, GameItems.TOOL_STATS["crude_axe"]["chop"])
	await get_tree().create_timer(0.2).timeout
	print("[smoke] wood after chop: ", p.inv.get("wood", 0))
	ok = ok and p.inv.get("wood", 0) > 0

	# crafting — advanced recipes need a workbench nearby
	p.inv["wood"] = 50
	p.inv["stone"] = 30
	p.inv["string"] = 6
	p.total_gathered["wood"] = 50
	p.total_gathered["stone"] = 30
	p.craft("stone_axe")   # no workbench yet — must refuse
	ok = ok and not p.owned_tools.has("stone_axe")
	p.craft("workbench")   # hand-craftable
	world.sv_place_structure("workbench", p.global_position + Vector3(-2, 0, 1), 0.0)
	await get_tree().create_timer(0.2).timeout
	p.craft("stone_axe")
	p.craft("campfire")
	p.craft("totem")
	print("[smoke] tools: ", p.owned_tools, " placeables: campfire=%d totem=%d" % [p.inv.get("campfire", 0), p.inv.get("totem", 0)])
	ok = ok and p.owned_tools.has("stone_axe") and p.inv.get("totem", 0) == 1

	# shipwreck looting
	world.sv_loot_crate("crate_0")
	world.sv_loot_crate("crate_0")   # second loot of same crate must do nothing
	await get_tree().create_timer(0.2).timeout
	print("[smoke] wreck: string=%d looted_event=%d" % [p.inv.get("string", 0), p.events.get("looted_wreck", 0)])
	ok = ok and p.events.get("looted_wreck", 0) == 1

	# quest chain: ruins chest -> lens -> beacon at the peak
	var kinds := {}
	for a in world.get_node("Animals").get_children():
		kinds[a.kind] = kinds.get(a.kind, 0) + 1
	print("[smoke] roster: ", kinds)
	ok = ok and kinds.get("bear", 0) >= 1 and kinds.get("boar", 0) >= 1
	p.inv["rusted_key"] = 1
	world.sv_open_chest()
	world.sv_open_chest()   # double-open must not double-grant
	await get_tree().create_timer(0.2).timeout
	print("[smoke] ruins: lens=%d opened=%d" % [p.inv.get("ancient_lens", 0), p.events.get("opened_ruins", 0)])
	ok = ok and p.inv.get("ancient_lens", 0) == 1 and p.events.get("opened_ruins", 0) == 1
	p.inv["iron_ore"] = 3
	p.inv["string"] = p.inv.get("string", 0) + 2
	p.inv["wood"] = 50
	p.craft("beacon")
	ok = ok and p.inv.get("beacon", 0) == 1
	world.sv_place_structure("beacon", world.peak_pos, 0.0)
	await get_tree().create_timer(0.2).timeout
	print("[smoke] beacon lit: ", p.events.get("beacon_lit", 0))
	ok = ok and p.events.get("beacon_lit", 0) == 1

	# the leviathan answers
	ok = ok and world.has_node("Lev")
	print("[smoke] leviathan summoned: ", world.has_node("Lev"))
	for i in 30:
		world.sv_attack_leviathan(20.0)
	await get_tree().create_timer(0.2).timeout
	print("[smoke] leviathan slain: dead=%s scales=%d event=%d" % [world.leviathan_dead, p.inv.get("leviathan_scale", 0), p.events.get("kill_leviathan", 0)])
	ok = ok and world.leviathan_dead and p.inv.get("leviathan_scale", 0) == 5 and p.events.get("kill_leviathan", 0) == 1

	# forge tier: clothes -> forge gate -> iron -> scale armor
	p.inv["fiber"] = 20
	p.inv["string"] = 10
	p.craft("fiber_tunic")
	ok = ok and p.equipment.get("torso", "") == "fiber_tunic"
	p.inv["iron_ore"] = 4
	p.craft("iron_bar")   # far from any forge — must refuse
	ok = ok and p.inv.get("iron_bar", 0) == 0
	p.inv["stone"] = 30
	p.inv["wood"] = 60
	p.inv["branch"] = 5
	p.craft("forge")
	ok = ok and p.crafted.has("forge")
	world.sv_place_structure("forge", p.global_position + Vector3(2, 0, 0), 0.0)
	world.sv_place_structure("furnace", p.global_position + Vector3(3, 0, 2), 0.0)
	await get_tree().create_timer(0.2).timeout
	world.sv_make_charcoal()   # smelting runs on charcoal now
	await get_tree().create_timer(0.2).timeout
	print("[smoke] charcoal: ", p.inv.get("charcoal", 0))
	ok = ok and p.inv.get("charcoal", 0) >= 2
	p.craft("iron_bar")
	p.craft("iron_bar")

	# storage: a crate takes a stack and gives it back
	world.sv_place_structure("crate", p.global_position + Vector3(-3, 0, -2), 0.0)
	await get_tree().create_timer(0.2).timeout
	var crate_nodes := world.get_node("Structures").get_children().filter(
		func(s): return s.get_meta("kind") == "crate")
	ok = ok and crate_nodes.size() == 1
	world.sv_container_put(crate_nodes[0].name, "stone", 7)
	await get_tree().create_timer(0.2).timeout
	var stored: int = crate_nodes[0].get_meta("store").get("stone", 0)
	world.sv_container_take(crate_nodes[0].name, "stone")
	await get_tree().create_timer(0.2).timeout
	print("[smoke] crate: stored=%d, after take=%s" % [stored, crate_nodes[0].get_meta("store")])
	ok = ok and stored == 7 and not crate_nodes[0].get_meta("store").has("stone")
	p.craft("iron_spear")
	print("[smoke] forge: bars_crafted=%s iron_spear=%s" % [p.crafted.has("iron_bar"), p.owned_tools.has("iron_spear")])
	ok = ok and p.owned_tools.has("iron_spear")
	p.inv["hide"] = 10
	p.craft("scale_chest")
	p.craft("hide_coat")   # weaker than scale — must NOT replace it
	print("[smoke] armor: torso=%s total=%.2f" % [p.equipment.get("torso"), p.armor_total()])
	ok = ok and p.equipment.get("torso", "") == "scale_chest"
	var pre_hp := p.hp
	p.rx_damage(30.0)
	print("[smoke] armored hit: hp %0.1f -> %0.1f (30 raw)" % [pre_hp, p.hp])
	ok = ok and pre_hp - p.hp < 25.0 and pre_hp - p.hp > 15.0

	# sea cave: exists, dwellers haunt it, torch crafts, moonstone mines
	ok = ok and world.cave_pos != Vector3.ZERO
	var dwellers := world.get_node("Animals").get_children().filter(
		func(a): return a.kind == "dweller")
	print("[smoke] cave at %.0f,%.0f — dwellers: %d" % [world.cave_pos.x, world.cave_pos.z, dwellers.size()])
	ok = ok and dwellers.size() >= 3   # 3 haunt the cave, more keep the Depths
	p.inv["branch"] = p.inv.get("branch", 0) + 1
	p.inv["fiber"] = p.inv.get("fiber", 0) + 2
	p.craft("torch")
	ok = ok and p.inv.get("torch", 0) >= 1
	var moonstones := world.get_node("Resources").get_children().filter(
		func(r): return r.get_meta("kind") == "moonstone")
	ok = ok and moonstones.size() >= 3
	world.sv_hit_resource(moonstones[0].name, 5.0)
	await get_tree().create_timer(0.2).timeout
	print("[smoke] moonstone mined: ", p.inv.get("moonstone", 0))
	ok = ok and p.inv.get("moonstone", 0) > 0
	p.global_position = world.cave_pos + Vector3(0, 1, 0)
	await get_tree().create_timer(1.2).timeout
	print("[smoke] entered cave event: ", p.events.get("entered_cave", 0))
	ok = ok and p.events.get("entered_cave", 0) == 1

	# far isle: terrain rose from the sea, raft crafts, monolith wakes
	var far3 := Vector3(world.far_center.x, 0, world.far_center.y)
	var far_h: float = world.height_at(far3.x, far3.z)
	print("[smoke] far isle at %.0f,%.0f h=%.1f" % [far3.x, far3.z, far_h])
	ok = ok and far_h > 2.0
	p.inv["wood"] = 45
	p.inv["string"] = p.inv.get("string", 0) + 4
	world.sv_place_structure("workbench", p.global_position + Vector3(2, 0, 2), 0.0)
	await get_tree().create_timer(0.2).timeout
	p.craft("raft")
	ok = ok and p.owned_tools.has("raft")
	p.global_position = Vector3(far3.x, far_h + 1.0, far3.z)
	await get_tree().create_timer(1.2).timeout
	print("[smoke] entered far isle: ", p.events.get("entered_far_isle", 0))
	ok = ok and p.events.get("entered_far_isle", 0) == 1
	p.inv["moonstone"] = p.inv.get("moonstone", 0) + 3
	world.sv_awaken_monolith()
	world.sv_awaken_monolith()   # second awakening must not double-grant
	await get_tree().create_timer(0.2).timeout
	print("[smoke] monolith: awakened=%s event=%d bars=%d" % [
		world.get_node("Monolith").get_meta("awakened"),
		p.events.get("monolith_awakened", 0), p.inv.get("iron_bar", 0)])
	ok = ok and world.get_node("Monolith").get_meta("awakened") and p.events.get("monolith_awakened", 0) == 1

	# the depths: hall exists, heartstone iron-gated mining, heart restored
	p.global_position = world.depths_center + Vector3(10, 1.2, 0)
	await get_tree().create_timer(1.2).timeout
	print("[smoke] entered depths: ", p.events.get("entered_depths", 0))
	ok = ok and p.events.get("entered_depths", 0) == 1
	var hearts := world.get_node("Resources").get_children().filter(
		func(r): return r.get_meta("kind") == "heartstone")
	ok = ok and hearts.size() == 3
	world.sv_hit_resource(hearts[0].name, 7.0)
	await get_tree().create_timer(0.2).timeout
	ok = ok and p.inv.get("heartstone", 0) > 0
	p.inv["heartstone"] = 3
	world.sv_restore_heart()
	world.sv_restore_heart()   # second restore must do nothing
	await get_tree().create_timer(0.3).timeout
	print("[smoke] heart: peaceful=%s event=%d shard=%d" % [world.peaceful, p.events.get("heart_restored", 0), p.inv.get("heart_shard", 0)])
	ok = ok and world.peaceful and p.events.get("heart_restored", 0) == 1 and p.inv.get("heart_shard", 0) == 1
	world._on_nightfall()   # peaceful: must not spawn a wave
	await get_tree().create_timer(0.2).timeout

	# grid inventory: reconcile builds stacks, crafts auto-bind to hotbar
	p.reconcile_grid()
	print("[smoke] grid: %d stacks, axe bound=%s, rows=%d" % [p.grid_stacks.size(), "crude_axe" in p.hotbar_items, p.grid_rows()])
	ok = ok and p.grid_stacks.size() > 0 and "crude_axe" in p.hotbar_items
	ok = ok and p.held_item() == p.hotbar_items[p.selected_slot]

	# fishing: rod crafts by hand, catches land in the pack, fire cooks them
	p.inv["branch"] = p.inv.get("branch", 0) + 2
	p.inv["string"] = p.inv.get("string", 0) + 2
	p.craft("fishing_rod")
	ok = ok and p.owned_tools.has("fishing_rod")
	p._fish_deep = false
	p._finish_catch()
	print("[smoke] fishing: rod=%s raw_fish=%d" % [p.owned_tools.has("fishing_rod"), p.inv.get("raw_fish", 0)])
	ok = ok and p.inv.get("raw_fish", 0) >= 1

	# biomes + new fauna + poison cure
	var biomes := {}
	for bx in range(-100, 101, 20):
		for bz in range(-100, 101, 20):
			if world.height_at(bx, bz) > 0.5:
				biomes[world.biome_at(bx, bz)] = true
	var roster2 := {}
	for a2 in world.get_node("Animals").get_children():
		roster2[a2.kind] = roster2.get(a2.kind, 0) + 1
	print("[smoke] biomes seen: %s · snakes=%d crows=%d ponds=%d" % [biomes.keys(), roster2.get("snake", 0), roster2.get("crow", 0), world.pond_centers.size()])
	ok = ok and biomes.size() >= 3 and roster2.get("snake", 0) >= 1 and roster2.get("crow", 0) >= 1
	p.rx_poison()
	ok = ok and p.poisoned_t > 0.0
	p.inv["berries"] = p.inv.get("berries", 0) + 1
	p._eat("berries")
	print("[smoke] venom cured: ", p.poisoned_t == 0.0)
	ok = ok and p.poisoned_t == 0.0

	# weather: rain gutters an unsheltered torch and douses burning walls
	var tree_count := world.get_node("Resources").get_children().filter(
		func(r): return r.get_meta("kind") == "tree").size()
	world.rx_weather("rain")
	world.sv_place_structure("torch", p.global_position + Vector3(-5, 0, 5), 0.0)
	await get_tree().create_timer(0.2).timeout
	var wet_torch: Node = world.get_node("Structures").get_children().filter(
		func(s): return s.get_meta("kind") == "torch").back()
	var torch_hp0: float = wet_torch.get_meta("hp")
	world._fire_tick()
	await get_tree().create_timer(0.2).timeout
	print("[smoke] weather=%s trees=%d torch %0.f->%0.f in rain" % [world.weather, tree_count, torch_hp0, wet_torch.get_meta("hp")])
	ok = ok and world.weather == "rain" and float(wet_torch.get_meta("hp")) < torch_hp0 and tree_count > 100
	world.rx_weather("clear")

	# identity: profile roundtrip + appearance applied to the rig
	var orig_profile := ""
	if FileAccess.file_exists(Profile.PATH):
		orig_profile = FileAccess.open(Profile.PATH, FileAccess.READ).get_as_text()
	var prof := Profile.defaults()
	prof["name"] = "smoketester"
	prof["beard"] = true
	prof["hair_style"] = 1
	Profile.save_profile(prof)
	var loaded := Profile.load_profile()
	p.apply_appearance(Profile.appearance_of(loaded))
	print("[smoke] identity: name=%s beard=%s" % [p.display_name(), p.appearance.get("beard")])
	ok = ok and p.display_name() == "smoketester" and p.appearance.get("beard") == true
	if orig_profile != "":
		var pf := FileAccess.open(Profile.PATH, FileAccess.WRITE)
		pf.store_string(orig_profile)
		pf.close()
	else:
		DirAccess.remove_absolute(Profile.PATH)

	# persistence round-trip
	world.sv_place_structure("campfire", p.global_position + Vector3(0, 0, 3), 0.0)
	await get_tree().create_timer(0.2).timeout
	world.save_now()
	p.save_local()
	ok = ok and FileAccess.file_exists("user://saves/world_42.json")
	print("[smoke] save file written: ", FileAccess.file_exists("user://saves/world_42.json"))

	# placing + totem stock
	world.sv_place_structure("totem", p.global_position + Vector3(2, 0, 0), 0.0)
	await get_tree().create_timer(0.2).timeout

	# building system: hammer -> foundation -> wall -> doorway -> door swings
	p.inv["wood"] = 80
	p.inv["stone"] = p.inv.get("stone", 0) + 2
	p.inv["string"] = p.inv.get("string", 0) + 1
	p.craft("hammer")
	ok = ok and p.owned_tools.has("hammer")
	var bpos := p.global_position + Vector3(8, 0.3, 0)
	world.sv_place_structure("foundation", bpos, 0.0)
	world.sv_place_structure("wall", bpos + Vector3(0, 0, 1.5), 0.0)
	world.sv_place_structure("doorway", bpos + Vector3(0, 0, -1.5), 0.0)
	await get_tree().create_timer(0.2).timeout
	var doorway := world.get_node("Structures").get_children().filter(
		func(s): return s.get_meta("kind") == "doorway")
	ok = ok and doorway.size() == 1
	var dw: Node3D = doorway[0]
	world.sv_place_structure("door", dw.global_position + dw.global_transform.basis.x * -0.6, 0.0)
	await get_tree().create_timer(0.2).timeout
	var doors := world.get_node("Structures").get_children().filter(
		func(s): return s.get_meta("kind") == "door")
	ok = ok and doors.size() == 1
	world.sv_toggle_door(doors[0].name)
	await get_tree().create_timer(0.4).timeout
	print("[smoke] build: pieces placed, door open=%s" % doors[0].get_meta("open"))
	ok = ok and doors[0].get_meta("open") == true
	var pre_wood: int = p.inv.get("wood", 0)
	world.sv_remove_structure(doors[0].name)
	await get_tree().create_timer(0.2).timeout
	print("[smoke] demolish: refund=%d wood" % [p.inv.get("wood", 0) - pre_wood])
	ok = ok and p.inv.get("wood", 0) == pre_wood + 2

	# building v2: stilt foundation over water, stairs, ladder, trapdoor
	var water_p := Vector3.ZERO
	for r in range(8, 120, 4):
		var cand := p.global_position + Vector3(r, 0, 0)
		if world.height_at(cand.x, cand.z) < -0.6:
			water_p = Vector3(roundf(cand.x / 3.0) * 3.0, 1.4, roundf(cand.z / 3.0) * 3.0)
			break
	ok = ok and water_p != Vector3.ZERO
	world.sv_place_structure("foundation", water_p, 0.0)
	world.sv_place_structure("stairs", bpos + Vector3(3, 0, 0), 0.0)
	world.sv_place_structure("trapdoor", bpos + Vector3(0, 2.6, 0), 0.0)
	await get_tree().create_timer(0.2).timeout
	var stilt: Node = world.get_node("Structures").get_children().filter(
		func(s): return s.get_meta("kind") == "foundation").back()
	var pillars := stilt.get_children().filter(func(c): return c is MeshInstance3D and c.mesh is CylinderMesh)
	var trap: Node = world.get_node("Structures").get_children().filter(
		func(s): return s.get_meta("kind") == "trapdoor").back()
	world.sv_toggle_door(trap.name)
	await get_tree().create_timer(0.4).timeout
	world.sv_place_structure("ladder", bpos + Vector3(0, 0, -1.7), 0.0)
	await get_tree().create_timer(0.2).timeout
	var has_ladder: bool = world.get_node("Structures").get_children().any(
		func(s): return s.get_meta("kind") == "ladder")
	print("[smoke] build v2: stilt pillars=%d trapdoor_open=%s ladder=%s stairs=%s" % [
		pillars.size(), trap.get_meta("open"), has_ladder,
		world.get_node("Structures").get_children().any(func(s): return s.get_meta("kind") == "stairs")])
	ok = ok and pillars.size() == 4 and trap.get_meta("open") == true and has_ladder

	# cloth & dye: dry grass all the way to a yellow shirt
	world.sv_place_structure("workbench", p.global_position + Vector3(3, 0, -3), 0.0)
	await get_tree().create_timer(0.2).timeout
	p.inv["fiber"] = 20
	p.inv["string"] = p.inv.get("string", 0) + 9
	p.craft("yellow_dye")
	p.craft("cloth")
	p.craft("cloth")
	p.craft("shirt_yellow")
	var has_shirt: bool = p.inv.get("shirt_yellow", 0) >= 1 or p.equipment.get("torso", "") == "shirt_yellow"
	print("[smoke] dye chain: yellow shirt made=%s" % has_shirt)
	ok = ok and has_shirt

	# iron lamp: forged, then glows from the pack
	world.sv_place_structure("forge", p.global_position + Vector3(-4, 0, 4), 0.0)
	await get_tree().create_timer(0.2).timeout
	p.inv["iron_bar"] = p.inv.get("iron_bar", 0) + 2
	p.inv["string"] = p.inv.get("string", 0) + 1
	p.craft("lamp")
	await get_tree().create_timer(0.5).timeout
	print("[smoke] lamp: owned=%d glowing=%s" % [p.inv.get("lamp", 0), p.lamp_net])
	ok = ok and p.inv.get("lamp", 0) == 1 and p.lamp_net

	# fire: an ignited wall burns down over the fire tick
	var burn_walls := world.get_node("Structures").get_children().filter(
		func(s): return s.get_meta("kind") == "wall")
	ok = ok and burn_walls.size() >= 1
	var bw: Node = burn_walls[0]
	var wall_hp0: float = bw.get_meta("hp")
	world.rx_ignite(String(bw.name))
	world._fire_tick()
	await get_tree().create_timer(0.2).timeout
	print("[smoke] fire: wall hp %.0f -> %.0f, burning=%s" % [wall_hp0, bw.get_meta("hp"), bw.get_meta("burning")])
	ok = ok and float(bw.get_meta("hp")) < wall_hp0 and bw.get_meta("burning") == true

	# painting on that wall
	world.sv_place_structure("painting", bw.global_position + Vector3(0, 1.3, 0.2), 0.0)
	await get_tree().create_timer(0.2).timeout
	ok = ok and world.get_node("Structures").get_children().any(
		func(s): return s.get_meta("kind") == "painting")

	var totem := world.get_node("Structures").get_children().filter(
		func(s): return s.get_meta("kind") == "totem")
	ok = ok and totem.size() == 1
	world.sv_deposit_wood(totem[0].name, 5)
	await get_tree().create_timer(0.2).timeout
	print("[smoke] totem stock: ", totem[0].get_meta("stock"))
	ok = ok and int(totem[0].get_meta("stock")) == world.TOTEM_START_STOCK + 5

	# animal attack (PnPvE means we can only test animals; players are untouchable)
	var animals := world.get_node("Animals").get_children()
	print("[smoke] animals alive: ", animals.size())
	ok = ok and animals.size() > 0
	world.sv_attack_animal(animals[0].name, 999.0)
	await get_tree().create_timer(0.2).timeout
	print("[smoke] meat after kill: %d, hide: %d" % [p.inv.get("raw_meat", 0), p.inv.get("hide", 0)])
	ok = ok and p.inv.get("raw_meat", 0) > 0 and p.inv.get("hide", 0) > 0

	# eating + goal ladder
	p.inv["raw_meat"] = p.inv.get("raw_meat", 0) + 1
	p.events["cooked"] = 1
	p.hunger = 20.0
	p._eat()
	print("[smoke] hunger after eating: ", p.hunger)
	ok = ok and p.hunger > 20.0
	await get_tree().create_timer(0.5).timeout
	print("[smoke] goals completed: ", p.hud.goals_done, "/", p.hud.goals.size())
	ok = ok and p.hud.goals_done >= 4

	# the long game: arm -> wave -> hardcore trials -> totem loss -> seal
	world.peaceful = false   # test seam: undo the heart for the gauntlet
	world.time_of_day = 23.0
	world.sv_arm_totem(totem[0].name)
	ok = ok and world.game_mode == "hard"
	world._spawn_wave()
	await get_tree().create_timer(0.5).timeout
	var raiders := world.get_node("Animals").get_children().filter(func(a): return a.raider)
	print("[smoke] long game: mode=%s wave=%d raiders=%d" % [world.game_mode, world._wave_names.size(), raiders.size()])
	ok = ok and world._wave_names.size() > 0 and raiders.size() == world._wave_names.size()
	world._on_dawn()
	ok = ok and world.hard_nights == 1 and world._wave_names.is_empty()
	world.hard_nights = 5
	world.sv_arm_totem(totem[0].name)
	ok = ok and world.game_mode == "hardcore"
	world.hc_goal = {"kind": "slay", "n": 0, "desc": "test"}
	world._on_dawn()
	ok = ok and world.hardcore_rounds == 1
	world.sv_place_structure("totem", p.global_position + Vector3(6, 0, 6), 0.0)
	await get_tree().create_timer(0.2).timeout
	world.hc_goal = {"kind": "deposit", "n": 9999, "desc": "test-fail"}
	world._night_deposits = 0
	world._on_dawn()   # fail: one totem burns
	await get_tree().create_timer(0.2).timeout
	var totems_left := world._totems().size()
	ok = ok and totems_left == 1 and not world.sealed
	world.hc_goal = {"kind": "deposit", "n": 9999, "desc": "test-fail-2"}
	world._on_dawn()   # fail again: last totem -> sealed
	await get_tree().create_timer(0.2).timeout
	print("[smoke] gauntlet: rounds=%d totems_left=%d sealed=%s" % [world.hardcore_rounds, totems_left, world.sealed])
	ok = ok and world.sealed
	world.save_now()
	var sealed_save: Variant = JSON.parse_string(FileAccess.open("user://saves/world_42.json", FileAccess.READ).get_as_text())
	ok = ok and sealed_save.get("sealed", false) == true

	print("[smoke] ", "ALL PASS" if ok else "FAILURES — see above")
	get_tree().quit(0 if ok else 1)
