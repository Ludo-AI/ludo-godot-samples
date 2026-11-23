extends Node
## Plays the level by itself and checks it: a jump with each timing lands on the right pier, the air time
## matches its timing, and a take-off from too far back ends in the water.
##     godot --headless --path . -- test=1
## Prints one line per check and quits with code 0 (all passed) or 1.

const Knight = preload("res://knight.gd")

var main: Node
var failures := 0


func _ready() -> void:
	main = get_parent()
	await get_tree().create_timer(0.5).timeout
	var k: Knight = main.knight
	var right: Array = main.cfg["level"]["piers"][1]
	_check("standing idle on the left pier", k.state == Knight.State.IDLE and k.idle_sprite.is_playing(), "state %d" % k.state)

	for timing in ["reference", "sheet"]:
		main.reset()
		k.reference_timing = timing == "reference"
		await get_tree().process_frame
		var x0: float = k.position.x
		main.jump()
		var air: float = await k.landed
		await k.jump_sprite.animation_finished
		await get_tree().process_frame
		var want: float = k.air_seconds_expected()[timing]
		_check("%s timing: air time %.2f s (expected %.2f s)" % [timing, air, want], absf(air - want) < 0.1, "")
		_check("%s timing: landed at x %d after %d px of travel (right pier %d to %d)" % [
			timing, k.position.x, k.position.x - x0, right[0], right[1]],
			k.state == Knight.State.IDLE and k.position.x > right[0] and k.position.x < right[1], "")
		# Feet lock: the planted boot is drawn on one spot before take-off and on one spot after landing.
		var up: Array = []
		var down: Array = []
		for e in k.boot_trace:
			(up if int(e[0]) <= k.takeoff_frame else down).append(float(e[1]))
		var up_moves: float = up.max() - up.min()
		var down_moves: float = down.max() - down.min()
		var step: float = down.min() - up.min()
		_check("%s timing: planted boot moves %d px before take-off, %d px after landing (%d and %d frames), %d px apart (travel %d)" % [
			timing, up_moves, down_moves, up.size(), down.size(), step, k.travel_px],
			up_moves <= k.grid and down_moves <= k.grid and absf(step - k.travel_px) <= k.grid, "")
		var back := 0.0
		for j in range(1, k.body_trace.size()):
			back = minf(back, float(k.body_trace[j][1]) - float(k.body_trace[j - 1][1]))
		_check("%s timing: body centre in the air never steps back (largest step back %d px over %d frames)" % [
			timing, -back, k.body_trace.size()], back >= 0.0, "")

	main.reset()
	k.reference_timing = true
	k.reset_to(48)
	await get_tree().process_frame
	main.jump()
	var sx: float = await k.splashed
	_check("take-off from x 48 falls in the water (splash at x %d)" % sx, k.state == Knight.State.GONE, "")

	print("SMOKE TEST: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _check(what: String, ok: bool, detail: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what + ("" if detail.is_empty() else "  (" + detail + ")"))
	if not ok:
		failures += 1
