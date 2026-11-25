extends Node3D
# Smuggler's Cove (Ludo video #55): a small pirate game dressed with 25 Ludo Prop models and a Ludo Hero pirate.
# Goal: knock five barrels into the sea. Sand texture: Ludo (image type texture). Water, dock planks and the
# cannonball are Godot primitives (our code). Every prop and the pirate are Ludo generations in res://props and res://pirate.
# Controls: arrows or WASD to run and turn, Space to kick, F to fire the cannon, T to show or hide the triangle counts.
# Untouched, the pirate plays the run from the video by himself; the first key you press hands him over to you.

const PROPS_JSON := "res://props/props.json"  # name -> {file, size, axis ("h" height or "l" longest side), tris}

# [prop, position (x along the shore, z towards the sea), y rotation, extra scale, dynamic?]
const LAYOUT := [
	# beach side (left of the run, z < 0)
	["palm", Vector3(-3.0, 0, -5.5), 20.0, 1.0, false],
	["palm", Vector3(9.0, 0, -6.5), 140.0, 0.85, false],
	["palm", Vector3(17.5, 0, -5.0), 260.0, 1.05, false],
	["campfire", Vector3(5.0, 0, -3.4), 0.0, 1.0, false],
	["torch", Vector3(1.6, 0, -2.2), 0.0, 1.0, false],
	["torch", Vector3(12.6, 0, -2.2), 0.0, 1.0, false],
	["signpost", Vector3(-0.6, 0, -2.6), 25.0, 1.0, false],
	["fishing_net", Vector3(7.8, 0, -4.6), 10.0, 1.0, false],
	["parrot_perch", Vector3(3.2, 0, -4.2), -20.0, 1.0, false],
	["cutlass_rack", Vector3(10.6, 0, -3.0), 15.0, 1.0, false],
	["ships_wheel", Vector3(15.6, 0, -3.6), -30.0, 1.0, false],
	["beach_rock", Vector3(-2.2, 0, -1.9), 40.0, 1.0, false],
	["beach_rock", Vector3(19.0, 0, -2.0), 200.0, 0.8, false],
	["driftwood_log", Vector3(6.4, 0, -1.7), 75.0, 1.0, false],
	["shell_cluster", Vector3(2.4, 0, -1.4), 30.0, 1.0, false],
	["chest", Vector3(11.8, 0, -4.4), -25.0, 1.0, false],
	["flour_sack", Vector3(0.6, 0, -4.0), 10.0, 1.0, false],
	["fish_basket", Vector3(4.2, 0, -1.6), -10.0, 1.0, false],
	["bucket_mop", Vector3(8.6, 0, -2.2), 0.0, 1.0, false],
	["anchor", Vector3(15.8, 0, -1.8), 70.0, 1.0, false],
	["lantern", Vector3(13.2, 0, 2.7), 0.0, 1.0, false],
	["cannonball_pile", Vector3(12.4, 0, -1.5), 0.0, 1.0, false],
	["cannon", Vector3(13.6, 0, -0.7), 0.0, 1.0, false],  # aimed down the shore at the dock stack (set in _ready)
	# shore side (right of the run, the sea beyond z = 3.2)
	["mooring_post", Vector3(16.2, 0, 2.8), 0.0, 1.0, false],
	["rope_coil", Vector3(9.4, 0, 2.6), 0.0, 1.0, false],
	["rowboat", Vector3(15.0, -0.62, 5.6), 10.0, 1.0, false],
	# bumpables
	["crate", Vector3(3.3, 0, 0.75), 10.0, 1.0, true],
	["crate", Vector3(3.5, 0, 1.75), -12.0, 1.0, true],
	["powder_keg", Vector3(11.2, 0, 1.9), 0.0, 1.0, true],
	["crate", Vector3(19.5, 0, 0.9), 30.0, 1.0, true],
]
# barrels the goal counts: [position, upright?]
const BARRELS := [
	Vector3(5.6, 0, 1.25),        # kicked into the sea at about 4 s
	Vector3(17.7, 0.05, 5.0),     # the dock stack: bottom two and the top one
	Vector3(17.7, 0.05, 6.05),
	Vector3(17.5, 0.05, 7.55),    # alone at the end of the dock
	Vector3(15.1, 0, 2.55),       # the shore barrel by the dock
]
const SHORE_Z := 3.2      # sand ends here
const SEA_Y := -0.55      # water surface
const DOCK := Rect2(16.2, 3.0, 3.0, 5.0)  # x, z, width (x), length (z): planks out over the sea

var props := {}
var overlay := true   # the triangle-count chips and the prop counter (T toggles the chips)
var t := 0.0
var cam: Camera3D
var pirate: CharacterBody3D
var barrels: Array[RigidBody3D] = []
var in_sea := 0
var floating := []  # [body, t_in, drift]
var lights := []    # [OmniLight3D, base energy, speed]
var hud_goal: Label
var hud_props: Label
var chips := []     # [Label3D, Node3D]
var cannon_node: Node3D
var cannon_fired := []
var sun: DirectionalLight3D
var env: Environment
var shot_nodes := []
var _sfx_log := []


func _ready() -> void:
	props = JSON.parse_string(FileAccess.get_file_as_string(PROPS_JSON))
	_build_world()
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	_build_hud()
	_build_level(true)
	_spawn_pirate()
	set_physics_process(true)


func _process(delta: float) -> void:
	t += delta
	for l in lights:
		var o: OmniLight3D = l[0]
		o.light_energy = l[1] * (0.82 + 0.12 * sin(t * l[2]) + 0.06 * sin(t * l[2] * 2.7 + 1.3))
	for f in floating:
		var b: RigidBody3D = f[0]
		var k: float = t - f[1]
		b.global_position.y = SEA_Y - 0.3 + 0.06 * sin(t * 2.1 + f[2])
		b.global_position.z += delta * 0.35
		b.rotation.z = 0.12 * sin(t * 1.7 + f[2])
	if rowboat:
		rowboat.position.y = -0.62 + 0.05 * sin(t * 1.6)
		rowboat.rotation.z = 0.04 * sin(t * 1.3)
	_follow_cam(delta)
	_update_chips()


func _physics_process(_delta: float) -> void:
	for b in barrels:
		if b.freeze:
			continue
		if b.global_position.y < SEA_Y - 0.15 and b.global_position.z > SHORE_Z:
			_splash(b.global_position)
			b.freeze = true
			floating.append([b, t, randf() * TAU])
			in_sea += 1
			_set_goal()
			_log("splash", "%d %s" % [in_sea, b.name])
			if in_sea >= 5:
				_log("win", 5)


# ---------- world ----------

func _build_world() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.56, 0.90)
	sm.sky_horizon_color = Color(0.80, 0.88, 0.96)
	sm.ground_horizon_color = Color(0.80, 0.88, 0.96)
	sm.ground_bottom_color = Color(0.13, 0.45, 0.6)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.90, 0.74)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
	add_child(sun)

	# sand (Ludo seamless texture, tiled), a static body the props and the pirate stand on
	var sand := StaticBody3D.new()
	add_child(sand)
	var smi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(80.0, 1.0, 40.0 + SHORE_Z)
	smi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://textures/sand.png")
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.28, 0.28, 0.28)
	mat.roughness = 1.0
	smi.material_override = mat
	sand.add_child(smi)
	var sc := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	sc.shape = bs
	sand.add_child(sc)
	sand.position = Vector3(5.0, -0.5, SHORE_Z - bm.size.z / 2.0)
	# a gentle wet strip at the water's edge
	var edge := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(80.0, 0.9, 1.2)
	edge.mesh = em
	var emat := mat.duplicate()
	emat.albedo_color = Color(0.82, 0.74, 0.62)
	edge.material_override = emat
	edge.position = Vector3(5.0, -0.5, SHORE_Z + 0.25)
	edge.rotation_degrees.x = -28.0
	add_child(edge)

	# water (primitive)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400.0, 400.0)
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.10, 0.58, 0.70, 1.0)
	wm.roughness = 0.08
	wm.metallic_specular = 0.9
	water.material_override = wm
	water.position = Vector3(0.0, SEA_Y, 200.0 + SHORE_Z - 4.0)
	add_child(water)

	# dock (primitive planks and posts, static)
	var dock := StaticBody3D.new()
	add_child(dock)
	var n := int(DOCK.size.y / 0.36)
	for i in range(n):
		var z := DOCK.position.y + 0.18 + i * 0.36
		var col := Color(0.58, 0.40, 0.23).lerp(Color(0.47, 0.31, 0.18), float(i % 3) / 2.0)
		_box(dock, Vector3(DOCK.position.x + DOCK.size.x / 2.0, 0.0, z), Vector3(DOCK.size.x, 0.1, 0.32), col)
	var dc := CollisionShape3D.new()
	var ds := BoxShape3D.new()
	ds.size = Vector3(DOCK.size.x, 0.1, DOCK.size.y)
	dc.shape = ds
	dc.position = Vector3(DOCK.position.x + DOCK.size.x / 2.0, 0.0, DOCK.position.y + DOCK.size.y / 2.0)
	dock.add_child(dc)
	for px in [DOCK.position.x + 0.15, DOCK.position.x + DOCK.size.x - 0.15]:
		for pz in [DOCK.position.y + 1.4, DOCK.position.y + 3.2, DOCK.position.y + DOCK.size.y - 0.15]:
			_box(dock, Vector3(px, -0.5, pz), Vector3(0.24, 1.1, 0.24), Color(0.36, 0.25, 0.15))


func _box(parent: Node, pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)


# ---------- props ----------

func _model(name: String) -> Node3D:
	# the GLB scaled to our size for it (labelled "our sizes" in the video), lowest point on y = 0, centred
	var spec: Dictionary = props[name]
	var inst: Node3D = (load(spec["file"]) as PackedScene).instantiate()
	var holder := Node3D.new()
	holder.name = name
	holder.add_child(inst)
	var box := _aabb(inst, Transform3D.IDENTITY)
	var size: float = box.size.y if spec["axis"] == "h" else max(box.size.x, box.size.z)
	var s: float = float(spec["size"]) / max(size, 0.0001)
	inst.scale = Vector3.ONE * s
	var c := box.get_center()
	inst.position = Vector3(-c.x * s, -box.position.y * s, -c.z * s)
	holder.set_meta("unit_scale", s)
	holder.set_meta("prop", name)
	holder.set_meta("inst", inst)
	return holder


func place(name: String, pos: Vector3, rot_deg: float, extra: float, dynamic: bool) -> Node3D:
	var holder := _model(name)
	holder.scale = Vector3.ONE * extra
	if dynamic:
		# a bumpable prop is a rigid body with a convex shape (the push lines are in pirate.gd)
		var body := RigidBody3D.new()
		body.name = name + "_body"
		body.set_meta("prop", name)
		body.mass = 6.0 if name != "barrel" else 9.0
		body.continuous_cd = true
		add_child(body)
		body.position = pos
		body.rotation_degrees.y = rot_deg
		body.add_child(holder)
		var shape := _convex(holder)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		_add_chip(name, body)
		return body
	add_child(holder)
	holder.position = pos
	holder.rotation_degrees.y = rot_deg - 90.0  # Prop models face +Z; the game camera looks down +X
	if name in ["lantern", "campfire", "torch"]:
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.62, 0.25)
		var top := {"lantern": 2.2, "campfire": 0.5, "torch": 1.7}[name] as float
		o.position = Vector3(0, top, 0)
		o.omni_range = 5.0
		o.shadow_enabled = false
		holder.add_child(o)
		lights.append([o, 2.2 if name != "torch" else 1.4, 9.0 + randf() * 4.0])
	_add_chip(name, holder)
	return holder


func _convex(holder: Node3D) -> ConvexPolygonShape3D:
	var pts := PackedVector3Array()
	_collect_points(holder, holder.transform.affine_inverse() * holder.transform, pts, true)
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	return shape


func _collect_points(n: Node, xf: Transform3D, pts: PackedVector3Array, root: bool) -> void:
	var here := xf
	if n is Node3D and not root:
		here = xf * (n as Node3D).transform
	elif root:
		here = (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		var cvx := mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
		for p in cvx.points:
			pts.append(here * p)
	for ch in n.get_children():
		_collect_points(ch, here, pts, false)


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var have := false
	var here := xf
	if n is Node3D:
		here = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out = here * (n as MeshInstance3D).mesh.get_aabb()
		have = true
	for ch in n.get_children():
		var cb := _aabb(ch, here)
		if cb.size != Vector3.ZERO:
			out = cb if not have else out.merge(cb)
			have = true
	return out


func _build_level(with_barrels: bool) -> void:
	for it in LAYOUT:
		var node := place(it[0], it[1], it[2], it[3], it[4])
		if it[0] == "rowboat":
			rowboat = node
		if it[0] == "cannon":
			cannon_node = node
			# aim the cannon at the dock stack
			var tgt: Vector3 = BARRELS[1]
			node.look_at(Vector3(tgt.x, 0, tgt.z), Vector3.UP)
			node.rotate_y(PI)  # look_at points -Z at the stack; the model's muzzle is +Z
	if with_barrels:
		for p in BARRELS:
			var b := place("barrel", p, randf() * 360.0, 1.0, true) as RigidBody3D
			b.name = "barrel_%d" % barrels.size()
			barrels.append(b)
		_set_goal()


# ---------- the pirate ----------

func _spawn_pirate() -> void:
	pirate = load("res://scripts/pirate.gd").new()
	pirate.name = "Pirate"
	pirate.set("cove", self)
	pirate.position = Vector3(-4.4, 0.05, 1.0)
	add_child(pirate)
	pirate.connect("kicked", _on_kick)


func _on_kick(pos: Vector3, dir: Vector3) -> void:
	# the kick lands: the nearest body in front of the foot gets an impulse
	var best: RigidBody3D = null
	var bd := 1.6
	for n in get_children():
		if n is RigidBody3D and not (n as RigidBody3D).freeze:
			var d := (n as RigidBody3D).global_position - pos
			d.y = 0
			if d.length() < bd and d.normalized().dot(dir) > 0.3:
				bd = d.length()
				best = n
	if best:
		best.apply_impulse(dir * 48.0 + Vector3.UP * 7.0, Vector3(0, 0.6, 0))
		_log("kick_hit", best.name)


func fire_cannon(target: Vector3) -> void:
	# the cannonball is a primitive sphere (our code); the cannon is the Ludo prop
	var muzzle := cannon_node.global_transform * Vector3(0, 0.75, 1.0)
	var ball := RigidBody3D.new()
	ball.mass = 40.0
	ball.continuous_cd = true
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.09)
	m.metallic = 0.6
	m.roughness = 0.4
	mi.material_override = m
	ball.add_child(mi)
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 0.16
	cs.shape = ss
	ball.add_child(cs)
	add_child(ball)
	ball.global_position = muzzle
	# a flat fast arc: time of flight 0.9 s
	var tf := 0.6
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var d := target - muzzle
	ball.linear_velocity = Vector3(d.x / tf, (d.y + 0.5 * g * tf * tf) / tf, d.z / tf)
	ball.contact_monitor = true
	ball.max_contacts_reported = 4
	ball.body_entered.connect(func(_o): _blast(ball, d.normalized()))
	# flash, smoke, recoil
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.7, 0.3)
	fl.light_energy = 8.0
	fl.omni_range = 7.0
	add_child(fl)
	fl.global_position = muzzle
	var tw := create_tween()
	tw.tween_property(fl, "light_energy", 0.0, 0.35)
	tw.tween_callback(fl.queue_free)
	_puff(muzzle, Color(0.85, 0.85, 0.82), 40, 1.4)
	var back := cannon_node.global_transform.basis.z.normalized() * -0.25
	var p0 := cannon_node.global_position
	var tw2 := create_tween()
	tw2.tween_property(cannon_node, "global_position", p0 + back, 0.08)
	tw2.tween_property(cannon_node, "global_position", p0, 0.5)
	_log("cannon", 1)


func _blast(ball: RigidBody3D, dir: Vector3) -> void:
	# the ball lands: everything loose within 2 m is thrown away from it (game feel)
	if ball.has_meta("hit"):
		return
	ball.set_meta("hit", true)
	_puff(ball.global_position, Color(0.75, 0.72, 0.68), 36, 2.4)
	for b in barrels:
		if b.freeze:
			continue
		var off := b.global_position - ball.global_position
		if off.length() < 2.0:
			off.y = 0
			b.apply_impulse(off.normalized() * 40.0 + dir * 45.0 + Vector3.UP * 22.0, Vector3(0, 0.5, 0))
	_log("blast", ball.global_position)


func _puff(pos: Vector3, col: Color, amount: int, speed: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 1.1
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -2.0, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = m
	p.mesh = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _splash(pos: Vector3) -> void:
	_puff(Vector3(pos.x, SEA_Y, pos.z), Color(0.92, 0.97, 1.0), 60, 4.5)


# ---------- HUD and chips ----------

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	hud_goal = Label.new()
	hud_goal.add_theme_font_size_override("font_size", 58)
	hud_goal.add_theme_color_override("font_color", Color(1, 0.97, 0.86))
	hud_goal.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.03))
	hud_goal.add_theme_constant_override("outline_size", 12)
	hud_goal.position = Vector2(1230, 36)
	cl.add_child(hud_goal)
	if overlay:
		hud_props = Label.new()
		hud_props.add_theme_font_size_override("font_size", 58)
		hud_props.add_theme_color_override("font_color", Color(1, 1, 1))
		hud_props.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		hud_props.add_theme_constant_override("outline_size", 12)
		hud_props.position = Vector2(640, 36)
		hud_props.text = "PROPS 25/25"
		cl.add_child(hud_props)


func _set_goal() -> void:
	hud_goal.text = "Barrels in the sea  %d/5" % in_sea
	if in_sea >= 5:
		hud_goal.text = "All five in the sea!"
		hud_goal.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
		hud_goal.position.x = 1280


func _add_chip(name: String, node: Node3D) -> void:
	if not overlay:
		return
	var l := Label3D.new()
	l.text = "%s tris" % _thousands(int(props[name]["tris"]))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = 54
	l.outline_size = 14
	l.modulate = Color(1, 1, 1)
	l.outline_modulate = Color(0.05, 0.05, 0.08)
	l.visible = false
	add_child(l)
	chips.append([l, node])


func _update_chips() -> void:
	if not overlay or cam == null:
		return
	chips.sort_custom(func(x, y): return not is_instance_valid(y[1]) or (is_instance_valid(x[1]) and cam.global_position.distance_to(x[1].global_position) < cam.global_position.distance_to(y[1].global_position)))
	var shown := 0
	for c in chips:
		var l: Label3D = c[0]
		var n: Node3D = c[1]
		if not is_instance_valid(n):
			l.visible = false
			continue
		var p := n.global_position
		var d := cam.global_position.distance_to(p)
		var front := not cam.is_position_behind(p)
		var sp := cam.unproject_position(p)
		l.visible = n.is_visible_in_tree() and front and d < 6.5 and sp.x > 120 and sp.x < 1800 and sp.y > 140 and sp.y < 1000
		if l.visible:
			shown += 1
			l.visible = shown <= 4
		l.global_position = p + Vector3(0, -0.05, 0)


static func _thousands(n: int) -> String:
	var s := str(n)
	return s if s.length() <= 3 else s.substr(0, s.length() - 3) + "," + s.substr(s.length() - 3)


# ---------- cameras ----------

var _orbit := 0.0
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO

func _follow_cam(delta: float) -> void:
	if pirate == null:
		return
	var fwd: Vector3 = pirate.get("facing")
	if pirate.get("done"):
		# the run is over: the camera circles him slowly while the cove plays on
		_orbit += delta * 0.32
		fwd = fwd.rotated(Vector3.UP, _orbit)
	var want: Vector3 = pirate.global_position - fwd * 3.4 + Vector3(0, 1.45, 0) + fwd.cross(Vector3.UP) * -0.5
	var look: Vector3 = pirate.global_position + fwd * 2.5 + Vector3(0, 0.75, 0)
	if _cam_pos == Vector3.ZERO:
		_cam_pos = want
		_cam_look = look
	var k := 1.0 - exp(-delta * 3.2)
	_cam_pos = _cam_pos.lerp(want, k)
	_cam_look = _cam_look.lerp(look, k)
	cam.global_position = _cam_pos
	cam.look_at(_cam_look, Vector3.UP)




func next_barrel(from: Vector3) -> Array:
	var best: RigidBody3D = null
	for b in barrels:
		if b.freeze or b.linear_velocity.length() > 0.6 or b.global_position.y < -0.2:
			continue
		if best == null or b.global_position.distance_to(from) < best.global_position.distance_to(from):
			best = b
	if best == null:
		return []
	var p := best.global_position
	var dir := Vector3(0, 0, 1)
	if p.z > SHORE_Z - 0.2:  # on the dock: off the nearer side
		dir = Vector3(1, 0, 0) if p.x > DOCK.position.x + DOCK.size.x / 2.0 else Vector3(-1, 0, 0)
	var stand := p - dir * 0.85
	if stand.z > SHORE_Z - 0.3 and (stand.x < DOCK.position.x + 0.3 or stand.x > DOCK.position.x + DOCK.size.x - 0.3):
		dir = -dir
	p.y = 0
	return [p, dir]


func barrel_target(i: int) -> Vector3:
	if i == 1:
		return Vector3(17.7, 0.6, 5.5)
	return Vector3(26.0, 6.0, 14.0)  # the salute, out over the sea


var rowboat: Node3D

func _log(ev: String, v) -> void:
	print("EV %.3f %s %s" % [t, ev, str(v)])


func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_T:
		for c in chips:
			(c[0] as Label3D).visible = false
		overlay = not overlay

