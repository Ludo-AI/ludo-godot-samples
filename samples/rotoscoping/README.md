# Harbour Jump: a rotoscoped jump in Godot

The Godot 4 project from the Ludo.ai "game techniques" video about rotoscoping. For Prince of Persia (1989), Jordan
Mechner filmed his younger brother in 1985 and turned the footage into frames by hand, which took months. Here the knight's jump came from a 3.9 second clip of a real
person, turned into a 49-frame pixel-art sprite sheet with Ludo's Transfer Motion. This project shows the two things a
game still has to do to make that sheet play well: give each frame the real person's timing, and move the character
across the level the way the person moved (root motion from the reference). Every picture in it was made with Ludo.ai
(https://ludo.ai); the code is ours.

## Run it

Open the folder in Godot 4.7 or later and press Play. The window is portrait (the level is a 9:16 picture).

| Key | What it does |
|---|---|
| Space, or A on a gamepad | Jump the gap |
| T, or the on-screen button | Switch the timing: **reference** (each frame lasts as long as the real person's pose) or **sheet** (every frame the same length, as the sheet came back) |
| M | Travel on or off. Off, the knight jumps in place, as the sheet does |
| Left / Right | Shuffle along the pier to try other take-off spots (there is no walk animation in this sample) |
| R | Reset |

Jump once with each timing and watch the reference clip in the top-right corner, which always plays at its real speed.
With sheet timing the knight leaves the ground while the person is still crouching, then floats for about a second.
With reference timing the two take off and land together. Take off from the far left end of the pier and he lands
short and falls in the water; the level resets.

Checks without a window: `godot --headless --path . -- test=1` jumps with both timings and from too far back, and
prints one line per check (`SMOKE TEST: PASS`).

## Files

- `main.gd`: the level. Loads the background, puts one static collision box on each pier, adds the knight, the labels,
  the button and the reference clip, and reads the keys.
- `knight.gd`: the knight (a `CharacterBody2D`, origin between his feet). Idle, jump, fall and splash. During the air
  frames (16 to 33) it sets his x from the travel curve; on the landing frame (34) it checks for a pier under his feet,
  and with none he drops into the water. On every frame it draws the sheet so the planted boot does not slide (see
  "Feet that stay put").
- `jump_timing.gd`: builds the `SpriteFrames`. `add_even` gives every frame `1 / fps` (sheet timing). `frame_seconds`
  and `add_timed` turn the retime keys into one duration per frame (reference timing). The frames are never changed.
- `data/retime.json`: the retime keys, `[clip seconds, sheet frame]`: `0:0, 0.6:6, 1.35:11, 1.67:15, 2.03:34, 3.6:47,
  3.9:48`. They pin the start, arm swing, crouch, take-off, landing, stand and end poses to the clip.
- `data/travel.json`: the person's travel, measured by `tools/measure_travel.py` (see below).
- `data/knight_feet.json`: where the planted boot and the body's centre sit in every frame of the jump sheet, measured
  by `tools/measure_feet.py` (x in pixels from the left of the frame's crop box, which starts 4 px into each cell; only
  the differences between frames are used).
- `art/config.json`: sheet grids, frame rates, the feet pivots, the pier tops and edges.
- `art/`: `knight_jump.png` (7 x 7 frames, 280 x 472 each), `knight_idle.png` (4 x 4 frames, drawn at twice the size
  and shown at half, so both sheets share one 4 px art pixel), `level_harbour.png` (768 x 1344).
- `ref/reference_jump.png`: the reference clip as a 30 fps sheet, for the corner picture.
- `tools/measure_travel.py`: measures the travel on a clip. `tools/measure_feet.py`: measures the feet on a sheet.
  `tests/smoke_test.gd`: the headless checks.

## Reference timing

Transfer Motion gives back the right poses, but not on the clip's clock. In our test the 3.9 s clip came back as 49
frames at 18.4 fps (2.67 s): the slow start was squeezed and the air time stretched. The person is in the air from
about 1.67 s to 2.03 s of the clip (pose to pose), about 0.36 s; the sheet's air frames, 15 to 33, last 1.03 s at its
own rate.

So the game keeps the frames and changes only how long each stays on screen. Each key pins a frame to a time in the
clip; the frames between two keys share that time evenly. Godot's `SpriteFrames` has a duration per frame, so with the
animation speed at 1 FPS each frame's duration is simply its length in seconds (`JumpTiming.add_timed`). The crouch
frames end up long, the air frames short.

## Travel from the reference (root motion)

The sheet jumps in place: Transfer Motion centres the knight in every cell. The real person moves forward. To get that
back, `tools/measure_travel.py` tracks him on the clip: the black bodysuit is darker than both the white wall and the
grey mat, so a brightness threshold finds him in every frame, and it records the centre of his body and of his ankles.
The camera in this clip follows him, so the script also measures how far the mat's texture slides between frames and
adds that back. In our test:

- feet travel from start to end: 566 px for a body 469 px tall, **1.21 body heights**;
- the ankles leave the mat at about 1.60 s and are back at about 2.17 s;
- `air_curve`: his body's position across the gap, from 0 at take-off to 1 at landing, 21 samples. It is close to a
  straight line, as a jump should be (gravity only acts up and down).

The knight is 328 px tall in the sheet, so he travels the measured 1.206 x 328 = 396 px, shaped by `air_curve`, while his air frames
play. Positions snap to the art's 4 px pixel, so the knight never sits between the background's pixels.

## Feet that stay put

Because Transfer Motion centres the knight in every cell, his feet drift inside the cells: while he crouches and
pushes off, the planted boot moves 52 px to the left over frames 10 to 15, and after landing it moves 44 px to the left
over frames 34 to 40. Drawn at a fixed spot, he would skate on the pier. `tools/measure_feet.py` finds the planted
boot in every ground frame (it matches the lowest 28 rows of each frame to the frame before) and writes
`data/knight_feet.json`. `knight.gd` then draws each ground frame so that boot stays on one spot: the take-off spot
before the jump, the landing spot after it, 396 px apart (the measured travel). In the air the body's centre moves
from where it was at take-off to where it will be at landing along the travel curve, and never steps back. The
travel runs over the air frames only (16 to 33), because frame 15 still has a toe on the ground. The frames are never
changed, only where each one is drawn. The headless test checks it: the planted boot moves 0 px on every ground
frame, with both timings.

The level is drawn for that jump: the gap is 160 px, about half the knight's height and 0.4 of his travel, so his toes
leave the left pier and his heels land well inside the right one.

## How the art was made (Ludo)

| Piece | Ludo command and settings |
|---|---|
| Knight (the sprite the jump starts from) | `ludo image create --image-type sprite --art-style "16-Bit Pixel" --perspective Side-Scroll --n 4 --prompt "a small knight adventurer in light steel armor with a short red cape and a blue tunic, no helmet visor, side view facing right, full body standing in a neutral idle pose, arms relaxed, transparent background"`. We kept the variation that came back with a closed helmet. |
| Jump (`knight_jump.png`) | `ludo sprite transfer-motion --image knight.png --video jump.mp4 --model hydra --duration 4 --frames 49 --no-loop --margin-ratio-horizontal 0.4 --margin-ratio-vertical 0.35 --prompt "Copy only the movement. The character is the small pixel-art knight from the sprite in every frame: closed steel helmet with visor, steel armor, short red cape, blue tunic, armored boots, 16-bit pixel art with flat colors. Never draw a human body, bare skin, bare feet or a black bodysuit."` |
| Idle (`knight_idle.png`) | The knight at its own pixel size first (free: `ludo toolbox image scale knight.png --by 1/6`, every 6 x 6 block back to one pixel), then `ludo sprite animate --initial-image knight-small.png --model ignis-pixel --duration 2 --frames 16 --n 3 --margin-ratio-horizontal 0.35 --margin-ratio-vertical 0.1 --motion-prompt "idle breathing, standing still, the cape hangs straight down behind him"`. We kept the first of the three. |
| Harbour (`level_harbour.png`) | `ludo image create --image-type fixed_background --art-style "32-Bit Pixel" --perspective Side-Scroll --aspect-ratio ar_9_16 --n 4 --prompt "Night harbour for a side-scrolling platformer, drawn large and close, as in a game where the hero stands about a quarter of the screen tall. Two flat wooden piers on stone posts, one on the left and one on the right, their tops perfectly level with each other at the same height, a little below the middle of the picture. Between them a clear gap of open dark blue water about three quarters of a standing person's height wide, about one third of the picture's width. A stack of big wooden crates and a barrel at the far left of the left pier, each crate about one tenth of the picture's height. Two hanging lanterns, a full moon, a few moored boat masts far in the background. Calm moonlit water fills the bottom of the picture. The upper half is open night sky, deep blue and readable. No characters, no text."`. "32-Bit Pixel" because its 4 px pixel matches the knight's; the "16-Bit Pixel" background came back with 8 px pixels, twice the knight's. |
| Reference clip sheet (`ref/reference_jump.png`) | Free: `ludo toolbox sprite from-video jump.mp4 --fps 30 --width 138` |

Free toolbox steps (offline, no account): `ludo toolbox sprite metrics <sheet> --grid 7x7` for the feet pivot and the
knight's height, `ludo toolbox sprite loop <takes...>` to compare idle takes.

## Do it with your own clip

1. Film 3 to 4 seconds: side view, whole body in frame the whole time, steady camera, plain background, dark clothes
   on a light wall (or light on dark). A real speed clip, not slow motion.
2. Make the sprite and the motion: `ludo sprite transfer-motion --image your_hero.png --video your_clip.mp4 --no-loop
   --frames 49` (add `--prompt` to keep the hero's look, as above).
3. Measure the travel: `python3 tools/measure_travel.py your_clip.mp4 --out data/travel.json` (needs ffmpeg, Pillow
   and NumPy; `--invert` for light clothes on a dark background, `--no-pan` for a locked-off camera). Then the feet:
   `python3 tools/measure_feet.py art/knight_jump.png --grid 7x7 --takeoff <last ground frame> --landing <first frame
   back down>`.
4. Find the keys: step through your clip and the sheet side by side and write down, for each key pose (start, crouch,
   take-off, landing, stand, end), the clip time and the sheet frame. Put them in `data/retime.json`, and the
   take-off and landing frames in `art/config.json`.
5. Press Play and switch between the timings with T.

## Paste this into your coding agent

```
I have a sprite sheet made from a video of a real person (Ludo Transfer Motion) and the video itself.
In my Godot 4 project:
1. Build the animation's SpriteFrames with one duration per frame from retime keys [[clip seconds, sheet frame], ...]:
   frames between two keys share the time between them evenly; set the animation speed to 1 FPS so each frame's
   duration is its length in seconds. Never change the frames, only their durations.
2. Measure the person's horizontal travel on the video (threshold the person against the background, track the
   body centre and the ankles per frame, correct for camera pan with the floor texture) and save it as JSON:
   travel in body heights and a 0..1 curve over the air time.
3. During the air frames, set the character's x from that curve, scaled to travel_heights x the character's height
   in pixels, snapped to the art's pixel size. On the landing frame, check for ground under the feet; without it,
   fall.
   The sheet's feet drift inside the cells (the character is centred in each cell): measure, per ground frame, the
   planted boot's x in the cell (match the lowest rows of each frame to the previous frame by the best sideways
   shift) and draw each ground frame so that boot stays on one spot; in the air, move the body's centre smoothly from
   its take-off place to its landing place, never backwards.
4. Add a key that switches between the sheet's own even timing and the reference timing, labelled on screen.
Use nearest filtering and keep the sprite and the level on the same pixel size.
```

## Credits and licence

- Motion source: "Forward Jump Animation Reference | Athletic Male" by Endless Reference,
  https://www.youtube.com/watch?v=R6-1Ls82hmQ, licensed CC BY 3.0
  (https://creativecommons.org/licenses/by/3.0/). Cropped to the side view, traced by Ludo Transfer Motion into the
  knight's jump and used as the motion reference; slowed and sped up frame by frame by the reference timing here.
  `ref/reference_jump.png` is the cropped clip as frames, and `knight_jump.png` is an adaptation of it, so keep this
  credit with either.
- Art (`art/`): CC BY 4.0, made with Ludo.ai by Jet Play, Inc. Credit line: Art: "Harbour Jump" by Ludo.ai
  (https://ludo.ai), CC BY 4.0.
- Code (`*.gd`, `main.tscn`, `project.godot`, `tools/`, `tests/`): MIT.
