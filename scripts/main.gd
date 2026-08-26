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
		pl.selected_slot = 1   # show the axe viewmodel
		if "--shot-crew" in args:
			# shoo wildlife out of frame, then stage two geared survivors
			for a in world.get_node("Animals").get_children():
				if a.global_position.distance_to(pl.global_position) < 15.0:
					a.queue_free()
			var fits: Array = [
				{},   # fresh castaway: face, hair, id-colored clothes
				{"head": "hide_hood", "torso": "hide_coat", "legs": "hide_pants", "back": "hide_pack"},
				{"head": "scale_helm", "torso": "scale_chest", "legs": "fiber_leggings", "back": "woven_pack"},
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
	columns.add_theme_constant_override("separation", 48)
	center.add_child(columns)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(340, 0)
	box.add_theme_constant_override("separation", 10)
	columns.add_child(box)
	_build_character_panel(columns)

	var title := Label.new()
	title.text = "M A R O O N"
	title.add_theme_font_size_override("font_size", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "you, your friends, and the wilderness"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.6)
	box.add_child(sub)

	box.add_child(HSeparator.new())

	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "world seed (blank = random)"
	box.add_child(seed_edit)

	var host_btn := Button.new()
	host_btn.text = "Host Island"
	host_btn.pressed.connect(_on_host_pressed)
	box.add_child(host_btn)

	box.add_child(HSeparator.new())

	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "friend's IP address"
	box.add_child(ip_edit)

	var join_btn := Button.new()
	join_btn.text = "Join Friend"
	join_btn.pressed.connect(_on_join_pressed)
	box.add_child(join_btn)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.modulate = Color(1, 0.85, 0.6)
	box.add_child(status_label)

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
	_opt_row(you, "Shirt", "shirt", Player.SHIRT_COLORS.size())
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

	# crafting
	p.inv["wood"] = 50
	p.inv["stone"] = 30
	p.inv["string"] = 6
	p.total_gathered["wood"] = 50
	p.total_gathered["stone"] = 30
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
	await get_tree().create_timer(0.2).timeout
	p.craft("iron_bar")
	p.craft("iron_bar")
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
	ok = ok and dwellers.size() == 3
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
	p.inv["wood"] = 30
	p.inv["string"] = p.inv.get("string", 0) + 4
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
	world.sv_place_structure("wall", p.global_position + Vector3(4, 0, 0), 0.0)
	await get_tree().create_timer(0.2).timeout
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
	p.selected_slot = 4
	p._eat()
	print("[smoke] hunger after eating: ", p.hunger)
	ok = ok and p.hunger > 20.0
	await get_tree().create_timer(0.5).timeout
	print("[smoke] goals completed: ", p.hud.goals_done, "/", p.hud.goals.size())
	ok = ok and p.hud.goals_done >= 4

	print("[smoke] ", "ALL PASS" if ok else "FAILURES — see above")
	get_tree().quit(0 if ok else 1)
