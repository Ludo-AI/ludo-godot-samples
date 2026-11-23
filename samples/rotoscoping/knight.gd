extends CharacterBody2D
## The knight: idles, jumps with the rotoscoped sheet, and moves sideways during the air frames with the travel
## measured on the reference clip (root motion). The body's origin is between his feet.
## Feet lock: the sheet jumps in place, and inside its cells the planted boot drifts (left by up to 52 px while he
## crouches and pushes off, 44 px while he lands). data/knight_feet.json gives the boot's x in every ground frame; the
## sprite is offset so the planted boot stays on one spot, and in the air the body's centre moves smoothly from the
## take-off spot to the landing spot. Only the drawing position changes, never the frames.

const JumpTiming = preload("res://jump_timing.gd")

signal took_off
signal landed(air_seconds: float)
signal fell
signal splashed(x: float)

enum State { IDLE, JUMP, FALL, GONE }

const GRAVITY := 2600.0
const SHUFFLE_SPEED := 90.0

var reference_timing := true  ## true: per-frame durations from the clip; false: the sheet's own even fps
var use_travel := true  ## false: jump in place, as the sheet does
var state := State.IDLE

var grid := 4.0  ## the art's pixel block: positions snap to it so the knight stays on the level's grid
var travel_px := 0.0  ## how far the feet move from take-off to landing
var air_curve: Array = []  ## 0 at take-off, 1 at landing (data/travel.json)
var feet: Array = []  ## per sheet frame: "boot" (planted boot x in the cell, ground frames) and "centroid_x" (data/knight_feet.json)
var pivot_x := 0.0
var boot_trace: Array = []  ## [frame, drawn x of the planted boot] on every ground frame of the last jump (smoke test)
var body_trace: Array = []  ## [frame, drawn x of the body's centre] on every air frame of the last jump (smoke test)
var takeoff_frame := 15
var landing_frame := 34
var water_y := 900.0
var min_x := 40.0
var max_x := 728.0

var _fine_x := 0.0  ## unsnapped x, so slow moves still add up
var _x0 := 0.0
var _air_start_us := 0
var _landing_checked := false
var _last_body := -INF
var idle_sprite := AnimatedSprite2D.new()
var jump_sprite := AnimatedSprite2D.new()


func setup(cfg: Dictionary, retime: Dictionary, travel: Dictionary) -> void:
	var jc: Dictionary = cfg["knight_jump"]
	var ic: Dictionary = cfg["knight_idle"]
	grid = float(cfg["level"]["grid"])
	water_y = float(cfg["level"]["water_y"])
	takeoff_frame = int(jc["takeoff_frame"])
	landing_frame = int(jc["landing_frame"])
	# The person travelled travel_heights of his own height; the knight travels the same share of his.
	travel_px = float(travel["travel_heights"]) * float(jc["knight_height"])
	air_curve = travel["air_curve"]
	feet = JumpTiming.load_json("res://data/knight_feet.json")["frames"]
	pivot_x = float(jc["pivot"][0])

	# Idle: one even-timed loop.
	var isf := SpriteFrames.new()
	isf.remove_animation("default")
	var itex := JumpTiming.load_texture(ic["file"])
	JumpTiming.add_even(isf, "idle", JumpTiming.sheet_frames(itex, ic["cols"], ic["rows"], ic["n"]), ic["fps"], true)
	_place(idle_sprite, isf, ic)

	# Jump: the same 49 frames twice, once per timing.
	var jsf := SpriteFrames.new()
	jsf.remove_animation("default")
	var frames := JumpTiming.sheet_frames(JumpTiming.load_texture(jc["file"]), jc["cols"], jc["rows"], jc["n"])
	JumpTiming.add_even(jsf, "sheet", frames, jc["fps"], false)
	JumpTiming.add_timed(jsf, "reference", frames,
		JumpTiming.frame_seconds(retime["keys"], frames.size(), float(retime["last_frame_seconds"])))
	_place(jump_sprite, jsf, jc)
	jump_sprite.animation_finished.connect(_on_jump_finished)

	# A small box at the feet: enough to stand on a pier, narrow enough to fall into the gap.
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(48, 96)
	shape.shape = box
	shape.position = Vector2(0, -48)
	add_child(shape)
	reset_to(position.x)


func _place(sprite: AnimatedSprite2D, sf: SpriteFrames, c: Dictionary) -> void:
	sprite.sprite_frames = sf
	sprite.centered = false
	sprite.scale = Vector2.ONE * float(c["scale"])
	sprite.offset = -Vector2(c["pivot"][0], c["pivot"][1])  # feet on the origin
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


func reset_to(x: float) -> void:
	_fine_x = x
	position.x = snappedf(x, grid)
	velocity = Vector2.ZERO
	state = State.IDLE
	show()
	jump_sprite.stop()
	jump_sprite.hide()
	idle_sprite.show()
	idle_sprite.play("idle")


func jump() -> void:
	if state != State.IDLE:
		return
	state = State.JUMP
	_x0 = position.x
	_air_start_us = 0
	_landing_checked = false
	idle_sprite.stop()
	idle_sprite.hide()
	jump_sprite.offset.x = -pivot_x
	boot_trace.clear()
	body_trace.clear()
	_last_body = -INF
	jump_sprite.show()
	jump_sprite.play("reference" if reference_timing else "sheet")


## How far (cell pixels) frame `i` is drawn from where the sheet puts it, so the feet do not slide. Ground frames before
## take-off and after landing: the planted boot sits where frame 0 has it. Air frames: the body's centre goes from its
## take-off place to its landing place along the same curve as the travel (`c`, 0 to 1), snapped to the art's grid.
func feet_shift(i: int, c: float) -> float:
	var b0 := float(feet[0]["boot"])
	if feet[i].get("boot") != null:
		return b0 - float(feet[i]["boot"])
	var s0 := b0 - float(feet[takeoff_frame]["boot"])
	var s1 := b0 - float(feet[landing_frame]["boot"])
	var c0 := float(feet[takeoff_frame]["centroid_x"])
	var c1 := float(feet[landing_frame]["centroid_x"])
	return s0 + c0 - float(feet[i]["centroid_x"]) + c * (s1 + c1 - s0 - c0)


func air_seconds_expected() -> Dictionary:
	var sf := jump_sprite.sprite_frames
	var ref := 0.0
	for f in range(takeoff_frame, landing_frame):
		ref += sf.get_frame_duration("reference", f)
	return {"sheet": (landing_frame - takeoff_frame) / sf.get_animation_speed("sheet"), "reference": ref}


func _process(_delta: float) -> void:
	if state != State.JUMP:
		return
	# Where are we in the air? 0 at the take-off frame, 1 at the landing frame, read from the animation itself,
	# so the travel follows whichever timing is playing.
	var f := jump_sprite.frame + jump_sprite.frame_progress
	var u := (f - takeoff_frame) / float(landing_frame - takeoff_frame)
	if u > 0.0 and _air_start_us == 0:
		_air_start_us = Time.get_ticks_usec()
		took_off.emit()
	# The travel runs over the air frames only (take-off frame + 1 to the landing frame): the take-off frame still has
	# a foot on the ground, so moving him during it would slide that foot.
	var c := JumpTiming.sample_curve(air_curve, (f - takeoff_frame - 1) / float(landing_frame - takeoff_frame - 1))
	if use_travel:
		_fine_x = _x0 + travel_px * c
		position.x = snappedf(_fine_x, grid)
	var i := jump_sprite.frame
	var fb = feet[i].get("boot")
	if fb != null:   # ground frame: an exact whole-block shift
		jump_sprite.offset.x = -pivot_x + feet_shift(i, c)
		boot_trace.append([i, position.x + jump_sprite.offset.x + float(fb)])
		_last_body = -INF
	else:   # air frame: snap the drawn place once (not origin and shift apart), and never let the body step back
		var left := snappedf((_fine_x if use_travel else _x0) + feet_shift(i, c), grid)
		var cx := float(feet[i]["centroid_x"])
		while left + cx < _last_body:
			left += grid
		_last_body = left + cx
		jump_sprite.offset.x = -pivot_x + left - position.x
		body_trace.append([i, _last_body])
	if jump_sprite.frame >= landing_frame and not _landing_checked:
		_landing_checked = true
		var air := (Time.get_ticks_usec() - _air_start_us) / 1e6
		if test_move(global_transform, Vector2(0, 2)):
			landed.emit(air)
		else:
			# Nothing under the feet: hold the last air frame and drop.
			state = State.FALL
			jump_sprite.pause()
			jump_sprite.frame = landing_frame - 1
			fell.emit()


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			var dir := Input.get_axis("move_left", "move_right")
			_fine_x = clampf(_fine_x + dir * SHUFFLE_SPEED * delta, min_x, max_x)
			position.x = snappedf(_fine_x, grid)
			if not test_move(global_transform, Vector2(0, 2)):
				state = State.FALL
				fell.emit()
		State.FALL:
			velocity.y += GRAVITY * delta
			move_and_slide()
			if position.y > water_y:
				state = State.GONE
				hide()
				splashed.emit(position.x)


func _on_jump_finished() -> void:
	if state == State.JUMP:
		# The last frame is drawn shifted to keep the boot planted: move the origin there, so the idle takes over in place.
		position.x += jump_sprite.offset.x + pivot_x
		jump_sprite.offset.x = -pivot_x
		_fine_x = position.x
		state = State.IDLE
		jump_sprite.hide()
		idle_sprite.show()
		idle_sprite.play("idle")
