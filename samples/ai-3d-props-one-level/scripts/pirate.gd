extends CharacterBody3D
# The pirate (a Ludo Hero model, rigged, with Ludo preset clips idle / run / kick / push merged into one GLB).
# He starts on an autopilot plan (the run from the video, the same every time); the first key you press hands him over:
# arrows or WASD run and turn, Space kicks, F fires the cannon at the nearest barrel still ashore. The movement and the
# push are ordinary CharacterBody3D code either way.

signal kicked(pos: Vector3, dir: Vector3)

const HEIGHT := 1.5        # our size for him, metres
const RUN_SPEED := 3.3     # m/s, matched to the run clip's feet (see STATUS)
const PUSH := 1.6          # impulse per physics tick on what he bumps
const KICK_AT := 0.42      # s into the kick clip when the foot lands

var cove: Node
var facing := Vector3(1, 0, 0)
var anim: AnimationPlayer
var model: Node3D
var plan := []
var step := -1
var step_t := 0.0
var kick_sent := false
var done := false
var player := false      # true once a key took over from the plan
var kick_t := -1.0       # time into a player's kick, -1 when not kicking
var _space := false
var _f := false

# the run: [op, arg]  ops: run (target), kick (direction), wait (s), fire (target), face (direction)
const PLAN := [
	["wait", 0.25],
	["run", Vector3(2.8, 0, 1.15)],        # shoulders the crate stack, it tumbles
	["run", Vector3(4.85, 0, 0.75)],
	["kick", Vector3(0.35, 0, 1.0)],       # barrel 1 rolls off the shore
	["run", Vector3(9.6, 0, 1.0)],
	["run", Vector3(10.6, 0, 0.5)],
	["wait", 0.8],
	["fire", 1],                           # the cannon at the dock stack
	["wait", 1.0],
	["run", Vector3(12.9, 0, 0.3)],        # towards the cannon and the lantern
	["run", Vector3(10.2, 0, 1.75)],       # back past the powder keg: it gets shouldered
	["run", Vector3(9.0, 0, 0.8)],
	["run", Vector3(12.6, 0, 0.9)],
	["seek", 0],                           # the shore barrel by the dock
	["seek", 0],                           # what is left of the stack
	["seek", 0],
	["seek", 0],
	["seek", 0],
	["wait", 1.3],
	["fire", 2],                           # a salute
	["run", Vector3(17.7, 0, 3.6)],        # back up the dock
	["run", Vector3(17.6, 0, 1.6)],        # and the beach
	["run", Vector3(18.7, 0, 0.5)],        # bumps the last crate
	["wait", 1.5],
	["run", Vector3(16.0, 0, 0.6)],
]


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = HEIGHT
	col.shape = cap
	col.position.y = HEIGHT / 2.0
	add_child(col)
	model = (load("res://pirate/pirate.glb") as PackedScene).instantiate()
	add_child(model)
	var box: AABB = cove._aabb(model, Transform3D.IDENTITY)
	var s: float = HEIGHT / max(box.size.y, 0.001)
	model.scale = Vector3.ONE * s
	model.position.y = -box.position.y * s
	anim = _find_anim(model)
	for n in ["idle", "run", "push"]:
		if anim and anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	plan = PLAN.duplicate()
	_next()


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var a := _find_anim(c)
		if a:
			return a
	return null


func _play(name: String, blend := 0.15) -> void:
	if anim and anim.has_animation(name) and anim.current_animation != name:
		anim.play(name, blend)


func _next() -> void:
	step += 1
	step_t = 0.0
	kick_sent = false
	if step >= plan.size():
		return
	var s: Array = plan[step]
	print("EV %.3f step %d %s %s %s" % [cove.t, step, s[0], str(s[1]), str(global_position.snapped(Vector3(0.01, 0.01, 0.01)))])
	match s[0]:
		"wait":
			_play("idle")
		"run":
			_play("run")
		"kick":
			facing = (s[1] as Vector3).normalized()
			_play("kick", 0.1)
		"fire":
			cove.fire_cannon(cove.barrel_target(int(s[1])))
			_next()
		"seek":
			# the nearest barrel still ashore: stand behind it on the landward side and kick it seaward
			var r: Array = cove.next_barrel(global_position)
			if r.is_empty():
				_next()
				return
			var bpos: Vector3 = r[0]
			var dir: Vector3 = r[1]
			var at := step + 1
			if bpos.z > 3.0 and global_position.z < 3.0:
				plan.insert(at, ["run", Vector3(17.7, 0, 2.6)])   # onto the dock from the beach end
				plan.insert(at + 1, ["run", Vector3(17.7, 0, 3.6)])
				at += 2
			plan.insert(at, ["run", bpos - dir * 0.85])
			plan.insert(at + 1, ["kick", dir])
			_next()


func _key(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0


func _drive(delta: float) -> Vector3:
	# the player's turn: tank controls, so the follow camera behind him always agrees with "forward"
	var fwd := _key(KEY_UP, KEY_W) - _key(KEY_DOWN, KEY_S)
	var turn := _key(KEY_RIGHT, KEY_D) - _key(KEY_LEFT, KEY_A)
	var sp := Input.is_physical_key_pressed(KEY_SPACE)
	var fk := Input.is_physical_key_pressed(KEY_F)
	if fk and not _f:
		var r: Array = cove.next_barrel(global_position)
		if not r.is_empty():
			cove.fire_cannon(r[0])
	_f = fk
	if sp and not _space and kick_t < 0.0:
		kick_t = 0.0
		kick_sent = false
		_play("kick", 0.1)
	_space = sp
	if kick_t >= 0.0:
		kick_t += delta
		if kick_t >= KICK_AT and not kick_sent:
			kick_sent = true
			emit_signal("kicked", global_position + facing * 0.4, facing)
		if kick_t >= 1.0:
			kick_t = -1.0
		return Vector3.ZERO
	facing = facing.rotated(Vector3.UP, -turn * delta * 2.6).normalized()
	_play("run" if fwd != 0.0 else "idle")
	return facing * RUN_SPEED * (fwd if fwd > 0.0 else fwd * 0.4)


func _physics_process(delta: float) -> void:
	step_t += delta
	var v := Vector3.ZERO
	if not player and (_key(KEY_UP, KEY_W) + _key(KEY_DOWN, KEY_S) + _key(KEY_LEFT, KEY_A) + _key(KEY_RIGHT, KEY_D)
			+ _key(KEY_SPACE, KEY_F) > 0.0):
		player = true
		done = false
		plan = []
	if player:
		v = _drive(delta)
	elif step < plan.size():
		var s: Array = plan[step]
		match s[0]:
			"wait":
				if step_t >= float(s[1]):
					_next()
			"run":
				var to: Vector3 = s[1]
				var d := to - global_position
				d.y = 0
				if d.length() < 0.25 or step_t > 3.5:
					_next()
				else:
					facing = facing.slerp(d.normalized(), min(1.0, delta * 8.0)).normalized()
					v = facing * RUN_SPEED
			"kick":
				if step_t >= KICK_AT and not kick_sent:
					kick_sent = true
					emit_signal("kicked", global_position + facing * 0.4, facing)
				if step_t >= 1.0:
					_next()
	else:
		_play("idle")
		done = true
	velocity.x = v.x
	velocity.z = v.z
	velocity.y = velocity.y - 9.8 * delta if not is_on_floor() else -0.5
	move_and_slide()
	# push what we bump: a CharacterBody3D treats a RigidBody3D as a wall, so push it ourselves
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			(c.get_collider() as RigidBody3D) \
				.apply_central_impulse(
					-c.get_normal() * PUSH)
	model.rotation.y = lerp_angle(model.rotation.y, atan2(facing.x, facing.z), min(1.0, delta * 12.0))
