extends Node2D
## Cinder's fight: the Godot sample for Ludo video #40 "AI VFX for games".
## Every picture and sound is a Ludo.ai generation (see README.md); the code is ours (MIT).
##
## Cinder the fox mage holds the left of a moonlit ruin. Slimes hop in and lunge, bats swoop.
## Effects, each one SpriteFrames exported by `ludo toolbox sprite export --engine godot`:
##   fx_fireball  loop, Add blend     fx_explosion  one-shot, Normal blend
##   fx_lightning one-shot, Add blend fx_aura       loop, Add blend, centred on Cinder's body, in front
## One-shots have Loop unticked in their SpriteFrames, so animation_finished fires and one line fades and frees them.
## Every effect fades in and out over a few frames and casts a little light of its own colour on the ruin (PointLight2D),
## so it sits in the scene instead of on top of it.
## Command line: `-- scene=main` (the fight, default), `scene=blend` (Normal vs Add), `scene=pixel` (the pixel fight).

const FLOOR := 958.0
const CINDER_X := 330.0
const SLIME_STOP := 610.0
const FOX_SCALE := 0.66
const RELEASE_FRAME := 4                          # cast frame 5: the strike lands, the staff points straight ahead
const SWAP_S := 0.1                               # idle <-> cast: the outgoing sprite fades over this long
const AIM_LAST := 18                              # frames 5 to 19 hold the aim; a cast in that span fires again from the aim
const STAFF_TIP := Vector2(452, -359) * FOX_SCALE  # the orb on that frame, from Cinder's feet
const BODY_CENTRE := Vector2(-5, -257) * FOX_SCALE # the middle of Cinder's body, from the feet (where the aura starts)

var scene := "main"
var t := 0.0
var events := []          # [time, method name, args]
var slimes: Array[Node2D] = []
var hearts: Array[Sprite2D] = []
var lives := 3
var world: Node2D
var actors: Node2D
var fx_layer: Node2D
var cinder_idle: AnimatedSprite2D
var cinder_cast: AnimatedSprite2D
var cinder: Node2D
var aura: AnimatedSprite2D = null
var aura_until := -1.0
var aura_light: PointLight2D = null
var pixel := false
var frames := {}
var light_tex: GradientTexture2D
var log_aura := false
var aura_mid := Vector2.ZERO   # the mean middle of the aura's frames, from its sprite centre
var centres := {}        # sprite -> the middle of each frame (alpha centroid, sprite pixels from the node), see centres_of()


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="):
			scene = a.substr(6)
		if a == "log=1":
			log_aura = true
	light_tex = GradientTexture2D.new()
	light_tex.width = 256
	light_tex.height = 256
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	light_tex.gradient = gr
	pixel = scene == "pixel"
	world = Node2D.new()
	add_child(world)
	var bg := Sprite2D.new()
	bg.texture = load("res://art/bg.png")
	bg.centered = false
	bg.modulate = Color(0.72, 0.72, 0.82)   # a darker ruin, so the glowing effects read
	world.add_child(bg)
	actors = Node2D.new()
	actors.modulate = Color(0.86, 0.86, 0.96)   # the same moonlight on the cast as on the ruin
	world.add_child(actors)
	fx_layer = Node2D.new()
	world.add_child(fx_layer)
	if scene != "blend":
		make_cinder()
		make_hud()
	if pixel:
		to_pixel_view()
	call("plan_" + scene)
	events.sort_custom(func(a, b): return a[0] < b[0])


# ---------- the pixel view: the same world drawn at 480x270, scaled up 4x with nearest filtering ----------
func to_pixel_view() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(480, 270)
	sv.transparent_bg = false
	remove_child(world)
	sv.add_child(world)
	world.scale = Vector2(0.25, 0.25)
	add_child(sv)
	move_child(sv, 0)
	var view := Sprite2D.new()
	view.texture = sv.get_texture()
	view.centered = false
	view.scale = Vector2(4, 4)
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(view)
	move_child(view, 1)


# ---------- helpers ----------
func sf(name: String) -> SpriteFrames:
	if not frames.has(name):
		frames[name] = load("res://art/%s.tres" % name)
	return frames[name]


## The pivot at the bottom of the drawn pixels of frame 0 (the feet), so a sprite stands on its y.
func feet(a: AnimatedSprite2D) -> void:
	var tex: Texture2D = a.sprite_frames.get_frame_texture("default", 0)
	var img := tex.get_image()
	var used := img.get_used_rect()
	a.offset = Vector2(-(used.position.x + used.size.x / 2.0) + img.get_width() / 2.0, -(used.end.y - img.get_height() / 2.0))


func sprite(name: String, pos: Vector2, s: float, add_blend := false, parent: Node = null) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = sf(name)
	a.position = pos
	a.scale = Vector2(s, s)
	if add_blend:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		a.material = m
	(parent if parent else fx_layer).add_child(a)
	a.play()
	if not a.sprite_frames.get_animation_loop("default"):
		a.animation_finished.connect(fade_out.bind(a, 0.15))   # a one-shot plays once, fades, then removes itself
	return a


func fade_in(n: CanvasItem, seconds: float, to := 1.0) -> void:
	n.modulate.a = 0.0
	n.create_tween().tween_property(n, "modulate:a", to, seconds)


func fade_out(n: CanvasItem, seconds: float) -> void:
	if is_instance_valid(n):
		n.create_tween().tween_property(n, "modulate:a", 0.0, seconds).finished.connect(n.queue_free)


## A soft light of the effect's colour on the ruin and the cast around it: up in `rise`, held, down in `fall`.
func glow(parent: Node, pos: Vector2, color: Color, size: float, energy: float, rise: float, hold: float, fall: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.texture_scale = size / 256.0
	l.color = color
	l.position = pos
	l.energy = 0.0
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", energy, rise)
	if hold >= 0.0:
		tw.tween_interval(hold)
		tw.tween_property(l, "energy", 0.0, fall)
		tw.tween_callback(l.queue_free)
	return l


func sound(name: String, db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://sfx/" + name)
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func at(time: float, method: String, args := []) -> void:
	events.append([time, method, args])


func _process(delta: float) -> void:
	while events.size() and events[0][0] <= t:
		var e = events.pop_front()
		callv(e[1], e[2])
	t += delta
	if log_aura and aura:
		var body: AnimatedSprite2D = body_on
		print("AURA t=%.3f aura_frame=%d aura_pos=%.1f,%.1f aura_scale=%.2f,%.2f fox=%s fox_frame=%d fox_pos=%.1f,%.1f fox_offset=%.1f,%.1f" % [
			t, aura.frame, aura.global_position.x, aura.global_position.y, aura.scale.x, aura.scale.y, "cast" if body == cinder_cast else "idle",
			body.frame, body.global_position.x, body.global_position.y, body.offset.x, body.offset.y])
	if aura:   # the halo eases onto the middle of Cinder's body on the frame on screen
		aura.position = aura.position.lerp(aura_target(), 1.0 - exp(-18.0 * delta))
	if aura and t > aura_until:
		var a := aura
		aura = null
		create_tween().tween_property(a, "modulate:a", 0.0, 0.4).finished.connect(a.queue_free)
		var l := aura_light
		create_tween().tween_property(l, "energy", 0.0, 0.4).finished.connect(l.queue_free)


# ---------- Cinder ----------
func make_cinder() -> void:
	cinder = Node2D.new()
	cinder.position = Vector2(CINDER_X, FLOOR)
	actors.add_child(cinder)
	cinder_idle = sprite("cinder_idle", Vector2.ZERO, FOX_SCALE, false, cinder)
	feet(cinder_idle)
	cinder_cast = sprite("cinder_cast", Vector2.ZERO, FOX_SCALE, false, cinder)
	for c in cinder_cast.animation_finished.get_connections():
		cinder_cast.animation_finished.disconnect(c.callable)
	feet(cinder_cast)
	cinder_cast.offset = cinder_idle.offset
	cinder_cast.visible = false
	body_on = cinder_idle
	cinder_cast.stop()
	cinder_cast.animation_finished.connect(func(): cinder_idle.frame = 0; show_body(cinder_idle))   # the strike ends on the idle's first pose
	for a in [cinder_idle, cinder_cast]:
		centres[a] = centres_of(a)


## The middle of each frame of a sprite: the centroid of its opaque pixels, measured once on an eighth-size copy, in
## the sprite's own pixels from the node (offset included). The aura follows it, so the halo stays on the fox's body
## while the strike leans it forward.
func centres_of(a: AnimatedSprite2D) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in a.sprite_frames.get_frame_count("default"):
		var img := a.sprite_frames.get_frame_texture("default", i).get_image()
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		img.resize(w / 8, h / 8, Image.INTERPOLATE_BILINEAR)
		var sum := Vector2.ZERO
		var n := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.16:
					sum += Vector2(x, y)
					n += 1
		var c := (sum / maxi(n, 1) + Vector2(0.5, 0.5)) * Vector2(float(w) / img.get_width(), float(h) / img.get_height())
		out.append(a.offset + c - Vector2(w, h) / 2.0)
	return out


## Swap Cinder's idle and cast sprites. The one going away stays a moment and fades (SWAP_S), so the change of
## sprite reads as motion instead of a pop.
var swap_tween: Tween = null
var body_on: AnimatedSprite2D = null   # the sprite Cinder is showing now (the other may still be fading out)
func show_body(on: AnimatedSprite2D) -> void:
	var off := cinder_idle if on == cinder_cast else cinder_cast
	if swap_tween:
		swap_tween.kill()
	body_on = on
	on.visible = true
	on.modulate.a = 1.0
	if not off.visible:
		return
	swap_tween = create_tween()
	swap_tween.tween_property(off, "modulate:a", 0.0, SWAP_S)
	swap_tween.tween_callback(func(): off.visible = false; off.modulate.a = 1.0)


## Where the aura's middle should sit: on the middle of the Cinder frame on screen, in Cinder's space.
func aura_target() -> Vector2:
	var body: AnimatedSprite2D = body_on
	return FOX_SCALE * centres[body][body.frame] - aura.scale * aura_mid


func staff_tip() -> Vector2:
	return cinder.position + STAFF_TIP


## Pull back, strike, hold the aim, ease back: the fireball leaves the orb on the frame the strike lands.
## frame0 > 0 starts later in the wind-up (the quick casts of a stream). A cast while Cinder still holds the aim goes
## back to the strike frame instead of starting over, so a stream of fireballs never snaps the staff back and forth.
func cast(target_y := -1.0, frame0 := 0) -> void:
	var fps := cinder_cast.sprite_frames.get_animation_speed("default")
	var aiming := body_on == cinder_cast and cinder_cast.is_playing() and cinder_cast.frame >= RELEASE_FRAME and cinder_cast.frame <= AIM_LAST
	show_body(cinder_cast)
	cinder_cast.play()
	cinder_cast.frame = RELEASE_FRAME if aiming else frame0
	get_tree().create_timer(maxf(0.0, (RELEASE_FRAME + 1 - frame0) / fps)).timeout.connect(fire.bind(target_y))   # once frame 5 is on screen


func fire(target_y := -1.0, from := Vector2.ZERO) -> void:
	var p := staff_tip() if from == Vector2.ZERO else from
	var name := "fx_fireball_px" if pixel else "fx_fireball"
	var f := sprite(name, p, 0.33 if not pixel else 0.36, true)
	fade_in(f, 0.08)
	glow(f, Vector2(40, 0), Color(1.0, 0.55, 0.2), 520.0, 0.9, 0.08, -1.0, 0.0)   # rides along with the fireball
	f.set_meta("vy", 0.0)
	f.set_meta("ty", target_y)
	sound("fireball.wav", -8.0)
	_fireballs.append(f)


var _fireballs: Array[AnimatedSprite2D] = []


func _physics_process(delta: float) -> void:
	for f in _fireballs.duplicate():
		if not is_instance_valid(f):
			_fireballs.erase(f)
			continue
		var target := nearest_slime(f.position.x)
		var goal_y: float = target.position.y - 75.0 if target else f.position.y
		f.position.x += 1150.0 * delta
		f.position.y = lerp(f.position.y, goal_y, 0.12)
		if target and absf(target.position.x - f.position.x) < 45.0:
			_fireballs.erase(f)
			f.queue_free()
			blast(target)
		elif f.position.x > 2150.0:
			_fireballs.erase(f)
			f.queue_free()


func nearest_slime(x: float) -> Node2D:
	var best: Node2D = null
	for s in slimes:
		if is_instance_valid(s) and s.position.x > x - 20.0 and not s.get_meta("dead", false) and s.position.x < 1900.0:
			if best == null or s.position.x < best.position.x:
				best = s
	return best


func blast(s: Node2D) -> void:
	var k := 0.74 if not pixel else 0.8
	var c := s.position + Vector2(0, -85)
	var e := sprite("fx_explosion", c - Vector2(3, 28) * k, k)   # the blast's own centre (frame 13) on the slime
	fade_in(e, 0.05)
	glow(fx_layer, c, Color(1.0, 0.6, 0.25), 900.0, 1.3, 0.06, 0.35, 1.2)
	sound("boom.mp3", -3.0)
	kill(s)


func kill(s: Node2D) -> void:
	if not is_instance_valid(s) or s.get_meta("dead", false):
		return
	s.set_meta("dead", true)
	slimes.erase(s)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(1.3, 0.2), 0.12)
	tw.tween_callback(s.queue_free)


func hop() -> void:
	var tw := create_tween()
	tw.tween_property(cinder, "position:y", FLOOR - 170.0, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(cinder, "position:y", FLOOR, 0.26).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


# ---------- enemies ----------
func slime(x: float, hop_every := 1.1, lunges := false) -> void:
	var s := Node2D.new()
	s.set_meta("lunges", lunges)   # only the slimes the plan marks attack; the rest stop and wobble
	s.position = Vector2(x, FLOOR)
	actors.add_child(s)
	var a := sprite("slime", Vector2.ZERO, 0.74, false, s)
	feet(a)
	a.frame = randi() % 8
	slimes.append(s)
	var tw := create_tween().set_loops()
	tw.tween_interval(hop_every * randf_range(0.85, 1.15))
	tw.tween_callback(slime_hop.bind(s))
	s.tree_exiting.connect(tw.kill)


func slime_hop(s: Node2D) -> void:
	if not is_instance_valid(s) or s.get_meta("dead", false):
		return
	if s.position.x <= SLIME_STOP + 5.0:
		if s.get_meta("lunges"):
			s.set_meta("lunges", false)
			lunge(s)
		return
	var nx := maxf(SLIME_STOP, s.position.x - 120.0)
	var tw := s.create_tween()   # bound to the slime, so it stops when the slime is freed
	tw.tween_property(s, "scale", Vector2(1.15, 0.85), 0.08)
	tw.tween_property(s, "scale", Vector2(0.9, 1.1), 0.08)
	tw.parallel().tween_property(s, "position:x", nx, 0.42)
	tw.parallel().tween_method(func(v: float): s.position.y = FLOOR - sin(v * PI) * 70.0, 0.0, 1.0, 0.42)
	tw.tween_property(s, "scale", Vector2(1.15, 0.85), 0.06)
	tw.tween_property(s, "scale", Vector2.ONE, 0.1)


func lunge(s: Node2D) -> void:
	var tw := s.create_tween()
	tw.tween_property(s, "position:x", CINDER_X + 120.0, 0.18)
	tw.tween_callback(hurt)
	tw.tween_property(s, "position:x", SLIME_STOP + 160.0, 0.3)
	sound("slime.wav", -6.0)


func bat(y := 380.0, swoop := true) -> void:
	var b := Node2D.new()
	b.position = Vector2(2020, y)
	actors.add_child(b)
	sprite("bat", Vector2.ZERO, 0.62, false, b)
	sound("bat.wav", -10.0)
	var tw := create_tween()
	if swoop:
		tw.tween_property(b, "position", Vector2(CINDER_X + 520.0, y + 120.0), 1.6)
		tw.tween_callback(hop)
		tw.tween_property(b, "position", Vector2(CINDER_X, FLOOR - 110.0), 0.32)
		tw.tween_property(b, "position", Vector2(-220, 260), 1.1)
	else:
		tw.tween_property(b, "position", Vector2(-220, y - 120.0), 4.0)
	tw.tween_callback(b.queue_free)
	var bob := create_tween().set_loops()
	bob.tween_property(b, "rotation", 0.08, 0.35)
	bob.tween_property(b, "rotation", -0.08, 0.35)
	b.tree_exiting.connect(bob.kill)


# ---------- big effects ----------
func lightning(x: float) -> void:
	var l := sprite("fx_lightning", Vector2(x, FLOOR + 20.0), 1.0, true)
	feet(l)
	fade_in(l, 0.04)
	glow(fx_layer, Vector2(x, FLOOR - 120.0), Color(0.7, 0.6, 1.0), 1300.0, 2.4, 0.04, 0.4, 0.45)
	sound("lightning.mp3", -4.0)
	var flash := ColorRect.new()
	flash.color = Color(0.65, 0.6, 1.0, 0.22)
	flash.size = Vector2(1920, 1080)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = m
	fx_layer.add_child(flash)
	create_tween().tween_property(flash, "color:a", 0.0, 0.25).finished.connect(flash.queue_free)
	for s in slimes.duplicate():
		if absf(s.position.x - x) < 230.0:
			get_tree().create_timer(0.15).timeout.connect(kill.bind(s))


func heart_drop(heal_for := 9.5) -> void:
	var h := Sprite2D.new()
	h.texture = load("res://art/heart.png")
	h.position = Vector2(CINDER_X + 40.0, 520)
	actors.add_child(h)
	var tw := create_tween()
	tw.tween_property(h, "position:y", FLOOR - 40.0, 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	tw.tween_interval(0.5)
	tw.tween_property(h, "scale", Vector2(1.6, 1.6), 0.15)
	tw.parallel().tween_property(h, "modulate:a", 0.0, 0.15)
	tw.tween_callback(h.queue_free)
	tw.tween_callback(heal.bind(heal_for))


## The aura is a halo around Cinder: centred on the body and following it through the strike, drawn in front with Add, faded in and out, lighting the ground.
func heal(seconds := 9.5) -> void:
	if aura == null:
		aura = sprite("fx_aura", BODY_CENTRE, 1.0, true, cinder)
		aura.scale = Vector2(0.6, 0.46)
		if aura_mid == Vector2.ZERO:
			var m := centres_of(aura)
			for c in m:
				aura_mid += c / m.size()
		aura.position = aura_target()
		aura.modulate = Color(0.55, 1.0, 0.65)   # sparkles and ring tinted green, so they read as healing light, not the robe's stars
		fade_in(aura, 0.25, 0.6)
		aura_light = glow(cinder, Vector2(0, -40), Color(0.45, 1.0, 0.55), 640.0, 1.6, 0.25, -1.0, 0.0)   # pools on the floor at the feet
	aura_until = t + seconds
	sound("aura.wav", 4.0)
	lives = 3
	for h in hearts:
		create_tween().tween_property(h, "modulate", Color.WHITE, 0.3)


# ---------- HUD ----------
func make_hud() -> void:
	var hud := Node2D.new()
	world.add_child(hud)
	for i in 3:
		var h := Sprite2D.new()
		h.texture = load("res://art/heart.png")
		h.position = Vector2(70 + i * 84, 70)
		h.scale = Vector2(0.75, 0.75)
		hud.add_child(h)
		hearts.append(h)


func hurt() -> void:
	if lives <= 0:
		return
	lives -= 1
	var h := hearts[lives]
	var tw := create_tween()
	tw.tween_property(h, "scale", Vector2(1.0, 1.0), 0.08)
	tw.tween_property(h, "scale", Vector2(0.75, 0.75), 0.12)
	tw.parallel().tween_property(h, "modulate", Color(0.25, 0.25, 0.3, 0.8), 0.2)
	var tw2 := create_tween()
	tw2.tween_property(cinder, "modulate", Color(1, 0.5, 0.5), 0.06)
	tw2.tween_property(cinder, "modulate", Color.WHITE, 0.2)


# ---------- the plans: what happens when ----------
func plan_main() -> void:
	seed(40)
	# cold open, 0 to 16 s (timed to the cut, v5): a fireball is already in the air on frame 0
	at(0.0, "slime", [1050.0]); at(0.0, "slime", [1420.0]); at(0.0, "slime", [1760.0])
	at(0.0, "fire", [-1.0, Vector2(700, FLOOR - 120)])
	at(0.2, "bat", [360.0])   # Cinder hops the bat at 1.8 to 2.3 s, so the first strike (2.5 s) starts on the ground
	at(2.5, "cast"); at(4.8, "cast")   # each fireball leaves 0.37 s after its cast line
	# 6.4 s, between the first two lines: two slimes bunch up and the lightning takes both
	at(6.0, "slime", [1240.0, 9.0]); at(6.0, "slime", [1380.0, 9.0])
	at(6.45, "lightning", [1310.0])
	# under the second line: a slime lunges, a heart greys, Cinder grabs a heart and the aura heals
	at(6.6, "slime", [800.0, 0.6, true])
	at(8.1, "heart_drop", [4.3])
	at(9.0, "slime", [1950.0]); at(9.0, "slime", [2100.0])
	at(10.6, "cast"); at(11.6, "cast")
	# 13.7 s, under the first chapter card: one explosion bursts on one slime and fades to nothing
	at(12.0, "slime", [1150.0, 9.0])
	at(12.95, "cast")
	# 17 to 58 s: the fight runs on under the voice
	at(16.9, "cast")   # the fight opens with a fireball, so the shot under the first app card moves
	play_on(17.0, 58.0)
	# L2a, 60 to 70 s: hits in a row
	for i in 5:
		at(59.0, "slime", [980.0 + i * 230.0, 3.0])
	for i in 6:
		at(60.5 + i * 1.6, "cast")
	at(65.0, "slime", [1950.0]); at(66.0, "slime", [2050.0])
	# L3a, 70 to 80 s: a stream of fireballs across the ruin, bats dive
	for i in 14:
		at(70.38 + i * 0.68, "cast", [-1.0, 3])
	at(70.6, "bat", [300.0, false]); at(72.8, "bat", [420.0]); at(76.2, "bat", [260.0, false])
	# L4a, 80 to 90 s: a heart, the aura pulses at Cinder's feet, slimes keep hopping in
	at(80.2, "heart_drop")
	at(80.5, "slime", [1500.0]); at(81.5, "slime", [1800.0]); at(83.0, "slime", [2000.0])
	at(85.2, "cast"); at(88.2, "cast")
	# L7a, 90 to 98 s: a crowd of slimes, a chain of hits
	for i in 6:
		at(89.0, "slime", [900.0 + i * 170.0, 2.5])
	for i in 4:
		at(90.4 + i * 0.85, "cast")
	at(93.8, "lightning", [1550.0])
	at(95.2, "cast"); at(96.4, "cast")
	play_on(98.0, 200.0)


func play_on(from: float, to: float) -> void:
	var x := from
	var k := 0
	while x < to:
		at(x, "slime", [1950.0 + (k % 3) * 90.0])
		at(x + 1.8, "cast")
		if k % 3 == 1:
			at(x + 0.6, "bat", [340.0 + (k % 2) * 80.0])
		if k % 5 == 3:
			at(x + 2.2, "slime", [1500.0])
		if k % 4 == 2:
			at(x, "slime", [1380.0, 3.0]); at(x, "slime", [1560.0, 3.0])
			at(x + 1.2, "lightning", [1470.0])
		x += 2.6
		k += 1


func plan_blend() -> void:
	# the same lightning strike twice: Normal blend on the left, Add blend on the right
	for i in 6:
		at(0.3 + i * 2.2, "blend_pair")


func blend_pair() -> void:
	# a blast burning behind each bolt, so you can see what Add does to what is behind it
	sprite("fx_explosion", Vector2(560, FLOOR - 330.0), 0.9)
	sprite("fx_explosion", Vector2(1360, FLOOR - 330.0), 0.9)
	var a := sprite("fx_lightning", Vector2(560, FLOOR + 20.0), 1.0, false)
	feet(a)
	var b := sprite("fx_lightning", Vector2(1360, FLOOR + 20.0), 1.0, true)
	feet(b)
	sound("lightning.mp3", -4.0)


func plan_pixel() -> void:
	seed(41)
	at(0.0, "slime", [1100.0]); at(0.0, "slime", [1500.0])
	at(0.0, "fire", [-1.0, Vector2(760, FLOOR - 120)])
	at(1.0, "bat", [380.0])
	play_on(1.5, 20.0)
