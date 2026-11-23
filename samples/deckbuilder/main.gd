extends Node2D
# Storm Keeper (ours, Ludo video #47 Gate 2a): a turn-based card battle in the roguelike deckbuilder genre, built for the
# video. The Keeper (faces right) fights the crab knight and the anglerfish brute (both face left). Nothing is mirrored.
# Every picture and sound is a Ludo generation (g2a/, step0/, PROVENANCE.md); this code is ours.
# The rules: draw five, three energy, drag a card onto a target to play it, damage comes off block first, then health;
# each enemy shows its next move as an icon and then does it; your block resets at the start of your turn; win and pick
# one of three new cards, which adds its CardData file to the deck. The autopilot plays a scripted hand order for the
# video (the draw pile is stacked per turn); the rules underneath are the real ones.
# Run: Godot --path battle --write-movie x.avi --fixed-fps 30 --quit-after N -- mode=game|show log=/abs/x.jsonl [cards=/abs/dir]

const FEET := 680.0
const HAND_Y := 962.0
const SPREAD := 215.0   # r3: 172 let the next card cover the end of the rules text in the hand
const HAND_S := 0.48
const HOVER_S := 0.75
const DRAW_P := Vector2(96, 1000)
const DISC_P := Vector2(1824, 1000)
const END_P := Vector2(1712, 776)   # r3: up, clear of a six-card hand at the wider spread
const ORB_P := Vector2(160, 850)
const BG_FPS := 24.0
const BG_TINT := Color(1, 1, 1)   # Gate 2b (founder r3 note 0:04.6 "just use whatever comes out of ludo directly"): the clip untouched. r2 was 0.63: worst-frame contrast of the numbers at or above r1 (tools/contrast_r2.py); the dial for the moving background: darker if the cards, intents or numbers stop reading
var ANIMS: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/anim/anims.json"))
const ANIM_NAMES := ["idle", "attack", "hurt", "death"]
# r3 (founder notes 0:04.6 and 2:31.3 "they aren't really popping off the bg"): how the fighters stand off the moving sea.
# Compared on checks/r3/pop_sheet.jpg with tools/pop_contrast.py; LOOK is the pick. Widths in game px.
const LOOKS := {
	"r2": {},
	"rim_shade": {"gamma": 0.8, "lift": 1.1, "light_w": 10.0, "light_a": 0.85, "shade": 0.5, "pool": 0.35},
	# Gate 2b (founder r3 note 0:04.6): nothing painted on the background; the fighters read by what lives on them
	"rim": {"gamma": 0.8, "lift": 1.1, "light_w": 10.0, "light_a": 0.85},
	"rim_ink": {"gamma": 0.8, "lift": 1.1, "light_w": 10.0, "light_a": 0.85, "ink": 3.0},
	"rim_strong": {"gamma": 0.75, "lift": 1.15, "light_w": 14.0, "light_a": 1.0},
	# the anglerfish's own rim light, wider and full strength (its edge sat at 2.0 on the untouched sea); per-fighter keys override
	"rim_o1": {"gamma": 0.8, "lift": 1.1, "light_w": 10.0, "light_a": 0.85, "angler": {"glow_w": 5.0, "glow_a": 0.8}},
	"rim_o2": {"gamma": 0.8, "lift": 1.1, "light_w": 10.0, "light_a": 0.85, "angler": {"glow_w": 7.0, "glow_a": 0.75, "ink": 0.0, "light_w": 14.0, "light_a": 1.0}},
	"rim_o4": {"gamma": 0.8, "lift": 1.1, "light_w": 10.0, "light_a": 0.85, "angler": {"glow_w": 5.0, "glow_a": 0.5, "ink": 0.0, "light_w": 14.0, "light_a": 1.0}},
	"rim_o3": {"gamma": 0.8, "lift": 1.1, "light_w": 10.0, "light_a": 0.85, "angler": {"glow_w": 9.0, "glow_a": 0.6, "light_w": 14.0, "light_a": 1.0}},
	"halo": {"gamma": 0.85, "glow_w": 16.0, "glow_a": 0.85},
	"ink_halo": {"gamma": 0.85, "ink": 3.0, "glow_w": 18.0, "glow_a": 0.85},
	"rim_halo_shade": {"gamma": 0.8, "lift": 1.1, "light_w": 10.0, "light_a": 0.85, "glow_w": 12.0, "glow_a": 0.5, "shade": 0.5},
}
var LOOK := "rim_o2"   # Gate 2b pick on the untouched sea (tools/pop_contrast.py checks/g2b/probe)
var dying_n := 0
var POOL_TEX: Texture2D
var HALO_TEX: Texture2D
var DOT_TEX: Texture2D
var framef: FileAccess
const ICONS := {"attack": "res://art/i_attack.png", "block": "res://art/i_block.png", "buff": "res://art/i_buff.png"}

var CardScene: PackedScene = preload("res://card.tscn")
var FLASH: Shader = preload("res://flash.gdshader")
var font: Font = preload("res://art/Gelasio-Bold.ttf")
var mode := "game"
var SLOW := 1.0   # slow=<x>: the whole game, the sea too, at x speed (Gate 3: the slow-motion shot is a capture at 0.35, not repeated frames)
var cards_dir := ""
var logf: FileAccess
var t := 0.0
var frame := 0
var world: Node2D
var ui: CanvasLayer
var top: CanvasLayer
var cursor: Node2D
var keeper: Fighter
var enemies: Array = []
var deck: Array = []
var draw_pile: Array = []
var discard: Array = []
var hand: Array = []
var powers: Array = []
var energy := 3
var max_energy := 3
var turn := 0
var orb: TextureRect
var orb_lbl: Label
var draw_lbl: Label
var disc_lbl: Label
var end_btn: Panel
var relic_bar: HBoxContainer
var dim: ColorRect
var sfx := {}
var rng := RandomNumberGenerator.new()
var has_compass := false
var bg: Sprite2D
var bg_tex: ImageTexture
var bg_dir := ""
var bg_n := 1
var bg_i := -1

class Fighter extends Node2D:
	var key := ""
	var spr: AnimatedSprite2D
	var mat: ShaderMaterial
	var strike := 0.3
	var hp := 10
	var max_hp := 10
	var block := 0
	var strength := 0
	var weak := 0
	var h := 300.0
	var w := 300.0
	var pattern: Array = []
	var turn_i := 0
	var dead := false
	var bar: ColorRect
	var bar_lbl: Label
	var blk: Node2D
	var blk_lbl: Label
	var intent: Node2D
	var intent_icon: Sprite2D
	var intent_lbl: Label
	var status_lbl: Label
	var pw: HBoxContainer
	var base_x := 0.0
	var s := 1.0
	var bob := 0.0
	# r3 (founder note 0:08.6 "the char moves when the animation switches"): one pivot for every animation. Each sheet's
	# shift (anims.json, from tools/anim_metrics.py) puts its first frame's body centre and feet on idle's; at a hand-over
	# the body is held where the outgoing frame had it (corr) and eased back to the new animation's own pose, never snapped.
	var A: Dictionary
	var base := Vector2.ZERO
	var corr := Vector2.ZERO
	var corr0 := Vector2.ZERO
	var corr_age := 1.0
	var pool: Sprite2D
	var halo: Sprite2D   # r3: the background dimmed right behind the body (a soft dark patch), when the look asks for it
	var shadow: Polygon2D
	var dying := false
	const EASE_T := 0.32
	func cur() -> Array:
		return pattern[turn_i % pattern.size()]
	func anchor(an: String, fr: int) -> Vector2:   # body centre x and feet y of that frame, in sheet px from the sprite's origin
		var m: Array = A[an]["m"][clampi(fr, 0, A[an]["m"].size() - 1)]; var sh: Array = A[an].get("shift", [0, 0])
		return Vector2(m[2] + sh[0], m[1] + sh[1])
	var dr_a := "idle"   # the frame and offset last drawn (main.gd's frame_pre_draw hook): the hold starts from what the eye saw,
	var dr_f := 0        # not from a frame the sprite has advanced to since
	var dr_off := Vector2.ZERO
	func switch(an: String) -> void:   # attack, hurt or death once (idle loops by itself): hold the body across the cut
		var m: Array = A[dr_a]["m"][clampi(dr_f, 0, A[dr_a]["m"].size() - 1)]; var sh: Array = A[an].get("shift", [0, 0])
		var d := Vector2(m[2], m[1]) + dr_off - (anchor(an, 0) - Vector2(sh[0], sh[1]) + base + Vector2(sh[0], sh[1]))
		corr0 = d; corr = d; corr_age = 0.0
		held += 1; spr.play(an); spr.frame = 0; place()
		spr.speed_scale = 0.0; start_f = Engine.get_process_frames()   # Gate 2b: frame 0 is the first one drawn (a fast sheet skipped it)
	# Gate 2b (founder r3 note 0:08.6 "the char changes width slightly between animations"): every one-shot starts from idle's
	# first pose. Before an attack lands, the attacker and its targets run their idle on to frame 0 (two frames a tick, at most about 0.3 s,
	# the short way round) and hold there, so attack, hurt and death start on the pose and width idle has, never mid-sway.
	var held := 0
	var settling := false
	func settle() -> void:   # idle's frames stepped by hand to frame 0, two per game frame, the short way round; then held
		if dying or spr.animation != "idle": return
		var n := int(A["idle"]["n"]); var fwd := spr.frame >= n / 2; held += 1; var my := held
		spr.pause(); settling = true
		while spr.frame != 0 and held == my and spr.animation == "idle":
			spr.frame = (spr.frame + 2) % n if fwd and spr.frame + 2 < n else (0 if fwd else maxi(0, spr.frame - 2))
			await get_tree().process_frame
		settling = false
		if held != my or spr.animation != "idle": return
		await get_tree().create_timer(0.9).timeout   # nothing came: idle runs on from frame 0
		if held == my and spr.animation == "idle" and not spr.is_playing() and not dying: spr.play("idle"); spr.frame = 0
	func settle_to_rest() -> void:
		settle()
		var guard := 0
		while settling and guard < 40:
			await get_tree().process_frame; guard += 1
	func place() -> void:
		var sh: Array = A[spr.animation].get("shift", [0, 0])
		spr.offset = base + Vector2(sh[0], sh[1]) + corr
	var start_f := -1
	func _process(delta: float) -> void:
		if start_f >= 0 and Engine.get_process_frames() > start_f: start_f = -1; spr.speed_scale = 1.0   # the parent runs before the sprite
		if corr_age < EASE_T:
			corr_age = minf(EASE_T, corr_age + delta); var k := corr_age / EASE_T
			corr = corr0 * (1.0 - k * k * (3.0 - 2.0 * k))
		place()

# ---------------------------------------------------------------- setup
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="): mode = a.substr(5)
		if a.begins_with("log="): logf = FileAccess.open(a.substr(4), FileAccess.WRITE)
		if a.begins_with("cards="): cards_dir = a.substr(6)
		if a.begins_with("look="): LOOK = a.substr(5)
		if a.begins_with("slow="): SLOW = float(a.substr(5)); Engine.time_scale = SLOW
		if a.begins_with("log="): framef = FileAccess.open(a.substr(4).replace(".jsonl", ".frames.jsonl"), FileAccess.WRITE)
	var gp := GradientTexture2D.new(); gp.width = 256; gp.height = 256; gp.fill = GradientTexture2D.FILL_RADIAL
	gp.fill_from = Vector2(0.5, 0.5); gp.fill_to = Vector2(1.0, 0.5); var gg := Gradient.new()
	gg.set_color(0, Color(1.0, 0.82, 0.55, 1.0)); gg.set_color(1, Color(1.0, 0.82, 0.55, 0.0)); gp.gradient = gg; POOL_TEX = gp
	var gh := GradientTexture2D.new(); gh.width = 256; gh.height = 256; gh.fill = GradientTexture2D.FILL_RADIAL
	gh.fill_from = Vector2(0.5, 0.5); gh.fill_to = Vector2(1.0, 0.5); var g3 := Gradient.new(); g3.set_offset(1, 1.0)
	g3.set_color(0, Color(0.62, 0.8, 0.9, 1.0)); g3.set_color(1, Color(0.62, 0.8, 0.9, 0.0)); g3.add_point(0.5, Color(0.62, 0.8, 0.9, 0.45)); gh.gradient = g3; HALO_TEX = gh
	var gd := GradientTexture2D.new(); gd.width = 24; gd.height = 24; gd.fill = GradientTexture2D.FILL_RADIAL
	gd.fill_from = Vector2(0.5, 0.5); gd.fill_to = Vector2(1.0, 0.5); var g2 := Gradient.new()
	g2.set_color(0, Color.WHITE); g2.set_color(1, Color(1, 1, 1, 0)); gd.gradient = g2; DOT_TEX = gd
	RenderingServer.frame_pre_draw.connect(log_frames)
	rng.seed = 47
	for k in ["swish", "thunk", "block", "draw", "hit", "chime", "sink"]:
		var p := AudioStreamPlayer.new()
		p.stream = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://sfx/%s.wav" % k))
		p.max_polyphony = 4
		add_child(p)
		sfx[k] = p
	world = Node2D.new(); add_child(world)
	# the background: a looping Video Generator clip of the shore picture, one JPEG per frame (art/bg, not imported: .gdignore),
	# decoded into one texture as the clock passes, so it loops without a seam and never holds every frame in memory
	bg_dir = ProjectSettings.globalize_path("res://art/bg")
	bg_n = Array(DirAccess.get_files_at(bg_dir)).filter(func(f): return f.ends_with(".jpg")).size()
	bg_tex = ImageTexture.create_from_image(Image.load_from_file(bg_dir.path_join("f000.jpg")))
	bg = Sprite2D.new(); bg.texture = bg_tex; bg.centered = false; bg.modulate = BG_TINT
	var k := 1080.0 / bg_tex.get_height() * 1.04; bg.scale = Vector2(k, k); bg.position = Vector2(-(bg_tex.get_width() * k - 1920) / 2, -30)
	world.add_child(bg)
	rain()
	ui = CanvasLayer.new(); ui.layer = 1; add_child(ui)
	top = CanvasLayer.new(); top.layer = 2; add_child(top)
	dim = ColorRect.new(); dim.color = Color(0.02, 0.04, 0.05, 0.0); dim.size = Vector2(1920, 1080); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE; top.add_child(dim)
	cursor = make_cursor(); cursor.position = Vector2(1500, 1200); cursor.z_index = 200
	var cl := CanvasLayer.new(); cl.layer = 3; add_child(cl); cl.add_child(cursor)
	if mode == "show": show_run()
	elif mode == "probe": probe_run()
	else: game_run()

var gt := 0.0
var bg_hold := -1
func _process(delta: float) -> void:
	frame += 1; t = frame / 30.0; gt += delta   # t: video time (the movie runs at a fixed 30 fps); gt: game time, which a hit stop slows
	var i := int(t * SLOW * BG_FPS) % bg_n if bg_hold < 0 else bg_hold   # Gate 2b (REVIEW-G2B): the sea runs on video time, a hit stop never freezes it
	if i != bg_i:
		bg_i = i; bg_tex.update(Image.load_from_file(bg_dir.path_join("f%03d.jpg" % i)))

func apply_look(f: Fighter, look: String) -> void:
	var L: Dictionary = LOOKS[look].duplicate()
	if L.has(f.key): L.merge(L[f.key], true)
	f.mat.set_shader_parameter("lift", L.get("lift", 1.0)); f.mat.set_shader_parameter("gamma", L.get("gamma", 1.0))
	f.halo.visible = L.has("shade"); f.halo.modulate = Color(0, 0, 0, L.get("shade", 0.0))
	f.mat.set_shader_parameter("rim", L.get("ink", 7.0 if f.key == "angler" else 0.0) / f.s)
	f.mat.set_shader_parameter("light_w", L.get("light_w", 0.0) / f.s)
	f.mat.set_shader_parameter("light_col", Color(0.86, 0.94, 1.0, L.get("light_a", 0.0)))
	f.mat.set_shader_parameter("glow_w", L.get("glow_w", 0.0) / f.s)
	f.mat.set_shader_parameter("glow_col", Color(0.82, 0.92, 1.0, L.get("glow_a", 0.0)))
	f.pool.visible = L.has("pool"); f.pool.modulate.a = L.get("pool", 0.0)

func fighters() -> Array:
	var out: Array = enemies.filter(func(e): return is_instance_valid(e))
	if keeper and is_instance_valid(keeper): out.push_front(keeper)
	return out

func log_frames() -> void:   # r3: every fighter's drawn animation, frame and pivot, every frame (tools/handover_check.py)
	for f in fighters(): f.dr_a = f.spr.animation; f.dr_f = f.spr.frame; f.dr_off = f.spr.offset
	if framef == null: return
	for f in fighters():
		if not f.spr.visible: continue
		framef.store_line(JSON.stringify({"t": snappedf(t, 0.001), "k": f.key, "id": f.get_instance_id() % 100000, "a": f.spr.animation, "f": f.spr.frame,
			"ox": snappedf(f.spr.offset.x, 0.01), "oy": snappedf(f.spr.offset.y, 0.01), "s": snappedf(f.s, 0.0001)}))

func probe_run() -> void:   # r3: the looks side by side for the contrast check, at four background moments, plus a mask of the sprites
	hud(); keeper = make_fighter("keeper", 420, 430, 50, [])
	await begin_battle([["crab", 1150, 270, 18, [["attack", 6]]], ["angler", 1655, 290, 14, [["attack", 5]]]])
	for e in alive(): show_intent(e)
	for e in alive():   # the damage numbers' plates where a hit puts them (white-number contrast is measured over them)
		var pl := plate(0.75 * 92 * 3 + 90, 92 * 1.6); pl.position = Vector2(e.base_x, FEET - e.h * 0.62); pl.z_index = 59; world.add_child(pl)
	await wait(1.0)
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
	for k in 4:
		bg_hold = (k * 41 + 7) % bg_n
		for f in fighters(): f.spr.pause(); f.spr.animation = "idle"; f.spr.frame = (k * 9) % int(f.A.idle.n); f.place()
		for look in LOOKS:
			for f in fighters(): apply_look(f, look)
			await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("%s_%d.png" % [look, k]))
		bg.visible = false; ui.visible = false; world.get_child(1).visible = false   # the mask: the sprites alone, white on black
		for f in fighters():
			f.mat.set_shader_parameter("flash", 1.0); f.mat.set_shader_parameter("rim", 0.0); apply_look(f, "r2")
			for n in f.get_children(): n.visible = n == f.spr
		await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("mask_%d.png" % k))
		bg.visible = true; ui.visible = true; world.get_child(1).visible = true
		for f in fighters():
			f.mat.set_shader_parameter("flash", 0.0); apply_look(f, LOOK)
			for n in f.get_children(): n.visible = (n != f.intent or f != keeper) and n != f.pool and n != f.halo
	get_tree().quit()

func ev(name: String, d := {}) -> void:
	d["t"] = snappedf(t, 0.001); d["ev"] = name
	if logf: logf.store_line(JSON.stringify(d)); logf.flush()

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snd(k: String, vol := 0.0) -> void:
	sfx[k].volume_db = vol; sfx[k].play()

func lbl(txt: String, size: int, col := Color.WHITE, outl := 10, w := 420.0) -> Label:
	var l := Label.new(); l.text = txt
	l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col); l.add_theme_color_override("font_outline_color", Color(0.05, 0.035, 0.03))
	l.add_theme_constant_override("outline_size", outl)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(w, size * 1.5); l.pivot_offset = l.size / 2; l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func at(l: Control, p: Vector2) -> Control:
	l.position = p - l.size / 2; return l

func rain() -> void:
	var img := Image.create(3, 26, false, Image.FORMAT_RGBA8)
	for y in 26:
		for x in 3: img.set_pixel(x, y, Color(1, 1, 1, float(y) / 26.0 * (0.5 if x != 1 else 1.0)))
	var r := CPUParticles2D.new(); r.texture = ImageTexture.create_from_image(img); r.amount = 220; r.lifetime = 1.1; r.preprocess = 2.0
	r.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE; r.emission_rect_extents = Vector2(1250, 10); r.position = Vector2(1100, -60)
	r.direction = Vector2(-0.28, 1); r.spread = 1.5; r.gravity = Vector2.ZERO; r.initial_velocity_min = 1150; r.initial_velocity_max = 1400
	r.particle_flag_align_y = true; r.color = Color(0.85, 0.95, 1.0, 0.33); r.fixed_fps = 30
	world.add_child(r)

func make_cursor() -> Node2D:
	var n := Node2D.new()
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 40), Vector2(10, 31), Vector2(18, 48), Vector2(25, 45), Vector2(17, 28), Vector2(30, 28)])
	var p := Polygon2D.new(); p.polygon = pts; p.color = Color.WHITE; n.add_child(p)
	var o := Line2D.new(); o.points = pts; o.closed = true; o.width = 3; o.default_color = Color(0.05, 0.04, 0.03); n.add_child(o)
	n.scale = Vector2(1.35, 1.35)
	return n

# ---------------------------------------------------------------- fighters
func make_fighter(key: String, x: float, h: float, hp: int, pattern: Array, outline := false) -> Fighter:
	var f := Fighter.new(); f.key = key; f.position = Vector2(x, FEET); f.base_x = x; f.hp = hp; f.max_hp = hp; f.pattern = pattern; f.h = h
	# idle, attack and hurt: Ludo Sprite Generator animations of this fighter in its own facing (never flipped), packed to one
	# frame size and ground line (ludo toolbox sprite pack); art/anim/anims.json holds each sheet's grid, fps and the character box
	var A: Dictionary = ANIMS[key]; var fr := SpriteFrames.new(); fr.remove_animation("default")
	for an in ANIM_NAMES.filter(func(x): return A.has(x)):
		var m: Dictionary = A[an]; var sheet := Card.mip(load("res://art/anim/%s_%s.png" % [key, an]))
		fr.add_animation(an); fr.set_animation_loop(an, an == "idle"); fr.set_animation_speed(an, m.fps)
		for i in int(m.n):
			var at_ := AtlasTexture.new(); at_.atlas = sheet
			at_.region = Rect2((i % int(m.cols)) * m.fw, (i / int(m.cols)) * m.fh, m.fw, m.fh); fr.add_frame(an, at_)
	f.s = h / float(A.char_h); f.w = float(A.char_w) * f.s; f.strike = float(A.attack.strike_s)
	var sh := Polygon2D.new(); var pts := PackedVector2Array()
	for i in 32: pts.append(Vector2(cos(i * TAU / 32) * f.w * 0.44, sin(i * TAU / 32) * 18))
	sh.polygon = pts; sh.color = Color(0.0, 0.02, 0.03, 0.55); f.add_child(sh); f.shadow = sh
	f.pool = Sprite2D.new(); f.pool.texture = POOL_TEX; f.pool.scale = Vector2(f.w * 1.25 / 256.0, 90.0 / 256.0); f.pool.position = Vector2(0, -6)
	var pm := CanvasItemMaterial.new(); pm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; f.pool.material = pm; f.pool.visible = false
	f.add_child(f.pool); f.move_child(f.pool, 0)
	f.halo = Sprite2D.new(); f.halo.texture = HALO_TEX; f.halo.scale = Vector2(f.w * 1.35 / 256.0, f.h * 1.25 / 256.0); f.halo.position = Vector2(0, -f.h * 0.5)
	f.halo.visible = false   # r3 "shade": the sea dimmed right behind the body
	f.add_child(f.halo); f.move_child(f.halo, 0)
	var sp := AnimatedSprite2D.new(); sp.sprite_frames = fr; sp.centered = false
	f.A = A; f.base = Vector2(-float(A.center_x), -float(A.ground))
	sp.scale = Vector2(f.s, f.s); sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	f.mat = ShaderMaterial.new(); f.mat.shader = FLASH; sp.material = f.mat
	f.add_child(sp); f.spr = sp
	sp.play("idle"); sp.frame = rng.randi() % int(A.idle.n); f.place()
	sp.animation_finished.connect(func(): if not f.dying: f.switch("idle"))
	apply_look(f, LOOK)   # r2's dark rim on the anglerfish (outline) is the default "ink" of a look that sets none
	var bw := 210.0
	var bg := ColorRect.new(); bg.color = Color(0.06, 0.05, 0.04, 0.92); bg.size = Vector2(bw, 30); bg.position = Vector2(-bw / 2, 24); f.add_child(bg)
	f.bar = ColorRect.new(); f.bar.color = Color(0.84, 0.17, 0.12); f.bar.size = Vector2(bw - 6, 24); f.bar.position = Vector2(-bw / 2 + 3, 27); f.add_child(f.bar)
	f.bar_lbl = lbl("", 25, Color.WHITE, 7, bw); f.add_child(at(f.bar_lbl, Vector2(0, 39)))
	f.blk = Node2D.new(); f.blk.position = Vector2(-bw / 2 - 34, 38); f.add_child(f.blk)
	var bi := Sprite2D.new(); bi.texture = Card.mip(load(ICONS["block"])); bi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; bi.scale = Vector2(0.42, 0.42); f.blk.add_child(bi)
	f.blk_lbl = lbl("", 30, Color.WHITE, 8, 80); f.blk.add_child(at(f.blk_lbl, Vector2(0, 2)))
	f.status_lbl = lbl("", 24, Color(1, 0.86, 0.5), 7, 300); f.add_child(at(f.status_lbl, Vector2(0, 78)))
	f.pw = HBoxContainer.new(); f.pw.position = Vector2(-bw / 2, 66); f.add_child(f.pw)
	f.intent = Node2D.new(); f.intent.position = Vector2(0, -h - 62); f.add_child(f.intent); f.intent.visible = false
	f.intent_icon = Sprite2D.new(); f.intent_icon.scale = Vector2(0.5, 0.5); f.intent_icon.position = Vector2(-28, 0); f.intent_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; f.intent.add_child(f.intent_icon)
	var ipl := plate(230, 120); ipl.position = Vector2(10, 2); f.intent.add_child(ipl); f.intent.move_child(ipl, 0)   # r3: the brighter fighters stay off the intent
	f.intent_lbl = lbl("", 46, Color.WHITE, 10, 120); f.intent.add_child(at(f.intent_lbl, Vector2(48, 4)))
	world.add_child(f); refresh(f)
	return f

func refresh(f: Fighter) -> void:
	f.bar.size.x = (204.0) * float(f.hp) / float(f.max_hp)
	f.bar_lbl.text = "%d/%d" % [f.hp, f.max_hp]
	f.blk.visible = f.block > 0; f.blk_lbl.text = str(f.block)
	var st := []
	if f.weak > 0: st.append("Weak %d" % f.weak)
	if f.strength > 0: st.append("Strength +%d" % f.strength)
	f.status_lbl.text = "  ".join(st)

func intent_value(e: Fighter) -> int:
	var it: Array = e.cur()
	if it[0] != "attack": return it[1]
	var d: int = it[1] + e.strength
	return int(floor(d * 0.75)) if e.weak > 0 else d

func show_intent(e: Fighter) -> void:
	var it: Array = e.cur()
	e.intent_icon.texture = Card.mip(load(ICONS[it[0]]))
	e.intent_lbl.text = ("+%d" % it[1]) if it[0] == "buff" else str(intent_value(e))
	e.intent.visible = true; e.intent.scale = Vector2(0.0, 1.0)
	create_tween().tween_property(e.intent, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ev("intent", {"who": e.key, "kind": it[0], "n": intent_value(e), "x": e.position.x})

func plate(w: float, h: float) -> Sprite2D:   # r3: a soft dark patch behind a number drawn over a fighter (the lifted bodies are brighter)
	var pl := Sprite2D.new(); pl.texture = POOL_TEX; pl.modulate = Color(0.0, 0.0, 0.0, 0.72); pl.scale = Vector2(w / 256.0, h / 256.0)
	return pl

func pop(p: Vector2, txt: String, col: Color, size := 80, parent: Node = null) -> void:
	var l := lbl(txt, size, col, 14, 520); (parent if parent else world).add_child(l); at(l, p); l.z_index = 60
	if parent == null:   # over the fighters
		var pl := plate(size * 0.75 * txt.length() + 90, size * 1.6); pl.position = l.size / 2; pl.show_behind_parent = true; l.add_child(pl)
	l.scale = Vector2(0.4, 0.4)
	var tw := create_tween(); tw.tween_property(l, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 95, 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.68)
	tw.tween_callback(l.queue_free)

func flash(f: Fighter) -> void:
	f.mat.set_shader_parameter("flash", 1.0)
	create_tween().tween_method(func(v: float): f.mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.28)

func shake(n: Node2D, amt := 16.0, dur := 0.3) -> void:
	var tw := create_tween(); var x0 := n.position.x
	for i in 6: tw.tween_property(n, "position:x", x0 + (amt if i % 2 == 0 else -amt) * (1.0 - i / 6.0), dur / 7.0)
	tw.tween_property(n, "position:x", x0, dur / 7.0)

func lunge(f: Fighter, dir: float, targets: Array = []) -> void:
	for x in targets: x.settle()   # Gate 2b: the target settles on idle's first pose while the attacker does (no pose snap at the hurt)
	await f.settle_to_rest()
	f.switch("attack"); await wait(maxf(0.0, f.strike - 0.13))
	var tw := create_tween()
	tw.tween_property(f, "position:x", f.base_x + dir * 140, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(f, "position:x", f.base_x, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ev("lunge", {"who": f.key, "x": f.base_x})
	await wait(0.13)

func damage(f: Fighter, dmg: int) -> void:
	var absorbed := mini(f.block, dmg); f.block -= absorbed; var rest := dmg - absorbed
	flash(f); shake(f.spr, 18.0, 0.3); snd("thunk" if f != keeper else "hit")
	if f.hp - rest > 0 or f == keeper: f.switch("hurt")   # r3: the killing blow plays the death instead
	if rest >= 8: shake(world, 7.0, 0.25)
	var head := Vector2(f.position.x if f != keeper else f.base_x, FEET - f.h * 0.62)
	if absorbed > 0:
		pop(Vector2(f.base_x + (-170 if f == keeper else 170), FEET - f.h * 0.3), "Blocked %d" % absorbed, Color(0.62, 0.88, 1.0), 50); snd("block", -4.0)
		create_tween().tween_property(f.blk, "scale", Vector2.ONE, 0.2).from(Vector2(1.5, 1.5))
	if rest > 0: pop(head, "-%d" % rest, Color(1.0, 0.92, 0.82), 92)
	f.hp = maxi(0, f.hp - rest); refresh(f)
	ev("hit", {"who": f.key, "dmg": dmg, "absorbed": absorbed, "rest": rest, "hp": f.hp, "x": f.base_x, "y": FEET - f.h * 0.5})
	if f.hp <= 0 and f != keeper: await die(f)

func die(f: Fighter) -> void:
	# r3 (founder note 0:11.4 "satisfying death animations"): the killing blow freezes the frame for a beat (hit stop, the
	# white flash held), then the fighter's own Ludo death animation plays (Ignis, its own facing) with a burst of spray;
	# once it lies still the body dissolves into sea foam from the edges in, and only then is it gone.
	f.dead = true; f.dying = true; f.intent.visible = false; dying_n += 1
	f.mat.set_shader_parameter("flash", 1.0)
	await hit_stop(0.12)
	flash(f); f.switch("death"); snd("sink"); ev("die", {"who": f.key, "x": f.base_x})
	burst(f.position + Vector2(0, -f.h * 0.5), f.w * 0.45, 46, 0.9)
	for n in [f.blk, f.pw]: create_tween().tween_property(n, "modulate:a", 0.0, 0.35)
	for n in f.get_children():
		if n is ColorRect or n is Label: create_tween().tween_property(n, "modulate:a", 0.0, 0.35)
	var D: Dictionary = f.A["death"]; f.mat.set_shader_parameter("cell", Vector2(D.fw, D.fh))
	# the anglerfish rolls belly up (pale): it starts to dissolve 0.45 s before its death ends (REVIEW-R3 should 1)
	await wait(float(D.n) / float(D.fps) + (0.15 if f.key != "angler" else -0.45))
	ev("dissolve", {"who": f.key})
	var foam := burst(f.position + Vector2(0, -f.h * 0.3), f.w * 0.4, 70, 1.3, true)
	var tw := create_tween().set_parallel()
	tw.tween_method(func(v: float): f.mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(f.pool, "modulate:a", 0.0, 0.6)
	tw.tween_property(f.shadow, "modulate:a", 0.0, 0.75)   # the ground shadow goes with the body
	tw.tween_property(f.halo, "modulate:a", 0.0, 0.6)
	await tw.finished
	f.spr.visible = false; ev("gone", {"who": f.key}); dying_n -= 1
	await wait(1.4); if is_instance_valid(foam): foam.queue_free()

func hit_stop(s: float) -> void:   # the game stops for a beat on the killing blow (the log keeps real time)
	Engine.time_scale = 0.03 * SLOW
	await get_tree().create_timer(s / SLOW, true, false, true).timeout
	Engine.time_scale = SLOW

func burst(p: Vector2, r: float, n: int, life: float, rise := false) -> CPUParticles2D:   # spray on the kill; foam as the body dissolves
	var b := CPUParticles2D.new(); b.texture = DOT_TEX; b.amount = n; b.lifetime = life; b.one_shot = true; b.explosiveness = 0.55 if rise else 0.95
	b.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE; b.emission_sphere_radius = r; b.position = p; b.z_index = 5
	b.direction = Vector2(0, -1); b.spread = 70.0 if rise else 180.0; b.gravity = Vector2(0, -60) if rise else Vector2(0, 900)
	b.initial_velocity_min = 40.0 if rise else 260.0; b.initial_velocity_max = 140.0 if rise else 620.0
	b.scale_amount_min = 0.25; b.scale_amount_max = 0.8 if rise else 0.6
	var g := Gradient.new(); g.set_color(0, Color(0.86, 0.97, 1.0, 0.95)); g.set_color(1, Color(0.6, 0.85, 0.95, 0.0)); b.color_ramp = g
	b.fixed_fps = 30; world.add_child(b); b.emitting = true
	return b

func gain_block(f: Fighter, n: int) -> void:
	f.block += n; refresh(f); snd("block")
	pop(Vector2(f.base_x, FEET - f.h * 0.55), "+%d Block" % n, Color(0.62, 0.88, 1.0), 62)
	create_tween().tween_property(f.blk, "scale", Vector2.ONE, 0.3).from(Vector2(2.0, 2.0)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ev("block", {"who": f.key, "n": n, "x": f.base_x})

# ---------------------------------------------------------------- the hand
func new_card(d: CardData) -> Card:
	var c: Card = CardScene.instantiate()
	c.setup(d)
	return c

func layout_hand(d := 0.22) -> void:
	var n := hand.size()
	for i in n:
		var c: Card = hand[i]
		var t := i - (n - 1) / 2.0
		var pos := Vector2(960 + t * SPREAD, HAND_Y + t * t * 8)
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "position", pos - c.pivot_offset, d)
		tw.tween_property(c, "rotation_degrees", t * 4.0, d)
		tw.tween_property(c, "scale", Vector2(HAND_S, HAND_S), d)
		c.z_index = i

func hover(c: Card) -> void:
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2(HOVER_S, HOVER_S), 0.16)
	tw.tween_property(c, "rotation_degrees", 0.0, 0.16)
	tw.tween_property(c, "position:y", 1080 - 768 * HOVER_S / 2 - 8 - c.pivot_offset.y, 0.16)
	c.z_index = 50
	ev("hover", {"card": c.data.title, "x": c.position.x + c.pivot_offset.x})

func piles() -> void:
	draw_lbl.text = str(draw_pile.size()); disc_lbl.text = str(discard.size())

func key_of(d: CardData) -> String:
	return d.resource_path.get_file().get_basename()

func draw_n(k: int, want: Array = []) -> void:
	for j in k:
		if draw_pile.is_empty(): await reshuffle()
		if draw_pile.is_empty(): return
		var idx := 0
		if j < want.size():   # the video's stacked deck: the named card comes off the pile next
			for q in draw_pile.size():
				if key_of(draw_pile[q]) == want[j]: idx = q
		var d: CardData = draw_pile.pop_at(idx)
		var c := new_card(d); ui.add_child(c); c.position = DRAW_P - c.pivot_offset; c.scale = Vector2(0.1, 0.1)
		hand.append(c); layout_hand(0.3); snd("swish", -3.0); piles()
		ev("draw", {"card": d.title})
		await wait(0.11)

func reshuffle() -> void:
	ev("reshuffle", {"n": discard.size()})
	snd("draw")
	pop(DRAW_P + Vector2(70, -110), "Reshuffle", Color(1, 0.9, 0.6), 40, ui)
	for i in mini(discard.size(), 6):
		var b := back(); ui.add_child(b); b.position = DISC_P - b.size / 2
		var tw := create_tween(); tw.tween_property(b, "position", DRAW_P - b.size / 2, 0.32).set_delay(i * 0.04).set_trans(Tween.TRANS_CUBIC)
		tw.tween_callback(b.queue_free)
	draw_pile = discard.duplicate(); discard.clear()
	for i in range(draw_pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i); var tmp = draw_pile[i]; draw_pile[i] = draw_pile[j]; draw_pile[j] = tmp
	await wait(0.4); piles()

func back() -> Panel:
	var p := Panel.new(); p.size = Vector2(62, 86); var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.1, 0.36, 0.38)
	sb.set_border_width_all(4); sb.border_color = Color(0.85, 0.62, 0.25); sb.set_corner_radius_all(8); p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func cursor_to(p: Vector2, d := 0.26) -> void:
	var tw := create_tween(); tw.tween_property(cursor, "position", p, d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

func find_card(title: String) -> Card:
	for c in hand:
		if c.data.title == title: return c
	return null

func alive() -> Array:
	return enemies.filter(func(e): return not e.dead)

func play(title: String, target: Fighter = null) -> void:
	var c := find_card(title)
	if c == null or c.data.cost > energy:
		push_warning("cannot play " + title); ev("skip", {"card": title}); return
	ev("pick", {"card": title})
	await cursor_to(Vector2(c.position.x + c.pivot_offset.x + 40, 760))   # r3: on the art once it lifts, never on the rules text
	hover(c); await wait(0.34)
	var dest := Vector2(target.base_x, FEET - target.h * 0.5) if target else Vector2(keeper.base_x + 140, 430)
	c.z_index = 100
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "position", dest - c.pivot_offset, 0.34); tw.tween_property(c, "scale", Vector2(0.5, 0.5), 0.34)
	tw.tween_property(c, "rotation_degrees", -6.0 if target else 0.0, 0.34); tw.tween_property(cursor, "position", dest + Vector2(0, 20), 0.34)
	ev("drag", {"card": title, "to": target.key if target else "self", "x": dest.x, "y": dest.y})
	if target: create_tween().tween_property(target.spr, "modulate", Color(1.25, 1.2, 1.0), 0.17).set_delay(0.17)
	await tw.finished
	if target: target.spr.modulate = Color.WHITE
	energy -= c.data.cost; orb_refresh(true)
	hand.erase(c); layout_hand()
	var tw2 := create_tween().set_parallel()   # the play: the card shoots into its target and is gone
	tw2.tween_property(c, "scale", Vector2(0.12, 0.12), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(c, "modulate:a", 0.0, 0.13)
	ev("play", {"card": title, "to": target.key if target else "self", "energy": energy})
	await tw2.finished
	await resolve(c.data, target)
	if c.data.kind != CardData.Kind.POWER: discard.append(c.data)
	c.queue_free(); piles()
	cursor_to(Vector2(cursor.position.x * 0.6 + 960 * 0.4, 760), 0.3)
	await wait(0.22)

func resolve(d: CardData, target: Fighter) -> void:
	if d.kind == CardData.Kind.POWER:
		powers.append(d); snd("chime", -4.0)
		var ic := TextureRect.new(); ic.texture = Card.mip(load(ICONS["buff"])); ic.custom_minimum_size = Vector2(40, 40); ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; keeper.pw.add_child(ic)
		pop(Vector2(keeper.base_x, FEET - keeper.h - 40), d.title, Color(0.7, 0.82, 1.0), 54)
		ev("power", {"card": d.title})
		return
	if d.damage > 0:
		await lunge(keeper, 1.0, alive() if d.all_enemies else [target])
		for e in (alive() if d.all_enemies else [target]):
			damage(e, d.damage)
		await wait(0.42)
	if d.block > 0: gain_block(keeper, d.block); await wait(0.3)
	if d.weak > 0:
		snd("block", -6.0)
		for e in alive():
			e.weak += d.weak; refresh(e); pop(Vector2(e.base_x, FEET - e.h * 0.6), "Weak", Color(0.8, 0.9, 0.7), 58)
			e.intent_lbl.text = str(intent_value(e))
		await wait(0.35)
	if d.draw > 0: await draw_n(d.draw, [])

func orb_refresh(pulse := false) -> void:
	orb_lbl.text = "%d/%d" % [energy, max_energy]
	if pulse: create_tween().tween_property(orb, "scale", Vector2.ONE, 0.25).from(Vector2(1.18, 1.18))

func banner(txt: String) -> void:
	var l := lbl(txt, 92, Color(1, 0.93, 0.75), 16, 900); top.add_child(at(l, Vector2(960, 300)))
	l.modulate.a = 0.0; l.scale = Vector2(0.85, 0.85)
	var tw := create_tween(); tw.tween_property(l, "modulate:a", 1.0, 0.14); tw.parallel().tween_property(l, "scale", Vector2.ONE, 0.2)
	tw.tween_interval(0.42); tw.tween_property(l, "modulate:a", 0.0, 0.2); tw.tween_callback(l.queue_free)
	ev("banner", {"text": txt})
	await wait(0.5)

# ---------------------------------------------------------------- the turn loop
func hud() -> void:
	orb = TextureRect.new(); orb.texture = Card.mip(load("res://art/orb.png")); orb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; orb.size = Vector2(170, 170); orb.pivot_offset = Vector2(85, 85); ui.add_child(at(orb, ORB_P))
	orb_lbl = lbl("3/3", 50, Color.WHITE, 12, 170); orb.add_child(at(orb_lbl, Vector2(85, 88)))
	var dp := back(); dp.size = Vector2(76, 104); ui.add_child(at(dp, DRAW_P)); draw_lbl = lbl("0", 38, Color.WHITE, 10, 76); dp.add_child(at(draw_lbl, Vector2(38, 52)))
	var xp := back(); xp.size = Vector2(76, 104); ui.add_child(at(xp, DISC_P)); xp.modulate = Color(0.75, 0.75, 0.8); disc_lbl = lbl("0", 38, Color.WHITE, 10, 76); xp.add_child(at(disc_lbl, Vector2(38, 52)))
	ui.add_child(at(lbl("Draw", 26, Color(1, 0.9, 0.7), 7, 120), DRAW_P + Vector2(0, -74)))
	ui.add_child(at(lbl("Discard", 26, Color(1, 0.9, 0.7), 7, 140), DISC_P + Vector2(0, -74)))
	end_btn = Panel.new(); var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.58, 0.3, 0.1); sb.set_corner_radius_all(14); sb.set_border_width_all(5); sb.border_color = Color(0.95, 0.78, 0.4)
	end_btn.add_theme_stylebox_override("panel", sb); end_btn.size = Vector2(230, 84); end_btn.pivot_offset = end_btn.size / 2; ui.add_child(at(end_btn, END_P))
	end_btn.add_child(at(lbl("End turn", 38, Color.WHITE, 9, 230), Vector2(115, 42)))
	relic_bar = HBoxContainer.new(); relic_bar.position = Vector2(26, 18); relic_bar.add_theme_constant_override("separation", 10); ui.add_child(relic_bar)
	for r in ["r_feather", "r_jar"]: add_relic(r)

func add_relic(k: String) -> TextureRect:
	var ic := TextureRect.new(); ic.texture = Card.mip(load("res://art/%s.png" % k)); ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ic.custom_minimum_size = Vector2(76, 76); ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	relic_bar.add_child(ic); return ic

func begin_battle(specs: Array) -> void:
	for e in enemies: e.queue_free()
	enemies.clear(); discard.clear(); draw_pile = deck.duplicate(); keeper.block = 0; refresh(keeper)
	powers.clear()   # powers last one fight
	for n in keeper.pw.get_children(): n.queue_free()
	for s in specs:
		var e := make_fighter(s[0], s[1], s[2], s[3], s[4], s[0] == "angler")
		e.position.y = FEET + 160; e.modulate.a = 0.0; enemies.append(e)
		var tw := create_tween().set_parallel(); tw.tween_property(e, "position:y", FEET, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(e, "modulate:a", 1.0, 0.3)
	snd("block", -3.0); piles(); turn = 0
	ev("battle", {"enemies": specs.map(func(s): return s[0])})
	await wait(0.4)

func start_turn(want: Array, extra := 0) -> void:
	turn += 1
	if keeper.block > 0:
		ev("block_reset", {"was": keeper.block})
		keeper.block = 0; refresh(keeper)
	energy = max_energy; orb_refresh(true)
	await banner("Your turn")
	for p in powers:
		if p.block > 0: gain_block(keeper, p.block)
		extra += p.draw
	if has_compass: extra += 1   # the Brass Compass relic: one more card every turn
	for e in alive(): show_intent(e)
	ev("turn", {"n": turn})
	await draw_n(5 + extra, want)
	await wait(0.2)

func end_turn() -> void:
	await cursor_to(END_P, 0.28)
	create_tween().tween_property(end_btn, "scale", Vector2.ONE, 0.2).from(Vector2(0.88, 0.88)); snd("draw", -4.0)
	ev("end_turn")
	for c in hand:
		discard.append(c.data)
		var tw := create_tween().set_parallel(); tw.tween_property(c, "position", DISC_P - c.pivot_offset, 0.3).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(c, "scale", Vector2(0.08, 0.08), 0.3); tw.chain().tween_callback(c.queue_free)
	hand.clear(); piles()
	cursor_to(Vector2(1500, 760), 0.3)
	await wait(0.3)
	await banner("Enemy turn")
	for e in alive():
		await enemy_act(e)
	for e in alive():
		e.weak = maxi(0, e.weak - 1); refresh(e)

func enemy_act(e: Fighter) -> void:
	var it: Array = e.cur()
	if e.block > 0: e.block = 0; refresh(e)
	ev("enemy_act", {"who": e.key, "kind": it[0], "x": e.base_x})
	match it[0]:
		"attack":
			var dmg := intent_value(e)
			await lunge(e, -1.0, [keeper])
			await damage(keeper, dmg)
		"block":
			gain_block(e, it[1])
		"buff":
			e.strength += it[1]; refresh(e); snd("chime", -6.0)
			pop(Vector2(e.base_x, FEET - e.h * 0.6), "Strength +%d" % it[1], Color(1, 0.75, 0.5), 56)
			create_tween().tween_property(e.spr, "scale:x", e.s, 0.35).from(e.s * 1.15)
	e.turn_i += 1
	create_tween().tween_property(e.intent, "modulate:a", 0.0, 0.2)
	await wait(0.72)
	e.intent.modulate.a = 1.0; e.intent.visible = false

func auto_turn() -> void:   # greedy: attacks on the weakest enemy first, then block, until the energy runs out
	await start_turn([])
	var guard := 0
	while energy > 0 and not won() and guard < 6:
		guard += 1
		var best: Card = null
		for c in hand:
			if c.data.cost <= energy and c.data.kind == CardData.Kind.ATTACK: best = c; break
		if best == null:
			for c in hand:
				if c.data.cost <= energy and c.data.kind == CardData.Kind.SKILL: best = c; break
		if best == null: break
		var tg: Array = alive(); tg.sort_custom(func(x, y): return x.hp < y.hp)
		await play(best.data.title, tg[0] if best.data.kind == CardData.Kind.ATTACK else null)
	if not won(): await end_turn()

func won() -> bool:
	return alive().is_empty()

func reward(keys: Array, pick: String, relic := "") -> void:
	while dying_n > 0: await wait(0.05)   # r3: the deaths play out before the reward screen dims the stage
	await wait(0.45)
	for c in hand:
		discard.append(c.data); c.queue_free()
	hand.clear()
	ev("reward")
	var tw := create_tween(); tw.tween_property(dim, "color:a", 0.62, 0.35)
	var title := lbl("Choose a card", 70, Color(1, 0.92, 0.72), 14, 900); top.add_child(at(title, Vector2(960, 190))); title.modulate.a = 0.0
	create_tween().tween_property(title, "modulate:a", 1.0, 0.3)
	snd("chime")
	var cs: Array = []
	for i in 3:
		var c := new_card(load("res://cards/%s.tres" % keys[i])); top.add_child(c); c.scale = Vector2(0.6, 0.6)
		var p := Vector2(960 + (i - 1) * 390, 600)
		c.position = p + Vector2(0, 700) - c.pivot_offset
		create_tween().tween_property(c, "position", p - c.pivot_offset, 0.42).set_delay(0.1 + i * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		cs.append(c)
		get_tree().create_timer(0.1 + i * 0.12).timeout.connect(func(): snd("swish", -3.0))
	await wait(0.75)
	if relic != "":
		var r := TextureRect.new(); r.texture = Card.mip(load("res://art/%s.png" % relic)); r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = Vector2(120, 120); r.pivot_offset = r.size / 2; top.add_child(at(r, Vector2(960, 300))); r.scale = Vector2.ZERO
		create_tween().tween_property(r, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		title.text = "Take a relic"
		await wait(0.35)
		await cursor_to(Vector2(975, 320), 0.3)
		snd("chime", -2.0); ev("relic", {"relic": relic})
		var rt := create_tween(); rt.tween_property(r, "position", Vector2(26 + relic_bar.get_child_count() * 86, 18), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		rt.parallel().tween_property(r, "size", Vector2(76, 76), 0.45)
		await rt.finished
		r.queue_free(); add_relic(relic); title.text = "Choose a card"
		has_compass = has_compass or relic == "r_compass"
		pop(Vector2(330, 60), "Brass Compass: +1 card a turn", Color(1, 0.9, 0.6), 36, top)
	var pi := keys.find(pick)
	for i in [0, 2, pi]:
		var c: Card = cs[i]
		await cursor_to(c.position + c.pivot_offset + Vector2(60, -110), 0.26)   # r3: on the art, off the name and the text
		var ht := create_tween(); ht.tween_property(c, "scale", Vector2(0.7, 0.7), 0.14)
		ev("reward_hover", {"card": c.data.title})
		await wait(0.42)
		if i != pi: create_tween().tween_property(c, "scale", Vector2(0.6, 0.6), 0.14)
	var pc: Card = cs[pi]
	snd("draw"); ev("reward_pick", {"card": pc.data.title})
	deck.append(pc.data)
	var ft := create_tween(); ft.tween_property(pc, "scale", Vector2(0.78, 0.78), 0.12)
	ft.tween_property(pc, "position", DRAW_P - pc.pivot_offset, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	ft.parallel().tween_property(pc, "scale", Vector2(0.06, 0.06), 0.5)
	for i in 3:
		if i != pi: create_tween().tween_property(cs[i], "modulate:a", 0.0, 0.3)
	pop(DRAW_P + Vector2(80, -130), "+1 card", Color(1, 0.9, 0.6), 44, ui)
	await wait(0.65)
	for c in cs: c.queue_free()
	create_tween().tween_property(dim, "color:a", 0.0, 0.3); create_tween().tween_property(title, "modulate:a", 0.0, 0.25)
	await wait(0.3); title.queue_free()

# ---------------------------------------------------------------- the played run (mode=game)
func game_run() -> void:
	hud()
	keeper = make_fighter("keeper", 420, 430, 50, [])
	for k in ["harpoon", "brace", "gulls", "patch", "chart", "undertow", "foghorn", "flare", "watch"]:
		deck.append(load("res://cards/%s.tres" % k))
	await begin_battle([["crab", 1150, 270, 18, [["attack", 6], ["block", 6], ["attack", 8]]], ["angler", 1655, 290, 14, [["attack", 5], ["buff", 2], ["attack", 7]]]])
	var crab: Fighter = enemies[0]; var ang: Fighter = enemies[1]
	# battle 1: the cold open
	await start_turn(["harpoon", "brace", "gulls", "chart", "foghorn"])
	await play("Harpoon Strike", crab)
	await play("Brace")
	await play("Gull Swarm", ang)
	await end_turn()
	await start_turn(["undertow", "flare", "patch", "watch"])
	await play("Undertow", crab)
	await play("Lantern Flare", ang)
	await reward(["wave", "beacon", "ward"], "wave")
	# battle 2: block first, a buff, a power, Rogue Wave
	await begin_battle([["crab", 1150, 270, 26, [["block", 6], ["attack", 8], ["attack", 10]]], ["angler", 1655, 290, 22, [["buff", 2], ["attack", 6], ["attack", 7]]]])
	crab = enemies[0]; ang = enemies[1]
	await start_turn(["brace", "harpoon", "gulls", "chart", "foghorn"])
	await play("Brace")
	await play("Tide Chart")
	await play("Harpoon Strike", ang)
	await play("Gull Swarm", ang)
	await end_turn()
	await start_turn(["flare", "wave", "watch", "undertow", "harpoon"])
	await play("Harpoon Strike", crab)
	await play("Rogue Wave", crab)
	await end_turn()
	await start_turn(["brace", "gulls", "foghorn", "patch", "chart"])
	await play("Brace")
	await play("Gull Swarm", crab)
	await play("Foghorn")
	await end_turn()
	await start_turn(["watch", "undertow", "flare", "harpoon", "wave"])
	await play("Keeper's Watch")
	await play("Undertow", crab)
	await reward(["beacon", "ward", "harpoon"], "beacon", "r_compass")
	# battle 3: the full sound; Rogue Wave takes both
	await begin_battle([["crab", 1150, 270, 16, [["attack", 7], ["block", 5]]], ["angler", 1655, 290, 15, [["attack", 6], ["attack", 6]]]])
	crab = enemies[0]; ang = enemies[1]
	await start_turn(["harpoon", "brace", "flare", "gulls", "chart", "undertow"])
	await play("Brace")
	await play("Harpoon Strike", crab)
	await play("Lantern Flare", ang)
	await end_turn()
	await start_turn(["wave", "patch", "foghorn", "beacon", "watch"])
	await play("Rogue Wave", crab)
	await reward(["ward", "harpoon", "flare"], "ward")
	# battle 4: two scripted turns, then the autopilot plays greedy turns to the end
	await begin_battle([["crab", 1150, 270, 24, [["attack", 9], ["block", 8], ["attack", 6]]], ["angler", 1655, 290, 24, [["buff", 3], ["attack", 7], ["attack", 8]]]])
	crab = enemies[0]; ang = enemies[1]
	await start_turn(["harpoon", "flare", "gulls", "chart", "brace", "patch"])
	await play("Harpoon Strike", crab)
	await play("Lantern Flare", ang)
	await play("Gull Swarm", ang)
	await play("Tide Chart")
	await end_turn()
	await start_turn(["ward", "watch", "wave", "beacon"])
	await play("Tidal Ward")
	await play("Keeper's Watch")
	await end_turn()
	while not won():
		await auto_turn()
	await wait(0.6)
	ev("victory"); await banner("Victory")
	cursor_to(Vector2(1500, 1250), 0.4)
	for c in hand: c.queue_free()
	hand.clear()
	await wait(3.0)
	ev("end"); await wait(0.2)
	get_tree().quit()

# ---------------------------------------------------------------- the showcase shots (mode=show)
func show_run() -> void:
	world.modulate = Color(0.55, 0.6, 0.62)
	var keys := ["harpoon", "brace", "gulls", "patch", "chart", "undertow", "foghorn", "flare", "watch", "wave", "beacon", "ward"]
	if cards_dir != "": await export_cards(keys)
	# 1. the anchor card, the deck dealing out of it into a fan
	ev("show", {"k": "fan"})
	var big := new_card(load("res://cards/harpoon.tres")); ui.add_child(big); big.scale = Vector2(1.05, 1.05); big.position = Vector2(960, 520) - big.pivot_offset
	await wait(1.0)
	var fan: Array = []
	for k in keys.slice(1, 9):
		var c := new_card(load("res://cards/%s.tres" % k)); ui.add_child(c); c.scale = Vector2(0.9, 0.9); c.position = big.position; c.z_index = -1; fan.append(c)
	fan.insert(4, big)
	for i in fan.size():
		var c: Card = fan[i]; var tt := i - (fan.size() - 1) / 2.0
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "position", Vector2(960 + tt * 178, 610 + tt * tt * 14) - c.pivot_offset, 0.55).set_delay(abs(tt) * 0.09)
		tw.tween_property(c, "rotation_degrees", tt * 5.0, 0.55).set_delay(abs(tt) * 0.09)
		tw.tween_property(c, "scale", Vector2(0.56, 0.56), 0.55).set_delay(abs(tt) * 0.09)
		c.z_index = i
		get_tree().create_timer(abs(tt) * 0.09).timeout.connect(func(): snd("swish", -6.0))
	await wait(1.4)
	for i in fan.size():   # each card lifts in turn
		var c: Card = fan[i]
		var tw := create_tween(); tw.tween_property(c, "position:y", c.position.y - 50, 0.16); tw.tween_property(c, "position:y", c.position.y, 0.2)
		await wait(0.2)
	await wait(1.4)
	for c in fan: c.queue_free()
	# 2. one frame, the ribbon tinted per type, plus a type icon
	ev("show", {"k": "ribbon"})
	var rc := new_card(load("res://cards/harpoon.tres")); ui.add_child(rc); rc.scale = Vector2(1.12, 1.12); rc.position = Vector2(760, 540) - rc.pivot_offset
	var names := ["Attack", "Skill", "Power"]
	var kl := lbl("Attack", 80, Color.WHITE, 14, 600); ui.add_child(at(kl, Vector2(1420, 540)))
	for i in 7:
		var k := i % 3
		rc.tint(k); kl.text = names[k]; kl.add_theme_color_override("font_color", Card.TINT[k].lightened(0.45))
		create_tween().tween_property(rc, "scale", Vector2(1.12, 1.12), 0.2).from(Vector2(1.17, 1.17))
		create_tween().tween_property(kl, "scale", Vector2.ONE, 0.2).from(Vector2(1.25, 1.25))
		snd("draw", -6.0); ev("ribbon", {"kind": names[k]})
		await wait(1.25)
	rc.queue_free(); kl.queue_free()
	# 3. the exploded card: the layers of the card scene, pulled apart
	ev("show", {"k": "explode"})
	var xc := new_card(load("res://cards/flare.tres")); ui.add_child(xc); xc.scale = Vector2(0.8, 0.8); xc.position = Vector2(960, 470) - xc.pivot_offset
	await wait(0.6)
	var parts := [["ArtWindow", "TextureRect: the art, clipped"], ["Frame", "TextureRect: the frame"], ["Ribbon", "Panel + Label: the name"], ["Cost", "Label: the cost"], ["Text", "Label: the text"]]
	var tags: Array = []
	for i in parts.size():
		var n: Control = xc.get_node(parts[i][0]); var off := Vector2(300, -40) * (i - 2)
		create_tween().tween_property(n, "position", n.position + off, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var tg := lbl(parts[i][1].replace(": ", "\n"), 30, Color(1, 0.92, 0.7), 9, 330); tg.size.y = 100
		ui.add_child(tg); tg.position = Vector2(960 + (i - 2) * 300 * 0.8 - 165, 900 - (i - 2) * 32 * 0.8); tg.modulate.a = 0.0
		create_tween().tween_property(tg, "modulate:a", 1.0, 0.3).set_delay(0.2); tags.append(tg)
		snd("swish", -8.0); ev("explode", {"part": parts[i][0]})
		await wait(0.45)
	await wait(4.0)   # r3: the exploded card holds as long as the video's shot over it (the cut audit in build_tl.py)
	for i in parts.size():
		var n: Control = xc.get_node(parts[i][0]); var off := Vector2(300, -40) * (i - 2)
		create_tween().tween_property(n, "position", n.position - off, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for tg in tags: create_tween().tween_property(tg, "modulate:a", 0.0, 0.3)
	await wait(1.2)
	xc.queue_free()
	for tg in tags: tg.queue_free()
	# 4. the fan: grey rectangles onto an arc, tilted, then the real cards
	ev("show", {"k": "grey"})
	var greys: Array = []
	for i in 5:
		var g := Panel.new(); var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.55, 0.57, 0.58); sb.set_corner_radius_all(18); sb.set_border_width_all(6); sb.border_color = Color(0.3, 0.32, 0.33)
		g.add_theme_stylebox_override("panel", sb); g.size = Vector2(470, 690); g.pivot_offset = g.size / 2; g.scale = Vector2(0.62, 0.62)
		ui.add_child(at(g, Vector2(960, 620))); greys.append(g)
	await wait(0.5)
	for i in 5:   # position on the arc
		var tt := i - 2.0
		create_tween().tween_property(greys[i], "position", Vector2(960 + tt * 220, 640 + tt * tt * 14) - greys[i].size / 2, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	snd("swish", -6.0); ev("grey", {"step": "arc"})
	await wait(1.3)
	for i in 5:   # tilt by the offset from the middle
		create_tween().tween_property(greys[i], "rotation_degrees", (i - 2.0) * 5.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	snd("swish", -6.0); ev("grey", {"step": "tilt"})
	await wait(1.3)
	var real: Array = []
	for i in 5:   # each grey card turns into a real one
		var g: Panel = greys[i]; var c := new_card(load("res://cards/%s.tres" % keys[i])); ui.add_child(c)
		c.scale = Vector2(0.0, 0.62 * 1.0); c.rotation_degrees = g.rotation_degrees; c.position = g.position + g.size / 2 - c.pivot_offset
		var tw := create_tween(); tw.tween_property(g, "scale:x", 0.0, 0.12); tw.tween_callback(g.queue_free); tw.tween_property(c, "scale:x", 0.62 * 470.0 / 470.0, 0.14)
		real.append(c); snd("draw", -6.0)
		await wait(0.22)
	ev("grey", {"step": "real"})
	await wait(2.2)
	for c in real: c.queue_free()
	# 5. the deck sorted by type
	ev("show", {"k": "deck"})
	var rows := [["harpoon", "gulls", "undertow", "flare", "wave"], ["brace", "patch", "chart", "foghorn", "ward"], ["watch", "beacon"]]
	var all: Array = []
	for r in 3:
		ui.add_child(at(lbl(["Attacks", "Skills", "Powers"][r], 40, Card.TINT[r].lightened(0.5), 10, 260), Vector2(170, 205 + r * 330)))
		for i in rows[r].size():
			var c := new_card(load("res://cards/%s.tres" % rows[r][i])); ui.add_child(c); c.scale = Vector2(0.0, 0.0)
			c.position = Vector2(520 + i * 300, 205 + r * 330) - c.pivot_offset
			create_tween().tween_property(c, "scale", Vector2(0.4, 0.4), 0.3).set_delay(r * 0.35 + i * 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			all.append(c)
		get_tree().create_timer(r * 0.35).timeout.connect(func(): snd("swish", -6.0))
	await wait(1.2)
	await lift_wave(all, 4.8, 30.0)
	for c in all: c.queue_free()
	for n in ui.get_children(): n.queue_free()
	# 6. the hand-size check: the old gull card and the new one, big and at hand size
	ev("show", {"k": "handsize"})
	var old := CardData.new(); old.title = "Gull Swarm"; old.kind = CardData.Kind.ATTACK; old.cost = 1; old.damage = 7; old.text = "Deal 7 damage."; old.art = load("res://art/cards/gulls_old.png")
	var pair := [new_card(old), new_card(load("res://cards/gulls.tres"))]
	for i in 2:
		var c: Card = pair[i]; ui.add_child(c); c.scale = Vector2(0.95, 0.95); c.position = Vector2(560 + i * 800, 500) - c.pivot_offset
	await wait(1.6)
	for i in 2:
		create_tween().tween_property(pair[i], "scale", Vector2(HAND_S, HAND_S), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	ui.add_child(at(lbl("hand size", 44, Color(1, 0.92, 0.7), 10, 400), Vector2(960, 860)))
	ui.add_child(at(lbl("many small details", 38, Color.WHITE, 9, 520), Vector2(560, 300)))
	ui.add_child(at(lbl("one big subject", 38, Color.WHITE, 9, 520), Vector2(1360, 300)))
	ev("handsize", {"step": "small"})
	await wait(0.6)
	await lift_wave(pair, 3.4, 22.0)
	for n in ui.get_children(): n.queue_free()
	# 7. the end: the Keeper on the rock, the whole deck fanned
	ev("show", {"k": "end"})
	world.modulate = Color.WHITE
	keeper = make_fighter("keeper", 960, 430, 50, []); keeper.bar.get_parent().remove_child(keeper.bar)
	for n in [keeper.bar_lbl, keeper.blk, keeper.status_lbl]: n.visible = false
	for n in keeper.get_children():
		if n is ColorRect: n.visible = false
	keeper.halo.visible = false; keeper.pool.visible = false   # r3: no dark patch under him on the rock (REVIEW-R3 should 7)
	var endfan: Array = []
	for i in keys.size():
		var c := new_card(load("res://cards/%s.tres" % keys[i])); ui.add_child(c); var tt := i - (keys.size() - 1) / 2.0
		c.scale = Vector2(0.34, 0.34); c.rotation_degrees = tt * 3.0; c.position = Vector2(960 + tt * 140, 1200) - c.pivot_offset
		create_tween().tween_property(c, "position", Vector2(960 + tt * 140, 935 + tt * tt * 5) - c.pivot_offset, 0.5).set_delay(0.3 + abs(tt) * 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		endfan.append(c)
	await wait(1.2)
	await lift_wave(endfan, 7.8, 40.0)
	ev("end"); await wait(0.2)
	get_tree().quit()

func lift_wave(cs: Array, total: float, h: float) -> void:   # each card lifts in turn, so a held layout never stands still
	var step := 0.28; var n := int(total / step)
	for k in n:
		var c: Control = cs[k % cs.size()]; var y := c.position.y
		var tw := create_tween(); tw.tween_property(c, "position:y", y - h, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "position:y", y, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await wait(step if k % cs.size() != cs.size() - 1 else step + 0.4)

func export_cards(keys: Array) -> void:
	var vp := SubViewport.new(); vp.size = Vector2i(560, 768); vp.transparent_bg = true; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(vp)
	for k in keys + ["gulls_old"]:
		var d: CardData
		if k == "gulls_old":
			d = CardData.new(); d.title = "Gull Swarm"; d.kind = CardData.Kind.ATTACK; d.cost = 1; d.text = "Deal 7 damage."; d.art = load("res://art/cards/gulls_old.png")
		else: d = load("res://cards/%s.tres" % k)
		var c := new_card(d); vp.add_child(c)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(cards_dir.path_join(k + ".png"))
		c.queue_free()
	vp.queue_free(); ev("exported", {"n": keys.size() + 1})
