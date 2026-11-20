extends Node2D
# Lamplight (ours, Ludo video #43 Gate 2a). One 50 s level, the same Ludo art in six cumulative pass modes:
#   mode=flat     the three layers as one plane (all at camera speed), day colours, still sprites, no light
#   mode=depth    + three planes at 0.12, 0.4 and 1.0 of the camera's speed
#   mode=light    + night (CanvasModulate), normal-mapped art (CanvasTexture), a PointLight2D per lantern, lamps flare
#   mode=life     + the animations (walk, idle, tongue snap, flinch, mosquito hover), fireflies, flicker
#   mode=palette  + the lamp post recoloured onto the swamp's palette (`ludo toolbox image recolor`)
#   mode=juice    + the V F X Sprite pop, a white hit flash, a tiny screen shake (the finished game)
#   mode=nmap     Pip beside his normal map, a light circling him (chapter 3 insert)
# Pip walks right and lights each lamp post he passes; mosquitoes dive at him from the right and he snaps them; two
# come from behind, sting him (he flinches, a heart greys) and fly off. Something happens every 2 to 3 s.
# Every picture and sound is a Ludo generation (step0/, g2a/, PROVENANCE.md); this script is ours.
# Run: Godot --path lamplight --write-movie f.png --fixed-fps 30 --quit-after 1500 -- mode=juice log=/abs/x.jsonl

const W := 1280.0
const GROUND := 572.0
const FPS := 30.0
const LAYER_S := 0.35        # r2: 16-Bit Pixel layers at about Pip's pixel size (r1 drew them at 0.95, art pixels 4x his)
const TILE_W := 1344.0 * LAYER_S
const TILES := 4
const FAR_TOP := 380.0
const MID_TOP := 454.0
const WATER_TOP := 515.0
const WATER := Color(0.055, 0.06, 0.09)
const MOON_S := LAYER_S * 8.0 * 2.25   # r3: the pixel-art moon (one texture pixel per art pixel) at the layers' art-pixel size on screen
const OUT := 1.5          # the 1280 x 720 layout drawn at 1920 x 1080
const HERO_H := 160.0
const SPEED := 150.0
const TONGUE_FPS := 20.0  # the snap plays at 20 frames a second in the game
const MOSQ_S := 0.38
const LEVELS := {"flat": 0, "depth": 1, "light": 2, "life": 3, "palette": 4, "juice": 5}

var mode := "juice"
var lvl := 5
var Z := 1.5
var frame := 0
var cam := 0.0
var cfg := {}
var world: Node2D
var glows: CanvasLayer
var hud: CanvasLayer
var layers := []
var hero := {}
var hero_root: Node2D
var hero_light: PointLight2D
var hero_halo: Sprite2D
var hero_flash: Sprite2D
var moon: Sprite2D
var posts := []
var flies := []
var mosqs := []
var hearts := []
var players := {}
var segs := []
var lamp_ts := [1.93, 5.8, 12.6, 21.6, 28.8, 37.0, 47.5]
var shake_t := -9.0
var logf: FileAccess
var flash_mat: ShaderMaterial
var nm := {}
var pipk := 2.1   # g2b (founder: "dial the effect 10%" = the lamp posts on his face; r3 2.4: x1.47 under a post vs between, now x1.42) r3 (r2: 0.2, REVIEW-R2 must 1): how much of each lamp post's light reaches Pip (his own light layer, 4)
# r3 (founder 1:36.2 "are you sure the lamp posts are lighting up the frog? i barely see any effect"): the posts' light
# on Pip's layer gets its own colour (whiter, so his green brightens instead of washing to lime), a lower height (the
# normal map turns his shading as he passes) and a tighter reach (he is dark between posts, bright under one)
var plc := Color(1.0, 0.9, 0.8)
var plh := 50.0
var pls := 1.3
var hle := 0.9
var pipm := 0.62  # r3: Pip's own night tone (his sprites' self_modulate at night): the lights multiply it too, so it sets
                  # how bright he gets under a post without changing how much brighter than between posts
var near_y := 0.0
var norim := false   # measure only: the mosquitoes without their own glow and rim (the step-0 look)
var mlog := []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.substr(5)
		elif a.begins_with("zoom="):
			Z = float(a.substr(5))
		elif a.begins_with("pipk="):
			pipk = float(a.substr(5))
		elif a.begins_with("plc="):
			var v := a.substr(4).split(",")
			plc = Color(float(v[0]), float(v[1]), float(v[2]))
		elif a.begins_with("plh="):
			plh = float(a.substr(4))
		elif a.begins_with("pls="):
			pls = float(a.substr(4))
		elif a.begins_with("pipm="):
			pipm = float(a.substr(5))
		elif a.begins_with("hle="):
			hle = float(a.substr(4))
		elif a == "norim=1":
			norim = true
		elif a.begins_with("log="):
			logf = FileAccess.open(a.substr(4), FileAccess.WRITE)
	lvl = LEVELS.get(mode, 5)
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://art/config.json"))
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nrender_mode unshaded;\nuniform float amt = 1.0;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tCOLOR = vec4(mix(c.rgb, vec3(1.0), amt), c.a * amt);\n}\n"
	flash_mat = ShaderMaterial.new()
	flash_mat.shader = sh
	if mode == "nmap":
		build_nmap()
		return
	build_schedule()
	var night := lvl >= 2
	# sky
	var sky := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.10, 0.13, 0.30) if night else Color(0.50, 0.62, 0.74))
	g.set_color(1, Color(0.36, 0.33, 0.52) if night else Color(0.74, 0.80, 0.84))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	sky.texture = gt
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.size = Vector2(W, 720)
	sky.light_mask = 0
	add_child(sky)
	# r2: at night a Ludo night sky and moon sit behind everything, fixed to the screen (their own canvas layer, so the
	# night tint and the lanterns leave them as drawn)
	if night:
		var back := CanvasLayer.new()
		back.layer = -1
		add_child(back)
		var st := TextureRect.new()
		st.texture = tex("sky")
		st.stretch_mode = TextureRect.STRETCH_SCALE
		st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		st.size = Vector2(1920, 1080)
		back.add_child(st)
		moon = Sprite2D.new()
		moon.texture = tex("moon")
		moon.scale = Vector2(MOON_S, MOON_S)
		moon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		moon.position = Vector2(1400, 160)
		back.add_child(moon)
		sky.visible = false
	var depth := lvl >= 1
	# r2: the three 16-Bit Pixel layers drawn at LAYER_S (art pixels close to Pip's), each tiled across the view; the far
	# and mid layers placed by the top of their art, the boardwalk by its walking surface; dark water behind the mid layer
	# shows between the boardwalk's posts
	var L: Dictionary = cfg["layers"]
	var spec := [["far", 0.12 if depth else 1.0, FAR_TOP - float(L["far_top"]) * LAYER_S], ["mid", 0.4 if depth else 1.0, MID_TOP - float(L["mid_top"]) * LAYER_S],
		["near", 1.0, GROUND - float(L["near_walk"]) * LAYER_S]]
	for s in spec:
		if s[0] == "mid":
			var wtr := ColorRect.new()
			wtr.color = WATER
			wtr.position = Vector2(0, WATER_TOP)
			wtr.size = Vector2(W, 720.0 - WATER_TOP)
			add_child(wtr)
		var pair := []
		for i in TILES:
			var sp := Sprite2D.new()
			sp.texture = ctex(s[0])
			sp.centered = false
			sp.scale = Vector2(LAYER_S, LAYER_S)
			sp.position.y = s[2]
			if s[0] == "near":
				near_y = sp.position.y
			if s[0] == "far":
				sp.light_mask = 2  # the lanterns do not light the distant trees
			add_child(sp)
			pair.append(sp)
		layers.append([pair, s[1]])
	world = Node2D.new()
	add_child(world)
	if night:
		var cm := CanvasModulate.new()
		cm.color = Color(0.74, 0.76, 0.98)
		add_child(cm)
	glows = CanvasLayer.new()
	glows.layer = 1
	add_child(glows)
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	# lamp posts, each where Pip is at its lamp time
	for lt in lamp_ts:
		var px: float = pip_at(lt)[0] + 68.0
		var p := Sprite2D.new()
		p.texture = ctex("post_pal" if lvl >= 4 else "post", "post_n")
		p.centered = false
		p.scale = Vector2(0.276, 0.276)
		p.offset = Vector2(-535, -991)
		p.position = Vector2(px, GROUND + 4)
		world.add_child(p)
		var lp := Vector2(px + 34, GROUND + 4 - 179)
		var l: PointLight2D = null
		var pl: PointLight2D = null
		var halo: Sprite2D = null
		if night:
			l = make_light(lp, Color(1.0, 0.70, 0.36), 0.0, 2.0)
			pl = make_light(lp, plc, 0.0, pls)   # the same lamp on Pip's layer, at pipk of its energy (r3: own colour, height, reach)
			pl.height = plh
			pl.range_item_cull_mask = 4
			halo = make_halo(lp, Color(1.0, 0.72, 0.4), 0.55)
			halo.modulate.a = 0.0
		posts.append({"x": px, "t": lt, "light": l, "pl": pl, "halo": halo})
	# hero
	hero_root = Node2D.new()
	world.add_child(hero_root)
	if lvl >= 3:
		for k in ["walk", "idle", "tongue", "flinch"]:
			var d: Dictionary = cfg["hero_" + k]
			var sp := Sprite2D.new()
			sp.texture = ctex("hero_" + k)
			sp.hframes = int(d["cols"])
			sp.vframes = int(d["rows"])
			sp.centered = false
			sp.light_mask = 4   # REVIEW-R2 must 1: Pip on his own light layer (his lantern, the mosquitoes, the lamp posts at pipk)
			var sc: float = HERO_H / float(d["h"])
			sp.scale = Vector2(sc, sc)
			sp.offset = Vector2(-float(d["cx"]), -float(d["base"][0]))   # r3: the feet of frame 0 on the ground (_process sets each frame's)
			sp.visible = false
			hero_root.add_child(sp)
			hero[k] = sp
	else:
		var sp := Sprite2D.new()
		sp.texture = ctex("hero_still")
		sp.centered = false
		sp.light_mask = 4   # REVIEW-R2 must 1: Pip on his own light layer (his lantern, the mosquitoes, the lamp posts at pipk)
		var hs: Dictionary = cfg["hero_still"]
		var sc: float = HERO_H / float(hs["h"])
		sp.scale = Vector2(sc, sc)
		sp.offset = Vector2(-float(hs["cx"]), -float(hs["base"][0]))
		hero_root.add_child(sp)
		hero["still"] = sp
	if night:
		for k in hero:
			hero[k].self_modulate = Color(pipm, pipm, pipm)
		hero_light = make_light(Vector2.ZERO, Color(1.0, 0.74, 0.40), 1.0, 0.45)   # REVIEW-R2 must 1: a small warm pool at the hip, so his head and back stay green in every move
		hero_light.range_item_cull_mask = 1 | 4
		hero_light.get_parent().remove_child(hero_light)
		hero_root.add_child(hero_light)
		hero_halo = make_halo(Vector2.ZERO, Color(1.0, 0.78, 0.45), 0.35)
	hero_flash = Sprite2D.new()
	hero_flash.material = flash_mat
	hero_flash.centered = false
	hero_flash.visible = false
	glows.add_child(hero_flash)
	# mosquitoes, one per encounter
	for s in segs:
		if s["kind"] != "snap" and s["kind"] != "sting":
			continue
		var m := Sprite2D.new()
		m.texture = ctex("mosq") if lvl >= 3 else still_frame("mosq")
		if lvl >= 3:
			m.hframes = int(cfg["mosq"]["cols"])
			m.vframes = int(cfg["mosq"]["rows"])
		m.scale = Vector2(MOSQ_S, MOSQ_S)
		m.visible = false
		world.add_child(m)
		var rec := {"seg": s, "node": m, "light": null, "rim": null, "flash": null, "pop": null}
		if night and not norim:
			# the mosquito's own glow (its red eyes) and a cool rim behind it, so it stands out from the dark trees
			rec["light"] = make_light(Vector2.ZERO, Color(1.0, 0.45, 0.40), 1.1, 0.45)
			rec["light"].range_item_cull_mask = 1 | 4
			rec["rim"] = make_halo(Vector2.ZERO, Color(0.70, 0.85, 1.0), 0.0)
			rec["rim"].scale = Vector2(0.42, 0.42)
		if lvl >= 5:
			var f := Sprite2D.new()
			f.texture = tex("mosq")
			f.hframes = int(cfg["mosq"]["cols"])
			f.vframes = int(cfg["mosq"]["rows"])
			f.material = flash_mat
			f.scale = m.scale
			f.visible = false
			glows.add_child(f)
			rec["flash"] = f
			var p := Sprite2D.new()
			p.texture = tex("pop")
			p.hframes = int(cfg["pop"]["cols"])
			p.vframes = int(cfg["pop"]["rows"])
			p.scale = Vector2(0.42, 0.42)
			p.visible = false
			glows.add_child(p)
			rec["pop"] = p
		var buzz := AudioStreamPlayer.new()
		buzz.stream = wav("mosq")
		buzz.volume_db = -12.0
		add_child(buzz)
		rec["buzz"] = buzz
		mosqs.append(rec)
	if lvl >= 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = 43
		for i in 70:
			var f := make_halo(Vector2.ZERO, Color(0.85, 1.0, 0.45), 0.0)
			f.scale = Vector2(0.05, 0.05)
			flies.append({"node": f, "x": rng.randf_range(0, 8200), "y": rng.randf_range(300, 540),
				"ph": rng.randf_range(0, TAU), "sp": rng.randf_range(0.6, 1.4)})
	# hearts HUD (a Ludo generation, made with Pip as the style picture)
	for i in 3:
		var h := Sprite2D.new()
		h.texture = tex("heart")
		h.scale = Vector2(0.105, 0.105)
		h.position = Vector2(70 + i * 76, 66)
		hud.add_child(h)
		hearts.append(h)
	for k in ["hero_walk", "hero_tongue", "hero_flinch", "pop"]:
		var p := AudioStreamPlayer.new()
		p.stream = wav(k)
		p.volume_db = -5.0 if k != "pop" else -3.0
		add_child(p)
		players[k] = p


# ---- the level: Pip's segments, each with its start time and x
func build_schedule() -> void:
	var plan := [["walk", 1.95], ["snap", 1.5], ["walk", 2.3], ["snap", 1.6], ["walk", 1.4], ["sting", 1.4], ["walk", 2.5],
		["snap", 1.6], ["walk", 1.2], ["snap", 1.6], ["snap", 3.2], ["walk", 2.4], ["idle", 2.4], ["snap", 3.4], ["walk", 2.6],
		["sting", 1.4], ["walk", 2.2], ["snap", 1.6], ["walk", 2.6], ["snap", 1.6], ["walk", 1.8], ["idle", 1.6], ["snap", 2.6],
		["walk", 5.0]]
	var t := 0.0
	var x := 400.0
	var tn: float = float(cfg["hero_tongue"]["n"]) / TONGUE_FPS
	var fl: float = float(cfg["hero_flinch"]["n"]) / float(cfg["hero_flinch"]["fps"])
	for p in plan:
		var k: String = p[0]
		var d: float = p[1]
		var lead := 0.0
		if k == "snap":
			lead = d
			d = tn
		elif k == "sting":
			lead = d
			d = fl
		segs.append({"kind": k, "t0": t, "t1": t + d, "x0": x, "lead": lead})
		if k == "walk":
			x += SPEED * d
		t += d


func pip_at(t: float) -> Array:
	for s in segs:
		if t < s["t1"] or s == segs[-1]:
			var a: float = t - s["t0"]
			var x: float = s["x0"] + (SPEED * a if s["kind"] == "walk" else 0.0)
			return [x, s["kind"], a, s]
	return [0.0, "walk", 0.0, segs[-1]]


# ---- helpers
func tex(name: String) -> Texture2D:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://art/%s.png" % name)))


func still_frame(name: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/%s.png" % name))
	return ImageTexture.create_from_image(img.get_region(Rect2i(0, 0, int(cfg[name]["fw"]), int(cfg[name]["fh"]))))


func ctex(name: String, nmap := "") -> Texture2D:
	if lvl < 2 and mode != "nmap":
		return tex(name)
	var c := CanvasTexture.new()
	c.diffuse_texture = tex(name)
	var n := nmap if nmap != "" else name + "_n"
	if FileAccess.file_exists("res://art/%s.png" % n):
		c.normal_texture = tex(n)
	return c


func wav(k: String) -> AudioStreamWAV:
	return AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://sfx/%s.wav" % k))


func soft_tex(size: int) -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.3, Color(1, 1, 1, 0.6))
	var t2 := GradientTexture2D.new()
	t2.gradient = g
	t2.fill = GradientTexture2D.FILL_RADIAL
	t2.fill_from = Vector2(0.5, 0.5)
	t2.fill_to = Vector2(1.0, 0.5)
	t2.width = size
	t2.height = size
	return t2


# r2: the lantern hangs at Pip's hip; its place in the current frame (tools/lamp_track.py), in Pip's local units
func lamp_at(state: String, n: int) -> Vector2:
	var d: Dictionary = cfg["hero_" + state] if lvl >= 3 else cfg["hero_still"]
	var p: Array = d["lamp"][min(n, d["lamp"].size() - 1)]
	var sc: float = HERO_H / float(d["h"])
	return Vector2((float(p[0]) - float(d["cx"])) * sc, (float(p[1]) - float(d["base"][min(n, d["base"].size() - 1)])) * sc)


func make_light(pos: Vector2, col: Color, energy: float, sc: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = soft_tex(512)
	l.texture_scale = sc
	l.color = col
	l.energy = energy
	l.height = 60.0
	l.range_item_cull_mask = 1
	l.position = pos
	world.add_child(l)
	return l


func make_halo(pos: Vector2, col: Color, alpha: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = soft_tex(256)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.modulate = Color(col.r, col.g, col.b, alpha)
	s.position = pos
	s.scale = Vector2(0.6, 0.6)
	glows.add_child(s)
	return s


func flicker(t: float, seed: float) -> float:
	if lvl < 3:
		return 1.0
	return 1.0 + 0.06 * sin(t * 11.0 + seed) + 0.04 * sin(t * 23.0 + seed * 2.0)


func ev(t: float, name: String, extra := {}) -> void:
	if logf:
		var d := {"t": snappedf(t, 0.001), "ev": name}
		d.merge(extra)
		logf.store_line(JSON.stringify(d))


func bez(a: Vector2, b: Vector2, c: Vector2, d: Vector2, k: float) -> Vector2:
	var u := 1.0 - k
	return a * u * u * u + b * 3.0 * u * u * k + c * 3.0 * u * k * k + d * k * k * k


func smooth(k: float) -> float:
	k = clamp(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


# ---- chapter 3 insert: Pip beside his normal map, a light circling him
func build_nmap() -> void:
	world = Node2D.new()
	add_child(world)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.10, 0.20)
	bg.size = Vector2(W, 720)
	bg.light_mask = 0
	world.add_child(bg)
	var cm := CanvasModulate.new()
	cm.color = Color(0.42, 0.44, 0.62)
	add_child(cm)
	glows = CanvasLayer.new()
	glows.layer = 1
	add_child(glows)
	var d: Dictionary = cfg["hero_idle"]
	var sc: float = 470.0 / float(d["h"])
	var a := Sprite2D.new()
	a.texture = ctex("hero_idle")
	a.hframes = int(d["cols"])
	a.vframes = int(d["rows"])
	a.centered = false
	a.scale = Vector2(sc, sc)
	a.offset = Vector2(-float(d["cx"]), -float(d["ground"]))
	a.position = Vector2(390, 620)
	world.add_child(a)
	var b := Sprite2D.new()
	b.texture = tex("hero_idle_n")
	b.hframes = a.hframes
	b.vframes = a.vframes
	b.centered = false
	b.scale = a.scale
	b.offset = a.offset
	b.position = Vector2(900, 620)
	glows.add_child(b)
	var l := make_light(Vector2.ZERO, Color(1.0, 0.76, 0.42), 2.2, 1.1)
	var orb := make_halo(Vector2.ZERO, Color(1.0, 0.80, 0.50), 0.9)
	orb.scale = Vector2(0.16, 0.16)
	var orb2 := make_halo(Vector2.ZERO, Color(1.0, 0.80, 0.50), 0.9)
	orb2.scale = Vector2(0.16, 0.16)
	nm = {"a": a, "b": b, "l": l, "orb": orb, "orb2": orb2, "fps": float(d["fps"])}
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(OUT, OUT), 0.0, Vector2.ZERO)
	glows.transform = Transform2D(0.0, Vector2(OUT, OUT), 0.0, Vector2.ZERO)


func step_nmap(t: float) -> void:
	var f := int(floor(t * float(nm["fps"]))) % 36
	nm["a"].frame = f
	nm["b"].frame = f
	var ang := t * 1.6
	var c := Vector2(390, 400)
	var p := c + Vector2(cos(ang) * 230.0, sin(ang) * 150.0)
	nm["l"].position = p
	nm["l"].height = 40.0 + 30.0 * sin(ang)
	nm["orb"].position = p
	nm["orb2"].position = p + Vector2(510, 0)


# ---- per frame
func _process(_dt: float) -> void:
	var t := frame / FPS
	frame += 1
	if mode == "nmap":
		step_nmap(t)
		return
	var P := pip_at(t)
	var hx: float = P[0]
	var kind: String = P[1]
	var at: float = P[2]
	var seg: Dictionary = P[3]
	var state := kind if kind != "snap" and kind != "sting" else ("tongue" if kind == "snap" else "flinch")
	hero_root.position = Vector2(hx, GROUND)
	if frame == 1 or at < 1.0 / FPS:
		ev(t, "seg_" + kind, {"x": hx})
		if kind == "walk":
			players["hero_walk"].play()
		elif kind == "snap":
			players["hero_tongue"].play()
		elif kind == "sting":
			players["hero_flinch"].play()
	if kind == "walk" and not players["hero_walk"].playing:
		players["hero_walk"].play()
	if kind != "walk" and players["hero_walk"].playing:
		players["hero_walk"].stop()
	var cur: Sprite2D = null
	if lvl >= 3:
		for k in hero:
			hero[k].visible = (k == state)
		cur = hero[state]
		var d: Dictionary = cfg["hero_" + state]
		var n := 0
		if state == "tongue":
			n = min(int(floor(at * TONGUE_FPS)), int(d["n"]) - 1)
		elif state == "flinch":
			n = min(int(floor(at * float(d["fps"]))), int(d["n"]) - 1)
		else:
			n = int(floor(at * float(d["fps"]))) % int(d["n"])
		cur.frame = n
		cur.offset.y = -float(d["base"][n])   # r3: every frame stands on its own lowest row (the feet), not frame 0's
	else:
		cur = hero["still"]
	if hero_light:
		hero_light.energy = hle * flicker(t, 0.0)   # r2: the lantern at the hip sits inside his outline, so it lights more of him than on his head
		hero_light.position = lamp_at(state, cur.frame if lvl >= 3 else 0)
	# camera: Pip about a third in from the left, his feet low in the frame
	var target := hx - 420.0
	cam = target if frame == 1 else cam + (target - cam) * 0.08
	world.position.x = -cam
	var s := OUT * Z
	var PX := 420.0 + 288.0 / s
	var PY := GROUND - 340.0 / s
	var sh := Vector2.ZERO
	if lvl >= 5 and t - shake_t < 0.25:
		var k := 1.0 - (t - shake_t) / 0.25
		sh = Vector2(sin(t * 97.0), cos(t * 83.0)) * 7.0 * k
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, Vector2(960.0 - PX * s, 540.0 - PY * s) + sh)
	get_viewport().canvas_transform = xf
	glows.transform = xf * Transform2D(0.0, Vector2(-cam, 0.0))
	for L in layers:
		var f: float = L[1]
		var x := -fmod(cam * f, TILE_W)
		for i in L[0].size():
			L[0][i].position.x = x + TILE_W * i
	if hero_halo:
		hero_halo.position = hero_root.position + hero_light.position
		hero_halo.modulate.a = 0.30 * flicker(t, 1.0)
	# hero flash (juice): Pip white for two frames when he is stung
	hero_flash.visible = false
	# mosquitoes
	var tn: float = float(cfg["hero_tongue"]["hit"]) / TONGUE_FPS
	var ct: Dictionary = cfg["hero_tongue"]
	var sct: float = HERO_H / float(ct["h"])
	for r in mosqs:
		var sg: Dictionary = r["seg"]
		var m: Sprite2D = r["node"]
		var t0: float = sg["t0"]
		var hs: float = sg["x0"]
		var spawn: float = t0 - float(sg["lead"])
		var p := Vector2.ZERO
		var vis := false
		var flip := false
		var gone := false
		var a2 := 1.0
		if sg["kind"] == "snap":
			var th := t0 + tn
			var tip := Vector2(hs + (float(ct["tip_x"]) - float(ct["cx"])) * sct + 16.0, GROUND - (float(ct["ground"]) - float(ct["tip_y"])) * sct)
			var hover := tip + Vector2(80, -26)
			var p0 := Vector2(hs + 680.0, GROUND - 340.0)
			var arrive: float = spawn + min(1.6, float(sg["lead"]) + 0.2)
			if t >= spawn and t < th + 0.14:
				vis = true
				if t < arrive:
					var k := smooth((t - spawn) / (arrive - spawn))
					p = bez(p0, Vector2(hs + 460, GROUND - 60), Vector2(hs + 300, GROUND - 260), hover, k)
				elif t < t0 + 0.4:
					p = hover + Vector2(10.0 * sin(t * 3.1), 8.0 * sin(t * 2.3))
				else:
					p = hover.lerp(tip, smooth((t - t0 - 0.4) / max(0.05, th - t0 - 0.4)))
				p.y += 5.0 * sin(t * 9.0)
				if t >= th:
					a2 = 1.0 - clamp((t - th) / 0.12, 0.0, 1.0)
					if lvl >= 5:
						a2 = 0.0 if t >= th + 2.0 / FPS else 1.0
			if t >= th and t - 1.0 / FPS < th:
				ev(t, "hit", {"x": tip.x, "y": tip.y})
				if lvl >= 5:
					shake_t = t
					players["pop"].play()
			r["hitp"] = tip
			r["th"] = th
		else:
			var head := Vector2(hs + 6.0, GROUND - HERO_H * 0.92)
			var p0 := Vector2(hs - 600.0, GROUND - 380.0)
			if t >= spawn and t < t0 + 1.6:
				vis = true
				flip = true
				if t < t0:
					p = bez(p0, Vector2(hs - 360, GROUND - 120), Vector2(hs - 160, GROUND - 330), head, smooth((t - spawn) / (t0 - spawn)))
				else:
					var k := (t - t0) / 1.6
					p = head.lerp(Vector2(hs + 640, GROUND - 560), k * k)
				p.y += 5.0 * sin(t * 9.0)
			if t >= t0 and t - 1.0 / FPS < t0:
				ev(t, "sting", {"x": head.x, "y": head.y})
				var lost := 0
				for h in hearts:
					if h.modulate.r > 0.9:
						h.modulate = Color(0.32, 0.32, 0.36, 0.9)
						lost += 1
						break
				if lvl >= 5:
					shake_t = t
			if lvl >= 5 and t >= t0 and t < t0 + 3.0 / FPS and cur:
				hero_flash.visible = true
				hero_flash.texture = tex_of(cur)
				hero_flash.hframes = cur.hframes
				hero_flash.vframes = cur.vframes
				hero_flash.frame = cur.frame
				hero_flash.offset = cur.offset
				hero_flash.scale = cur.scale
				hero_flash.position = hero_root.position
		m.visible = vis and a2 > 0.0
		m.position = p
		if m.visible:
			mlog.append([snappedf((p.x - cam - PX) * s + 960.0, 0.1), snappedf((p.y - PY) * s + 540.0, 0.1)])
		m.flip_h = flip
		m.scale = Vector2(MOSQ_S, MOSQ_S) * (a2 if lvl < 5 else 1.0)
		if lvl >= 3:
			m.frame = int(floor(t * float(cfg["mosq"]["fps"]))) % int(cfg["mosq"]["n"])
		var buzz: AudioStreamPlayer = r["buzz"]
		if vis and not buzz.playing and t < spawn + 0.05:
			buzz.play()
		if not vis and buzz.playing:
			buzz.stop()
		if r["light"]:
			r["light"].position = p
			r["light"].energy = 1.1 if m.visible else 0.0
			r["rim"].position = p + Vector2(0, -4)
			r["rim"].modulate.a = 0.20 if m.visible else 0.0
		if r["flash"]:
			var th2: float = r.get("th", -9.0)
			var on: bool = sg["kind"] == "snap" and t >= th2 and t < th2 + 2.0 / FPS
			r["flash"].visible = on
			r["flash"].position = p
			r["flash"].frame = m.frame
			r["flash"].flip_h = flip
			var pop: Sprite2D = r["pop"]
			var pk := int(floor((t - th2) * float(cfg["pop"]["fps"])))
			pop.visible = sg["kind"] == "snap" and t >= th2 and pk < int(cfg["pop"]["n"])
			if pop.visible:
				pop.frame = pk
				pop.position = r["hitp"] + Vector2(10, -6)
	# lamp posts flare as Pip reaches them, then settle (flicker with life)
	for p in posts:
		var lt: float = p["t"]
		if t >= lt and t - 1.0 / FPS < lt:
			ev(t, "lamp", {"x": p["x"]})
		if p["light"] != null:
			var e := 0.0
			if t >= lt:
				var a: float = t - lt
				e = 2.6 * clamp(a / 0.12, 0.0, 1.0) if a < 0.12 else lerp(2.6, 1.4, clamp((a - 0.12) / 0.6, 0.0, 1.0))
				e *= flicker(t, p["x"])
			p["light"].energy = e
			p["pl"].energy = e * pipk
			p["halo"].modulate.a = 0.45 * e / 1.4
	for f in flies:
		var node: Sprite2D = f["node"]
		node.position = Vector2(f["x"] + 30.0 * sin(t * 0.7 * f["sp"] + f["ph"]), f["y"] + 18.0 * sin(t * 1.3 * f["sp"] + f["ph"] * 2.0))
		node.modulate.a = 0.35 + 0.55 * max(0.0, sin(t * 2.2 * f["sp"] + f["ph"]))
	if logf:
		var sx := (hx - cam - PX) * s + 960.0
		logf.store_line(JSON.stringify({"t": snappedf(t, 0.001), "pip": [snappedf(sx, 0.1), snappedf((GROUND - PY) * s + 540.0, 0.1)], "state": state, "mosq": mlog,
			"f": cur.frame, "oy": cur.offset.y, "sc": snappedf(cur.scale.y, 0.0001), "cs": s, "py": PY, "near": near_y}))
	mlog = []


func tex_of(sp: Sprite2D) -> Texture2D:
	var tx := sp.texture
	if tx is CanvasTexture:
		return (tx as CanvasTexture).diffuse_texture
	return tx
