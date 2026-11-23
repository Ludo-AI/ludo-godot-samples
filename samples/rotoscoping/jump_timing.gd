extends RefCounted
## Helpers that turn a sprite sheet into SpriteFrames, with the same duration for every frame
## ("sheet timing") or one duration per frame taken from a reference clip ("reference timing").
## The frames themselves are never changed: only how long each one stays on screen.


## Loads a PNG at run time (no editor import needed) as a texture.
static func load_texture(path: String) -> Texture2D:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))


## Reads a JSON file from the project.
static func load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Cuts a sheet of cols x rows cells into its first `count` frames.
static func sheet_frames(tex: Texture2D, cols: int, rows: int, count: int) -> Array[AtlasTexture]:
	var fw := tex.get_width() / cols
	var fh := tex.get_height() / rows
	var out: Array[AtlasTexture] = []
	for i in count:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i % cols * fw, i / cols * fh, fw, fh)
		out.append(a)
	return out


## Sheet timing: every frame lasts 1 / fps seconds, the way the sheet came back.
static func add_even(sf: SpriteFrames, anim: String, frames: Array[AtlasTexture], fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for f in frames:
		sf.add_frame(anim, f, 1.0)


## Reference timing: the animation runs at 1 FPS, so each frame's relative duration is its length in seconds.
static func add_timed(sf: SpriteFrames, anim: String, frames: Array[AtlasTexture], seconds: PackedFloat64Array) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, 1.0)
	sf.set_animation_loop(anim, false)
	for i in frames.size():
		sf.add_frame(anim, frames[i], seconds[i])


## The time in the clip at which sheet frame `f` starts. `keys` is [[clip seconds, sheet frame], ...] in order;
## frames between two keys share the time between them evenly.
static func clip_time(keys: Array, f: float) -> float:
	for k in range(keys.size() - 1):
		var a: Array = keys[k]
		var b: Array = keys[k + 1]
		if f <= float(b[1]):
			return lerpf(float(a[0]), float(b[0]), (f - float(a[1])) / (float(b[1]) - float(a[1])))
	return float(keys[-1][0])


## How long each of `count` frames stays on screen under the keys. The last frame has no next key, so it gets
## `last_frame_s`.
static func frame_seconds(keys: Array, count: int, last_frame_s: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for f in count:
		out.append(clip_time(keys, f + 1) - clip_time(keys, f) if f + 1 < count else last_frame_s)
	return out


## Reads the travel curve (0 at take-off, 1 at landing, evenly spaced over the air time) at u in 0..1.
static func sample_curve(curve: Array, u: float) -> float:
	if curve.size() < 2:
		return clampf(u, 0.0, 1.0)
	var x := clampf(u, 0.0, 1.0) * (curve.size() - 1)
	var i := mini(int(x), curve.size() - 2)
	return lerpf(float(curve[i]), float(curve[i + 1]), x - i)
