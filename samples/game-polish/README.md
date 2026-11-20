# Lamplight

A small Godot 4.7 scene from the Ludo video "How to make your game look good": Pip, a frog lamplighter, walks a swamp
boardwalk at night, lighting lamp posts and snapping at mosquitoes. The same level runs in seven modes, one per chapter
of the video, each adding one pass to the one before.

Open the folder in Godot 4.7 and press Play. The modes are command-line arguments after `--`:

```
godot --path . -- mode=flat      # the art as it came, no depth, no light
godot --path . -- mode=depth     # + parallax layers and a moving camera
godot --path . -- mode=light     # + night (CanvasModulate), normal-mapped art (CanvasTexture), a PointLight2D per lantern
godot --path . -- mode=life      # + idle, walk and snap animations with their sounds
godot --path . -- mode=palette   # + the lamp post recolored to the swamp's palette
godot --path . -- mode=juice     # + the tongue's pop, the hit flash, a little screen shake (the finished game)
godot --path . -- mode=nmap      # Pip beside his normal map, a light circling him
```

Everything is built in `main.gd` (one scene, no editor setup). Art is loaded from `art/` at run time, sounds from `sfx/`.

## How the art was made (Ludo)

Every picture, animation and sound here was made with Ludo (ludo.ai). Prompts and settings:

| Piece | Ludo tool and settings | Prompt |
| --- | --- | --- |
| Pip (`hero_still.png`) | Image Generator, Sprite, 16-Bit Pixel, Side-Scroll, Normal Map; then an image edit | "a small round green frog lamplighter with a bare round head, a glowing brass lantern hanging at his hip from crossed leather straps over his cream belly, standing calmly, full body, side view facing right"; edit: "Move the glowing brass lantern from his head to his hip, where the satchel is: the satchel is replaced by the lantern, which hangs at his hip from crossed leather straps over his body. His head is bare and round." |
| Walk (`hero_walk.png`, `hero_walk_n.png`) | Sprite Generator, Animate, 3 s, loop, Normal Map | "walks forward at a steady pace, a full looping walk cycle, the lantern at his hip swinging on its strap" |
| Idle (`hero_idle.png`) | Sprite Generator, Animate, 3 s, loop, Normal Map | "stands and breathes calmly, blinks once, the lantern at his hip sways gently on its strap" |
| Snap (`hero_tongue.png`) | Sprite Generator, Animate, 3 s, Normal Map | "crouches and holds still for a moment, then snaps his long tongue straight forward and pulls it back" |
| Flinch (`hero_flinch.png`) | Sprite Generator, Animate, 3 s, Normal Map | "flinches back with a startled jolt as if something stung the top of his head, winces, then shakes it off and recovers; only the frog, no insects or effects" |
| Far layer (`far.png`) | Image Generator, Parallax Layer, 16-Bit Pixel | "far background layer of a night swamp: a continuous line of tall distant bald cypress trees with hanging spanish moss, dark blue silhouettes fading into soft mist at their base, empty clear sky above, calm and atmospheric, no characters" |
| Middle layer (`mid.png`) | Image Generator, Parallax Layer, 16-Bit Pixel | "middle layer of a night swamp: tall cattail reeds and grasses, a few cypress trunks with hanging moss, small glowing mushrooms, rich greens and teals, readable shapes, no characters" |
| Boardwalk (`near.png`, `near_n.png`) | Image Generator, Parallax Layer, 16-Bit Pixel, Normal Map | "foreground ground strip for a side-scrolling platformer: a sturdy wooden plank boardwalk seen from the side, its deck in the middle of the image, thick support posts going down into dark still swamp water that fills the bottom, lily pads and small reeds, warm weathered wood, no characters" |
| Night sky (`sky.png`) | Image Generator, Fixed Background, 16-Bit Pixel | "a calm night sky only: deep blue fading to soft violet near the horizon, scattered small twinkling stars, a few thin wisps of cloud, nothing on the ground, no trees, no moon" |
| Moon (`moon.png`) | Image Generator, asset, 16-Bit Pixel; brought to a coarser grid with Convert to Pixel Art | "a full moon for a night sky in a pixel art 2D game: a pale cream disc with a few soft grey crater patches, crisp hard pixel edges, a small limited palette, no glow, no halo, no stars, plain flat background" |
| Mosquito (`mosq.png`) | Generate with Style, Pip as the style picture, Sprite, Normal Map; then Animate, 3 s, loop | "a big swamp mosquito enemy with a long needle nose, glowing red eyes, translucent wings, hovering, side view facing left, 16-bit pixel art game sprite" (as Ludo stored it); animate: "hovers in place, wings buzzing very fast, body bobbing slightly" |
| Lamp post (`post.png`) | Generate with Style, Pip as the style picture, asset; background removed | "a crooked wooden swamp lamp post with an iron lantern hanging from its arm, standing on its own, side view, 16-bit pixel art game asset" (as Ludo stored it) |
| Heart (`heart.png`) | Generate with Style, Pip as the style picture, asset; background removed | "a single red heart health icon for a game HUD, chunky, front view, 16-bit pixel art game asset" |
| Pop (`pop.png`) | Image Generator, V F X Sprite, 16-Bit Pixel; then Animate | "a small warm yellow and orange hit spark burst, a pop of light with a few sparks, centered"; animate: "the spark bursts outward quickly and fades away" |
| Sounds (`sfx/`) | Each animation came back from Animate with its own sound | |

Free Ludo toolbox commands (offline, no account; `ludo toolbox`):

```
ludo toolbox image normals post.png --shape-radius 21 --detail-scale 3     # post_n.png and mid_n.png
ludo toolbox image palette swamp.png --save swamp.hex                     # the three layers stacked
ludo toolbox image recolor post.png --palette swamp.hex                   # post_pal.png
```

## License

Code (`main.gd`, `main.tscn`, `project.godot`): MIT. Art and sound (`art/`, `sfx/`): CC BY 4.0, made with Ludo (ludo.ai).
