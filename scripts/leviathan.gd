class_name Leviathan extends StaticBody3D
# The endgame answer to the beacon. A sea serpent that circles beyond the reef
# near the shipwreck. Its verb: it SURGES at anyone standing on the beach —
# a straight, committed lunge. Dodge it and it beaches itself for a few
# seconds: the punish window. Fought from the shore with whatever you've made.
# Server drives the head; every peer trails the body segments locally.

const MAX_HP := 400.0
const BITE_DMG := 30.0
const SEGMENTS := 7

var hp := MAX_HP
var anchor := Vector3.ZERO
var dying := false

# server AI
var mode := "circle"        # circle | surge | beached | retreat
var mode_timer := 0.0
var surge_timer := 6.0
var circle_angle := 0.0
var target_peer := 0
var attack_cooldown := 0.0

# client interpolation
var net_target_pos := Vector3.ZERO
var net_target_yaw := 0.0
var _has_net_state := false

var _segs: Array[MeshInstance3D] = []

func setup(a: Vector3) -> void:
	anchor = a
	global_position = anchor
	circle_angle = 0.0

func _ready() -> void:
	var hide_mat := StandardMaterial3D.new()
	hide_mat.albedo_color = Color(0.07, 0.20, 0.22)
	# head
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 1.4
	hm.height = 2.4
	head.mesh = hm
	head.material_override = hide_mat
	head.position.y = 0.6
	add_child(head)
	var jaw := MeshInstance3D.new()
	var jm := BoxMesh.new()
	jm.size = Vector3(1.2, 0.5, 1.6)
	jaw.mesh = jm
	jaw.material_override = hide_mat
	jaw.position = Vector3(0, 0.2, -1.4)
	add_child(jaw)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.6, 1.0, 0.9)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.4, 1.0, 0.85)
	eye_mat.emission_energy_multiplier = 3.0
	for side in [-0.55, 0.55]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.18
		em.height = 0.36
		eye.mesh = em
		eye.material_override = eye_mat
		eye.position = Vector3(side, 1.1, -0.9)
		add_child(eye)
	# fins
	var fin_mat := StandardMaterial3D.new()
	fin_mat.albedo_color = Color(0.10, 0.28, 0.30)
	var fin := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.15, 1.4, 1.2)
	fin.mesh = fm
	fin.material_override = fin_mat
	fin.position = Vector3(0, 1.8, 0.4)
	fin.rotation_degrees.x = -20
	add_child(fin)
	# trailing body — top_level so they swim in world space
	for i in SEGMENTS:
		var seg := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r := 1.2 - i * 0.13
		sm.radius = r
		sm.height = r * 2.0
		seg.mesh = sm
		seg.material_override = hide_mat
		seg.top_level = true
		add_child(seg)
		seg.global_position = global_position - Vector3(0, 0, 2.2) * (i + 1)
		_segs.append(seg)
	# head collider
	var shape := CollisionShape3D.new()
	var cs := SphereShape3D.new()
	cs.radius = 1.6
	shape.shape = cs
	shape.position.y = 0.6
	add_child(shape)
	set_meta("leviathan", true)

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server() and _has_net_state:
		global_position = global_position.lerp(net_target_pos, minf(1.0, delta * 10.0))
		rotation.y = lerp_angle(rotation.y, net_target_yaw, minf(1.0, delta * 10.0))
	# every peer trails the body chain locally (visual only)
	var prev := global_position + Vector3(0, 0.2, 0)
	for seg in _segs:
		var to_seg := seg.global_position - prev
		to_seg.y = 0
		if to_seg.length() < 0.01:
			to_seg = Vector3(0, 0, 1)
		seg.global_position = prev + to_seg.normalized() * 2.0
		if not dying:
			seg.global_position.y = 0.15 + sin(Time.get_ticks_msec() * 0.002 + prev.x) * 0.25
		prev = seg.global_position

func on_hit(peer: int) -> void:
	target_peer = peer
	if mode == "circle":
		surge_timer = minf(surge_timer, 1.5)   # blood in the water

func server_ai(delta: float, world: World) -> void:
	if dying:
		return
	mode_timer -= delta
	surge_timer -= delta
	attack_cooldown -= delta
	match mode:
		"circle":
			circle_angle += delta * 0.5
			var ring := anchor + Vector3(cos(circle_angle), 0, sin(circle_angle)) * 16.0
			ring.y = 0.1
			var to_r := ring - global_position
			if to_r.length() > 0.3:
				global_position += to_r.limit_length(7.0 * delta)
				rotation.y = atan2(to_r.x, to_r.z) + PI
			if surge_timer <= 0.0:
				var target := _pick_target(world)
				if target != null:
					target_peer = target.peer_id
					mode = "surge"
					mode_timer = 4.0
				else:
					surge_timer = 4.0
		"surge":
			var players := world.get_node("Players")
			if mode_timer <= 0.0 or not players.has_node(str(target_peer)):
				mode = "retreat"
				return
			var t: Node3D = players.get_node(str(target_peer))
			var to_t := t.global_position - global_position
			to_t.y = 0
			rotation.y = atan2(to_t.x, to_t.z) + PI
			global_position += to_t.limit_length(10.0 * delta)
			global_position.y = 0.1
			if to_t.length() < 2.4 and attack_cooldown <= 0.0:
				attack_cooldown = 2.0
				t.rx_damage.rpc_id(target_peer, BITE_DMG)
				mode = "retreat"
			elif world.height_at(global_position.x, global_position.z) > 1.4:
				mode = "beached"      # overcommitted — the punish window
				mode_timer = 3.5
		"beached":
			rotation.y += sin(Time.get_ticks_msec() * 0.02) * delta * 2.0   # writhing
			if mode_timer <= 0.0:
				mode = "retreat"
		"retreat":
			var back := anchor - global_position
			back.y = 0
			if back.length() < 2.0:
				mode = "circle"
				surge_timer = randf_range(5.0, 9.0)
			else:
				global_position += back.limit_length(6.0 * delta)
				global_position.y = 0.1
				rotation.y = atan2(back.x, back.z) + PI

func _pick_target(world: World) -> Node3D:
	var best: Node3D = null
	var best_d := 45.0
	for p in world.get_node("Players").get_children():
		var d: float = anchor.distance_to(p.global_position)
		if d < best_d and world.height_at(p.global_position.x, p.global_position.z) < 5.0:
			best_d = d
			best = p
	return best

func die() -> void:
	dying = true
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", global_position.y - 8.0, 5.0)
	for seg in _segs:
		var st := create_tween()
		st.tween_property(seg, "global_position:y", seg.global_position.y - 8.0, 5.0)
	tw.tween_callback(queue_free)
