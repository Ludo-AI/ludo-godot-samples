# Smuggler's Cove: one Godot level dressed with 25 AI 3D props

A small Godot 4 pirate level from the Ludo.ai video "AI 3D props for one level". Every prop on the beach and the pirate
were made with [Ludo.ai](https://ludo.ai?utm_source=github&utm_medium=repo&utm_campaign=godot-samples&utm_content=readme-cove);
the water, the dock planks and the cannonball are Godot primitives built in code.

Open `project.godot` in Godot 4.7 or later and press Play. The pirate first plays the run from the video by himself
(he knocks five barrels into the sea). Press any key to take over:

| key | does |
|---|---|
| arrows or WASD | run forward or back, turn |
| Space | kick (the nearest barrel or crate in front of his foot flies) |
| F | fire the cannon at the nearest barrel still ashore |
| T | show or hide each prop's triangle count |

## What to look at

- `scripts/cove.gd`, `place()`: how each prop goes in. The GLB is scaled to its real size (Ludo models come back about one
  unit across; `props/props.json` holds each prop's size in metres) and set on the ground; anything the player can bump
  becomes a `RigidBody3D` with a convex `CollisionShape3D` built from the mesh in code (`_convex()`).
- `scripts/pirate.gd`: a `CharacterBody3D`. A character body treats rigid bodies as walls, so after `move_and_slide()` it
  pushes whatever it touched with `apply_central_impulse()`; the kick sends a signal that `cove.gd` turns into an impulse.
- The lights: an `OmniLight3D` inside the lantern, the campfire and each torch (in `place()`), and a warmer sun.

## How the assets were made (Ludo.ai)

**Props (25).** One prompt per prop, the same style line on every one, two pictures each, the better one kept, then
picture to 3D:

1. `ludo image create --image-type 3d --art-style "Stylized 3D" --n 2 --prompt "<prop>, <style line>"`
   - style line: `stylized hand-painted low-poly game prop, chunky readable shapes, warm saturated colors, one single object, whole object visible, centered, plain white background`
   - props, for example: `a sturdy wooden pirate barrel with iron hoops`, `a wooden cargo crate with rope handles and a stenciled anchor mark`,
     `a black iron pirate cannon on a wooden carriage with wheels`, `a campfire of stacked logs with a small iron cooking pot on a tripod over it`
2. `ludo model create --image <picked picture> --model prop --target-num-faces 5000` (Prop model, 2048 textures, GLB).

All 25 landed between 4,627 and 6,024 triangles for a 5,000 target (`ludo toolbox model info` reads any GLB, free and
offline). Credits: 1 per picture pair and 4 per model, 125 for the 25.

**The pirate.** `ludo model create-image` (a full-body A-pose character picture), `ludo model create --model hero`,
`ludo model rig --rig-type humanoid_template --joint-naming godot`, then four preset moves (idle, jog, kick, push) with
`ludo model animate-preset`, merged into `pirate/pirate.glb`.

**The sand.** `ludo image create --image-type texture`: "warm golden beach sand seen from straight above, soft wind
ripples, a few tiny pebbles, stylized hand-painted game texture, warm saturated colors, seamless tileable".

## Licence

Code: MIT. Art (the GLB models and their textures, the sand): CC BY 4.0, credit Ludo.ai. See the repository's `LICENSE`
and `ASSETS.md`.
