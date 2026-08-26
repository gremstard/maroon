class_name World extends Node3D
# The island: seeded terrain, resources, animals, structures, time, decay.
# Server-authoritative for everything dynamic; terrain/resources are generated
# deterministically from the seed on every peer.

const SIZE := 120         # grid cells per side
const CELL := 2.0         # meters per cell
const DAY_LENGTH := 720.0 # real seconds per in-game day (12 min)
const CLAIM_RADIUS := 20.0
const TOTEM_START_STOCK := 10

var wseed: int = 0
var noise: FastNoiseLite
var time_of_day := 8.0    # hours, 0..24
var day := 1

var sun: DirectionalLight3D
var env: WorldEnvironment
var struct_counter := 0
var animal_counter := 0

var _time_sync_accum := 0.0
var _anim_sync_accum := 0.0
var _decay_accum := 0.0
var _totem_feed_accum := 0.0

func setup(s: int) -> void:
	wseed = s
	noise = FastNoiseLite.new()
	noise.seed = s
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.012
	noise.fractal_octaves = 4

	for n in ["Players", "Resources", "Animals", "Structures"]:
		var holder := Node3D.new()
		holder.name = n
		add_child(holder)

	var far_rng := RandomNumberGenerator.new()
	far_rng.seed = wseed + 31337
	var far_ang := far_rng.randf() * TAU
	far_center = Vector2(cos(far_ang), sin(far_ang)) * FAR_DIST
	pond_centers.clear()
	for i in 3:
		var pa := far_rng.randf() * TAU
		var pr := far_rng.randf_range(25.0, 70.0)
		pond_centers.append(Vector2(cos(pa), sin(pa)) * pr)
	lobe_centers.clear()
	for i in 2:
		# peninsulas hanging off the rim — no island is round
		var la := far_rng.randf() * TAU
		lobe_centers.append(Vector2(cos(la), sin(la)) * SIZE * CELL * far_rng.randf_range(0.40, 0.48))

	_build_environment()
	_build_terrain()
	_build_water()
	_find_peak()
	_scatter_resources()
	_build_shipwreck()
	_build_ruins()
	_build_cave()
	_build_far_isle()

	if multiplayer.is_server():
		_load_save()               # restores structures/day/resources if this seed was played before
		_spawn_initial_animals()   # wildlife always returns fresh

# ================================================================ terrain

const FAR_DIST := 235.0    # how far past the reef the Far Isle sits
const FAR_R := 60.0        # its radius — smaller, taller, harsher
var far_center := Vector2.ZERO
var pond_centers: Array[Vector2] = []
var lobe_centers: Array[Vector2] = []

func _coast_wobble(v: Vector2, seed_off: float) -> float:
	# No island in nature is a circle. The coastline radius breathes with
	# angle-sampled noise: bays, headlands, that one weird peninsula.
	if v.length() < 0.01:
		return 1.0
	var d := v.normalized()
	return 1.0 + 0.30 * noise.get_noise_2d(d.x * 38.0 + seed_off, d.y * 38.0 - seed_off)

func height_at(x: float, z: float) -> float:
	var v := Vector2(x, z)
	var r := v.length() / (SIZE * CELL * 0.46 * _coast_wobble(v, 11.0))
	var falloff := clampf(1.0 - r * r * r, 0.0, 1.0)
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	var h := (n * 16.0 + 3.0) * falloff - 3.0
	if far_center != Vector2.ZERO:
		var fv := v - far_center
		var fr := fv.length() / (FAR_R * _coast_wobble(fv, 47.0))
		var ffall := clampf(1.0 - fr * fr * fr, 0.0, 1.0)
		var fn := noise.get_noise_2d(x + 533.0, z - 777.0) * 0.5 + 0.5
		h = maxf(h, (fn * 22.0 + 4.0) * ffall - 3.0)
	for lobe in lobe_centers:
		var lv := v - lobe
		var lr := lv.length() / (30.0 * _coast_wobble(lv, 71.0))
		var lfall := clampf(1.0 - lr * lr * lr, 0.0, 1.0)
		var ln := noise.get_noise_2d(x - 311.0, z + 218.0) * 0.5 + 0.5
		h = maxf(h, (ln * 9.0 + 2.5) * lfall - 3.0)
	# ponds: gentle inland dips that fill with the sea-level water table
	for p in pond_centers:
		h -= 5.0 * exp(-v.distance_squared_to(p) / 90.0)
	return h

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := SIZE * CELL * 0.5
	for cz in SIZE:
		for cx in SIZE:
			var x0 := cx * CELL - half
			var z0 := cz * CELL - half
			var pts := [
				Vector3(x0, 0, z0), Vector3(x0 + CELL, 0, z0),
				Vector3(x0 + CELL, 0, z0 + CELL), Vector3(x0, 0, z0 + CELL),
			]
			for i in 4:
				pts[i].y = height_at(pts[i].x, pts[i].z)
			for idx in [0, 1, 2, 0, 2, 3]:
				var p: Vector3 = pts[idx]
				st.set_color(_ground_color(p.y))
				st.add_vertex(p)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)
	mi.create_trimesh_collision()

	# second patch: the Far Isle, past the reef
	var fst := SurfaceTool.new()
	fst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var far_cells := int(FAR_R * 2.4 / CELL)
	var fhalf := far_cells * CELL * 0.5
	for cz in far_cells:
		for cx in far_cells:
			var x0 := cx * CELL - fhalf + far_center.x
			var z0 := cz * CELL - fhalf + far_center.y
			var pts := [
				Vector3(x0, 0, z0), Vector3(x0 + CELL, 0, z0),
				Vector3(x0 + CELL, 0, z0 + CELL), Vector3(x0, 0, z0 + CELL),
			]
			var above := false
			for i in 4:
				pts[i].y = height_at(pts[i].x, pts[i].z)
				above = above or pts[i].y > -2.5
			if not above:
				continue
			for idx in [0, 1, 2, 0, 2, 3]:
				var p: Vector3 = pts[idx]
				fst.set_color(_ground_color(p.y))
				fst.add_vertex(p)
	fst.generate_normals()
	var fmi := MeshInstance3D.new()
	fmi.name = "FarTerrain"
	fmi.mesh = fst.commit()
	fmi.material_override = mat
	add_child(fmi)
	fmi.create_trimesh_collision()

func _ground_color(h: float) -> Color:
	if h < 0.9:
		return Color(0.78, 0.71, 0.50)   # sand
	elif h < 9.0:
		return Color(0.30, 0.52, 0.26)   # grass
	else:
		return Color(0.48, 0.47, 0.44)   # rock

func _build_water() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE * CELL * 3.0, SIZE * CELL * 3.0)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.32, 0.45, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	mi.material_override = mat
	mi.position.y = 0.0
	add_child(mi)

func _build_environment() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	add_child(sun)

	env = WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 1.0
	e.fog_enabled = true
	e.fog_density = 0.002
	env.environment = e
	add_child(env)
	_apply_time_of_day()

func get_spawn_pos(pid: int) -> Vector3:
	# Castaways wash up on the beach: walk inward from the sea until we find
	# low dry land. Deterministic per player id.
	var ang := float(pid) * 1.7
	var dir := Vector3(cos(ang), 0, sin(ang))
	var r := SIZE * CELL * 0.46
	while r > 10.0:
		var pos := dir * r
		var h := height_at(pos.x, pos.z)
		if h > 0.8 and h < 4.0:
			return Vector3(pos.x, h + 1.5, pos.z)
		r -= 2.0
	return Vector3(0, height_at(0, 0) + 1.5, 0)

# ================================================================ resources

func _scatter_resources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = wseed
	var half := SIZE * CELL * 0.45
	var holder := get_node("Resources")
	var deco := Node3D.new()
	deco.name = "Deco"
	add_child(deco)
	for i in 1600:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var roll := rng.randf()
		var h := height_at(x, z)
		if h < 0.5:
			continue
		var kind := ""
		match biome_at(x, z):
			"shore":
				if roll < 0.30:
					kind = "pebble"
				elif roll < 0.45:
					kind = "grass"
				elif roll < 0.52:
					kind = "branch"   # driftwood
			"forest":
				if roll < 0.40:
					kind = "tree"
				elif roll < 0.56:
					kind = "branch"
				elif roll < 0.66:
					kind = "bush"
				elif roll < 0.72:
					kind = "rock"
				elif roll < 0.78:
					kind = "grass"
			"meadow":
				if roll < 0.40:
					kind = "grass"
				elif roll < 0.52:
					kind = "bush"
				elif roll < 0.58:
					kind = "branch"
				elif roll < 0.64:
					kind = "tree"
				elif roll < 0.80:
					_scatter_deco(deco, "flower", Vector3(x, h, z), rng)
			"highland":
				if roll < 0.26:
					kind = "rock"
				elif roll < 0.38:
					kind = "iron"
				elif roll < 0.44 and h > 11.0:
					kind = "moonstone" if roll < 0.40 else "iron"
				elif roll < 0.56:
					kind = "pebble"
				elif roll < 0.64:
					kind = "tree"
		if kind == "":
			continue
		var res := _make_resource(kind, i)
		holder.add_child(res)
		res.global_position = Vector3(x, h, z)
		res.rotation.y = rng.randf() * TAU
		if kind == "tree":
			for k in rng.randi_range(0, 2):
				_scatter_deco(deco, "leaves", Vector3(x + rng.randf_range(-2.5, 2.5), 0, z + rng.randf_range(-2.5, 2.5)), rng)

func biome_at(x: float, z: float) -> String:
	var h := height_at(x, z)
	if h < 1.2:
		return "shore"
	if h > 10.0:
		return "highland"
	var m := noise.get_noise_2d(x * 0.6 + 999.0, z * 0.6 - 999.0)
	return "meadow" if m > 0.16 else "forest"

func _scatter_deco(deco: Node3D, kind: String, pos: Vector3, rng: RandomNumberGenerator) -> void:
	# pure set dressing — no collision, no interaction, just life
	var mi := MeshInstance3D.new()
	match kind:
		"leaves":
			var dm := CylinderMesh.new()
			dm.top_radius = rng.randf_range(0.3, 0.7)
			dm.bottom_radius = dm.top_radius
			dm.height = 0.04
			mi.mesh = dm
			mi.material_override = _flat_mat(Color(0.48, 0.34, 0.16).lerp(Color(0.62, 0.42, 0.18), rng.randf()))
		"flower":
			var fm := CylinderMesh.new()
			fm.top_radius = 0.09
			fm.bottom_radius = 0.02
			fm.height = 0.3
			mi.mesh = fm
			var petals := [Color(0.85, 0.75, 0.30), Color(0.80, 0.35, 0.40), Color(0.75, 0.70, 0.85), Color(0.9, 0.9, 0.9)]
			mi.material_override = _flat_mat(petals[rng.randi() % petals.size()])
	deco.add_child(mi)
	var h := height_at(pos.x, pos.z)
	if h < 0.5:
		mi.queue_free()
		return
	mi.position = Vector3(pos.x, h + (0.03 if kind == "leaves" else 0.15), pos.z)
	mi.rotation.y = rng.randf() * TAU

func _make_resource(kind: String, idx: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "res_%d" % idx
	body.set_meta("res", true)
	body.set_meta("kind", kind)
	body.set_meta("hp", GameItems.RES_STATS[kind]["hp"])
	var shape := CollisionShape3D.new()
	match kind:
		"tree":
			# three species, same wood: pine, broadleaf, birch
			var variant := idx % 3
			var trunk := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.22 if variant == 2 else 0.25
			cyl.bottom_radius = 0.3 if variant == 2 else 0.35
			cyl.height = 4.6 if variant == 2 else 4.0
			trunk.mesh = cyl
			trunk.material_override = _flat_mat(
				Color(0.82, 0.80, 0.74) if variant == 2 else Color(0.42, 0.30, 0.18))
			trunk.position.y = cyl.height * 0.5
			body.add_child(trunk)
			if variant == 2:
				# birch: bark bands
				for band_y in [1.2, 2.4, 3.5]:
					var band := MeshInstance3D.new()
					var bcm := CylinderMesh.new()
					bcm.top_radius = 0.235
					bcm.bottom_radius = 0.235
					bcm.height = 0.16
					band.mesh = bcm
					band.material_override = _flat_mat(Color(0.22, 0.20, 0.18))
					band.position.y = band_y
					body.add_child(band)
			var leaves := MeshInstance3D.new()
			if variant == 0:
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 1.8
				cone.height = 3.5
				leaves.mesh = cone
				leaves.material_override = _flat_mat(Color(0.16, 0.42, 0.20))
				leaves.position.y = 4.8
			else:
				var ball := SphereMesh.new()
				ball.radius = 2.1 if variant == 1 else 1.5
				ball.height = 3.2 if variant == 1 else 2.4
				leaves.mesh = ball
				leaves.material_override = _flat_mat(
					Color(0.24, 0.48, 0.20) if variant == 1 else Color(0.42, 0.56, 0.22))
				leaves.position.y = 4.6 if variant == 1 else 5.1
			body.add_child(leaves)
			var cs := CylinderShape3D.new()
			cs.radius = 0.4
			cs.height = 4.4
			shape.shape = cs
			shape.position.y = 2.2
		"rock":
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 1.4
			mi.mesh = sm
			mi.material_override = _flat_mat(Color(0.52, 0.52, 0.54))
			mi.position.y = 0.4
			body.add_child(mi)
			var ss := SphereShape3D.new()
			ss.radius = 1.0
			shape.shape = ss
			shape.position.y = 0.4
		"iron":
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.8
			sm.height = 1.1
			mi.mesh = sm
			mi.material_override = _flat_mat(Color(0.33, 0.29, 0.27))
			mi.position.y = 0.35
			body.add_child(mi)
			var rust := MeshInstance3D.new()
			var rm := SphereMesh.new()
			rm.radius = 0.3
			rm.height = 0.5
			rust.mesh = rm
			rust.material_override = _flat_mat(Color(0.62, 0.36, 0.18))
			rust.position = Vector3(0.35, 0.6, 0.25)
			body.add_child(rust)
			var iss := SphereShape3D.new()
			iss.radius = 0.85
			shape.shape = iss
			shape.position.y = 0.35
		"moonstone":
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.7
			sm.height = 1.0
			mi.mesh = sm
			mi.material_override = _flat_mat(Color(0.20, 0.20, 0.24))
			mi.position.y = 0.3
			body.add_child(mi)
			var crystal_mat := StandardMaterial3D.new()
			crystal_mat.albedo_color = Color(0.75, 0.85, 1.0)
			crystal_mat.emission_enabled = true
			crystal_mat.emission = Color(0.55, 0.7, 1.0)
			crystal_mat.emission_energy_multiplier = 1.6
			for k in 3:
				var crystal := MeshInstance3D.new()
				var ccm := CylinderMesh.new()
				ccm.top_radius = 0.0
				ccm.bottom_radius = 0.1
				ccm.height = 0.55
				crystal.mesh = ccm
				crystal.material_override = crystal_mat
				crystal.position = Vector3(k * 0.25 - 0.25, 0.75, fmod(k * 0.3, 0.3) - 0.1)
				crystal.rotation_degrees.z = k * 16.0 - 16.0
				body.add_child(crystal)
			var mss := SphereShape3D.new()
			mss.radius = 0.8
			shape.shape = mss
			shape.position.y = 0.4
		"branch":
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = 0.08
			cm.height = 1.3
			mi.mesh = cm
			mi.material_override = _flat_mat(Color(0.40, 0.28, 0.16))
			mi.rotation_degrees = Vector3(88, 0, 12)
			mi.position.y = 0.12
			body.add_child(mi)
			var bss := SphereShape3D.new()
			bss.radius = 0.55
			shape.shape = bss
			shape.position.y = 0.2
		"grass":
			var gm := _flat_mat(Color(0.72, 0.65, 0.32))
			for k in 3:
				var blade := MeshInstance3D.new()
				var bcm := CylinderMesh.new()
				bcm.top_radius = 0.0
				bcm.bottom_radius = 0.05
				bcm.height = 0.7
				blade.mesh = bcm
				blade.material_override = gm
				blade.position = Vector3(k * 0.14 - 0.14, 0.3, fmod(k * 0.21, 0.2))
				blade.rotation_degrees.z = k * 14.0 - 14.0
				body.add_child(blade)
			var gss := SphereShape3D.new()
			gss.radius = 0.55
			shape.shape = gss
			shape.position.y = 0.25
		"pebble":
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.25
			sm.height = 0.32
			mi.mesh = sm
			mi.material_override = _flat_mat(Color(0.55, 0.55, 0.57))
			mi.position.y = 0.1
			body.add_child(mi)
			var pss := SphereShape3D.new()
			pss.radius = 0.4
			shape.shape = pss
			shape.position.y = 0.15
		"bush":
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.7
			sm.height = 1.0
			mi.mesh = sm
			mi.material_override = _flat_mat(Color(0.22, 0.50, 0.24))
			mi.position.y = 0.4
			body.add_child(mi)
			var berry := MeshInstance3D.new()
			var bm := SphereMesh.new()
			bm.radius = 0.12
			bm.height = 0.24
			berry.mesh = bm
			berry.material_override = _flat_mat(Color(0.8, 0.15, 0.2))
			berry.position = Vector3(0.3, 0.7, 0.25)
			body.add_child(berry)
			var bs := SphereShape3D.new()
			bs.radius = 0.7
			shape.shape = bs
			shape.position.y = 0.4
	body.add_child(shape)
	return body

func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

# A player asked to hit a resource node.
@rpc("any_peer", "call_local", "reliable")
func sv_hit_resource(res_name: String, power: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	var holder := get_node("Resources")
	if not holder.has_node(res_name):
		return
	var res := holder.get_node(res_name)
	if not res.visible:
		return
	var kind: String = res.get_meta("kind")
	var hp: float = res.get_meta("hp")
	if hp <= 0.0:
		return
	power = clampf(power, 0.0, 8.0)
	var stats: Dictionary = GameItems.RES_STATS[kind]
	var is_pickup: bool = stats.get("pickup", false)
	if is_pickup:
		power = maxf(power, 1.0)   # foraging works bare-handed
	if power < 0.75:
		return   # wrong tool — the client already showed a hint
	hp -= power
	var yield_count: int = int(stats.get("count", 1)) * int(maxf(1.0, floorf(power)))
	rx_resource_hp.rpc(res_name, hp)
	_grant_items(sender, {stats["item"]: yield_count})
	if hp <= 0.0 and (is_pickup or kind == "bush"):
		# Forage and bushes come back after a while.
		get_tree().create_timer(90.0).timeout.connect(func() -> void:
			if is_instance_valid(self) and holder.has_node(res_name):
				rx_resource_hp.rpc(res_name, stats["hp"]))

@rpc("authority", "call_local", "reliable")
func rx_resource_hp(res_name: String, hp: float) -> void:
	var holder := get_node("Resources")
	if not holder.has_node(res_name):
		return
	var res := holder.get_node(res_name)
	res.set_meta("hp", hp)
	var dead := hp <= 0.0
	res.visible = not dead
	for c in res.get_children():
		if c is CollisionShape3D:
			c.disabled = dead

func _grant_items(peer: int, items: Dictionary) -> void:
	var players := get_node("Players")
	if players.has_node(str(peer)):
		players.get_node(str(peer)).rx_add_items.rpc_id(peer, items)

# ================================================================ animals

func _spawn_initial_animals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = wseed + 77
	for i in 8:
		_server_spawn_animal("deer", rng)
	for i in 5:
		_server_spawn_animal("wolf", rng)
	for i in 4:
		_server_spawn_animal("boar", rng)
	for i in 2:
		_server_spawn_animal("bear", rng, 8.0)   # bears keep to the highlands
	for i in 3:
		# dwellers haunt the sea cave
		animal_counter += 1
		var ang := rng.randf() * TAU
		var dp := cave_pos + Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(1.5, 6.0)
		rx_spawn_animal.rpc("a_%d" % animal_counter, "dweller",
			Vector3(dp.x, height_at(dp.x, dp.z) + 0.5, dp.z))
	# snakes in the dry meadows, crows over the shore
	for i in 4:
		for attempt in 60:
			var x := rng.randf_range(-SIZE * CELL * 0.4, SIZE * CELL * 0.4)
			var z := rng.randf_range(-SIZE * CELL * 0.4, SIZE * CELL * 0.4)
			if height_at(x, z) > 1.5 and biome_at(x, z) == "meadow":
				animal_counter += 1
				rx_spawn_animal.rpc("a_%d" % animal_counter, "snake", Vector3(x, height_at(x, z) + 0.3, z))
				break
	for i in 3:
		for attempt in 60:
			var x := rng.randf_range(-SIZE * CELL * 0.4, SIZE * CELL * 0.4)
			var z := rng.randf_range(-SIZE * CELL * 0.4, SIZE * CELL * 0.4)
			if height_at(x, z) > 0.4 and biome_at(x, z) in ["shore", "meadow"]:
				animal_counter += 1
				rx_spawn_animal.rpc("a_%d" % animal_counter, "crow", Vector3(x, height_at(x, z) + 2.5, z))
				break
	# the far isle is predator country
	var far_kinds := ["bear", "bear", "wolf", "wolf", "wolf", "boar"]
	for kind in far_kinds:
		for attempt in 30:
			var ang := rng.randf() * TAU
			var r := rng.randf_range(5.0, FAR_R * 0.7)
			var x := far_center.x + cos(ang) * r
			var z := far_center.y + sin(ang) * r
			if height_at(x, z) > 2.0:
				animal_counter += 1
				rx_spawn_animal.rpc("a_%d" % animal_counter, kind, Vector3(x, height_at(x, z) + 0.9, z))
				break

func _server_spawn_animal(kind: String, rng: RandomNumberGenerator, min_h := 1.5) -> void:
	var half := SIZE * CELL * 0.4
	for attempt in 40:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if height_at(x, z) > min_h:
			animal_counter += 1
			var aname := "a_%d" % animal_counter
			rx_spawn_animal.rpc(aname, kind, Vector3(x, height_at(x, z) + 0.9, z))
			return

@rpc("authority", "call_local", "reliable")
func rx_spawn_animal(aname: String, kind: String, pos: Vector3) -> void:
	var holder := get_node("Animals")
	if holder.has_node(aname):
		return
	var a := Animal.new()
	a.name = aname
	a.kind = kind
	holder.add_child(a)
	a.global_position = pos

@rpc("any_peer", "call_local", "reliable")
func sv_attack_animal(aname: String, dmg: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	var holder := get_node("Animals")
	if not holder.has_node(aname):
		return
	var a: Animal = holder.get_node(aname)
	a.hp -= clampf(dmg, 0.0, 60.0)
	a.on_provoked(sender)
	rx_animal_flinch.rpc(aname)
	if a.hp <= 0.0:
		rx_animal_dead.rpc(aname)
		var drops := {"raw_meat": Animal.STATS[a.kind]["meat"]}
		var hide_yield: int = {"deer": 1, "wolf": 1, "boar": 2, "bear": 3}.get(a.kind, 0)
		if hide_yield > 0:
			drops["hide"] = hide_yield
		if a.kind == "dweller":
			drops["string"] = 2   # its silk, wound tight
		if a.kind == "wolf" and randf() < 0.5:
			drops["rusted_key"] = 1   # the wolves got to the captain first
		_grant_items(sender, drops)
		_notify_kill(sender, a.kind)

func _notify_kill(peer: int, kind: String) -> void:
	var players := get_node("Players")
	if players.has_node(str(peer)):
		players.get_node(str(peer)).rx_event.rpc_id(peer, "kill_" + kind)

@rpc("authority", "call_local", "reliable")
func rx_animal_flinch(aname: String) -> void:
	# hit feedback everyone can see: a quick recoil pulse
	var holder := get_node("Animals")
	if not holder.has_node(aname):
		return
	var a: Node3D = holder.get_node(aname)
	a.scale = Vector3.ONE * 1.12
	var tw := a.create_tween()
	tw.tween_property(a, "scale", Vector3.ONE, 0.18)

@rpc("authority", "call_local", "reliable")
func rx_animal_dead(aname: String) -> void:
	var holder := get_node("Animals")
	if holder.has_node(aname):
		holder.get_node(aname).queue_free()

@rpc("authority", "call_local", "unreliable")
func rx_lev_state(pos: Vector3, yaw: float) -> void:
	if multiplayer.is_server() or not has_node("Lev"):
		return
	var lev: Leviathan = get_node("Lev")
	lev.net_target_pos = pos
	lev.net_target_yaw = yaw
	lev._has_net_state = true

@rpc("authority", "call_local", "unreliable")
func rx_animal_states(states: Array) -> void:
	if multiplayer.is_server():
		return
	var holder := get_node("Animals")
	for s in states:
		var aname := String(s[0])
		if holder.has_node(aname):
			var a: Animal = holder.get_node(aname)
			a.net_target_pos = s[1]
			a.net_target_yaw = s[2]
			a._has_net_state = true

# ================================================================ structures

@rpc("any_peer", "call_local", "reliable")
func sv_place_structure(kind: String, pos: Vector3, yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	struct_counter += 1
	rx_place_structure.rpc("st_%d" % struct_counter, kind, pos, yaw)
	if kind == "beacon" and Vector2(pos.x - peak_pos.x, pos.z - peak_pos.z).length() < 15.0:
		# Lit at the island's highest point — the signal carries past the reef.
		var players := get_node("Players")
		if players.has_node(str(sender)):
			players.get_node(str(sender)).rx_event.rpc_id(sender, "beacon_lit")
		_summon_leviathan()

@rpc("authority", "call_local", "reliable")
func rx_place_structure(sname: String, kind: String, pos: Vector3, yaw: float) -> void:
	var holder := get_node("Structures")
	if holder.has_node(sname):
		return
	Sfx.play_at(self, pos, "place", -4.0)
	var body := StaticBody3D.new()
	body.name = sname
	body.set_meta("struct", true)
	body.set_meta("kind", kind)
	var shape := CollisionShape3D.new()
	match kind:
		"campfire":
			body.set_meta("hp", 100.0)
			var base := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.5
			cyl.bottom_radius = 0.6
			cyl.height = 0.3
			base.mesh = cyl
			base.material_override = _flat_mat(Color(0.35, 0.33, 0.32))
			base.position.y = 0.15
			body.add_child(base)
			var flame := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.25
			fm.height = 0.5
			flame.mesh = fm
			var flame_mat := StandardMaterial3D.new()
			flame_mat.albedo_color = Color(1.0, 0.55, 0.1)
			flame_mat.emission_enabled = true
			flame_mat.emission = Color(1.0, 0.5, 0.1)
			flame_mat.emission_energy_multiplier = 2.0
			flame.material_override = flame_mat
			flame.position.y = 0.45
			body.add_child(flame)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.6, 0.25)
			light.omni_range = 9.0
			light.position.y = 1.0
			body.add_child(light)
			var cs := CylinderShape3D.new()
			cs.radius = 0.6
			cs.height = 0.6
			shape.shape = cs
			shape.position.y = 0.3
		"wall", "foundation", "floor", "half_wall", "doorway", "window", "gable", "roof", "slope", "hatched", "door", "shutter":
			_build_piece(body, shape, kind, yaw)
		"torch":
			body.set_meta("hp", 40.0)
			var stick := MeshInstance3D.new()
			var scm := CylinderMesh.new()
			scm.top_radius = 0.04
			scm.bottom_radius = 0.06
			scm.height = 1.1
			stick.mesh = scm
			stick.material_override = _flat_mat(Color(0.40, 0.28, 0.16))
			stick.position.y = 0.55
			body.add_child(stick)
			var tflame := MeshInstance3D.new()
			var tfm := SphereMesh.new()
			tfm.radius = 0.14
			tfm.height = 0.32
			tflame.mesh = tfm
			var tfmat := StandardMaterial3D.new()
			tfmat.albedo_color = Color(1.0, 0.75, 0.2)
			tfmat.emission_enabled = true
			tfmat.emission = Color(1.0, 0.65, 0.15)
			tfmat.emission_energy_multiplier = 3.0
			tflame.material_override = tfmat
			tflame.position.y = 1.22
			body.add_child(tflame)
			var tlight := OmniLight3D.new()
			tlight.light_color = Color(1.0, 0.7, 0.3)
			tlight.omni_range = 8.0
			tlight.light_energy = 1.6
			tlight.position.y = 1.3
			body.add_child(tlight)
			var tcs := CylinderShape3D.new()
			tcs.radius = 0.1
			tcs.height = 1.2
			shape.shape = tcs
			shape.position.y = 0.6
		"crate", "chest", "drawers", "cabinet":
			body.set_meta("hp", 150.0)
			body.set_meta("store", {})
			var wood_c := Color(0.50, 0.38, 0.24)
			var dark_c := Color(0.40, 0.29, 0.17)
			match kind:
				"crate":
					_piece_box(body, Vector3(0.9, 0.7, 0.9), wood_c, Vector3(0, 0.35, 0))
					_piece_box(body, Vector3(0.95, 0.1, 0.12), dark_c, Vector3(0, 0.5, 0), false)
				"chest":
					_piece_box(body, Vector3(1.1, 0.65, 0.7), dark_c, Vector3(0, 0.33, 0))
					_piece_box(body, Vector3(1.14, 0.16, 0.74), Color(0.45, 0.30, 0.16), Vector3(0, 0.62, 0), false)
					_piece_box(body, Vector3(0.12, 0.14, 0.05), Color(0.6, 0.55, 0.35), Vector3(0, 0.42, -0.36), false)
				"drawers":
					_piece_box(body, Vector3(1.0, 1.0, 0.55), wood_c, Vector3(0, 0.5, 0))
					for dy in [0.25, 0.55, 0.85]:
						_piece_box(body, Vector3(0.85, 0.22, 0.05), dark_c, Vector3(0, dy, -0.29), false)
						_piece_box(body, Vector3(0.16, 0.05, 0.05), Color(0.3, 0.3, 0.32), Vector3(0, dy, -0.33), false)
				"cabinet":
					_piece_box(body, Vector3(1.0, 1.9, 0.55), wood_c, Vector3(0, 0.95, 0))
					_piece_box(body, Vector3(0.44, 1.7, 0.05), dark_c, Vector3(-0.24, 0.95, -0.29), false)
					_piece_box(body, Vector3(0.44, 1.7, 0.05), dark_c, Vector3(0.24, 0.95, -0.29), false)
		"lamp":
			body.set_meta("hp", 120.0)
			var post := MeshInstance3D.new()
			var pcm := CylinderMesh.new()
			pcm.top_radius = 0.05
			pcm.bottom_radius = 0.08
			pcm.height = 1.6
			post.mesh = pcm
			post.material_override = _flat_mat(Color(0.30, 0.32, 0.36))
			post.position.y = 0.8
			body.add_child(post)
			var cage := MeshInstance3D.new()
			var cgm := BoxMesh.new()
			cgm.size = Vector3(0.3, 0.34, 0.3)
			cage.mesh = cgm
			var lmat := StandardMaterial3D.new()
			lmat.albedo_color = Color(1.0, 0.9, 0.6)
			lmat.emission_enabled = true
			lmat.emission = Color(1.0, 0.85, 0.5)
			lmat.emission_energy_multiplier = 2.5
			cage.material_override = lmat
			cage.position.y = 1.75
			body.add_child(cage)
			var llight := OmniLight3D.new()
			llight.light_color = Color(1.0, 0.88, 0.6)
			llight.omni_range = 9.0
			llight.light_energy = 1.5
			llight.position.y = 1.75
			body.add_child(llight)
			var lcs := CylinderShape3D.new()
			lcs.radius = 0.12
			lcs.height = 1.9
			shape.shape = lcs
			shape.position.y = 0.95
		"painting":
			body.set_meta("hp", 40.0)
			var art_rng := RandomNumberGenerator.new()
			art_rng.seed = sname.hash()
			_piece_box(body, Vector3(0.9, 0.7, 0.06), Color(0.32, 0.22, 0.12), Vector3(0, 0, 0))
			var canvas_c := Color.from_hsv(art_rng.randf(), 0.3, 0.85)
			_piece_box(body, Vector3(0.78, 0.58, 0.03), canvas_c, Vector3(0, 0, -0.03), false)
			for k in art_rng.randi_range(3, 6):
				var blob := Color.from_hsv(art_rng.randf(), art_rng.randf_range(0.4, 0.8), art_rng.randf_range(0.4, 0.9))
				_piece_box(body, Vector3(art_rng.randf_range(0.08, 0.4), art_rng.randf_range(0.08, 0.35), 0.015),
					blob, Vector3(art_rng.randf_range(-0.28, 0.28), art_rng.randf_range(-0.2, 0.2), -0.05), false)
		"furnace":
			body.set_meta("hp", 250.0)
			var fstone := _flat_mat(Color(0.36, 0.36, 0.38))
			var fbody := MeshInstance3D.new()
			var fbm := BoxMesh.new()
			fbm.size = Vector3(1.2, 1.5, 1.2)
			fbody.mesh = fbm
			fbody.material_override = fstone
			fbody.position.y = 0.75
			body.add_child(fbody)
			var mouth := MeshInstance3D.new()
			var mbm := BoxMesh.new()
			mbm.size = Vector3(0.5, 0.45, 0.1)
			mouth.mesh = mbm
			var mmat := StandardMaterial3D.new()
			mmat.albedo_color = Color(1.0, 0.4, 0.1)
			mmat.emission_enabled = true
			mmat.emission = Color(1.0, 0.35, 0.05)
			mmat.emission_energy_multiplier = 2.0
			mouth.material_override = mmat
			mouth.position = Vector3(0, 0.45, -0.58)
			body.add_child(mouth)
			var chim := MeshInstance3D.new()
			var cbm2 := BoxMesh.new()
			cbm2.size = Vector3(0.4, 0.8, 0.4)
			chim.mesh = cbm2
			chim.material_override = fstone
			chim.position = Vector3(0, 1.9, 0.25)
			body.add_child(chim)
			var fcs := BoxShape3D.new()
			fcs.size = Vector3(1.2, 2.3, 1.2)
			shape.shape = fcs
			shape.position.y = 1.15
		"workbench":
			body.set_meta("hp", 200.0)
			var top := MeshInstance3D.new()
			var tbm := BoxMesh.new()
			tbm.size = Vector3(1.8, 0.12, 0.9)
			top.mesh = tbm
			top.material_override = _flat_mat(Color(0.50, 0.38, 0.24))
			top.position.y = 0.9
			body.add_child(top)
			for lx in [-0.8, 0.8]:
				for lz in [-0.35, 0.35]:
					var leg := MeshInstance3D.new()
					var lbm := BoxMesh.new()
					lbm.size = Vector3(0.12, 0.9, 0.12)
					leg.mesh = lbm
					leg.material_override = _flat_mat(Color(0.40, 0.29, 0.17))
					leg.position = Vector3(lx, 0.45, lz)
					body.add_child(leg)
			var vice := MeshInstance3D.new()
			var vbm := BoxMesh.new()
			vbm.size = Vector3(0.2, 0.18, 0.2)
			vice.mesh = vbm
			vice.material_override = _flat_mat(Color(0.45, 0.45, 0.48))
			vice.position = Vector3(0.7, 1.05, 0)
			body.add_child(vice)
			var wcs := BoxShape3D.new()
			wcs.size = Vector3(1.8, 1.1, 0.9)
			shape.shape = wcs
			shape.position.y = 0.55
		"forge":
			body.set_meta("hp", 300.0)
			var block := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.6, 1.1, 1.2)
			block.mesh = bm
			block.material_override = _flat_mat(Color(0.38, 0.38, 0.37))
			block.position.y = 0.55
			body.add_child(block)
			var chimney := MeshInstance3D.new()
			var chm := BoxMesh.new()
			chm.size = Vector3(0.5, 1.3, 0.5)
			chimney.mesh = chm
			chimney.material_override = _flat_mat(Color(0.32, 0.32, 0.31))
			chimney.position = Vector3(0.45, 1.7, 0)
			body.add_child(chimney)
			var ember := MeshInstance3D.new()
			var ebm := BoxMesh.new()
			ebm.size = Vector3(0.7, 0.4, 0.15)
			ember.mesh = ebm
			var ember_mat := StandardMaterial3D.new()
			ember_mat.albedo_color = Color(1.0, 0.45, 0.1)
			ember_mat.emission_enabled = true
			ember_mat.emission = Color(1.0, 0.4, 0.05)
			ember_mat.emission_energy_multiplier = 2.5
			ember.material_override = ember_mat
			ember.position = Vector3(0, 0.5, -0.55)
			body.add_child(ember)
			var flight := OmniLight3D.new()
			flight.light_color = Color(1.0, 0.55, 0.2)
			flight.omni_range = 6.0
			flight.position.y = 1.0
			body.add_child(flight)
			var fbs := BoxShape3D.new()
			fbs.size = Vector3(1.6, 2.3, 1.2)
			shape.shape = fbs
			shape.position.y = 1.15
		"beacon":
			body.set_meta("hp", 400.0)
			var base := MeshInstance3D.new()
			var basem := CylinderMesh.new()
			basem.top_radius = 0.7
			basem.bottom_radius = 0.9
			basem.height = 0.8
			base.mesh = basem
			base.material_override = _flat_mat(Color(0.42, 0.42, 0.40))
			base.position.y = 0.4
			body.add_child(base)
			var pole := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.12
			pm.bottom_radius = 0.18
			pm.height = 4.0
			pole.mesh = pm
			pole.material_override = _flat_mat(Color(0.40, 0.28, 0.16))
			pole.position.y = 2.6
			body.add_child(pole)
			var flame := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.5
			fm.height = 1.0
			flame.mesh = fm
			var flame_mat := StandardMaterial3D.new()
			flame_mat.albedo_color = Color(1.0, 0.75, 0.2)
			flame_mat.emission_enabled = true
			flame_mat.emission = Color(1.0, 0.7, 0.15)
			flame_mat.emission_energy_multiplier = 4.0
			flame.material_override = flame_mat
			flame.position.y = 5.0
			body.add_child(flame)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.75, 0.3)
			light.omni_range = 30.0
			light.light_energy = 2.0
			light.position.y = 5.0
			body.add_child(light)
			var bcs := CylinderShape3D.new()
			bcs.radius = 0.9
			bcs.height = 5.0
			shape.shape = bcs
			shape.position.y = 2.5
		"totem":
			body.set_meta("hp", 400.0)
			body.set_meta("stock", TOTEM_START_STOCK)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.6, 3.0, 0.6)
			mi.mesh = bm
			mi.material_override = _flat_mat(Color(0.55, 0.30, 0.15))
			mi.position.y = 1.5
			body.add_child(mi)
			var eye := MeshInstance3D.new()
			var em := SphereMesh.new()
			em.radius = 0.18
			em.height = 0.36
			eye.mesh = em
			var eye_mat := StandardMaterial3D.new()
			eye_mat.albedo_color = Color(0.2, 0.9, 0.9)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(0.2, 0.9, 0.9)
			eye.material_override = eye_mat
			eye.position = Vector3(0, 2.4, 0.31)
			body.add_child(eye)
			var lbl := Label3D.new()
			lbl.name = "StockLabel"
			lbl.text = "wood: %d" % TOTEM_START_STOCK
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.position.y = 3.5
			lbl.font_size = 48
			lbl.pixel_size = 0.005
			body.add_child(lbl)
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.6, 3.0, 0.6)
			shape.shape = bs
			shape.position.y = 1.5
	body.add_child(shape)
	holder.add_child(body)
	body.global_position = pos
	body.rotation.y = yaw

@rpc("any_peer", "call_local", "reliable")
func sv_deposit_wood(sname: String, amount: int) -> void:
	if not multiplayer.is_server():
		return
	var holder := get_node("Structures")
	if not holder.has_node(sname):
		return
	var t := holder.get_node(sname)
	if t.get_meta("kind") != "totem":
		return
	rx_totem_stock.rpc(sname, int(t.get_meta("stock")) + clampi(amount, 0, 100))

@rpc("authority", "call_local", "reliable")
func rx_totem_stock(sname: String, stock: int) -> void:
	var holder := get_node("Structures")
	if not holder.has_node(sname):
		return
	var t := holder.get_node(sname)
	t.set_meta("stock", stock)
	if t.has_node("StockLabel"):
		t.get_node("StockLabel").text = "wood: %d" % stock

@rpc("authority", "call_local", "reliable")
func rx_struct_hp(sname: String, hp: float) -> void:
	var holder := get_node("Structures")
	if not holder.has_node(sname):
		return
	if hp <= 0.0:
		holder.get_node(sname).queue_free()
	else:
		holder.get_node(sname).set_meta("hp", hp)

func _is_protected(pos: Vector3) -> bool:
	for s in get_node("Structures").get_children():
		if s.get_meta("kind") == "totem" and int(s.get_meta("stock")) > 0:
			if s.global_position.distance_to(pos) <= CLAIM_RADIUS:
				return true
	return false

# ================================================================ shipwreck

var wreck_pos := Vector3.ZERO

func _build_shipwreck() -> void:
	# Every island has one: the ship you washed up from, beached on the coast.
	# First quest site — lootable supply crates.
	var rng := RandomNumberGenerator.new()
	rng.seed = wseed + 999
	var ang := rng.randf() * TAU
	var dir := Vector3(cos(ang), 0, sin(ang))
	var r := SIZE * CELL * 0.46
	while r > 10.0 and height_at(dir.x * r, dir.z * r) < 0.3:
		r -= 2.0
	wreck_pos = dir * (r + 5.0)
	wreck_pos.y = maxf(height_at(wreck_pos.x, wreck_pos.z), -0.4)

	var holder := Node3D.new()
	holder.name = "Wreck"
	add_child(holder)
	for i in 4:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(2.0, 5.0), 0.35, rng.randf_range(0.8, 1.6))
		mi.mesh = bm
		mi.material_override = _flat_mat(Color(0.36, 0.25, 0.15))
		holder.add_child(mi)
		mi.global_position = wreck_pos + Vector3(rng.randf_range(-3, 3), rng.randf_range(0.3, 1.5), rng.randf_range(-3, 3))
		mi.rotation_degrees = Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 360), rng.randf_range(-25, 25))
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.12
	mm.bottom_radius = 0.2
	mm.height = 8.0
	mast.mesh = mm
	mast.material_override = _flat_mat(Color(0.30, 0.21, 0.13))
	holder.add_child(mast)
	mast.global_position = wreck_pos + Vector3(0, 2.2, 0)
	mast.rotation_degrees.z = 55.0
	for i in 2:
		var crate := StaticBody3D.new()
		crate.name = "crate_%d" % i
		crate.set_meta("crate", true)
		crate.set_meta("looted", false)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1, 1, 1)
		mi.mesh = bm
		mi.material_override = _flat_mat(Color(0.58, 0.44, 0.20))
		mi.position.y = 0.5
		crate.add_child(mi)
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1, 1, 1)
		shape.shape = bs
		shape.position.y = 0.5
		crate.add_child(shape)
		holder.add_child(crate)
		crate.global_position = wreck_pos + Vector3(i * 2.4 - 1.2, 0.1, 2.2)
		crate.rotation.y = rng.randf() * TAU

@rpc("any_peer", "call_local", "reliable")
func sv_loot_crate(cname: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	var holder := get_node("Wreck")
	if not holder.has_node(cname):
		return
	if holder.get_node(cname).get_meta("looted"):
		return
	rx_crate_looted.rpc(cname)
	_grant_items(sender, {"string": 2, "fiber": 4, "berries": 4, "journal": 1})
	var players := get_node("Players")
	if players.has_node(str(sender)):
		players.get_node(str(sender)).rx_event.rpc_id(sender, "looted_wreck")

@rpc("authority", "call_local", "reliable")
func rx_crate_looted(cname: String) -> void:
	var holder := get_node("Wreck")
	if not holder.has_node(cname):
		return
	var crate := holder.get_node(cname)
	crate.set_meta("looted", true)
	for c in crate.get_children():
		if c is MeshInstance3D:
			c.material_override = _flat_mat(Color(0.30, 0.24, 0.15))

# ================================================================ the leviathan

var leviathan_dead := false

func _summon_leviathan() -> void:
	if not multiplayer.is_server() or leviathan_dead or has_node("Lev"):
		return
	# It answers from the deep water beyond the wreck.
	var flat := Vector2(wreck_pos.x, wreck_pos.z)
	var dir := flat.normalized() if flat.length() > 1.0 else Vector2.RIGHT
	var anchor_2d := dir * (flat.length() + 26.0)
	rx_spawn_leviathan.rpc(Vector3(anchor_2d.x, 0.1, anchor_2d.y))

@rpc("authority", "call_local", "reliable")
func rx_spawn_leviathan(anchor: Vector3) -> void:
	if has_node("Lev"):
		return
	var lev := Leviathan.new()
	lev.name = "Lev"
	add_child(lev)
	lev.setup(anchor)
	Sfx.play_at(self, anchor, "roar", 6.0)   # heard across half the island

@rpc("any_peer", "call_local", "reliable")
func sv_attack_leviathan(dmg: float) -> void:
	if not multiplayer.is_server() or not has_node("Lev"):
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	var lev: Leviathan = get_node("Lev")
	if lev.dying:
		return
	lev.hp -= clampf(dmg, 0.0, 60.0)
	lev.on_hit(sender)
	if lev.hp <= 0.0:
		leviathan_dead = true
		rx_leviathan_dead.rpc()
		_grant_items(sender, {"leviathan_scale": 5, "raw_meat": 8})
		for p in get_node("Players").get_children():
			p.rx_event.rpc_id(p.peer_id, "kill_leviathan")
		save_now()

@rpc("authority", "call_local", "reliable")
func rx_leviathan_dead() -> void:
	if has_node("Lev"):
		get_node("Lev").die()

# ================================================================ the ruins & the peak

var peak_pos := Vector3.ZERO

func _find_peak() -> void:
	# Deterministic highest point — where the Signal Beacon must burn.
	var half := SIZE * CELL * 0.5
	var best_h := -999.0
	var x := -half
	while x <= half:
		var z := -half
		while z <= half:
			var h := height_at(x, z)
			if h > best_h:
				best_h = h
				peak_pos = Vector3(x, h, z)
			z += 4.0
		x += 4.0

func _build_ruins() -> void:
	# An older castaway's collapsed homestead, somewhere inland.
	# Its chest is locked — the wolves got to the captain first.
	var rng := RandomNumberGenerator.new()
	rng.seed = wseed + 4242
	var pos := Vector3.ZERO
	for attempt in 200:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(SIZE * CELL * 0.15, SIZE * CELL * 0.35)
		var p := Vector3(cos(ang), 0, sin(ang)) * r
		var h := height_at(p.x, p.z)
		if h > 3.0 and h < 9.0:
			pos = Vector3(p.x, h, p.z)
			break
	if pos == Vector3.ZERO:
		pos = Vector3(0, height_at(0, 0), 0)

	var holder := Node3D.new()
	holder.name = "Ruins"
	add_child(holder)
	var stone := _flat_mat(Color(0.42, 0.42, 0.40))
	# broken wall stubs in a rough square
	for i in 8:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(1.2, 2.8), rng.randf_range(0.6, 2.0), 0.5)
		mi.mesh = bm
		mi.material_override = stone
		holder.add_child(mi)
		var ang := i * TAU / 8.0 + rng.randf_range(-0.2, 0.2)
		mi.global_position = pos + Vector3(cos(ang), 0, sin(ang)) * 4.0 + Vector3(0, bm.size.y * 0.5, 0)
		mi.rotation.y = ang + PI / 2.0 + rng.randf_range(-0.2, 0.2)
	# the locked chest
	var chest := StaticBody3D.new()
	chest.name = "ruins_chest"
	chest.set_meta("chest", true)
	chest.set_meta("opened", false)
	var cmesh := MeshInstance3D.new()
	var cbm := BoxMesh.new()
	cbm.size = Vector3(1.1, 0.8, 0.7)
	cmesh.mesh = cbm
	cmesh.material_override = _flat_mat(Color(0.35, 0.24, 0.12))
	cmesh.position.y = 0.4
	chest.add_child(cmesh)
	var band := MeshInstance3D.new()
	var bbm := BoxMesh.new()
	bbm.size = Vector3(1.14, 0.16, 0.74)
	band.mesh = bbm
	band.material_override = _flat_mat(Color(0.45, 0.30, 0.16))
	band.position.y = 0.55
	chest.add_child(band)
	var cshape := CollisionShape3D.new()
	var cbs := BoxShape3D.new()
	cbs.size = Vector3(1.1, 0.8, 0.7)
	cshape.shape = cbs
	cshape.position.y = 0.4
	chest.add_child(cshape)
	holder.add_child(chest)
	chest.global_position = pos
	chest.rotation.y = rng.randf() * TAU

@rpc("any_peer", "call_local", "reliable")
func sv_open_chest() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	var chest := get_node("Ruins/ruins_chest")
	if chest.get_meta("opened"):
		return
	rx_chest_opened.rpc()
	_grant_items(sender, {"ancient_lens": 1, "string": 3, "cooked_meat": 2})
	var players := get_node("Players")
	if players.has_node(str(sender)):
		players.get_node(str(sender)).rx_event.rpc_id(sender, "opened_ruins")

@rpc("authority", "call_local", "reliable")
func rx_chest_opened() -> void:
	var chest := get_node("Ruins/ruins_chest")
	chest.set_meta("opened", true)
	for c in chest.get_children():
		if c is MeshInstance3D:
			c.material_override = _flat_mat(Color(0.22, 0.16, 0.09))

# ================================================================ building pieces

func _piece_box(body: Node3D, size: Vector3, c: Color, pos: Vector3, with_shape := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _flat_mat(c)
	mi.position = pos
	body.add_child(mi)
	if with_shape:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		body.add_child(cs)

func _build_piece(body: StaticBody3D, shape: CollisionShape3D, kind: String, yaw: float) -> void:
	var wood := Color(0.50, 0.38, 0.24)
	var wood_dark := Color(0.40, 0.29, 0.17)
	var thatch := Color(0.68, 0.60, 0.34)
	var hp: float = {"foundation": 250.0, "wall": 150.0, "door": 100.0, "shutter": 60.0}.get(kind, 120.0)
	body.set_meta("hp", hp)
	body.set_meta("base_yaw", yaw)
	match kind:
		"foundation":
			body.set_meta("top_y", 0.0)   # top is at body origin
			_piece_box(body, Vector3(3, 0.5, 3), wood_dark, Vector3(0, -0.25, 0))
		"floor":
			_piece_box(body, Vector3(3, 0.22, 3), wood, Vector3(0, 0.11, 0))
		"roof":
			_piece_box(body, Vector3(3.3, 0.22, 3.3), wood_dark, Vector3(0, 0.11, 0))
		"wall":
			_piece_box(body, Vector3(3, 2.6, 0.22), wood, Vector3(0, 1.3, 0))
		"half_wall":
			_piece_box(body, Vector3(3, 1.3, 0.22), wood, Vector3(0, 0.65, 0))
		"doorway":
			_piece_box(body, Vector3(0.9, 2.6, 0.22), wood, Vector3(-1.05, 1.3, 0))
			_piece_box(body, Vector3(0.9, 2.6, 0.22), wood, Vector3(1.05, 1.3, 0))
			_piece_box(body, Vector3(1.2, 0.5, 0.22), wood, Vector3(0, 2.35, 0))
		"window":
			_piece_box(body, Vector3(0.9, 2.6, 0.22), wood, Vector3(-1.05, 1.3, 0))
			_piece_box(body, Vector3(0.9, 2.6, 0.22), wood, Vector3(1.05, 1.3, 0))
			_piece_box(body, Vector3(1.2, 1.0, 0.22), wood, Vector3(0, 0.5, 0))
			_piece_box(body, Vector3(1.2, 0.5, 0.22), wood, Vector3(0, 2.35, 0))
		"gable":
			var mi := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(3, 1.5, 0.22)
			mi.mesh = pm
			mi.material_override = _flat_mat(wood)
			mi.position.y = 0.75
			body.add_child(mi)
			var cs := CollisionShape3D.new()
			cs.shape = pm.create_convex_shape()
			cs.position.y = 0.75
			body.add_child(cs)
		"slope":
			var mi := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(3, 1.5, 3)
			pm.left_to_right = 1.0
			mi.mesh = pm
			mi.material_override = _flat_mat(wood_dark)
			mi.position.y = 0.75
			body.add_child(mi)
			var cs := CollisionShape3D.new()
			cs.shape = pm.create_convex_shape()
			cs.position.y = 0.75
			body.add_child(cs)
		"hatched":
			var mi := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(3.4, 1.5, 3.4)
			mi.mesh = pm
			mi.material_override = _flat_mat(thatch)
			mi.position.y = 0.75
			body.add_child(mi)
			var cs := CollisionShape3D.new()
			cs.shape = pm.create_convex_shape()
			cs.position.y = 0.75
			body.add_child(cs)
		"door":
			# body origin = hinge; panel hangs to +x, swings on toggle
			body.set_meta("open", false)
			_piece_box(body, Vector3(1.16, 2.15, 0.09), wood_dark, Vector3(0.58, 1.1, 0))
			var knob := MeshInstance3D.new()
			var km := SphereMesh.new()
			km.radius = 0.05
			km.height = 0.1
			knob.mesh = km
			knob.material_override = _flat_mat(Color(0.3, 0.3, 0.32))
			knob.position = Vector3(1.0, 1.1, -0.08)
			body.add_child(knob)
		"shutter":
			body.set_meta("open", false)
			_piece_box(body, Vector3(1.16, 1.0, 0.07), wood_dark, Vector3(0.58, 1.5, 0))
	# the primary shape node is unused for pieces (each box brings its own)
	shape.disabled = true

@rpc("any_peer", "call_local", "reliable")
func sv_toggle_door(sname: String) -> void:
	if not multiplayer.is_server():
		return
	var holder := get_node("Structures")
	if not holder.has_node(sname):
		return
	var s := holder.get_node(sname)
	if s.get_meta("kind") not in ["door", "shutter"]:
		return
	rx_door.rpc(sname, not s.get_meta("open"))

@rpc("authority", "call_local", "reliable")
func rx_door(sname: String, open: bool) -> void:
	var holder := get_node("Structures")
	if not holder.has_node(sname):
		return
	var s := holder.get_node(sname)
	s.set_meta("open", open)
	var target: float = float(s.get_meta("base_yaw")) + (1.9 if open else 0.0)
	var tw := s.create_tween()
	tw.tween_property(s, "rotation:y", target, 0.25).set_trans(Tween.TRANS_SINE)
	Sfx.play_at(self, s.global_position, "place", -14.0)

@rpc("any_peer", "call_local", "reliable")
func sv_remove_structure(sname: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	var holder := get_node("Structures")
	if not holder.has_node(sname):
		return
	var kind: String = holder.get_node(sname).get_meta("kind")
	if kind == "totem":
		return   # totems fall to decay, not hammers
	if kind in GameItems.BUILD_PIECES:
		_grant_items(sender, {"wood": int(GameItems.BUILD_PIECES[kind]["wood"] / 2.0)})
	rx_remove_structure.rpc(sname)

@rpc("authority", "call_local", "reliable")
func rx_remove_structure(sname: String) -> void:
	var holder := get_node("Structures")
	if holder.has_node(sname):
		holder.get_node(sname).queue_free()

@rpc("any_peer", "call_local", "reliable")
func sv_repair(sname: String) -> void:
	if not multiplayer.is_server():
		return
	var holder := get_node("Structures")
	if not holder.has_node(sname):
		return
	var s := holder.get_node(sname)
	rx_struct_hp.rpc(sname, minf(float(s.get_meta("hp")) + 40.0, 400.0))

# ================================================================ fire

var _fire_accum := 0.0

func _fire_tick() -> void:
	# Open flames are useful and dangerous — that's the deal.
	var structs := get_node("Structures").get_children()
	for s in structs:
		var kind: String = s.get_meta("kind")
		if kind in ["torch", "campfire"]:
			for t in structs:
				if t.get_meta("kind") in GameItems.BUILD_PIECES \
						and not t.get_meta("burning", false) \
						and t.global_position.distance_to(s.global_position) < 2.4 \
						and randf() < 0.015:
					rx_ignite.rpc(String(t.name))
			if kind == "campfire":
				for p in get_node("Players").get_children():
					if p.global_position.distance_to(s.global_position) < 0.9:
						p.rx_damage.rpc_id(p.peer_id, 4.0)
	for s in structs:
		if s.get_meta("burning", false):
			var bt: float = float(s.get_meta("burn_t")) - 2.0
			s.set_meta("burn_t", bt)
			rx_struct_hp.rpc(String(s.name), float(s.get_meta("hp")) - 9.0)
			if bt <= 0.0 and get_node("Structures").has_node(String(s.name)):
				rx_extinguish.rpc(String(s.name))

@rpc("authority", "call_local", "reliable")
func rx_ignite(sname: String) -> void:
	var holder := get_node("Structures")
	if not holder.has_node(sname):
		return
	var s := holder.get_node(sname)
	if s.get_meta("burning", false):
		return
	s.set_meta("burning", true)
	s.set_meta("burn_t", 10.0)
	var fx := Node3D.new()
	fx.name = "FireFx"
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.35
	fm.height = 0.7
	flame.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.5, 0.1, 0.85)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.45, 0.05)
	fmat.emission_energy_multiplier = 3.0
	flame.material_override = fmat
	flame.position.y = 1.2
	fx.add_child(flame)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.5, 0.15)
	fl.omni_range = 6.0
	fl.position.y = 1.2
	fx.add_child(fl)
	s.add_child(fx)
	Sfx.play_at(self, s.global_position, "roar", -16.0)

@rpc("authority", "call_local", "reliable")
func rx_extinguish(sname: String) -> void:
	var holder := get_node("Structures")
	if not holder.has_node(sname):
		return
	var s := holder.get_node(sname)
	s.set_meta("burning", false)
	if s.has_node("FireFx"):
		s.get_node("FireFx").queue_free()

# ================================================================ storage & furnace

func container_stacks_used(store: Dictionary) -> int:
	var used := 0
	for item in store:
		used += ceili(float(store[item]) / GameItems.stack_max(item))
	return used

@rpc("any_peer", "call_local", "reliable")
func sv_container_put(sname: String, item: String, count: int) -> void:
	if not multiplayer.is_server():
		return
	var holder := get_node("Structures")
	if not holder.has_node(sname) or count <= 0:
		return
	var s := holder.get_node(sname)
	var kind: String = s.get_meta("kind")
	if kind not in GameItems.CONTAINERS:
		return
	var store: Dictionary = s.get_meta("store")
	store[item] = int(store.get(item, 0)) + count
	if container_stacks_used(store) > GameItems.CONTAINERS[kind] * 4:
		store[item] -= count   # over capacity — bounce it back
		if store[item] <= 0:
			store.erase(item)
		_grant_items(multiplayer.get_remote_sender_id() if multiplayer.get_remote_sender_id() != 0 else 1, {item: count})
		return
	rx_container_store.rpc(sname, store)

@rpc("any_peer", "call_local", "reliable")
func sv_container_take(sname: String, item: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	var holder := get_node("Structures")
	if not holder.has_node(sname):
		return
	var s := holder.get_node(sname)
	var store: Dictionary = s.get_meta("store")
	if not store.has(item):
		return
	var count: int = mini(int(store[item]), GameItems.stack_max(item))
	store[item] -= count
	if store[item] <= 0:
		store.erase(item)
	rx_container_store.rpc(sname, store)
	_grant_items(sender, {item: count})

@rpc("authority", "call_local", "reliable")
func rx_container_store(sname: String, store: Dictionary) -> void:
	var holder := get_node("Structures")
	if holder.has_node(sname):
		holder.get_node(sname).set_meta("store", store)

@rpc("any_peer", "call_local", "reliable")
func sv_make_charcoal() -> void:
	# The client already burned its 4 wood; the furnace answers with charcoal.
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	_grant_items(sender, {"charcoal": 2})

# ================================================================ the sea cave

var cave_pos := Vector3.ZERO

func _build_cave() -> void:
	# A dark grotto beneath the cliffs on the far side of the island from the
	# wreck. The roof blocks the sun; inside, torchlight is the only safety.
	var rng := RandomNumberGenerator.new()
	rng.seed = wseed + 777
	var wreck_ang := atan2(wreck_pos.z, wreck_pos.x)
	var best := Vector3.ZERO
	var best_flatness := 99.0
	for attempt in 300:
		var ang := wreck_ang + PI + rng.randf_range(-1.2, 1.2)
		var r := rng.randf_range(SIZE * CELL * 0.2, SIZE * CELL * 0.4)
		var p := Vector3(cos(ang) * r, 0, sin(ang) * r)
		var h := height_at(p.x, p.z)
		if h < 4.0 or h > 10.0:
			continue
		var spread := 0.0
		for k in 8:
			var oa := k * TAU / 8.0
			spread = maxf(spread, absf(height_at(p.x + cos(oa) * 8.0, p.z + sin(oa) * 8.0) - h))
		if spread < best_flatness:
			best_flatness = spread
			best = Vector3(p.x, h, p.z)
	cave_pos = best if best != Vector3.ZERO else Vector3(40, height_at(40, 40), 40)

	var holder := Node3D.new()
	holder.name = "Cave"
	add_child(holder)
	var stone := _flat_mat(Color(0.22, 0.22, 0.24))
	var inner_r := 9.0
	# ring walls, one gap for the mouth (facing the sea / away from island center)
	var mouth_ang := atan2(cave_pos.z, cave_pos.x)
	for k in 10:
		var ang := k * TAU / 10.0
		if absf(wrapf(ang - mouth_ang, -PI, PI)) < 0.5:
			continue   # the mouth
		var wall := StaticBody3D.new()
		var wm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(6.4, 7.0, 2.2)
		wm.mesh = bm
		wm.material_override = stone
		wm.position.y = 2.6
		wall.add_child(wm)
		var ws := CollisionShape3D.new()
		var wbs := BoxShape3D.new()
		wbs.size = bm.size
		ws.shape = wbs
		ws.position.y = 2.6
		wall.add_child(ws)
		holder.add_child(wall)
		var wp := cave_pos + Vector3(cos(ang), 0, sin(ang)) * inner_r
		wall.global_position = Vector3(wp.x, height_at(wp.x, wp.z) - 0.6, wp.z)
		wall.rotation.y = -ang + PI / 2.0
	# roof slabs — these make the dark
	for k in 3:
		var roof := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(24.0 - k * 4.0, 1.6, 24.0 - k * 4.0)
		roof.mesh = rm
		roof.material_override = stone
		holder.add_child(roof)
		roof.global_position = cave_pos + Vector3(0, 6.0 + k * 1.3, 0)
		roof.rotation.y = k * 0.35
	# ore garden inside: iron + the island's only moonstone
	var res_holder := get_node("Resources")
	for k in 5:
		var ang := rng.randf() * TAU
		var rr := rng.randf_range(2.0, inner_r - 2.5)
		var kind := "moonstone" if k < 3 else "iron"
		var res := _make_resource(kind, 9000 + k)
		res_holder.add_child(res)
		var rp := cave_pos + Vector3(cos(ang) * rr, 0, sin(ang) * rr)
		res.global_position = Vector3(rp.x, height_at(rp.x, rp.z), rp.z)
		res.rotation.y = rng.randf() * TAU

func light_near(pos: Vector3, radius: float) -> bool:
	# Is there a burning structure — or a survivor gripping a torch —
	# close enough to hold the dark back?
	for s in get_node("Structures").get_children():
		if s.get_meta("kind") in ["torch", "campfire", "beacon", "lamp"] \
				and s.global_position.distance_to(pos) < radius:
			return true
	for p in get_node("Players").get_children():
		if (p.held_net == "torch" or p.lamp_net) and p.global_position.distance_to(pos) < radius:
			return true
	return false

# ================================================================ the far isle

func _build_far_isle() -> void:
	# Chain #2's destination: smaller, taller, harsher, richer. Reached by
	# raft — a moonstone guides you through the reef.
	var rng := RandomNumberGenerator.new()
	rng.seed = wseed + 92
	var res_holder := get_node("Resources")
	for i in 220:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(0.0, FAR_R * 0.85)
		var x := far_center.x + cos(ang) * r
		var z := far_center.y + sin(ang) * r
		var h := height_at(x, z)
		if h < 1.2:
			continue
		var roll := rng.randf()
		var kind := "tree"
		if roll < 0.14:
			kind = "rock"
		elif roll < 0.24:
			kind = "iron"      # far richer veins than home
		elif roll < 0.30 and h > 10.0:
			kind = "moonstone"
		elif roll < 0.42:
			kind = "branch"
		elif roll < 0.54:
			kind = "grass"
		elif roll < 0.60:
			kind = "bush"
		var res := _make_resource(kind, 10000 + i)
		res_holder.add_child(res)
		res.global_position = Vector3(x, h, z)
		res.rotation.y = rng.randf() * TAU

	# the Monolith — at the far isle's heart, waiting for moonstones
	var mono := StaticBody3D.new()
	mono.name = "Monolith"
	mono.set_meta("monolith", true)
	mono.set_meta("awakened", false)
	var mh := height_at(far_center.x, far_center.y)
	var slab := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(1.6, 5.5, 0.9)
	slab.mesh = sm
	slab.material_override = _flat_mat(Color(0.12, 0.12, 0.15))
	slab.position.y = 2.75
	mono.add_child(slab)
	var socket := MeshInstance3D.new()
	var scm := BoxMesh.new()
	scm.size = Vector3(0.5, 0.5, 0.2)
	socket.mesh = scm
	socket.name = "Socket"
	socket.material_override = _flat_mat(Color(0.25, 0.28, 0.35))
	socket.position = Vector3(0, 2.6, -0.4)
	mono.add_child(socket)
	var mshape := CollisionShape3D.new()
	var mbs := BoxShape3D.new()
	mbs.size = Vector3(1.8, 5.5, 1.1)
	mshape.shape = mbs
	mshape.position.y = 2.75
	mono.add_child(mshape)
	add_child(mono)
	mono.global_position = Vector3(far_center.x, mh, far_center.y)

@rpc("any_peer", "call_local", "reliable")
func sv_awaken_monolith() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	if get_node("Monolith").get_meta("awakened"):
		return
	rx_monolith_awakened.rpc()
	_grant_items(sender, {"iron_bar": 6, "cooked_meat": 5, "string": 8})
	var players := get_node("Players")
	if players.has_node(str(sender)):
		players.get_node(str(sender)).rx_event.rpc_id(sender, "monolith_awakened")
	save_now()

@rpc("authority", "call_local", "reliable")
func rx_monolith_awakened() -> void:
	var mono := get_node("Monolith")
	if mono.get_meta("awakened"):
		return
	mono.set_meta("awakened", true)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.75, 0.85, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.55, 0.7, 1.0)
	glow.emission_energy_multiplier = 3.0
	mono.get_node("Socket").material_override = glow
	var mlight := OmniLight3D.new()
	mlight.light_color = Color(0.6, 0.75, 1.0)
	mlight.omni_range = 14.0
	mlight.light_energy = 2.0
	mlight.position.y = 3.0
	mono.add_child(mlight)
	Sfx.play_at(self, mono.global_position, "chime", 2.0)

# ================================================================ persistence

var _save_accum := 0.0

func _save_file() -> String:
	return "user://saves/world_%d.json" % wseed

func save_now() -> void:
	if not multiplayer.is_server() or multiplayer.multiplayer_peer == null:
		return
	DirAccess.make_dir_recursive_absolute("user://saves")
	var structs: Array = []
	for s in get_node("Structures").get_children():
		var e := {
			"name": String(s.name), "kind": s.get_meta("kind"),
			"pos": [s.global_position.x, s.global_position.y, s.global_position.z],
			"yaw": s.rotation.y, "hp": s.get_meta("hp"),
		}
		if s.get_meta("kind") == "totem":
			e["stock"] = int(s.get_meta("stock"))
		if s.get_meta("kind") in GameItems.CONTAINERS:
			e["store"] = s.get_meta("store")
		structs.append(e)
	var res := {}
	for r in get_node("Resources").get_children():
		var hp: float = r.get_meta("hp")
		if hp < GameItems.RES_STATS[r.get_meta("kind")]["hp"]:
			res[String(r.name)] = hp
	var crates: Array = []
	for c in get_node("Wreck").get_children():
		if c is StaticBody3D and c.get_meta("looted", false):
			crates.append(String(c.name))
	var data := {
		"day": day, "tod": time_of_day, "struct_counter": struct_counter,
		"structs": structs, "res": res, "looted": crates,
		"chest_opened": get_node("Ruins/ruins_chest").get_meta("opened"),
		"lev_dead": leviathan_dead,
		"monolith": get_node("Monolith").get_meta("awakened"),
	}
	var f := FileAccess.open(_save_file(), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

func _load_save() -> bool:
	if not FileAccess.file_exists(_save_file()):
		return false
	var f := FileAccess.open(_save_file(), FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if data == null:
		return false
	day = int(data.get("day", 1))
	time_of_day = float(data.get("tod", 8.0))
	struct_counter = int(data.get("struct_counter", 0))
	for e in data.get("structs", []):
		var pos: Array = e["pos"]
		rx_place_structure(e["name"], e["kind"], Vector3(pos[0], pos[1], pos[2]), float(e["yaw"]))
		rx_struct_hp(e["name"], float(e["hp"]))
		if e["kind"] == "totem":
			rx_totem_stock(e["name"], int(e.get("stock", 0)))
		if e["kind"] in GameItems.CONTAINERS:
			var st: Dictionary = e.get("store", {})
			var clean := {}
			for k in st:
				clean[String(k)] = int(st[k])
			rx_container_store(e["name"], clean)
	for rname in data.get("res", {}):
		rx_resource_hp(rname, float(data["res"][rname]))
	for cname in data.get("looted", []):
		rx_crate_looted(cname)
	if data.get("chest_opened", false):
		rx_chest_opened()
	if data.get("monolith", false):
		rx_monolith_awakened()
	leviathan_dead = data.get("lev_dead", false)
	if not leviathan_dead:
		for e in data.get("structs", []):
			var pos: Array = e["pos"]
			if e["kind"] == "beacon" and Vector2(pos[0] - peak_pos.x, pos[2] - peak_pos.z).length() < 15.0:
				_summon_leviathan()   # the beacon still burns; so does its answer
				break
	print("[maroon] world %d restored: day %d, %d structures" % [wseed, day, data.get("structs", []).size()])
	return true

# ================================================================ time & ticks

func is_night() -> bool:
	return time_of_day < 5.5 or time_of_day > 20.5

func _process(delta: float) -> void:
	if multiplayer.is_server() and multiplayer.multiplayer_peer != null:
		var was_night := is_night()
		time_of_day += delta * 24.0 / DAY_LENGTH
		if time_of_day >= 24.0:
			time_of_day -= 24.0
			day += 1
		if is_night() and not was_night:
			_on_nightfall()
		_time_sync_accum += delta
		if _time_sync_accum >= 2.0:
			_time_sync_accum = 0.0
			rx_time.rpc(time_of_day, day)
		_decay_tick(delta)
		_fire_accum += delta
		if _fire_accum >= 2.0:
			_fire_accum = 0.0
			_fire_tick()
		_save_accum += delta
		if _save_accum >= 60.0:
			_save_accum = 0.0
			save_now()
	_apply_time_of_day()

func _on_nightfall() -> void:
	# The island pushes back: more wolves each night.
	var rng := RandomNumberGenerator.new()
	rng.seed = wseed + day * 131
	var wolves := 0
	for a in get_node("Animals").get_children():
		if a.kind == "wolf":
			wolves += 1
	for i in mini(2 + day / 2, 10 - wolves):
		_server_spawn_animal("wolf", rng)
	if get_node("Animals").get_children().filter(func(a): return a.kind == "deer").size() < 4:
		for i in 3:
			_server_spawn_animal("deer", rng)

@rpc("authority", "call_local", "unreliable")
func rx_time(tod: float, d: int) -> void:
	time_of_day = tod
	day = d

func _apply_time_of_day() -> void:
	if sun == null:
		return
	var t := (time_of_day - 6.0) / 12.0   # 0 at sunrise, 1 at sunset
	sun.rotation_degrees = Vector3(-t * 180.0, 30.0, 0)
	var elevation := sin(t * PI)
	sun.light_energy = clampf(elevation, 0.03, 1.0)
	sun.light_color = Color(1.0, lerpf(0.55, 0.95, clampf(elevation, 0, 1)), lerpf(0.35, 0.9, clampf(elevation, 0, 1)))

func _decay_tick(delta: float) -> void:
	_decay_accum += delta
	_totem_feed_accum += delta
	if _totem_feed_accum >= 60.0:
		_totem_feed_accum = 0.0
		for s in get_node("Structures").get_children():
			if s.get_meta("kind") == "totem":
				var stock := int(s.get_meta("stock"))
				if stock > 0:
					rx_totem_stock.rpc(s.name, stock - 1)
	if _decay_accum >= 10.0:
		_decay_accum = 0.0
		for s in get_node("Structures").get_children():
			var kind: String = s.get_meta("kind")
			var starved_totem := kind == "totem" and int(s.get_meta("stock")) <= 0
			if kind != "totem" and _is_protected(s.global_position):
				continue
			if kind == "totem" and not starved_totem:
				continue
			rx_struct_hp.rpc(s.name, float(s.get_meta("hp")) - 4.0)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or multiplayer.multiplayer_peer == null:
		return
	for a in get_node("Animals").get_children():
		a.server_ai(delta, self)
	if has_node("Lev"):
		get_node("Lev").server_ai(delta, self)
	_anim_sync_accum += delta
	if _anim_sync_accum >= 0.12:
		_anim_sync_accum = 0.0
		var states: Array = []
		for a in get_node("Animals").get_children():
			states.append([String(a.name), a.global_position, a.rotation.y])
		if states.size() > 0:
			rx_animal_states.rpc(states)
		if has_node("Lev"):
			var lev: Leviathan = get_node("Lev")
			if not lev.dying:
				rx_lev_state.rpc(lev.global_position, lev.rotation.y)

# ================================================================ late-join sync

func sync_to(peer: int) -> void:
	rx_time.rpc_id(peer, time_of_day, day)
	for a in get_node("Animals").get_children():
		rx_spawn_animal.rpc_id(peer, a.name, a.kind, a.global_position)
	for s in get_node("Structures").get_children():
		rx_place_structure.rpc_id(peer, s.name, s.get_meta("kind"), s.global_position, s.rotation.y)
		rx_struct_hp.rpc_id(peer, s.name, s.get_meta("hp"))
		if s.get_meta("kind") == "totem":
			rx_totem_stock.rpc_id(peer, s.name, int(s.get_meta("stock")))
		if s.get_meta("kind") in GameItems.CONTAINERS:
			rx_container_store.rpc_id(peer, String(s.name), s.get_meta("store"))
	for r in get_node("Resources").get_children():
		var hp: float = r.get_meta("hp")
		if hp < GameItems.RES_STATS[r.get_meta("kind")]["hp"]:
			rx_resource_hp.rpc_id(peer, String(r.name), hp)
	for c in get_node("Wreck").get_children():
		if c is StaticBody3D and c.get_meta("looted", false):
			rx_crate_looted.rpc_id(peer, String(c.name))
	if get_node("Ruins/ruins_chest").get_meta("opened"):
		rx_chest_opened.rpc_id(peer)
	if get_node("Monolith").get_meta("awakened"):
		rx_monolith_awakened.rpc_id(peer)
	if has_node("Lev") and not get_node("Lev").dying:
		rx_spawn_leviathan.rpc_id(peer, get_node("Lev").anchor)
