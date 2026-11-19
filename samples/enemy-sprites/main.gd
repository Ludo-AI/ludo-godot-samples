extends Node2D
# Mossgrove (#42), ours, written by Claude Code (brief FD built the level, brief FF the fight). Bramble the hedgehog
# knight walks through the forest; each enemy does its one job on him with its own Ludo animation and sound, and he
# answers with his own Ludo animations (jump, slash, block). Every picture and sound is a Ludo generation loaded at
# runtime (tools/prep_game.py writes res://art and res://sfx); the hit flash is flash.gdshader.
# The enemy scripts wait for the wind-up's last frame (`go` in config.json), then move (C19).
# Args after --:  mode=fight|boar3|mush3|boss|read|end|lineup  order=boar,toad,moth,mushroom,beetle  log=<path>

const W := 1920.0
const H := 1080.0
const SPEED := 300.0
const BASE_FACE := {"bramble": 1}   # every enemy sheet faces left (-1)
var GROUND := 895.0
var cfg := {}
var mode := "fight"
var order := ["boar", "toad", "moth", "mushroom", "beetle"]
var t := 0.0
var fno := 0
var cam: Camera2D
var shader: Shader
var sfx := {}
var shake := 0.0
var rng := RandomNumberGenerator.new()
var plain := false
var logf: FileAccess
var actors: Array = []     # every actor dictionary (see make())
var br: Dictionary         # Bramble
var cam_x := 0.0
var hearts: Array = []
var lives := 3
var glob: Node2D


func tex(p: String) -> ImageTexture:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(p)))


func c(key: String) -> Dictionary:
	return cfg[key]


func play(key: String, vol := 0.0, pitch := 1.0, from := 0.0) -> void:
	if not sfx.has(key):
		return
	var p := AudioStreamPlayer.new()
	p.stream = sfx[key]
	p.volume_db = vol
	p.pitch_scale = pitch
	add_child(p)
	p.play(from)
	p.finished.connect(p.queue_free)


func ev(name: String, extra := {}) -> void:
	if logf:
		var d := {"ev": name, "t": snappedf(t, 0.001), "f": fno}
		d.merge(extra)
		logf.store_line(JSON.stringify(d))


# ---------------------------------------------------------------- actors

func make(base: String, pos: Vector2) -> Dictionary:
	var s := Sprite2D.new()
	var m := ShaderMaterial.new()
	m.shader = shader
	s.material = m
	s.z_index = 3 if base == "bramble" else (2 if base == "moth" else 1)
	add_child(s)
	var a := {"base": base, "spr": s, "x": pos.x, "y": pos.y, "vx": 0.0, "face": BASE_FACE.get(base, -1),
		"key": "", "t0": 0.0, "loop": true, "f0": 0, "f1": 0, "rate": 1.0, "flash": 0.0, "alpha": 1.0,
		"recoil": 0.0, "alive": true, "breath": false, "lift": 0.0, "px": pos.x, "id": actors.size()}
	if base != "moth":
		var pts := PackedVector2Array()
		for i in 28:
			var an := TAU * i / 28.0
			pts.append(Vector2(cos(an), sin(an) * 0.16))
		var sh := Polygon2D.new()
		sh.polygon = pts
		sh.color = Color(0.12, 0.07, 0.05, 0.38)
		add_child(sh)
		a["shadow"] = sh
	anim(a, base, true)
	actors.append(a)
	return a


func anim(a: Dictionary, key: String, loop: bool, f0 := 0, f1 := -1, rate := 1.0) -> void:
	var k: Dictionary = c(key)
	var s: Sprite2D = a.spr
	if a.key != key:
		s.texture = tex("res://art/%s.png" % key)
		s.hframes = int(k.cols)
		s.vframes = int(k.rows)
	a.key = key
	a.t0 = t
	a.loop = loop
	a.f0 = f0
	a.f1 = int(k.n) - 1 if f1 < 0 else f1
	a.rate = rate
	# r2 review: draw the new sheet's frame, scale and offset at once. A coroutine can switch sheets after this frame's
	# _process, and the old scale on the new sheet drew the boss 1.5x big for one frame at every slam/charge hand-over.
	draw_actor(a, 0.0)


func dur(a: Dictionary) -> float:
	return float(a.f1 - a.f0 + 1) / (float(c(a.key).fps) * float(a.rate))


func half_w(base: String) -> float:
	return float(c(base).bw) * float(c(base).scale) / 2.0


func gap(a: Dictionary) -> float:
	return float(a.x) - float(br.x)


func draw_actor(a: Dictionary, delta: float) -> void:
	var k: Dictionary = c(a.key)
	var s: Sprite2D = a.spr
	var n := int(a.f1) - int(a.f0) + 1
	var f := int((t - float(a.t0)) * float(k.fps) * float(a.rate))
	f = (f % n) if a.loop else clampi(f, 0, n - 1)
	f += int(a.f0)
	if a.has("hold_f"):
		f = int(a.hold_f)
	s.frame = f
	a["frame"] = f
	var sc := float(k.scale)
	var flip := int(a.face) != int(BASE_FACE.get(a.base, -1))
	var by := 1.0
	if a.breath:
		by = 1.0 + 0.018 * sin(t * 3.2 + float(a.x) * 0.01)
	s.scale = Vector2(-sc if flip else sc, sc * by)
	var dy := 0.0
	if a.key == "bramble_jump":
		dy = -float(k.dy[f]) / sc   # the engine owns the arc: take the sheet's own rise out
	s.offset = Vector2(float(k.fw) / 2.0 - float(k.cx), float(k.fh) / 2.0 - float(k.feet) + dy)
	s.position = Vector2(float(a.x), float(a.y) - float(a.lift))
	# Gate 2b (REVIEW-R2 "the hit flash reads see-through"): a hit or hurt is a solid white pop held for 0.1 s, then off;
	# r2 faded it out over 6 frames and its grey in-between frames read like a ghost. The softer block flashes keep the fade.
	var fl := float(a.flash)
	if float(a.get("fhold", 0.0)) > 0.0:
		a.fhold = float(a.fhold) - delta
		fl = 1.0
		if float(a.fhold) <= 0.0:
			a.flash = 0.0
	else:
		a.flash = maxf(0.0, fl - delta * 5.0)
		fl = a.flash
	var mat: ShaderMaterial = s.material
	mat.set_shader_parameter("flash", fl)
	s.modulate.a = a.alpha
	a.recoil = maxf(0.0, float(a.recoil) - delta)
	if a.has("shadow"):
		var sh: Polygon2D = a.shadow
		sh.visible = s.visible and float(a.alpha) > 0.05
		sh.position = Vector2(float(a.x), GROUND + 2)
		var lift := clampf((GROUND - s.position.y) / 300.0, 0.0, 0.7)
		var w := half_w(a.base) * 0.95 * (1.0 - lift * 0.6)
		sh.scale = Vector2(w, w)
		sh.color.a = 0.38 * float(a.alpha)


# ---------------------------------------------------------------- set-up

func _ready() -> void:
	rng.seed = 42
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=")
		if kv.size() != 2:
			continue
		if kv[0] == "mode":
			mode = kv[1]
		elif kv[0] == "ground":
			GROUND = float(kv[1])
		elif kv[0] == "order":
			order = Array(kv[1].split(","))
		elif kv[0] == "plain":
			plain = kv[1] == "1"
		elif kv[0] == "log":
			logf = FileAccess.open(kv[1], FileAccess.WRITE)
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://art/config.json"))
	shader = load("res://flash.gdshader")
	for k in cfg.keys():
		var p := "res://sfx/%s.wav" % k
		if FileAccess.file_exists(p):
			sfx[k] = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(p))
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	var bt := tex("res://art/bg.png")
	var bs := H / bt.get_height()
	var par := Parallax2D.new()
	par.repeat_size = Vector2(bt.get_width() * bs, 0)
	par.repeat_times = 4
	add_child(par)
	var b := Sprite2D.new()
	b.texture = bt
	b.centered = false
	b.scale = Vector2(bs, bs)
	par.add_child(b)
	br = make("bramble", Vector2(420, GROUND))
	br["walk"] = true
	br["jt0"] = -1.0
	hud()
	cam_x = float(br.x) + W * 0.2
	run_mode()


func hud() -> void:
	# three hearts, engine-drawn, top left
	var layer := CanvasLayer.new()
	add_child(layer)
	var pts := PackedVector2Array()
	for i in 40:
		var u := TAU * i / 40.0
		pts.append(Vector2(16 * pow(sin(u), 3), -(13 * cos(u) - 5 * cos(2 * u) - 2 * cos(3 * u) - cos(4 * u))) * 1.7)
	for i in 3:
		var edge := Polygon2D.new()
		edge.polygon = pts
		edge.color = Color("#ffe6a8")
		edge.scale = Vector2(1.18, 1.18)
		edge.position = Vector2(70 + i * 76, 64)
		layer.add_child(edge)
		var h := Polygon2D.new()
		h.polygon = pts
		h.color = Color(0.86, 0.25, 0.3)
		h.position = edge.position
		layer.add_child(h)
		hearts.append(h)


func lose_heart() -> void:
	if lives > 0:
		lives -= 1
		(hearts[lives] as Polygon2D).color = Color(0.32, 0.3, 0.34)
		ev("heart")


func run_mode() -> void:
	if mode == "lineup" or mode == "end":
		lineup()
		return
	if mode == "fight":
		fight(order)
	elif mode == "boar3":
		boar3()
	elif mode == "mush3":
		mush3()
	elif mode == "boss":
		boss_long()
	elif mode == "read":
		read()


func lineup() -> void:
	# everyone on the path at game size, idling (engine breathing; the moth flaps), the moth above the boar and toad
	cam.position = Vector2(W / 2, H / 2)
	cam_x = W / 2
	var keys := ["bramble", "mushroom", "boar", "toad", "beetle"]
	var total := 0.0
	for k in keys:
		total += half_w(k) * 2
	var gapx := (W - 160 - total) / (keys.size() - 1)
	var x := 80.0
	br.walk = false
	br.breath = true
	br.x = x + half_w("bramble")
	x += half_w("bramble") * 2 + gapx
	var at := {}
	for k in keys.slice(1):
		var a := make(k, Vector2(x + half_w(k), GROUND))
		a.hold_f = 0
		a.breath = true
		at[k] = a
		x += half_w(k) * 2 + gapx
	br.hold_f = 0
	var mo := make("moth", Vector2((float(at.boar.x) + float(at.toad.x)) / 2, GROUND - 330))
	mo["bob"] = true


# ---------------------------------------------------------------- helpers (coroutines)

func wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, false).timeout


func until(cond: Callable) -> void:
	while not cond.call():
		await get_tree().process_frame


func bramble_walk() -> void:
	br.tail = -1.0   # any later order cancels a slash's pending return to the walk
	br.walk = true
	br.erase("hold_f")
	anim(br, "bramble", true)


func bramble_stop() -> void:
	br.tail = -1.0
	br.walk = false
	anim(br, "bramble", true)
	br.hold_f = 0


func jump(h: float, d: float) -> void:
	br.jt0 = t
	br.jh = h
	br.jd = d
	var k: Dictionary = c("bramble_jump")
	anim(br, "bramble_jump", false, int(k.air[0]), int(k.air[1]), float(int(k.air[1]) - int(k.air[0]) + 1) / (float(k.fps) * d))
	play("bramble_jump", -6.0, 1.3)
	ev("jump")
	await wait(d)
	br.jt0 = -1.0
	if br.walk:
		anim(br, "bramble", true)
	else:
		bramble_stop()


func slash(resume := true) -> void:
	# the slash sheet from 6 frames before the sword's furthest reach, at double speed; returns at the hit. After the
	# follow-through he walks on if he was walking (and resume), else stands. r2: the return is cancelled by any order
	# given meanwhile (r1 read: a stale return set him walking into the boss and he was drawn inside it).
	var k: Dictionary = c("bramble_slash")
	var st := int(k.strike)
	var f0 := maxi(0, st - 6)
	var walking: bool = br.walk and resume
	br.walk = false
	br.erase("hold_f")
	anim(br, "bramble_slash", false, f0, mini(int(k.n) - 1, st + 8), 2.0)
	play("bramble_slash", -4.0, 1.6)
	ev("slash")
	var id := t
	br.tail = id
	await wait(float(st - f0) / (float(k.fps) * 2.0))
	slash_tail(walking, id)


func slash_tail(walking: bool, id: float) -> void:
	await wait(8.0 / (float(c("bramble_slash").fps) * 2.0))
	if float(br.get("tail", -1.0)) != id:
		return
	br.tail = -1.0
	if walking:
		bramble_walk()
	else:
		bramble_stop()


func block_up() -> void:
	br.tail = -1.0
	var k: Dictionary = c("bramble_block")
	br.walk = false
	br.erase("hold_f")
	anim(br, "bramble_block", false, 0, int(k.hold), 2.0)
	ev("block")


func top(a: Dictionary) -> float:
	return float(a.y) - float(a.lift) + float(c(a.key).ty[int(a.get("frame", 0))])


func reach_ov(a: Dictionary) -> float:
	# overlap in px of the sword's reach at the strike (config `reach`, from the slash sheet) with the target's body box
	# this frame (per-frame edges lx/rx/ty); > 0 = contact. Not slashing = no reach.
	if str(br.key) != "bramble_slash":
		return -999.0
	var r: Array = c("bramble_slash").reach
	var bx := float(br.x)
	var byy := float(br.y)
	var ox := minf(bx + float(r[1]), rgt(a)) - maxf(bx + float(r[0]), lft(a))
	var oy := minf(byy + float(r[3]), float(a.y) - float(a.lift)) - maxf(byy + float(r[2]), top(a))
	return minf(ox, oy)


func hit(a: Dictionary, push := 0.0) -> void:
	var ov := reach_ov(a)
	if ov <= 0.0:
		ev("miss_" + str(a.base), {"ov": snappedf(ov, 0.1)})
		return
	a.flash = 1.0
	a.fhold = 0.1
	if push != 0.0:
		a.recoil = 0.3
		a.kick = push
	ev("hit_" + str(a.base), {"ov": snappedf(ov, 0.1)})


func hurt(push: float) -> void:
	br.flash = 1.0
	br.fhold = 0.1
	br.recoil = 0.35
	br.kick = -push
	lose_heart()
	ev("hurt")


func die(a: Dictionary) -> void:
	# the death sheet (one Animate prompt, C11) plays once and holds its last pose, then the body fades
	a.alive = false
	a.vx = 0.0
	a.erase("hold_f")
	var key := str(a.base) + "_death"
	var k: Dictionary = c(key)
	# r2: the death pose reaches further forward than the standing one (the boss topples 320 px forward): the hit knocks
	# the body back so its front edge stays 20 px clear of Bramble's (the fall never lands on him)
	var reach := 0.0
	for i in range(0, int(k.settle) + 1):
		reach = minf(reach, float(k.lx[i]))
	a.dreach = reach   # the body's furthest-forward edge while it falls: Bramble stops short of it (see _process)
	var need := (float(br.x) + float(c("bramble").rx[0]) + 20.0) - (float(a.x) + reach)
	if need > 0.0:
		a.recoil = 0.3   # knocked back (logged as recoil: pushed away while still facing him)
		a.kick = 0.0
		var x0 := float(a.x)
		var twk := create_tween()
		twk.tween_method(func(v: float): a.x = v, x0, x0 + need, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	anim(a, key, false, 0, int(k.settle), 1.4)
	play(key, -3.0, 1.2)
	ev("die_" + str(a.base))
	await wait(dur(a) + 0.35)
	var tw := create_tween()
	tw.tween_property(a.spr, "modulate:a", 0.0, 0.45)
	await wait(0.45)
	a.alpha = 0.0
	a.spr.visible = false


func spawn(base: String, dx: float, y := 0.0) -> Dictionary:
	var a := make(base, Vector2(float(br.x) + dx, GROUND - y))
	ev("spawn_" + base)
	return a


# ---------------------------------------------------------------- the encounters

func enc_boar(start_mid := false) -> void:
	# stands, scrapes, holds (the wind-up), then charges once its wind-up's last frame is done; Bramble jumps it
	var k: Dictionary = c("boar")
	var b := spawn("boar", 1500.0 if not start_mid else 520.0)
	b.hold_f = 0
	if not start_mid:
		await until(func(): return gap(b) < 1080.0)
		b.erase("hold_f")
		anim(b, "boar", false)
		play("boar", -2.0)
		ev("windup_boar")
		await wait(float(int(k.go)) / float(k.fps))
	else:
		b.erase("hold_f")
		anim(b, "boar", false, int(k.go))
	ev("go_boar")
	b.charge = true
	if start_mid:
		b.vx = -950.0
	# r2: take off 0.24 s before contact at the closing speed, stay up until the boar has passed under him
	var body := float(c("bramble").rx[0]) - float(c("bramble").lx[0])
	await until(func(): return gap(b) - half_w("boar") - body / 2.0 < (SPEED - float(b.vx)) * 0.24)
	var rel := maxf(400.0, SPEED - float(b.vx))
	await jump(360.0, clampf((gap(b) + half_w("boar") + body) / rel + 0.12, 0.8, 1.15))
	await until(func(): return gap(b) < -1300.0)
	b.spr.visible = false
	b.alpha = 0.0


func enc_toad(blk := true) -> void:
	# Bramble stops at the toad's tell and raises his shield; the toad puffs (wind-up), spits once its wind-up is done;
	# the glob hits the shield; then he walks up and strikes it down
	var k: Dictionary = c("toad")
	var d := spawn("toad", 1000.0)
	d.hold_f = 0
	await until(func(): return gap(d) < 640.0)
	bramble_stop()
	d.erase("hold_f")
	var f0 := maxi(0, int(k.tell) - 2)   # r2 toad: its sheet idles before the puff; the game starts it just before the tell
	anim(d, "toad", false, f0)
	var src_fps := float(k.get("fps_src", k.fps))
	play("toad", 0.0, float(k.fps) / src_fps, float(f0) / src_fps)   # the sheet's own sound, in step with its frames
	ev("windup_toad")
	if blk:
		block_up()
	await wait(float(int(k.strike) - f0) / float(k.fps))
	ev("go_toad")
	glob = make_glob()
	var g0 := Vector2(float(d.x) - half_w("toad") * 0.9, GROUND - 62)
	var tgt := Vector2(float(br.x) + 70, GROUND - 118)
	glob.position = g0
	var tw := create_tween()
	tw.tween_method(func(u: float): glob.position = g0.lerp(tgt, u) - Vector2(0, sin(u * PI) * 46), 0.0, 1.0, 0.34)
	await wait(0.34)
	glob.queue_free()
	glob = null
	if blk:
		play("bramble_block", -4.0, 1.4)
		br.flash = 0.5
		br.recoil = 0.25
		br.kick = -90.0
		ev("clank")
	else:
		hurt(200.0)
	await wait(0.35)
	bramble_walk()
	await until(func(): return gap(d) < half_w("toad") + half_w("bramble") + 30.0)
	await slash()
	hit(d)
	die(d)


func enc_moth() -> void:
	# hovers ahead, climbs, dives at Bramble's head (game code: the sheet only flaps); he strikes it out of the air
	var m := spawn("moth", 1150.0, 430.0)
	var x0 := float(m.x)
	await until(func(): return gap(m) < 760.0)
	ev("windup_moth")
	var tw := create_tween()
	tw.tween_method(func(v: float): m.lift = v, 0.0, 120.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await wait(0.55)
	ev("go_moth")
	play("moth")
	var p0 := Vector2(float(m.x), float(m.y))
	var l0 := float(m.lift)
	var r: Array = c("bramble_slash").reach
	var mk: Dictionary = c("moth")
	# end of the dive: the moth's front 40 px inside the sword's tip, its body centred on the swing's height
	# (measured from Bramble live: he walks on until his swing starts)
	var ey := GROUND + (float(r[2]) + float(r[3])) / 2.0 - float(mk.ty[0]) / 2.0
	var path := func(u: float) -> void:
		m.x = lerpf(p0.x, float(br.x) + float(r[1]) - 40.0 - float(mk.lx[0]), u)
		m.y = lerpf(p0.y, ey, u * u)
		m.lift = l0 * (1.0 - u)
	var dive := 0.55
	var sk: Dictionary = c("bramble_slash")
	var lead := float(int(sk.strike) - maxi(0, int(sk.strike) - 6)) / (float(sk.fps) * 2.0)
	var tw2 := create_tween()
	tw2.tween_method(path, 0.0, 1.0, dive)
	await wait(maxf(0.0, dive - lead))
	await slash()
	tw2.kill()
	path.call(1.0)
	hit(m)
	m.vx = 0.0
	die(m)
	var y0 := float(m.y)
	var tw3 := create_tween()
	tw3.tween_method(func(v: float): m.y = v, y0, GROUND, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func enc_mushroom(kill := false) -> void:
	# walks into Bramble and bumps him (a heart greys); he hops it, then turns the next one into a strike
	var mu := spawn("mushroom", 1250.0)
	mu.vx = -130.0
	if kill:
		await until(func(): return gap(mu) < half_w("mushroom") + half_w("bramble") + 40.0)
		await slash()
		hit(mu)
		die(mu)
		return
	# r2: the bump stops at contact (its front edge this frame at his body's front), never sinking into him
	await until(func(): return lft(mu) - (float(br.x) + float(c("bramble").rx[0])) < 4.0)
	mu.vx = 0.0
	bramble_stop()
	play("mushroom")
	hurt(260.0)
	ev("bump")
	await wait(0.4)
	await slash()
	hit(mu)
	die(mu)
	bramble_walk()


func boss_in() -> Dictionary:
	# the ground shakes and the boss lands from above, right of Bramble
	var bb := spawn("beetle", 900.0, 900.0)
	bb.lift = 0.0
	bb.hold_f = 0
	bramble_stop()
	shake = 0.25
	var y0 := float(bb.y)
	var tw := create_tween()
	tw.tween_method(func(v: float): bb.y = v, y0, GROUND, 0.42).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await wait(0.42)
	shake = 0.5
	play("beetle_death", -8.0, 0.7)
	ev("boss_land")
	return bb


func lft(a: Dictionary) -> float:
	return float(a.x) + float(c(a.key).lx[int(a.get("frame", 0))])


func rgt(a: Dictionary) -> float:
	return float(a.x) + float(c(a.key).rx[int(a.get("frame", 0))])


func boss_slam(bb: Dictionary) -> void:
	# Bramble steps up so the horn comes down right on his shield, raises it at the tell, and takes the slam on it
	var k: Dictionary = c("beetle")
	var tip := float(c("beetle").lx[int(k.strike)])
	bramble_walk()
	await until(func(): return float(bb.x) + tip - rgt(br) < 12.0)
	bramble_stop()
	block_up()
	bb.erase("hold_f")
	anim(bb, "beetle", false)
	play("beetle")
	ev("windup_beetle")
	await wait(float(int(k.go)) / float(k.fps))
	ev("go_beetle")
	await wait(float(int(k.strike) - int(k.go)) / float(k.fps))
	shake = 0.45
	ev("slam")
	play("bramble_block", -2.0, 1.0)
	br.flash = 0.6
	br.recoil = 0.35
	br.kick = -1300.0
	ev("clank")
	await wait(float(int(k.n) - int(k.strike)) / float(k.fps))
	bb.hold_f = 0


func boss_charge(bb: Dictionary) -> void:
	# head down, hold (the second wind-up), then the charge once that wind-up is done; Bramble takes it on his shield
	var k: Dictionary = c("beetle_charge")
	bb.erase("hold_f")
	anim(bb, "beetle_charge", false)
	play("beetle_charge")
	ev("windup_charge")
	block_up()
	await wait(float(int(k.go)) / float(k.fps))
	ev("go_charge")
	bb.vx = -700.0
	await until(func(): return lft(bb) - rgt(br) < 6.0)
	bb.vx = 0.0
	play("bramble_block", -2.0, 1.1)
	shake = 0.3
	br.flash = 0.6
	br.recoil = 0.35
	br.kick = -700.0
	ev("clank")
	await wait(maxf(0.1, float(int(k.n) - 1) / float(k.fps) - (t - float(bb.t0))))
	anim(bb, "beetle", false)
	bb.hold_f = 0


func strike_boss(bb: Dictionary) -> void:
	bramble_walk()
	await until(func(): return lft(bb) - rgt(br) < 30.0)
	await slash(false)   # strikes from where he stands, then stays (no walking on into the boss)
	hit(bb, 900.0)


func boss_fight(kill: bool) -> void:
	var bb: Dictionary = await boss_in()
	await wait(0.6)
	await boss_slam(bb)
	await wait(0.3)
	await boss_charge(bb)
	await wait(0.2)
	await strike_boss(bb)
	await wait(0.3)
	await strike_boss(bb)
	await wait(0.3)
	await strike_boss(bb)
	if kill:
		await die(bb)
	bramble_walk()


func fight(seq: Array) -> void:
	var first := true
	for e in seq:
		match str(e):
			"boar":
				await enc_boar(first)
			"toad":
				await enc_toad(true)
			"moth":
				await enc_moth()
			"mushroom":
				await enc_mushroom(false)
			"mushkill":
				await enc_mushroom(true)
			"beetle":
				await boss_fight(true)
		first = false
		await wait(0.2)
	ev("fight_done")


func boar3() -> void:
	for i in 3:
		await enc_boar(false)
		await wait(0.1)


func mush3() -> void:
	await wait(0.4)
	for i in 3:
		enc_mushroom(true)
		await wait(1.7)
	await wait(2.2)
	fight(["toad", "moth", "mushroom", "boar"])


func boss_long() -> void:
	# chapter 6: both attacks twice, each with its own wind-up, then the boss goes down
	var bb: Dictionary = await boss_in()
	await wait(0.5)
	await boss_slam(bb)
	await wait(0.2)
	await boss_charge(bb)
	await strike_boss(bb)
	await wait(0.3)
	await boss_slam(bb)
	await strike_boss(bb)
	await wait(0.3)
	await boss_charge(bb)
	await strike_boss(bb)
	await wait(0.3)
	await strike_boss(bb)
	await die(bb)
	bramble_walk()
	ev("fight_done")


func read() -> void:
	# chapter 4: the boss without the warm outline, then the outline wipes on around it mid-shot
	var bb: Dictionary = await boss_in()
	var raw := Sprite2D.new()
	raw.material = ShaderMaterial.new()
	(raw.material as ShaderMaterial).shader = shader
	raw.texture = tex("res://art/beetle_raw.png")
	raw.set_meta("key", "beetle")
	raw.hframes = int(c("beetle").cols)
	raw.vframes = int(c("beetle").rows)
	raw.z_index = 2
	add_child(raw)
	bb.raw = raw
	(bb.spr.material as ShaderMaterial).shader = load("res://wipe.gdshader")
	(bb.spr.material as ShaderMaterial).set_shader_parameter("reveal", 0.0)
	(bb.spr.material as ShaderMaterial).set_shader_parameter("cols", float(c("beetle").cols))
	await wait(0.5)
	await boss_slam(bb)
	await wait(0.3)
	await boss_charge(bb)
	await strike_boss(bb)
	await wait(0.3)
	ev("outline_on")
	# Gate 2b: plain=1 is the same run with the outline never drawn (REVIEW-R2 "the split halves are out of step": the split
	# screen now shows this run and the outlined one at the same game time, so both halves move as one)
	if not plain:
		var tw := create_tween()
		tw.tween_method(func(u: float): (bb.spr.material as ShaderMaterial).set_shader_parameter("reveal", u), 0.0, 1.0, 1.0)
	await wait(1.0)
	if not plain:
		(bb.spr.material as ShaderMaterial).set_shader_parameter("reveal", 2.0)
		bb.raw_off = true   # the outlined sheet now draws the whole boss: one beetle, never two layers out of step
	ev("outline_done")
	await wait(0.3)
	await boss_slam(bb)
	await strike_boss(bb)
	await wait(0.3)
	await strike_boss(bb)
	await die(bb)
	bramble_walk()
	ev("fight_done")


# ---------------------------------------------------------------- the frame

func _process(delta: float) -> void:
	t += delta
	fno += 1
	# Bramble
	var vx := SPEED if br.walk else 0.0
	var blocked := false
	if br.walk:
		var front := float(br.x) + float(c("bramble").rx[0]) + 20.0
		for a in actors:
			if not is_same(a, br) and not a.alive and (a.spr as Sprite2D).visible and float(a.alpha) > 0.05 \
					and float(a.x) + float(a.get("dreach", 0.0)) < front and rgt(a) > float(br.x):
				blocked = true
	if blocked:
		vx = 0.0
		br.hold_f = 0
		br.blk = true
	elif br.get("blk", false):
		br.blk = false
		if br.walk:
			br.erase("hold_f")
	if float(br.recoil) > 0.0:
		vx += float(br.get("kick", 0.0)) * (float(br.recoil) / 0.35)
	br.x = float(br.x) + vx * delta
	var y := GROUND
	if float(br.jt0) >= 0.0:
		var k := clampf((t - float(br.jt0)) / float(br.jd), 0.0, 1.0)
		y -= sin(k * PI) * float(br.jh)
	br.y = y
	# enemies
	for a in actors:
		if is_same(a, br):
			continue
		var avx := float(a.vx)
		if a.get("charge", false) and a.alive:
			var k: Dictionary = c("boar")
			if int(a.get("frame", 0)) >= int(k.go):
				a.vx = maxf(float(a.vx) - 3200 * delta, -950.0)
				avx = float(a.vx)
			if (t - float(a.t0)) * float(k.fps) >= float(k.n):
				a.hold_f = int(k.strike)
		if float(a.recoil) > 0.0:
			avx += float(a.get("kick", 0.0)) * (float(a.recoil) / 0.3)
		a.x = float(a.x) + avx * delta
		if a.get("bob", false):
			a.lift = sin(t * 2.4) * 16.0
	for a in actors:
		draw_actor(a, delta)
	for a in actors:
		if a.has("raw"):
			var r: Sprite2D = a.raw
			var s: Sprite2D = a.spr
			if str(r.get_meta("key", "")) != str(a.key):
				# founder r1 (1:57.7, "two beetles here?"): the raw sprite kept the slam sheet while the boss played its
				# charge and death sheets, so two beetles stood on screen. Now it swaps sheet with the boss.
				r.texture = tex("res://art/%s_raw.png" % a.key)
				r.hframes = int(c(a.key).cols)
				r.vframes = int(c(a.key).rows)
				r.set_meta("key", str(a.key))
				(s.material as ShaderMaterial).set_shader_parameter("cols", float(c(a.key).cols))
			r.visible = s.visible and not a.get("raw_off", false)
			r.modulate.a = s.modulate.a
			r.frame = s.frame
			r.scale = s.scale
			r.offset = s.offset
			r.position = s.position
			(r.material as ShaderMaterial).set_shader_parameter("flash", (s.material as ShaderMaterial).get_shader_parameter("flash"))
	# camera: Bramble at 30% of the screen
	if mode != "end" and mode != "lineup":
		var cx := float(br.x) + W * 0.2
		cam_x = cx if fno <= 1 else lerpf(cam_x, cx, 0.12)
	cam.position = Vector2(cam_x, H / 2)
	if shake > 0:
		shake -= delta
		cam.offset = Vector2(rng.randf_range(-14, 14), rng.randf_range(-10, 10)) * (shake / 0.4)
	else:
		cam.offset = Vector2.ZERO
	if logf:
		var row := []
		for a in actors:
			if (a.spr as Sprite2D).visible and float(a.alpha) > 0.05:
				row.append([a.base, snappedf(float(a.x), 0.1), snappedf(float(a.y) - float(a.lift), 0.1), int(a.face),
					1 if float(a.recoil) > 0.0 else 0, a.key, int(a.get("frame", 0)), 1 if a.alive else 0, int(a.id),
					str((a.raw as Sprite2D).get_meta("key", "")) if a.has("raw") and (a.raw as Sprite2D).visible else ""])
		logf.store_line(JSON.stringify({"f": fno, "t": snappedf(t, 0.001), "cam": snappedf(cam_x, 0.1), "a": row}))
		logf.flush()


func make_glob() -> Node2D:
	# the spit: a poison glob in the toad's own green, with the cast's warm edge (engine-drawn, 3 shapes)
	var n := Node2D.new()
	var pts := PackedVector2Array()
	for i in 20:
		var an := TAU * i / 20.0
		pts.append(Vector2(cos(an) * 17, sin(an) * 13))
	var edge := Polygon2D.new()
	edge.polygon = pts
	edge.color = Color("#ffe6a8")
	edge.scale = Vector2(1.25, 1.3)
	n.add_child(edge)
	var body := Polygon2D.new()
	body.polygon = pts
	body.color = Color(0.42, 0.62, 0.25)
	n.add_child(body)
	var hi := Polygon2D.new()
	hi.polygon = pts
	hi.color = Color(0.72, 0.85, 0.45)
	hi.scale = Vector2(0.35, 0.35)
	hi.position = Vector2(-5, -4)
	n.add_child(hi)
	n.z_index = 4
	add_child(n)
	return n
