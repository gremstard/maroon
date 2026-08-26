class_name Player extends CharacterBody3D
# First-person survivor. Only the owning peer simulates; others interpolate.
# PnPvE rule lives in _swing(): hits on other players are refused by code.

const SPEED := 5.0
const SPRINT := 8.0
const JUMP := 7.0
const GRAVITY := 18.0
const REACH := 3.2

const HOTBAR_SLOTS := 4         # four bindings: tools, placeables, food, torch
const GRID_COLS := 4            # Tarkov-style pack: 4 wide, rows grow with packs
const GRID_BASE_ROWS := 2
const CARRY_BASE := 60          # items carried before weight slows you

var peer_id := 1
var hp := 100.0
var hunger := 100.0
var inv := {"wood": 0, "stone": 0}
var owned_tools := {}           # e.g. {"stone_axe": true}
var equipment := {}             # gear slot -> item, e.g. {"torso": "hide_coat"}
var hotbar_items: Array = ["", "", "", ""]   # bindings by item name; "" = bare hands
var grid_stacks: Array = []     # {item, count, x, y, w, h}; x == -1 means overflow
var selected_slot := 0
var swing_cooldown := 0.0

# progress tracking for the goal ladder
var total_gathered := {}
var crafted := {}
var events := {}                # "kill_wolf", "cooked", "deposited", "wall_built"

var cam: Camera3D
var head: Node3D
var hud: Hud = null
var mesh_holder: Node3D
var _hat_mesh: MeshInstance3D = null
var _pack_mesh: MeshInstance3D = null
var _equip_bcast_accum := 0.0

# box-rig body parts (Unturned-style: flat colors, no textures, code-animated)
var _head_box: MeshInstance3D
var _shirt: MeshInstance3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _leg_mats: Array[StandardMaterial3D] = []
var _boots: Array[MeshInstance3D] = []
var _shirt_color := Color.WHITE
var _pants_color := Color.WHITE
var _walk_prev := Vector3.ZERO
var _walk_phase := 0.0

# remote interpolation
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var _has_net := false
var _sync_accum := 0.0

func is_local() -> bool:
	return multiplayer.multiplayer_peer != null and peer_id == multiplayer.get_unique_id()

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.4
	cs.height = 1.8
	shape.shape = cs
	shape.position.y = 0.9
	add_child(shape)

	mesh_holder = Node3D.new()
	add_child(mesh_holder)
	_build_body()

	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)

	if is_local():
		mesh_holder.visible = false   # first-person: you see the world, friends see you
		cam = Camera3D.new()
		cam.current = true
		head.add_child(cam)
		hud = Hud.new()
		add_child(hud)
		hud.setup(self)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		load_local()
		# your identity, chosen in the menu
		apply_appearance(Profile.appearance_of(Profile.load_profile()))
		rx_appearance.rpc(appearance)
	else:
		_tag = Label3D.new()
		_tag.text = display_name()
		_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_tag.position.y = 2.3
		_tag.font_size = 40
		_tag.pixel_size = 0.004
		add_child(_tag)

func _unhandled_input(event: InputEvent) -> void:
	if not is_local():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.0025
		head.rotation.x = clampf(head.rotation.x - event.relative.y * 0.0025, -1.4, 1.4)
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		if hud:
			hud.toggle_pause()
	if in_build_mode() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("build_rotate"):
			_ghost_rot = (_ghost_rot + 1) % 4
		if event.is_action_pressed("demolish"):
			var hit := _raycast()
			if not hit.is_empty() and hit["collider"] is Node and hit["collider"].has_meta("struct"):
				_world().sv_remove_structure.rpc_id(1, String(hit["collider"].name))
		if event is InputEventMouseButton and event.pressed:
			var n := GameItems.BUILD_PIECES.size()
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				build_index = (build_index + 1) % n
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				build_index = (build_index - 1 + n) % n

func _physics_process(delta: float) -> void:
	if not is_local():
		if _has_net:
			global_position = global_position.lerp(net_pos, minf(1.0, delta * 12.0))
			rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, delta * 12.0))
		_animate_walk(delta)
		return

	swing_cooldown -= delta
	_survival_tick(delta)
	_update_viewmodel()
	_update_ghost()
	if sailing:
		_sail(delta)
		return

	# movement
	var input_dir := Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input_dir = Input.get_vector("mv_left", "mv_right", "mv_fwd", "mv_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := (SPRINT if Input.is_action_pressed("sprint") and hunger > 5.0 else SPEED) * weight_mult()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_pressed("jump"):
		velocity.y = JUMP
	move_and_slide()

	# feel: head bob, footsteps, sprint FOV
	var moving := is_on_floor() and Vector2(velocity.x, velocity.z).length() > 1.0
	if moving:
		var prev_bob := sin(_bob_phase)
		_bob_phase += delta * speed * 1.9
		cam.position.y = sin(_bob_phase) * 0.045
		if prev_bob > -0.9 and sin(_bob_phase) <= -0.9:
			Sfx.play(self, "step", -16.0)
	else:
		cam.position.y = lerpf(cam.position.y, 0.0, delta * 8.0)
	cam.fov = lerpf(cam.fov, 82.0 if speed > SPEED + 0.5 and moving else 75.0, delta * 6.0)

	# actions
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		for i in HOTBAR_SLOTS:
			if Input.is_action_just_pressed("slot_%d" % (i + 1)):
				selected_slot = i
		if Input.is_action_just_pressed("attack"):
			_use_selected()
		if Input.is_action_just_pressed("interact"):
			_interact()
	if Input.is_action_just_pressed("craft_menu") and hud:
		hud.toggle_craft()

	# replicate
	_sync_accum += delta
	if _sync_accum >= 0.05 and multiplayer.multiplayer_peer != null:
		_sync_accum = 0.0
		rx_state.rpc(global_position, rotation.y, sailing)

# ---------------------------------------------------------------- building

const GHOST_SHAPES := {
	"foundation": [Vector3(3, 0.5, 3), Vector3(0, -0.25, 0)],
	"floor":      [Vector3(3, 0.22, 3), Vector3(0, 0.11, 0)],
	"roof":       [Vector3(3.3, 0.22, 3.3), Vector3(0, 0.11, 0)],
	"wall":       [Vector3(3, 2.6, 0.22), Vector3(0, 1.3, 0)],
	"half_wall":  [Vector3(3, 1.3, 0.22), Vector3(0, 0.65, 0)],
	"doorway":    [Vector3(3, 2.6, 0.22), Vector3(0, 1.3, 0)],
	"window":     [Vector3(3, 2.6, 0.22), Vector3(0, 1.3, 0)],
	"gable":      [Vector3(3, 1.5, 0.22), Vector3(0, 0.75, 0)],
	"slope":      [Vector3(3, 1.5, 3), Vector3(0, 0.75, 0)],
	"hatched":    [Vector3(3.4, 1.5, 3.4), Vector3(0, 0.75, 0)],
	"door":       [Vector3(1.16, 2.15, 0.09), Vector3(0.58, 1.1, 0)],
	"shutter":    [Vector3(1.16, 1.0, 0.07), Vector3(0.58, 1.5, 0)],
}

var build_index := 0
var _ghost: MeshInstance3D = null
var _ghost_kind := ""
var _ghost_valid := false
var _ghost_pos := Vector3.ZERO
var _ghost_yaw := 0.0
var _ghost_rot := 0

func build_piece_name() -> String:
	return GameItems.BUILD_PIECES.keys()[build_index]

func in_build_mode() -> bool:
	return held_item() == "hammer" and owned_tools.has("hammer")

func _update_ghost() -> void:
	if _ghost and not in_build_mode():
		_ghost.visible = false
		return
	if not in_build_mode():
		return
	var kind := build_piece_name()
	if _ghost == null or _ghost_kind != kind:
		if _ghost:
			_ghost.queue_free()
		_ghost_kind = kind
		_ghost = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = GHOST_SHAPES[kind][0]
		_ghost.mesh = bm
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ghost.material_override = m
		var pivot := Node3D.new()
		pivot.add_child(_ghost)
		_ghost.position = GHOST_SHAPES[kind][1]
		_world().add_child(pivot)
	var hit := _raycast()
	_ghost_valid = not hit.is_empty() and _compute_ghost(kind, hit)
	if inv.get("wood", 0) < int(GameItems.BUILD_PIECES[kind]["wood"]):
		_ghost_valid = false
	var pivot2 := _ghost.get_parent() as Node3D
	pivot2.global_position = _ghost_pos
	pivot2.rotation.y = _ghost_yaw
	_ghost.visible = not hit.is_empty()
	var mat: StandardMaterial3D = _ghost.material_override
	mat.albedo_color = Color(0.3, 1.0, 0.4, 0.4) if _ghost_valid else Color(1.0, 0.25, 0.2, 0.4)

func _piece_at(pos: Vector3, kind: String) -> bool:
	for s in _world().get_node("Structures").get_children():
		if s.get_meta("kind") == kind and s.global_position.distance_to(pos) < 0.6:
			return true
	return false

func _snap3(v: float) -> float:
	return roundf(v / 3.0) * 3.0

func _compute_ghost(kind: String, hit: Dictionary) -> bool:
	var col: Object = hit["collider"]
	var hpos: Vector3 = hit["position"]
	var w := _world()
	_ghost_yaw = 0.0
	if kind == "foundation":
		if col is Node and col.has_meta("struct") and col.get_meta("kind") == "foundation":
			# extend from an existing foundation toward where you're aiming
			var base := col as Node3D
			var d := hpos - base.global_position
			var off := Vector3(3, 0, 0) * signf(d.x) if absf(d.x) > absf(d.z) else Vector3(0, 0, 3) * signf(d.z)
			_ghost_pos = base.global_position + off
			return not _piece_at(_ghost_pos, "foundation")
		if col is Node and (col.has_meta("struct") or col.has_meta("res") or col.has_meta("animal")):
			return false
		var cx := _snap3(hpos.x)
		var cz := _snap3(hpos.z)
		var top := -99.0
		var lo := 99.0
		for corner in [Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(1.5, 1.5), Vector2(-1.5, 1.5)]:
			var h := w.height_at(cx + corner.x, cz + corner.y)
			top = maxf(top, h)
			lo = minf(lo, h)
		if lo < 0.3 or top - lo > 2.2:
			return false
		_ghost_pos = Vector3(cx, top + 0.3, cz)
		return not _piece_at(_ghost_pos, "foundation")
	if kind == "door" or kind == "shutter":
		var want := "doorway" if kind == "door" else "window"
		if col is Node and col.has_meta("struct") and col.get_meta("kind") == want:
			var frame := col as Node3D
			_ghost_pos = frame.global_position + frame.global_transform.basis.x * -0.6
			_ghost_yaw = frame.rotation.y
			return not _piece_at(_ghost_pos, kind)
		return false
	# everything else builds off an existing piece
	if not (col is Node and col.has_meta("struct")):
		return false
	var base2 := col as Node3D
	var bkind: String = base2.get_meta("kind")
	var cell_x: float
	var cell_z: float
	var level_y: float
	if bkind == "foundation" or bkind == "floor":
		if bkind == "floor" and kind in ["floor", "roof", "slope", "hatched"]:
			# extend sideways at the same level
			var d2 := hpos - base2.global_position
			var off2 := Vector3(3, 0, 0) * signf(d2.x) if absf(d2.x) > absf(d2.z) else Vector3(0, 0, 3) * signf(d2.z)
			_ghost_pos = base2.global_position + off2
			_ghost_yaw = _ghost_rot * PI / 2.0
			return not _piece_at(_ghost_pos, kind)
		cell_x = base2.global_position.x
		cell_z = base2.global_position.z
		level_y = base2.global_position.y + (0.22 if bkind == "floor" else 0.0)
	elif bkind in ["wall", "doorway", "window", "half_wall", "gable"]:
		var n := base2.global_transform.basis.z
		var side := -1.0 if n.dot(global_position - base2.global_position) > 0.0 else 1.0
		cell_x = _snap3(base2.global_position.x + n.x * 1.5 * side)
		cell_z = _snap3(base2.global_position.z + n.z * 1.5 * side)
		level_y = base2.global_position.y + (1.3 if bkind == "half_wall" else 2.6)
	else:
		return false
	if kind in ["floor", "roof", "slope", "hatched"]:
		if bkind == "foundation":
			return false   # the foundation already is your floor
		_ghost_pos = Vector3(cell_x, level_y, cell_z)
		_ghost_yaw = _ghost_rot * PI / 2.0
		return not _piece_at(_ghost_pos, kind)
	# wall family: snap to the cell edge you're aiming at
	var lx := hpos.x - cell_x
	var lz := hpos.z - cell_z
	if absf(lx) > absf(lz):
		_ghost_pos = Vector3(cell_x + 1.5 * signf(lx), level_y, cell_z)
		_ghost_yaw = PI / 2.0
	else:
		_ghost_pos = Vector3(cell_x, level_y, cell_z + 1.5 * signf(lz))
		_ghost_yaw = 0.0
	return not _piece_at(_ghost_pos, kind)

func _try_place_piece() -> void:
	if not owned_tools.has("hammer"):
		if hud:
			hud.flash("Craft a Hammer first (Tab) — then build straight from wood.")
		return
	if not _ghost_valid:
		if hud:
			hud.flash("Can't build there. Foundations go on open ground; the rest snaps to them.")
		return
	var kind := build_piece_name()
	inv["wood"] -= int(GameItems.BUILD_PIECES[kind]["wood"])
	if kind in ["wall", "half_wall", "doorway", "window", "gable"]:
		events["wall_built"] = events.get("wall_built", 0) + 1
	_world().sv_place_structure.rpc_id(1, kind, _ghost_pos, _ghost_yaw)

# ---------------------------------------------------------------- sailing

var sailing := false
var _raft_visual: Node3D = null

func _sail(delta: float) -> void:
	# On the raft: glide over water, beach on shallows. E hops off in shallows.
	var input_dir := Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input_dir = Input.get_vector("mv_left", "mv_right", "mv_fwd", "mv_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	global_position += dir * 5.0 * delta
	global_position.y = 0.32 + sin(Time.get_ticks_msec() * 0.002) * 0.05
	velocity = Vector3.ZERO
	var ground := _world().height_at(global_position.x, global_position.z)
	if ground > 0.45:
		_set_sailing(false)
		if hud:
			hud.flash("The raft grinds onto the sand.")
	if Input.is_action_just_pressed("interact"):
		if ground > 0.0:
			_set_sailing(false)
		elif hud:
			hud.flash("Too deep to swim — steer for the shallows first.")
	if Input.is_action_just_pressed("craft_menu") and hud:
		hud.toggle_craft()
	_sync_accum += delta
	if _sync_accum >= 0.05 and multiplayer.multiplayer_peer != null:
		_sync_accum = 0.0
		rx_state.rpc(global_position, rotation.y, sailing)

func _set_sailing(on: bool) -> void:
	sailing = on
	_update_raft_visual()

func _update_raft_visual() -> void:
	if _raft_visual == null:
		_raft_visual = Node3D.new()
		add_child(_raft_visual)
		var wood := Color(0.42, 0.30, 0.17)
		var sizes := [
			[Vector3(2.2, 0.22, 3.0), wood, Vector3(0, 0.05, 0)],
			[Vector3(0.3, 0.3, 3.2), wood.darkened(0.25), Vector3(-1.1, 0.05, 0)],
			[Vector3(0.3, 0.3, 3.2), wood.darkened(0.25), Vector3(1.1, 0.05, 0)],
		]
		for s in sizes:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = s[0]
			mi.mesh = bm
			mi.material_override = _flat(s[1])
			mi.position = s[2]
			_raft_visual.add_child(mi)
	_raft_visual.visible = sailing

var _torch_light: OmniLight3D = null

func _survival_tick(delta: float) -> void:
	reconcile_grid()
	# a held torch pushes back the night (and the dwellers)
	var torch_out: bool = held_item() == "torch" and inv.get("torch", 0) > 0
	if torch_out and _torch_light == null:
		_torch_light = OmniLight3D.new()
		_torch_light.light_color = Color(1.0, 0.7, 0.3)
		_torch_light.omni_range = 8.0
		_torch_light.light_energy = 1.4
		_torch_light.position.y = 1.6
		add_child(_torch_light)
	if _torch_light:
		_torch_light.visible = torch_out
	_psave_accum += delta
	if _psave_accum >= 60.0:
		_psave_accum = 0.0
		save_local()
	if events.get("entered_cave", 0) == 0 and _world() != null \
			and _world().cave_pos != Vector3.ZERO \
			and global_position.distance_to(_world().cave_pos) < 9.0:
		events["entered_cave"] = 1
		Sfx.play(self, "howl", -10.0)
		if hud:
			hud.flash("The Sea Cave. Something skitters in the dark —\nkeep a torch burning.")
	if events.get("entered_far_isle", 0) == 0 and _world() != null:
		var fc: Vector2 = _world().far_center
		if fc != Vector2.ZERO and Vector2(global_position.x - fc.x, global_position.z - fc.y).length() < _world().FAR_R * 0.8 \
				and _world().height_at(global_position.x, global_position.z) > 0.5:
			events["entered_far_isle"] = 1
			Sfx.play(self, "chime", -6.0)
			if hud:
				hud.flash("The Far Isle. Richer veins, hungrier things —\nand a dark stone standing at its heart.")
	_equip_bcast_accum += delta
	if _equip_bcast_accum >= 5.0:
		_equip_bcast_accum = 0.0
		if not equipment.is_empty():
			rx_equip.rpc(equipment)      # late joiners see your gear
		if not appearance.is_empty():
			rx_appearance.rpc(appearance)   # ...and your face
	hunger = maxf(hunger - delta * 100.0 / 480.0, 0.0)   # empty in ~8 min
	if hunger <= 0.0:
		hp -= delta * 2.0
	elif hunger > 70.0 and hp < 100.0:
		hp = minf(hp + delta * 1.5, 100.0)
	if hp <= 0.0:
		_respawn()

func _respawn() -> void:
	hp = 100.0
	hunger = 60.0
	var w := _world()
	if w:
		global_position = w.get_spawn_pos(peer_id)
	velocity = Vector3.ZERO
	if hud:
		hud.flash("You washed back up on the beach.")

# ---------------------------------------------------------------- actions

func _world() -> World:
	var n := get_node_or_null("/root/Main/World")
	return n as World

func current_tool() -> String:
	var held := held_item()
	return held if GameItems.TOOL_STATS.has(held) else "hand"

func held_item() -> String:
	return hotbar_items[selected_slot]

func set_hotbar(slot: int, item: String) -> void:
	hotbar_items[slot] = item

func _auto_hotbar(item: String) -> void:
	# A fresh craft jumps into your hands if there's room for it.
	var bindable := GameItems.TOOL_STATS.has(item) or item == "hammer" \
		or item in GameItems.PLACEABLES or item in GameItems.FOODS
	if not bindable or item in hotbar_items:
		# upgraded tool replaces its lesser cousin in place
		for cat in ["axe", "pick", "spear"]:
			if item == best_tool(cat):
				for i in HOTBAR_SLOTS:
					if hotbar_items[i] != item and hotbar_items[i].ends_with(cat):
						hotbar_items[i] = item
		return
	for i in HOTBAR_SLOTS:
		if hotbar_items[i] == "":
			hotbar_items[i] = item
			return

func best_tool(category: String) -> String:
	var ladder: Array = {
		"axe": ["iron_axe", "stone_axe", "crude_axe"],
		"pick": ["iron_pick", "stone_pick", "crude_pick"],
		"spear": ["iron_spear", "spear"],
	}.get(category, [])
	for t in ladder:
		if owned_tools.has(t):
			return t
	return ""

# ---------------------------------------------------------------- grid pack

func grid_rows() -> int:
	var rows := GRID_BASE_ROWS
	if equipment.get("back", "") == "woven_pack":
		rows += 1
	elif equipment.get("back", "") == "hide_pack":
		rows += 2
	return rows

func _cell_free(x: int, y: int, w: int, h: int, ignore: int = -1) -> bool:
	if x < 0 or y < 0 or x + w > GRID_COLS or y + h > grid_rows():
		return false
	for i in grid_stacks.size():
		if i == ignore:
			continue
		var s: Dictionary = grid_stacks[i]
		if s["x"] < 0:
			continue
		if x < s["x"] + s["w"] and x + w > s["x"] and y < s["y"] + s["h"] and y + h > s["y"]:
			return false
	return true

func _find_spot(item: String) -> Array:
	# Returns [x, y, w, h] or [] if the pack is full. Tries both rotations.
	var size := GameItems.grid_size(item)
	for y in grid_rows():
		for x in GRID_COLS:
			if _cell_free(x, y, size.x, size.y):
				return [x, y, size.x, size.y]
			if size.x != size.y and _cell_free(x, y, size.y, size.x):
				return [x, y, size.y, size.x]
	return []

func can_fit(item: String) -> bool:
	for s in grid_stacks:
		if s["item"] == item and s["count"] < GameItems.stack_max(item):
			return true
	return not _find_spot(item).is_empty()

func reconcile_grid() -> void:
	# The counts in `inv` are the truth; the grid is how you carry them.
	for s in grid_stacks:
		s["_want"] = 0
	for item in inv:
		var remaining: int = inv[item]
		for s in grid_stacks:
			if s["item"] != item or remaining <= 0:
				continue
			var take: int = mini(remaining, GameItems.stack_max(item))
			s["_want"] = take
			remaining -= take
		while remaining > 0:
			var take2: int = mini(remaining, GameItems.stack_max(item))
			var spot := _find_spot(item)
			if spot.is_empty():
				grid_stacks.append({"item": item, "count": take2, "_want": take2, "x": -1, "y": -1, "w": 1, "h": 1})
			else:
				grid_stacks.append({"item": item, "count": take2, "_want": take2, "x": spot[0], "y": spot[1], "w": spot[2], "h": spot[3]})
			remaining -= take2
	for i in range(grid_stacks.size() - 1, -1, -1):
		var s2: Dictionary = grid_stacks[i]
		s2["count"] = s2.get("_want", 0)
		s2.erase("_want")
		if s2["count"] <= 0:
			grid_stacks.remove_at(i)
	# overflow stacks keep trying to come home
	for s3 in grid_stacks:
		if s3["x"] < 0:
			var spot2 := _find_spot(s3["item"])
			if not spot2.is_empty():
				s3["x"] = spot2[0]
				s3["y"] = spot2[1]
				s3["w"] = spot2[2]
				s3["h"] = spot2[3]

# ---------------------------------------------------------------- box-rig body

const SKIN_TONES := [
	Color(0.93, 0.78, 0.62), Color(0.87, 0.70, 0.53), Color(0.76, 0.57, 0.40),
	Color(0.60, 0.42, 0.28), Color(0.45, 0.30, 0.20),
]
const HAIR_COLORS := [
	Color(0.18, 0.13, 0.09), Color(0.35, 0.22, 0.10), Color(0.55, 0.42, 0.22),
	Color(0.75, 0.65, 0.45), Color(0.30, 0.30, 0.32), Color(0.50, 0.20, 0.10),
]

func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# A box whose top face can be a different size than its bottom — the taper is
# what separates an Unturned silhouette from a Minecraft one. Flat normals.
func _tapered_mesh(bw: float, bd: float, tw: float, td: float, h: float) -> ArrayMesh:
	var b := [Vector3(-bw, 0, -bd), Vector3(bw, 0, -bd), Vector3(bw, 0, bd), Vector3(-bw, 0, bd)]
	var t := [Vector3(-tw, h, -td), Vector3(tw, h, -td), Vector3(tw, h, td), Vector3(-tw, h, td)]
	var quads := [
		[b[0], b[1], t[1], t[0]], [b[1], b[2], t[2], t[1]],
		[b[2], b[3], t[3], t[2]], [b[3], b[0], t[0], t[3]],
		[t[0], t[1], t[2], t[3]], [b[3], b[2], b[1], b[0]],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in quads:
		var n: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.add_vertex(q[idx])
	return st.commit()

func _tbox(bw: float, bd: float, tw: float, td: float, h: float, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _tapered_mesh(bw, bd, tw, td, h)
	mi.material_override = _flat(c)
	mi.position = pos
	mesh_holder.add_child(mi)
	return mi

func _box(size: Vector3, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _flat(c)
	mi.position = pos
	mesh_holder.add_child(mi)
	return mi

func _limb(bw: float, bd: float, tw: float, td: float, len_: float, c: Color, pivot_pos: Vector3) -> Node3D:
	# Pivot node at the joint; the tapered mesh hangs below it (wide end up).
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	mesh_holder.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.name = "sleeve"
	mi.mesh = _tapered_mesh(bw, bd, tw, td, len_)
	mi.material_override = _flat(c)
	mi.position.y = -len_
	pivot.add_child(mi)
	return pivot

var _hair: MeshInstance3D = null
var _skin_color := Color.WHITE
var _tag: Label3D = null
var appearance := {}            # chosen in the menu; empty = rolled from peer_id

const SHIRT_COLORS := [
	Color(0.55, 0.25, 0.30), Color(0.25, 0.45, 0.30), Color(0.30, 0.40, 0.60),
	Color(0.70, 0.55, 0.25), Color(0.45, 0.30, 0.55), Color(0.75, 0.72, 0.65),
	Color(0.25, 0.25, 0.28), Color(0.70, 0.40, 0.20),
]

func display_name() -> String:
	return String(appearance.get("name", "")) if appearance.get("name", "") != "" else "survivor %d" % peer_id

func apply_appearance(ap: Dictionary) -> void:
	appearance = ap
	for c in mesh_holder.get_children():
		c.queue_free()
	_hat_mesh = null
	_pack_mesh = null
	_hair = null
	_held = null
	_build_body()
	_refresh_gear_visuals()
	if _tag:
		_tag.text = display_name()

@rpc("any_peer", "call_local", "reliable")
func rx_appearance(ap: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() not in [0, peer_id]:
		return   # only the owner shapes this survivor
	if ap.hash() != appearance.hash():
		apply_appearance(ap)

func _build_body() -> void:
	# Unturned-style box-rig: untextured flat colors (never pixel textures —
	# that's what makes Minecraft read as Minecraft), tapered segments, a
	# simple geometric face. Appearance comes from the menu character creator;
	# anything unset is rolled deterministically from the peer id.
	_skin_color = SKIN_TONES[int(appearance.get("skin", peer_id)) % SKIN_TONES.size()]
	var hair_c: Color = HAIR_COLORS[int(appearance.get("hair_color", peer_id * 7 + 3)) % HAIR_COLORS.size()]
	var hair_style := int(appearance.get("hair_style", 0))   # 0 short, 1 long, 2 bald
	var has_beard: bool = appearance.get("beard", (peer_id * 13) % 3 == 0)
	# You wash ashore in your underwear. Everything else is crafted.
	_shirt_color = _skin_color
	_pants_color = _skin_color

	# torso: bare skin until you weave something
	_shirt = _tbox(0.26, 0.15, 0.32, 0.18, 0.64, _skin_color, Vector3(0, 0.88, 0))
	_box(Vector3(0.52, 0.26, 0.36), Color(0.42, 0.44, 0.48), Vector3(0, 0.90, 0))   # the shorts
	# head + face
	_head_box = _box(Vector3(0.44, 0.44, 0.42), _skin_color, Vector3(0, 1.76, 0))
	var eye_c := Color(0.13, 0.11, 0.09)
	_box(Vector3(0.075, 0.09, 0.02), eye_c, Vector3(-0.10, 1.80, -0.215))
	_box(Vector3(0.075, 0.09, 0.02), eye_c, Vector3(0.10, 1.80, -0.215))
	_box(Vector3(0.14, 0.045, 0.02), eye_c.lightened(0.15), Vector3(0, 1.64, -0.215))
	# hair: cap + back panel (length by style), optional beard
	if hair_style != 2:
		_hair = _box(Vector3(0.48, 0.14, 0.46), hair_c, Vector3(0, 2.02, 0.01))
		var hair_back := MeshInstance3D.new()
		var hbm := BoxMesh.new()
		hbm.size = Vector3(0.48, 0.30 if hair_style == 0 else 0.72, 0.10)
		hair_back.mesh = hbm
		hair_back.material_override = _flat(hair_c)
		hair_back.position = Vector3(0, -0.18 if hair_style == 0 else -0.39, 0.19)
		_hair.add_child(hair_back)
	if has_beard:
		_box(Vector3(0.32, 0.12, 0.03), hair_c, Vector3(0, 1.57, -0.21))
	# arms: sleeve tapers to the wrist, skin hands
	_arm_l = _limb(0.075, 0.075, 0.09, 0.09, 0.52, _skin_color, Vector3(-0.41, 1.46, 0))
	_arm_r = _limb(0.075, 0.075, 0.09, 0.09, 0.52, _skin_color, Vector3(0.41, 1.46, 0))
	for arm in [_arm_l, _arm_r]:
		var hand := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.14, 0.14, 0.14)
		hand.mesh = hm
		hand.material_override = _flat(_skin_color)
		hand.position.y = -0.58
		arm.add_child(hand)
	# legs: slight taper to the ankle, dark boots
	_leg_l = _limb(0.095, 0.10, 0.115, 0.12, 0.76, _skin_color, Vector3(-0.14, 0.88, 0))
	_leg_r = _limb(0.095, 0.10, 0.115, 0.12, 0.76, _skin_color, Vector3(0.14, 0.88, 0))
	_leg_mats.clear()
	_boots.clear()
	for leg in [_leg_l, _leg_r]:
		for c in leg.get_children():
			if c is MeshInstance3D:
				_leg_mats.append(c.material_override)
		var boot := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.22, 0.14, 0.32)
		boot.mesh = bm
		boot.material_override = _flat(Color(0.20, 0.16, 0.12))
		boot.position = Vector3(0, -0.82, -0.04)
		boot.visible = false   # boots come with leg gear
		leg.add_child(boot)
		_boots.append(boot)

func _animate_walk(delta: float) -> void:
	if is_local():
		return   # nobody sees your own body in first person
	var speed := (global_position - _walk_prev).length() / maxf(delta, 0.001)
	_walk_prev = global_position
	var stride := clampf(speed / SPEED, 0.0, 1.6)
	_walk_phase += delta * 9.0 * maxf(stride, 0.01)
	var swing := sin(_walk_phase) * 0.7 * stride
	_arm_l.rotation.x = swing
	_arm_r.rotation.x = -swing
	_leg_l.rotation.x = -swing
	_leg_r.rotation.x = swing

# ---------------------------------------------------------------- viewmodel

var _viewmodel: Node3D = null
var _vm_key := "-"
var _bob_phase := 0.0

const TOOL_MATERIAL_COLORS := {
	"crude": Color(0.55, 0.55, 0.57), "stone": Color(0.45, 0.45, 0.47),
	"iron": Color(0.75, 0.78, 0.82), "spear": Color(0.45, 0.45, 0.47),
}

func _vm_box(parent: Node3D, size: Vector3, c: Color, pos: Vector3, rot_x_deg := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _flat(c)
	mi.position = pos
	mi.rotation_degrees.x = rot_x_deg
	parent.add_child(mi)

func _update_viewmodel() -> void:
	# First-person held tool, bottom right — built from boxes like everything.
	if cam == null:
		return
	var tool := held_item()
	var key := tool
	if key == _vm_key:
		return
	_vm_key = key
	held_net = tool
	if multiplayer.multiplayer_peer != null:
		rx_tool.rpc(tool)   # others see what you're holding
	if _viewmodel:
		_viewmodel.queue_free()
	_viewmodel = Node3D.new()
	cam.add_child(_viewmodel)
	_viewmodel.position = Vector3(0.28, -0.24, -0.5)
	_viewmodel.scale = Vector3.ONE * 0.8
	var wood := Color(0.42, 0.30, 0.17)
	var head_c: Color = TOOL_MATERIAL_COLORS.get(tool.get_slice("_", 0), Color(0.5, 0.5, 0.5))
	_vm_box(_viewmodel, Vector3(0.06, 0.06, 0.22), _skin_color, Vector3(0, -0.03, 0.05), -20)   # forearm/hand
	if tool == "torch":
		_vm_box(_viewmodel, Vector3(0.05, 0.05, 0.4), wood, Vector3(0, 0.06, -0.1), -50)
		var flame := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.07
		fm.height = 0.15
		flame.mesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(1.0, 0.75, 0.2)
		fmat.emission_enabled = true
		fmat.emission = Color(1.0, 0.65, 0.15)
		fmat.emission_energy_multiplier = 3.0
		flame.material_override = fmat
		flame.position = Vector3(0, 0.32, -0.26)
		_viewmodel.add_child(flame)
		return
	if tool == "hammer":
		_vm_box(_viewmodel, Vector3(0.045, 0.045, 0.34), wood, Vector3(0, 0.03, -0.1), -35)
		_vm_box(_viewmodel, Vector3(0.1, 0.1, 0.14), Color(0.45, 0.45, 0.48), Vector3(0, 0.16, -0.26), -35)
		return
	if not GameItems.TOOL_STATS.has(tool):
		return
	# all tool parts share one tilted root so they stay attached
	var tool_root := Node3D.new()
	tool_root.position = Vector3(0, 0.0, -0.02)
	tool_root.rotation_degrees.x = -35
	_viewmodel.add_child(tool_root)
	var part := func(size: Vector3, c: Color, pos: Vector3) -> void:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = _flat(c)
		mi.position = pos
		tool_root.add_child(mi)
	if tool.ends_with("axe"):
		part.call(Vector3(0.04, 0.04, 0.42), wood, Vector3(0, 0, -0.10))
		part.call(Vector3(0.04, 0.15, 0.10), head_c, Vector3(0, 0.05, -0.29))
	elif tool.ends_with("pick"):
		part.call(Vector3(0.04, 0.04, 0.42), wood, Vector3(0, 0, -0.10))
		part.call(Vector3(0.04, 0.05, 0.30), head_c, Vector3(0, 0.05, -0.29))
	elif tool.ends_with("spear"):
		part.call(Vector3(0.035, 0.035, 0.72), wood, Vector3(0, 0, -0.22))
		part.call(Vector3(0.045, 0.045, 0.12), head_c, Vector3(0, 0, -0.62))

func _swing_feel(hit_sound: String, hit_pos: Variant) -> void:
	Sfx.play(self, "whoosh", -10.0)
	if _viewmodel:
		# wind up slightly, then a fast diagonal chop with eased recovery
		_viewmodel.rotation_degrees = Vector3.ZERO
		_viewmodel.position = Vector3(0.28, -0.24, -0.5)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_viewmodel, "rotation_degrees:x", 14.0, 0.05).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(_viewmodel, "rotation_degrees:x", -72.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_viewmodel, "rotation_degrees:z", 18.0, 0.08)
		tw.parallel().tween_property(_viewmodel, "position:y", -0.30, 0.08)
		tw.chain().tween_property(_viewmodel, "rotation_degrees", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_viewmodel, "position", Vector3(0.28, -0.24, -0.5), 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hit_sound != "" and hit_pos is Vector3:
		Sfx.play_at(_world(), hit_pos, hit_sound, -4.0)
		var tw2 := create_tween()
		cam.rotation.x = 0.025
		tw2.tween_property(cam, "rotation:x", 0.0, 0.12)
	rx_swing_fx.rpc()

var _held: Node3D = null

var held_net := ""   # what this survivor is holding, as others know it

@rpc("any_peer", "call_remote", "reliable")
func rx_tool(tool: String) -> void:
	# Third-person held tool, gripped in the right hand.
	if multiplayer.get_remote_sender_id() != peer_id or _arm_r == null:
		return
	held_net = tool
	if _held:
		_held.queue_free()
		_held = null
	if tool == "hand":
		return
	_held = Node3D.new()
	_arm_r.add_child(_held)
	_held.position = Vector3(0, -0.62, 0)
	_held.rotation_degrees.x = -90   # held forward
	var wood := Color(0.42, 0.30, 0.17)
	var head_c: Color = TOOL_MATERIAL_COLORS.get(tool.get_slice("_", 0), Color(0.5, 0.5, 0.5))
	var part := func(size: Vector3, c: Color, pos: Vector3) -> void:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = _flat(c)
		mi.position = pos
		_held.add_child(mi)
	if tool.ends_with("axe"):
		part.call(Vector3(0.05, 0.55, 0.05), wood, Vector3(0, 0.18, 0))
		part.call(Vector3(0.05, 0.13, 0.18), head_c, Vector3(0, 0.42, 0.07))
	elif tool.ends_with("pick"):
		part.call(Vector3(0.05, 0.55, 0.05), wood, Vector3(0, 0.18, 0))
		part.call(Vector3(0.05, 0.06, 0.40), head_c, Vector3(0, 0.42, 0))
	elif tool.ends_with("spear"):
		part.call(Vector3(0.045, 0.95, 0.045), wood, Vector3(0, 0.3, 0))
		part.call(Vector3(0.055, 0.16, 0.055), head_c, Vector3(0, 0.82, 0))
	elif tool == "torch":
		part.call(Vector3(0.05, 0.5, 0.05), wood, Vector3(0, 0.15, 0))
		var tf := MeshInstance3D.new()
		var tfm2 := SphereMesh.new()
		tfm2.radius = 0.08
		tfm2.height = 0.18
		tf.mesh = tfm2
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(1.0, 0.75, 0.2)
		tmat.emission_enabled = true
		tmat.emission = Color(1.0, 0.65, 0.15)
		tmat.emission_energy_multiplier = 3.0
		tf.material_override = tmat
		tf.position = Vector3(0, 0.44, 0)
		_held.add_child(tf)
		var tl := OmniLight3D.new()
		tl.light_color = Color(1.0, 0.7, 0.3)
		tl.omni_range = 7.0
		tl.position = Vector3(0, 0.44, 0)
		_held.add_child(tl)
	elif tool == "hammer":
		part.call(Vector3(0.05, 0.4, 0.05), wood, Vector3(0, 0.12, 0))
		part.call(Vector3(0.11, 0.12, 0.15), Color(0.45, 0.45, 0.48), Vector3(0, 0.34, 0))

@rpc("any_peer", "call_remote", "unreliable")
func rx_swing_fx() -> void:
	# Another survivor swings: their right arm arcs, and you hear it.
	if multiplayer.get_remote_sender_id() != peer_id or _arm_r == null:
		return
	_arm_r.rotation.x = 0
	var tw := create_tween()
	tw.tween_property(_arm_r, "rotation:x", -2.2, 0.08)
	tw.tween_property(_arm_r, "rotation:x", 0.0, 0.22)
	Sfx.play_at(self, global_position + Vector3(0, 1.4, 0), "whoosh", -12.0)

# ---------------------------------------------------------------- gear & weight

func armor_total() -> float:
	var total := 0.0
	for gear_slot in equipment:
		total += GameItems.CLOTHES[equipment[gear_slot]].get("armor", 0.0)
	return minf(total, GameItems.ARMOR_CAP)

func carry_cap() -> int:
	var cap := CARRY_BASE
	for gear_slot in equipment:
		cap += GameItems.CLOTHES[equipment[gear_slot]].get("carry", 0)
	return cap

func carry_weight() -> int:
	var w := 0
	for item in inv:
		w += maxi(inv[item], 0)
	return w

func weight_mult() -> float:
	# Weight is a speed disadvantage only, never a hard cap.
	var over := carry_weight() - carry_cap()
	if over <= 0:
		return 1.0
	return clampf(1.0 - 0.3 * float(over) / float(carry_cap()), 0.7, 1.0)

func _near_struct(kind: String, dist: float) -> bool:
	for s in _world().get_node("Structures").get_children():
		if s.get_meta("kind") == kind and s.global_position.distance_to(global_position) < dist:
			return true
	return false

func _try_equip(item: String) -> void:
	var stats: Dictionary = GameItems.CLOTHES[item]
	var gear_slot: String = stats["gear_slot"]
	var score: float = stats.get("armor", 0.0) * 100.0 + stats.get("carry", 0)
	var current_score := -1.0
	if equipment.has(gear_slot):
		var cur: Dictionary = GameItems.CLOTHES[equipment[gear_slot]]
		current_score = cur.get("armor", 0.0) * 100.0 + cur.get("carry", 0)
	if score > current_score:
		equipment[gear_slot] = item
		if hud:
			hud.flash("Equipped %s. Armor %d%%, carry %d." % [GameItems.nice(item), int(armor_total() * 100), carry_cap()])
		rx_equip.rpc(equipment)
	elif hud:
		hud.flash("%s is no better than what you're wearing." % GameItems.nice(item))

@rpc("any_peer", "call_local", "reliable")
func rx_equip(eq: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() not in [0, peer_id]:
		return   # only the owner dresses this survivor
	equipment = eq
	_refresh_gear_visuals()

func _refresh_gear_visuals() -> void:
	# Since there's no chat, your look IS your name: gear shows on your body.
	if _shirt == null:
		return
	var torso_c := _skin_color   # bare until dressed
	if equipment.has("torso"):
		torso_c = GameItems.TIER_COLORS[GameItems.CLOTHES[equipment["torso"]]["tier"]]
	_shirt.material_override.albedo_color = torso_c
	for arm in [_arm_l, _arm_r]:
		arm.get_node("sleeve").material_override.albedo_color = torso_c
	var legs_c := _skin_color
	if equipment.has("legs"):
		legs_c = GameItems.TIER_COLORS[GameItems.CLOTHES[equipment["legs"]]["tier"]].darkened(0.25)
	for lm in _leg_mats:
		lm.albedo_color = legs_c
	for boot in _boots:
		boot.visible = equipment.has("legs")
	if equipment.has("head") and _hat_mesh == null:
		# brimmed cap: crown + wider brim, replaces hair
		_hat_mesh = _box(Vector3(0.40, 0.20, 0.40), Color.WHITE, Vector3(0, 2.08, 0))
		var brim := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.62, 0.05, 0.62)
		brim.mesh = bm
		brim.material_override = _hat_mesh.material_override
		brim.position.y = -0.1
		_hat_mesh.add_child(brim)
	if _hat_mesh and equipment.has("head"):
		_hat_mesh.material_override.albedo_color = GameItems.TIER_COLORS[GameItems.CLOTHES[equipment["head"]]["tier"]]
	if _hair:
		_hair.visible = not equipment.has("head")
	if equipment.has("back") and _pack_mesh == null:
		_pack_mesh = _box(Vector3(0.40, 0.52, 0.22), Color.WHITE, Vector3(0, 1.18, 0.28))
	if _pack_mesh and equipment.has("back"):
		_pack_mesh.material_override.albedo_color = GameItems.TIER_COLORS[GameItems.CLOTHES[equipment["back"]]["tier"]].darkened(0.2)

func _raycast() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from + (-cam.global_transform.basis.z) * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	return space.intersect_ray(q)

func _use_selected() -> void:
	var held := held_item()
	if held == "hammer":
		_try_place_piece()
		return
	if held in GameItems.FOODS:
		_eat(held)
		return
	if held in GameItems.PLACEABLES:
		_place(held)
		return
	_swing()   # tools and bare hands

func _swing() -> void:
	if swing_cooldown > 0.0:
		return
	swing_cooldown = 0.5
	var hit := _raycast()
	if hit.is_empty():
		_swing_feel("", null)
		return
	var col: Object = hit["collider"]
	var w := _world()
	if col is Player:
		# ---- THE RULE. PnPvE: survivors cannot harm survivors. ----
		_swing_feel("", null)
		if hud:
			hud.flash("Survivors can't be harmed. You're in this together.")
		return
	if col is Node and col.has_meta("animal"):
		var stats: Dictionary = GameItems.TOOL_STATS[current_tool()]
		w.sv_attack_animal.rpc_id(1, String(col.name), stats["dmg"])
		_swing_feel("thud", hit["position"])
		return
	if col is Node and col.has_meta("leviathan"):
		var stats: Dictionary = GameItems.TOOL_STATS[current_tool()]
		w.sv_attack_leviathan.rpc_id(1, stats["dmg"])
		_swing_feel("thud", hit["position"])
		return
	if col is Node and col.has_meta("res"):
		var snd := _gather(col)
		_swing_feel(snd, hit["position"])
		return
	_swing_feel("", null)

# Returns the impact sound for a successful gather, or "" if the tool refused.
func _gather(col: Node) -> String:
	var w := _world()
	var kind: String = col.get_meta("kind")
	var rstats: Dictionary = GameItems.RES_STATS[kind]
	var tstats: Dictionary = GameItems.TOOL_STATS[current_tool()]
	var power: float
	var snd := "pickup"
	if rstats.get("pickup", false):
		power = 1.0   # foraging works bare-handed
	elif kind == "tree":
		power = tstats["chop"]
		snd = "chop"
		if power <= 0.0:
			if hud:
				hud.flash("Too thick for bare hands. Craft an axe: branch + 2 stone + string.")
			return ""
	else:   # rock / iron
		power = tstats["mine"]
		snd = "mine"
		if power <= 0.0:
			if hud:
				hud.flash("You need a pick: branch + 2 stone + string.")
			return ""
		if kind in ["iron", "moonstone"] and power < 4.0:
			if hud:
				hud.flash("The ore shrugs off your crude pick. Craft a Stone Pick.")
			return ""
	if not can_fit(rstats["item"]):
		if hud:
			hud.flash("Your pack is full. Drop something, spend something, or get a bigger pack.")
		return ""
	w.sv_hit_resource.rpc_id(1, String(col.name), power)
	return snd

func _eat(preferred := "") -> void:
	var order := [preferred] if preferred != "" else ["cooked_meat", "berries", "raw_meat"]
	for food in order:
		if inv.get(food, 0) > 0:
			inv[food] -= 1
			var f: Dictionary = GameItems.FOODS[food]
			hunger = minf(hunger + f["hunger"], 100.0)
			hp = clampf(hp + f["hp"], 1.0, 100.0)
			Sfx.play(self, "eat", -6.0)
			if hud:
				hud.flash("Ate %s." % GameItems.nice(food))
			return
	if hud:
		hud.flash("Nothing to eat. Berries grow on bushes; deer drop meat.")

func _place(kind: String) -> void:
	if inv.get(kind, 0) <= 0:
		if hud:
			hud.flash("Craft a %s first (Tab)." % GameItems.nice(kind))
		return
	var hit := _raycast()
	if hit.is_empty():
		if hud:
			hud.flash("Aim at the ground, closer.")
		return
	var pos: Vector3 = hit["position"]
	if kind == "beacon":
		var peak: Vector3 = _world().peak_pos
		if Vector2(pos.x - peak.x, pos.z - peak.z).length() >= 15.0:
			if hud:
				hud.flash("It would burn here… but the signal must come from the island's peak.")
			return   # don't waste it — beacons only matter up top
	inv[kind] -= 1
	if kind == "wall":
		events["wall_built"] = events.get("wall_built", 0) + 1
	_world().sv_place_structure.rpc_id(1, kind, pos, rotation.y)

func _interact() -> void:
	var hit := _raycast()
	if hit.is_empty():
		_try_embark()
		return
	var col: Object = hit["collider"]
	if col is Node and col.has_meta("res") and GameItems.RES_STATS[col.get_meta("kind")].get("pickup", false):
		if _gather(col) != "":
			Sfx.play(self, "pickup", -8.0)
		return
	if col is Node and col.has_meta("crate"):
		_world().sv_loot_crate.rpc_id(1, String(col.name))
		return
	if col is Node and col.has_meta("monolith"):
		if col.get_meta("awakened"):
			if hud:
				hud.flash("The monolith hums softly, satisfied.")
		elif inv.get("moonstone", 0) >= 3:
			inv["moonstone"] -= 3
			_world().sv_awaken_monolith.rpc_id(1)
			if hud:
				hud.flash("The moonstones slot home. Light crawls up the stone…")
		elif hud:
			hud.flash("Three sockets, moonstone-shaped. The stone waits.")
		return
	if col is Node and col.has_meta("chest"):
		if col.get_meta("opened"):
			if hud:
				hud.flash("Empty. Whoever lived here is long gone.")
		elif inv.get("rusted_key", 0) > 0:
			inv["rusted_key"] -= 1
			_world().sv_open_chest.rpc_id(1)
			if hud:
				hud.flash("The rusted key turns…")
		elif hud:
			hud.flash("Locked tight. The night wolves carry something rusted…")
		return
	if col is Node and col.has_meta("struct"):
		var kind: String = col.get_meta("kind")
		if kind == "campfire":
			if inv.get("raw_meat", 0) > 0:
				inv["raw_meat"] -= 1
				inv["cooked_meat"] = inv.get("cooked_meat", 0) + 1
				events["cooked"] = events.get("cooked", 0) + 1
				if hud:
					hud.flash("Cooked meat over the fire.")
			elif hud:
				hud.flash("No raw meat to cook. Hunt a deer.")
		elif kind in ["door", "shutter"]:
			_world().sv_toggle_door.rpc_id(1, String(col.name))
		elif in_build_mode() and kind in GameItems.BUILD_PIECES:
			if inv.get("wood", 0) >= 1:
				inv["wood"] -= 1
				_world().sv_repair.rpc_id(1, String(col.name))
				if hud:
					hud.flash("Patched it up.")
			elif hud:
				hud.flash("Repairs take wood.")
		elif kind == "totem":
			var deposit: int = mini(inv.get("wood", 0), 5)
			if deposit > 0:
				inv["wood"] -= deposit
				events["deposited"] = events.get("deposited", 0) + deposit
				Sfx.play(self, "pickup", -8.0)
				_world().sv_deposit_wood.rpc_id(1, String(col.name), deposit)
				if hud:
					hud.flash("Fed the totem %d wood." % deposit)
			elif hud:
				hud.flash("The totem hungers for wood.")
		return
	_try_embark()   # E at the water's edge with a raft: push off

func _try_embark() -> void:
	if sailing or not owned_tools.has("raft"):
		return
	if _world().height_at(global_position.x, global_position.z) < 0.7 and global_position.y < 1.5:
		_set_sailing(true)
		Sfx.play(self, "place", -8.0)
		if hud:
			hud.flash("You push off. Steer with WASD — beach on shallows (or E) to land.")
	elif hud and selected_slot == 0:
		hud.flash("Wade into the shallows to launch the raft.")

func craft(recipe: String) -> void:
	if recipe in GameItems.FORGE_ONLY and not _near_struct("forge", 6.0):
		if hud:
			hud.flash("This needs a forge's heat. Build one (stone + wood) and stand close.")
		return
	var cost: Dictionary = GameItems.RECIPES[recipe]
	for mat in cost:
		if inv.get(mat, 0) < cost[mat]:
			if hud:
				hud.flash("Need %s." % GameItems.cost_text(recipe))
			return
	for mat in cost:
		inv[mat] -= cost[mat]
	crafted[recipe] = true
	Sfx.play(self, "craft", -8.0)
	_auto_hotbar(recipe)
	if recipe in GameItems.CLOTHES:
		_try_equip(recipe)
	elif recipe in GameItems.MATERIALS:
		inv[recipe] = inv.get(recipe, 0) + 1
		if hud:
			hud.flash("Twisted fiber into %s." % GameItems.nice(recipe))
	elif recipe in GameItems.PLACEABLES:
		inv[recipe] = inv.get(recipe, 0) + 1
		if hud:
			hud.flash("Crafted %s. Select its slot and click ground to place." % GameItems.nice(recipe))
	else:
		owned_tools[recipe] = true
		if hud:
			hud.flash("Crafted %s." % GameItems.nice(recipe))

# ---------------------------------------------------------------- persistence

var _psave_accum := 0.0

func _psave_file() -> String:
	return "user://saves/player_%d.json" % _world().wseed

func save_local() -> void:
	if not is_local() or _world() == null:
		return
	DirAccess.make_dir_recursive_absolute("user://saves")
	var data := {
		"inv": inv, "tools": owned_tools.keys(), "crafted": crafted.keys(),
		"gathered": total_gathered, "events": events,
		"hp": hp, "hunger": hunger, "equipment": equipment,
		"hotbar": hotbar_items, "grid": grid_stacks,
	}
	var f := FileAccess.open(_psave_file(), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

func load_local() -> void:
	if not is_local() or _world() == null or not FileAccess.file_exists(_psave_file()):
		return
	var f := FileAccess.open(_psave_file(), FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if data == null:
		return
	for k in data.get("inv", {}):
		inv[k] = int(data["inv"][k])
	for t in data.get("tools", []):
		owned_tools[t] = true
	for c in data.get("crafted", []):
		crafted[c] = true
	for k in data.get("gathered", {}):
		total_gathered[k] = int(data["gathered"][k])
	for k in data.get("events", {}):
		events[k] = int(data["events"][k])
	hp = float(data.get("hp", 100.0))
	hunger = float(data.get("hunger", 100.0))
	for gear_slot in data.get("equipment", {}):
		equipment[gear_slot] = data["equipment"][gear_slot]
	var hb: Array = data.get("hotbar", [])
	for i in mini(hb.size(), HOTBAR_SLOTS):
		hotbar_items[i] = String(hb[i])
	for g in data.get("grid", []):
		grid_stacks.append({"item": String(g["item"]), "count": int(g["count"]),
			"x": int(g["x"]), "y": int(g["y"]), "w": int(g["w"]), "h": int(g["h"])})
	if hotbar_items == ["", "", "", ""]:
		# older save or fresh hands: bind the best of what you own
		for cat in ["axe", "pick", "spear"]:
			_auto_hotbar(best_tool(cat))
		if owned_tools.has("hammer"):
			_auto_hotbar("hammer")
	reconcile_grid()
	if not equipment.is_empty():
		rx_equip.rpc(equipment)
	if hud:
		hud.flash("Welcome back, survivor.")

# ---------------------------------------------------------------- rpcs

@rpc("authority", "call_remote", "unreliable")
func rx_state(pos: Vector3, yaw: float, sail := false) -> void:
	net_pos = pos
	net_yaw = yaw
	_has_net = true
	if not is_local() and sail != sailing:
		_set_sailing(sail)

@rpc("any_peer", "call_local", "reliable")
func rx_add_items(items: Dictionary) -> void:
	if not is_local():
		return
	for item in items:
		inv[item] = inv.get(item, 0) + items[item]
		total_gathered[item] = total_gathered.get(item, 0) + items[item]
	if hud:
		var parts: PackedStringArray = []
		for item in items:
			parts.append("+%d %s" % [items[item], GameItems.nice(item)])
		hud.flash(" ".join(parts), true)
		if items.has("journal"):
			hud.flash("The captain's journal: \"…buried what mattered at the old homestead\ninland. The wolves took the key with the rest of me.\"")
		if items.has("rusted_key"):
			hud.flash("A rusted key, swallowed whole. The journal was right.")
		if items.has("ancient_lens"):
			hud.flash("An ancient lens — it could focus a flame into a signal.\nIron, wood, and the island's peak…")

@rpc("any_peer", "call_local", "reliable")
func rx_damage(amount: float) -> void:
	if not is_local():
		return
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return   # only the server deals damage. Never another player.
	amount *= 1.0 - armor_total()   # what you wear is what you get
	hp -= amount
	Sfx.play(self, "hurt", -4.0)
	if hud:
		hud.damage_flash()
		hud.flash("Something savages you! (-%d)" % int(amount))
	if hp <= 0.0:
		_respawn()

@rpc("any_peer", "call_local", "reliable")
func rx_event(ev: String) -> void:
	if not is_local():
		return
	events[ev] = events.get(ev, 0) + 1
	if hud:
		match ev:
			"kill_wolf":
				hud.flash("Wolf slain.")
			"kill_bear":
				hud.flash("The bear falls. The highlands are quieter now.")
			"kill_boar":
				hud.flash("Boar down. Next time, don't meet its eyes.")
			"beacon_lit":
				hud.flash("The beacon roars to life. Its light sweeps past the reef —\nand something in the deep answers. It circles the wreck.")
			"kill_leviathan":
				hud.flash("The Leviathan shudders, and sinks.\nThe sea goes quiet. The island is truly yours.")
