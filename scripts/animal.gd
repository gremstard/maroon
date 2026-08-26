class_name Animal extends StaticBody3D
# The grounded roster. Every creature is a real animal with one learnable verb:
#   deer — skittish, food on legs
#   wolf — pack hunter, hunts players at night or when provoked
#   bear — two-phase: investigates first (stand STILL and it loses interest —
#          real bear-safety advice, no tutorial needed); its charge is a dead
#          straight line it cannot steer, so juke it and punish the recovery
#   boar — face-aggro: look it in the eye and it freezes, paws the ground
#          (the telegraph), then charges. Avert your gaze and walk on by.
# AI runs on the server only; other peers interpolate broadcast state.

const STATS := {
	"deer": {"hp": 40.0, "dmg": 0.0,  "meat": 2, "radius": 0.35, "color": Color(0.62, 0.44, 0.26)},
	"wolf": {"hp": 60.0, "dmg": 10.0, "meat": 1, "radius": 0.4,  "color": Color(0.25, 0.25, 0.28)},
	"bear": {"hp": 150.0, "dmg": 25.0, "meat": 4, "radius": 0.7,  "color": Color(0.24, 0.16, 0.10)},
	"boar": {"hp": 70.0, "dmg": 15.0, "meat": 3, "radius": 0.45, "color": Color(0.74, 0.64, 0.44)},
	"dweller": {"hp": 90.0, "dmg": 20.0, "meat": 1, "radius": 0.5, "color": Color(0.16, 0.14, 0.20)},
	"snake": {"hp": 25.0, "dmg": 6.0, "meat": 1, "radius": 0.3, "color": Color(0.36, 0.44, 0.20)},
	"crow": {"hp": 15.0, "dmg": 0.0, "meat": 1, "radius": 0.25, "color": Color(0.12, 0.12, 0.14)},
}

var kind := "deer"
var hp := 40.0

# server-side AI state
var mode := "idle"          # idle | investigate | telegraph | charge | recover | flee
var mode_timer := 0.0
var charge_dir := Vector3.ZERO
var wander_target := Vector3.ZERO
var wander_timer := 0.0
var flee_dir := Vector3.ZERO
var aggro_peer := 0
var aggro_timer := 0.0
var attack_cooldown := 0.0
var _target_prev_pos := Vector3.ZERO
var _target_still_time := 0.0

# client-side interpolation
var net_target_pos := Vector3.ZERO
var net_target_yaw := 0.0
var _has_net_state := false

func _ready() -> void:
	var s: Dictionary = STATS[kind]
	hp = s["hp"]
	var m := StandardMaterial3D.new()
	m.albedo_color = s["color"]
	var scale_f: float = s["radius"] / 0.35

	var mi := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = s["radius"]
	body_mesh.height = 1.4 * scale_f
	mi.mesh = body_mesh
	mi.rotation_degrees.x = 90.0
	mi.position.y = 0.5 * scale_f
	mi.material_override = m
	add_child(mi)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.22 * scale_f
	hm.height = 0.44 * scale_f
	head.mesh = hm
	head.material_override = m
	head.position = Vector3(0, 0.75, -0.7) * scale_f
	add_child(head)
	if kind == "snake":
		# low, long, patient
		mi.position.y = 0.16
		mi.scale = Vector3(0.9, 0.55, 1.7)
		head.position = Vector3(0, 0.22, -0.72)
	if kind == "crow":
		head.position = Vector3(0, 0.55, -0.4)
		for side in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(0.55, 0.04, 0.24)
			wing.mesh = wm
			wing.material_override = m
			wing.position = Vector3(side * 0.35, 0.45, 0)
			wing.rotation_degrees.z = side * 12.0
			add_child(wing)
		var beak := MeshInstance3D.new()
		var bkm := CylinderMesh.new()
		bkm.top_radius = 0.0
		bkm.bottom_radius = 0.04
		bkm.height = 0.18
		beak.mesh = bkm
		beak.material_override = _beak_mat()
		beak.rotation_degrees.x = -90
		beak.position = Vector3(0, 0.55, -0.6)
		add_child(beak)
	if kind == "dweller":
		# too many pale eyes, and legs it shouldn't have
		var deye := StandardMaterial3D.new()
		deye.albedo_color = Color(0.85, 0.95, 1.0)
		deye.emission_enabled = true
		deye.emission = Color(0.7, 0.85, 1.0)
		for k in 4:
			var eye := MeshInstance3D.new()
			var em := SphereMesh.new()
			em.radius = 0.05
			em.height = 0.1
			eye.mesh = em
			eye.material_override = deye
			eye.position = Vector3(k * 0.09 - 0.135, 0.78 + (k % 2) * 0.07, -0.85)
			add_child(eye)
		for k in 6:
			var leg := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.03
			lm.bottom_radius = 0.015
			lm.height = 0.7
			leg.mesh = lm
			leg.material_override = m
			var side := -1.0 if k % 2 == 0 else 1.0
			leg.position = Vector3(side * 0.5, 0.35, (k / 2) * 0.4 - 0.4)
			leg.rotation_degrees.z = side * -35.0
			add_child(leg)
	if kind == "wolf" or kind == "bear":
		var eye_mat := StandardMaterial3D.new()
		var ec := Color(1, 0.2, 0.1) if kind == "wolf" else Color(1, 0.6, 0.1)
		eye_mat.albedo_color = ec
		eye_mat.emission_enabled = true
		eye_mat.emission = ec
		for side in [-0.08, 0.08]:
			var eye := MeshInstance3D.new()
			var em := SphereMesh.new()
			em.radius = 0.045 * scale_f
			em.height = 0.09 * scale_f
			eye.mesh = em
			eye.material_override = eye_mat
			eye.position = Vector3(side * scale_f, 0.8 * scale_f, -0.88 * scale_f)
			add_child(eye)
	if kind == "boar":
		# tusks — the thing you notice right before you regret eye contact
		var tusk_mat := StandardMaterial3D.new()
		tusk_mat.albedo_color = Color(0.92, 0.90, 0.82)
		for side in [-0.12, 0.12]:
			var tusk := MeshInstance3D.new()
			var tm := CylinderMesh.new()
			tm.top_radius = 0.0
			tm.bottom_radius = 0.05
			tm.height = 0.25
			tusk.mesh = tm
			tusk.material_override = tusk_mat
			tusk.position = Vector3(side, 0.55, -0.95)
			tusk.rotation_degrees.x = -30
			add_child(tusk)
	var shape := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = s["radius"] + 0.05
	cs.height = 1.6 * scale_f
	shape.shape = cs
	shape.position.y = 0.8 * scale_f
	add_child(shape)
	set_meta("animal", true)

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server() and _has_net_state:
		global_position = global_position.lerp(net_target_pos, minf(1.0, delta * 10.0))
		rotation.y = lerp_angle(rotation.y, net_target_yaw, minf(1.0, delta * 10.0))

func on_provoked(peer: int) -> void:
	match kind:
		"deer":
			mode = "flee"
			mode_timer = 6.0
			flee_dir = Vector3.ZERO
		"wolf":
			aggro_peer = peer
			aggro_timer = 20.0
		"bear", "boar":
			aggro_peer = peer
			aggro_timer = 20.0
			if mode in ["idle", "investigate", "recover"]:
				mode = "telegraph"
				mode_timer = 0.6   # hit it and it comes fast
		"dweller":
			aggro_peer = peer
			aggro_timer = 20.0
		"snake", "crow":
			mode = "flee" if kind == "snake" else "leave"
			mode_timer = 4.0
			flee_dir = Vector3(randf() - 0.5, 0, randf() - 0.5).normalized()

# Called by World on the server every physics frame.
func server_ai(delta: float, world: World) -> void:
	wander_timer -= delta
	mode_timer -= delta
	aggro_timer -= delta
	attack_cooldown -= delta
	match kind:
		"wolf":
			_ai_wolf(delta, world)
		"deer":
			_ai_deer(delta, world)
		"bear":
			_ai_bear(delta, world)
		"boar":
			_ai_boar(delta, world)
		"dweller":
			_ai_dweller(delta, world)
		"snake":
			_ai_snake(delta, world)
		"crow":
			_ai_crow(delta, world)
	var ground := world.height_at(global_position.x, global_position.z)
	if kind == "crow":
		global_position.y = ground + 2.6 + sin(Time.get_ticks_msec() * 0.003) * 0.35
	else:
		global_position.y = ground + 0.1

func _beak_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.62, 0.30)
	return m

func _ai_snake(delta: float, world: World) -> void:
	# It doesn't chase. It waits in the grass. That's worse.
	match mode:
		"flee":
			_move(flee_dir, 5.0, delta, world)
			if mode_timer <= 0.0:
				mode = "idle"
		_:
			var t := _nearest_player(world)
			if t and global_position.distance_to(t.global_position) < 2.4 and attack_cooldown <= 0.0:
				attack_cooldown = 4.0
				t.rx_damage.rpc_id(t.peer_id, STATS["snake"]["dmg"])
				t.rx_poison.rpc_id(t.peer_id)
				mode = "flee"
				mode_timer = 3.0
				flee_dir = (global_position - t.global_position).normalized()
				flee_dir.y = 0
			elif randf() < delta * 0.03:
				_wander(delta, world, 0.8)   # the grass shifts, barely

func _ai_crow(delta: float, world: World) -> void:
	# Circles overhead; swoops anyone carrying food and takes a bite with it.
	match mode:
		"leave":
			_move(flee_dir, 7.0, delta, world)
			if mode_timer <= 0.0:
				mode = "idle"
				wander_timer = 0.0
		_:
			var t := _nearest_player(world)
			if t and global_position.distance_to(t.global_position) < 22.0 and attack_cooldown <= 0.0:
				var to_t := t.global_position - global_position
				to_t.y = 0
				if to_t.length() < 1.3:
					attack_cooldown = 12.0
					t.rx_crow_steal.rpc_id(t.peer_id)
					mode = "leave"
					mode_timer = 4.0
					flee_dir = -to_t.normalized()
				else:
					_move(to_t.normalized(), 6.5, delta, world)
			else:
				_wander(delta, world, 3.5)

# ---------------------------------------------------------------- movement bits

func _move(dir: Vector3, speed: float, delta: float, world: World, face := true) -> void:
	if dir == Vector3.ZERO:
		return
	var next := global_position + dir * speed * delta
	if world.height_at(next.x, next.z) > 0.4:
		global_position = next
		if face:
			rotation.y = atan2(dir.x, dir.z) + PI

func _wander(delta: float, world: World, speed := 2.0) -> void:
	if wander_timer <= 0.0 or global_position.distance_to(wander_target) < 1.0:
		wander_timer = randf_range(3.0, 8.0)
		var ang := randf() * TAU
		wander_target = global_position + Vector3(cos(ang), 0, sin(ang)) * randf_range(4.0, 14.0)
		if world.height_at(wander_target.x, wander_target.z) < 1.0:
			wander_target = Vector3.ZERO
	if wander_target != Vector3.ZERO:
		var to_t := wander_target - global_position
		to_t.y = 0
		if to_t.length() > 0.5:
			_move(to_t.normalized(), speed, delta, world)

func _bite(target: Node3D, dmg: float, reach := 1.7) -> bool:
	var to_p := target.global_position - global_position
	to_p.y = 0
	if to_p.length() <= reach and attack_cooldown <= 0.0:
		attack_cooldown = 1.3
		target.rx_damage.rpc_id(target.peer_id, dmg)
		return true
	return false

func _nearest_player(world: World) -> Node3D:
	var best: Node3D = null
	var best_d := 999.0
	for p in world.get_node("Players").get_children():
		var d: float = global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best

func _aggro_target(world: World) -> Node3D:
	if aggro_timer > 0.0 and world.get_node("Players").has_node(str(aggro_peer)):
		return world.get_node("Players").get_node(str(aggro_peer))
	return null

# ---------------------------------------------------------------- per-kind AI

func _ai_wolf(delta: float, world: World) -> void:
	var target: Node3D = _aggro_target(world)
	if target == null and world.is_night():
		var near := _nearest_player(world)
		if near and global_position.distance_to(near.global_position) < 25.0:
			target = near
	if target != null:
		var to_p := target.global_position - global_position
		to_p.y = 0
		if not _bite(target, STATS["wolf"]["dmg"]):
			if to_p.length() > 1.7:
				_move(to_p.normalized(), 4.5, delta, world)
	else:
		_wander(delta, world)

func _ai_deer(delta: float, world: World) -> void:
	if mode == "flee" and mode_timer > 0.0:
		if flee_dir == Vector3.ZERO:
			var nearest := _nearest_player(world)
			if nearest:
				flee_dir = global_position - nearest.global_position
				flee_dir.y = 0
				flee_dir = flee_dir.normalized()
		_move(flee_dir, 5.5, delta, world)
	else:
		mode = "idle"
		flee_dir = Vector3.ZERO
		_wander(delta, world)

func _ai_bear(delta: float, world: World) -> void:
	var target: Node3D = _aggro_target(world)
	if target == null:
		target = _nearest_player(world)
		if target and global_position.distance_to(target.global_position) > 18.0:
			target = null
	match mode:
		"idle":
			if target != null:
				mode = "investigate"
				_target_still_time = 0.0
				_target_prev_pos = target.global_position
			else:
				_wander(delta, world, 1.6)
		"investigate":
			if target == null:
				mode = "idle"
				return
			# The real-world rule: hold still and it loses interest.
			var moved: float = (target.global_position - _target_prev_pos).length()
			_target_prev_pos = target.global_position
			if moved / maxf(delta, 0.001) < 0.8:
				_target_still_time += delta
			else:
				_target_still_time = 0.0
			if _target_still_time > 2.5 and aggro_timer <= 0.0:
				mode = "idle"           # it huffs and wanders off
				wander_timer = 0.0
				return
			var to_p := target.global_position - global_position
			to_p.y = 0
			if to_p.length() < 10.0 and (_target_still_time < 0.3 or aggro_timer > 0.0):
				mode = "charge"          # locked in — a straight line it can't steer
				mode_timer = 2.2
				charge_dir = to_p.normalized()
			else:
				_move(to_p.normalized(), 1.8, delta, world)
		"charge":
			_move(charge_dir, 9.0, delta, world)
			if target != null and _bite(target, STATS["bear"]["dmg"], 1.9):
				mode = "recover"
				mode_timer = 2.5
			elif mode_timer <= 0.0:
				mode = "recover"         # overshot — the punish window
				mode_timer = 2.5
		"recover":
			if mode_timer <= 0.0:
				mode = "idle"
		_:
			mode = "idle"

func _ai_boar(delta: float, world: World) -> void:
	var target: Node3D = _aggro_target(world)
	match mode:
		"idle":
			if target == null:
				target = _looking_at_me(world)
			if target != null:
				aggro_peer = target.peer_id
				aggro_timer = 15.0
				mode = "telegraph"       # freeze, lock eyes, paw the ground
				mode_timer = 1.2
			else:
				_wander(delta, world, 1.8)
		"telegraph":
			if target != null:
				var to_p := target.global_position - global_position
				rotation.y = atan2(to_p.x, to_p.z) + PI
				rotation.z = sin(mode_timer * 40.0) * 0.06   # pawing shudder
			if mode_timer <= 0.0:
				rotation.z = 0.0
				if target != null:
					var to_p := target.global_position - global_position
					to_p.y = 0
					charge_dir = to_p.normalized()
					mode = "charge"
					mode_timer = 2.0
				else:
					mode = "idle"
		"charge":
			_move(charge_dir, 7.5, delta, world)
			if target != null and _bite(target, STATS["boar"]["dmg"]):
				mode = "recover"
				mode_timer = 1.8
			elif mode_timer <= 0.0:
				mode = "recover"
				mode_timer = 1.8
		"recover":
			if mode_timer <= 0.0:
				mode = "idle"
		_:
			mode = "idle"

func _ai_dweller(delta: float, world: World) -> void:
	# The verb: light means safety. It will not come near a burning torch,
	# campfire, or beacon — step outside the glow and it comes for you.
	if world.light_near(global_position, 6.0):
		var away := global_position - _nearest_light(world)
		away.y = 0
		if away.length() > 0.01:
			_move(away.normalized(), 6.0, delta, world)   # recoils from the glow
		return
	var target: Node3D = _aggro_target(world)
	if target == null:
		target = _nearest_player(world)
		if target and global_position.distance_to(target.global_position) > 16.0:
			target = null
	if target != null and not world.light_near(target.global_position, 5.0):
		var to_p := target.global_position - global_position
		to_p.y = 0
		if not _bite(target, STATS["dweller"]["dmg"], 1.6):
			if to_p.length() > 1.6:
				_move(to_p.normalized(), 5.5, delta, world)
	else:
		_wander(delta, world, 1.4)

func _nearest_light(world: World) -> Vector3:
	var best := global_position + Vector3(1, 0, 0)
	var best_d := 999.0
	for s in world.get_node("Structures").get_children():
		if s.get_meta("kind") in ["torch", "campfire", "beacon"]:
			var d: float = global_position.distance_to(s.global_position)
			if d < best_d:
				best_d = d
				best = s.global_position
	return best

func _looking_at_me(world: World) -> Node3D:
	# Eye contact within 14 m triggers the boar.
	for p in world.get_node("Players").get_children():
		var to_me: Vector3 = global_position - p.global_position
		to_me.y = 0
		var d: float = to_me.length()
		if d > 14.0 or d < 0.5:
			continue
		var forward := Vector3(-sin(p.rotation.y), 0, -cos(p.rotation.y))
		if forward.dot(to_me.normalized()) > 0.93:
			return p
	return null
