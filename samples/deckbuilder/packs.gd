extends Node
# Content packs (autoload "Packs"). A pack is a folder, res://packs/<name>/, that holds only the files it changes, at the same
# paths and pixel sizes as the originals (art/..., sfx/..., art/anim/anims.json, art/bg/ frames), plus an optional music.mp3 (Ludo Music, made as a loop).
# Pick one at launch:  godot --path . -- pack=winter-lights     (or set the project setting storm_keeper/pack)
# With no pack the game runs exactly as it shipped.
# Pictures and resources are swapped in before the battle loads (Resource.take_over_path, so every load("res://art/...") and
# every card .tres gets the pack's picture); the three things the battle reads straight from disk (anims.json, the sounds and
# the background frames) ask Packs.file() for their path. The pack's music plays on a loop under the battle.

var pack := ""
var root := ""
var music: AudioStreamPlayer
var swapped := 0
var held: Array[Resource] = []   # the cache keeps resources only while something holds them: the pack's pictures stay held here

func _init() -> void:
	pack = str(ProjectSettings.get_setting("storm_keeper/pack", ""))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("pack="): pack = a.substr(5)
	if pack == "" or pack == "none":
		pack = ""; return
	root = "res://packs/%s/" % pack
	if not DirAccess.dir_exists_absolute(root):
		push_warning("Packs: no folder %s, running the original game" % root); pack = ""; root = ""; return
	_swap("")
	print("Packs: %s, %d pictures swapped" % [pack, swapped])

func _swap(sub: String) -> void:   # every picture and resource in the pack takes over the original's path
	var seen := {}
	for f in DirAccess.get_files_at(root + sub):
		f = f.trim_suffix(".import").trim_suffix(".remap")   # an exported build lists x.png.import / x.tres.remap
		if seen.has(f) or not f.get_extension() in ["png", "webp", "tres", "res"]: continue
		seen[f] = true
		var r: Resource = load(root + sub + f)
		if r:
			r.take_over_path("res://" + sub + f); held.append(r); swapped += 1
			if load("res://" + sub + f) != r: push_warning("Packs: %s did not take over" % f)
	for d in DirAccess.get_directories_at(root + sub):
		if d != "bg": _swap(sub + d + "/")   # art/bg holds JPEG frames the battle reads itself (see file())

func file(path: String) -> String:   # a path the battle reads from disk: the pack's copy when the pack has one
	if pack == "": return path
	var p := path.replace("res://", root)
	if FileAccess.file_exists(p) or DirAccess.dir_exists_absolute(p): return p
	return path

func _ready() -> void:
	if pack == "" or not ResourceLoader.exists(root + "music.mp3"): return
	var s: AudioStreamMP3 = load(root + "music.mp3"); s.loop = true
	music = AudioStreamPlayer.new(); music.stream = s; music.volume_db = -8.0; add_child(music); music.play()
	print("Packs: music %s, %.1f s" % [root + "music.mp3", s.get_length()])
