extends Node2D
## The harbour level: background, two piers to stand on, the knight, the on-screen labels and the reference clip
## in a corner. Everything is built here at run time; the scene file only holds this script.
## Files: art/level_harbour.png (the level), art/knight_idle.png and art/knight_jump.png (via knight.gd),
## ref/reference_jump.png (the clip in the corner); their grids and positions are in art/config.json.

const JumpTiming = preload("res://jump_timing.gd")
const Knight = preload("res://knight.gd")
const VIEW := Vector2(768, 1344)

var cfg: Dictionary
var retime: Dictionary
var travel: Dictionary
var knight: Knight
var camera := Camera2D.new()
var ref_clip := AnimatedSprite2D.new()
var timing_label := Label.new()
var travel_label := Label.new()
var stat_label := Label.new()
var timing_button := Button.new()
var splash := Splash.new()


func _ready() -> void:
	_add_inputs()
	cfg = JumpTiming.load_json("res://art/config.json")
	retime = JumpTiming.load_json("res://data/retime.json")
	travel = JumpTiming.load_json("res://data/travel.json")
	var lv: Dictionary = cfg["level"]

	var bg := Sprite2D.new()
	bg.texture = JumpTiming.load_texture(lv["file"])
	bg.centered = false
	add_child(bg)

	for p in lv["piers"]:  # one static box per pier, its top where the feet stand
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(float(p[1]) - float(p[0]), 64)
		shape.shape = box
		body.position = Vector2((float(p[0]) + float(p[1])) / 2.0, float(lv["pier_top"]) + 32)
		body.add_child(shape)
		add_child(body)

	knight = Knight.new()
	knight.position = Vector2(float(lv["start_x"]), float(lv["pier_top"]))
	add_child(knight)
	knight.setup(cfg, retime, travel)
	knight.landed.connect(_on_landed)
	knight.splashed.connect(_on_splashed)
	add_child(splash)

	camera.position = VIEW / 2  # the level is exactly one screen
	add_child(camera)
	camera.make_current()
	_build_ui()
	_refresh_labels()

	for arg in OS.get_cmdline_user_args():
		if arg == "timing=sheet":
			knight.reference_timing = false
			_refresh_labels()
		elif arg == "test=1":
			add_child(load("res://tests/smoke_test.gd").new())


func _add_inputs() -> void:
	var keys := {
		"jump": [KEY_SPACE], "timing": [KEY_T], "travel": [KEY_M], "reset": [KEY_R],
		"move_left": [KEY_LEFT], "move_right": [KEY_RIGHT],
	}
	var pads := {"jump": JOY_BUTTON_A, "timing": JOY_BUTTON_Y, "reset": JOY_BUTTON_BACK,
		"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
		if pads.has(action):
			var j := InputEventJoypadButton.new()
			j.button_index = pads[action]
			InputMap.action_add_event(action, j)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump()
	elif event.is_action_pressed("timing"):
		toggle_timing()
	elif event.is_action_pressed("travel"):
		knight.use_travel = not knight.use_travel
		_refresh_labels()
	elif event.is_action_pressed("reset"):
		reset()


func jump() -> void:
	if knight.state != Knight.State.IDLE:
		return
	knight.jump()
	# The reference clip starts with the jump: clip second 0 is sheet frame 0. It always plays at its real speed,
	# so with sheet timing you can watch the knight fall behind the person.
	ref_clip.frame = 0
	ref_clip.play("clip")


func toggle_timing() -> void:
	knight.reference_timing = not knight.reference_timing
	_refresh_labels()


func reset() -> void:
	knight.position.y = float(cfg["level"]["pier_top"])
	knight.reset_to(float(cfg["level"]["start_x"]))
	ref_clip.stop()
	ref_clip.frame = 0
	stat_label.text = ""


func _on_landed(air: float) -> void:
	var e := knight.air_seconds_expected()
	stat_label.text = "Air frames %d to %d took %.2f s.\nSheet as returned: %.2f s. Reference: %.2f s." % [
		knight.takeoff_frame, knight.landing_frame - 1, air, e["sheet"], e["reference"]]
	var t := create_tween()  # a 4 px bump on the landing
	t.tween_property(camera, "offset:y", 4.0, 0.05)
	t.tween_property(camera, "offset:y", 0.0, 0.1)


func _on_splashed(x: float) -> void:
	stat_label.text = "Splash! He landed short of the pier.\nR to reset (or wait)."
	splash.start(Vector2(x, float(cfg["level"]["water_y"]) - 20))
	get_tree().create_timer(1.6).timeout.connect(func():
		if knight.state == Knight.State.GONE:
			reset())


func _refresh_labels() -> void:
	var jc: Dictionary = cfg["knight_jump"]
	if knight.reference_timing:
		timing_label.text = "TIMING: REFERENCE\nEach frame lasts as long as the real jump's pose"
		timing_button.text = "T: switch to sheet timing"
	else:
		timing_label.text = "TIMING: SHEET\nAs returned: %d frames at %.1f fps" % [jc["n"], jc["fps"]]
		timing_button.text = "T: switch to reference timing"
	if knight.use_travel:
		travel_label.text = "Travel: from the reference (%.2f body heights)  M: off" % float(travel["travel_heights"])
	else:
		travel_label.text = "Travel: off, the sheet jumps in place  M: on"


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var rc: Dictionary = cfg["reference_clip"]

	_style(timing_label, 30, Color(1, 0.92, 0.6))
	timing_label.position = Vector2(24, 24)
	ui.add_child(timing_label)

	_style(travel_label, 20, Color(0.85, 0.9, 1))
	travel_label.position = Vector2(24, 112)
	ui.add_child(travel_label)

	timing_button.position = Vector2(24, 150)
	timing_button.add_theme_font_size_override("font_size", 22)
	timing_button.focus_mode = Control.FOCUS_NONE
	timing_button.pressed.connect(toggle_timing)
	ui.add_child(timing_button)

	# The reference clip, small, in the top-right corner (CC BY 3.0, credit below it and in the README).
	var csf := SpriteFrames.new()
	csf.remove_animation("default")
	var ctex := JumpTiming.load_texture(rc["file"])
	JumpTiming.add_even(csf, "clip", JumpTiming.sheet_frames(ctex, rc["cols"], rc["rows"], rc["n"]), rc["fps"], false)
	ref_clip.sprite_frames = csf
	ref_clip.animation = "clip"
	ref_clip.centered = false
	ref_clip.scale = Vector2(1.5, 1.5)
	ref_clip.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var clip_w := ctex.get_width() / int(rc["cols"]) * 1.5
	ref_clip.position = Vector2(VIEW.x - clip_w - 24, 236)
	ui.add_child(ref_clip)
	var credit := Label.new()
	_style(credit, 13, Color(0.8, 0.85, 0.95))
	credit.text = "Reference clip, CC BY 3.0:\n\"Forward Jump Animation\nReference\" by Endless\nReference (cropped)"
	credit.position = ref_clip.position + Vector2(0, ctex.get_height() / int(rc["rows"]) * 1.5 + 6)
	ui.add_child(credit)

	_style(stat_label, 20, Color(1, 1, 1))
	stat_label.position = Vector2(24, 1060)
	ui.add_child(stat_label)

	var help := Label.new()
	_style(help, 20, Color(0.85, 0.9, 1))
	help.text = "Space / A: jump    T: timing    M: travel\nLeft / Right: shuffle    R: reset"
	help.position = Vector2(24, 1250)
	ui.add_child(help)


func _style(l: Label, size: int, color: Color) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.08))
	l.add_theme_constant_override("outline_size", 6)


## Three rings spreading on the water where he fell in.
class Splash extends Node2D:
	var t := -1.0

	func start(at: Vector2) -> void:
		position = at
		t = 0.0

	func _process(delta: float) -> void:
		if t < 0.0:
			return
		t += delta
		if t > 1.2:
			t = -1.0
		queue_redraw()

	func _draw() -> void:
		if t < 0.0:
			return
		for i in 3:
			var k := t - i * 0.15
			if k > 0.0:
				var a := clampf(1.0 - k / 1.0, 0.0, 1.0)
				var r := 16.0 + k * 120.0
				var pts := PackedVector2Array()
				for j in 33:  # a flat ellipse: a ring lying on the water
					var ang := TAU * j / 32.0
					pts.append(Vector2(cos(ang) * r, sin(ang) * r * 0.25))
				draw_polyline(pts, Color(0.75, 0.88, 1, a), 4)
