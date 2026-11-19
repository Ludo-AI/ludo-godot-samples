# Mossgrove: five AI enemy sprites in one Godot level

The Godot 4 project from the Ludo AI video "AI enemy sprites". Bramble the hedgehog knight walks through a forest and
each enemy does its one job on him: the mushroom bumps, the boar scrapes and charges (Bramble jumps it), the toad spits
at his shield, the moth dives, and the rhinoceros beetle boss rears its horn and slams. Every picture and sound in it was
made with Ludo AI (https://ludo.ai); the code is ours.

## Run it

Open the folder in Godot 4 and press Play. The art and sounds load at runtime from `art/` and `sfx/`; each sheet's grid,
frame rate and timing are in `art/config.json`.

Optional arguments after `--`: `mode=fight|boar3|mush3|boss|read|end|lineup`, `order=boar,toad,moth,mushroom,beetle`.

## Files

- `main.gd`: the level. Each enemy waits for its wind-up's last frame (`go` in `art/config.json`), then moves.
- `flash.gdshader`: the white hit flash. `wipe.gdshader`: the warm outline wiping on.
- `art/`: the sprite sheets (6 x 6 or 6 x 5 frames) and the forest background. `sfx/`: one sound per animation, made
  with it.

## How the art was made

**Characters:** Ludo Image Generator, Generate with Style (image type Sprite). Style picture: a Cel-Shaded hero and
mushroom made first with the Image Generator (Sprite, Cel-Shaded, Side-Scroll). Each prompt is the character, then the
same style words:

- mushroom: "a small angry mushroom creature enemy, brick-red cap with cream spots, stubby legs, walking"
- boar: "a stocky wild boar enemy, round chunky body with smooth flat-colored hide, a short simple bristle mane, big
  ivory tusks, standing ready to charge"
- toad: "a wide, low, flat poison toad enemy, much wider than it is tall, squatting close to the ground, big wide mouth,
  puffed throat, warty back"
- moth: "a round fluffy night moth enemy flying, wide spread wings with simple eye spots, glowing yellow eyes"
- beetle: "a huge rhinoceros beetle boss with one big curved horn on its head, dusty violet shell with a warm orange
  underbelly, six sturdy legs, standing"
- style words: "side view facing left, full body, chunky cute cartoon game enemy with big expressive angry eyes, bold
  dark brown outlines of the same weight as the reference, flat colors with hard two-tone cel shading, light from the
  upper left, the muted dusk forest palette of the reference (moss green, teal, dusty violet, warm browns), simple
  shapes, low detail, same style as the reference characters and forest"

The forest is Generate with Style from the same picture, as a Side-Scrolling Background.

**Animations:** Sprite Generator, Animate, the character as First Frame, model Hydra, 3 s, 36 frames, Animation Margin
manual (35% / 15%, or more for the moves that travel), loop off. Each comes back with its own sound. Motion prompts:

- mushroom: "walking forward in place with an angry little bounce"
- boar: "the boar lowers its head and scrapes the ground with its front hoof twice, holds completely still for a moment,
  then lunges forward hard with its tusks, in place"
- toad: "the toad puffs up its throat big for a moment, then spits a glob of green poison forward, then deflates"
- moth: "flying in place, flapping its wings steadily"
- beetle: "the beetle rears its horn back high and holds still for a moment, then slams its horn down hard into the ground"
- beetle charge: "the beetle lowers its head and points its horn forward, holds still for a moment, then charges forward
  hard, in place"
- deaths: "gets hit, recoils, topples over and lies still" (the moth: "gets hit, recoils, tumbles down and lies still")
- Bramble: "jumping up high and landing", "swings his sword forward in one fast slash, then returns to his stance",
  "raises his shield in front of him and braces behind it, then holds still"

**Free toolbox steps** (`ludo toolbox`, offline, no account): the warm outline (`ludo toolbox image outline <sheet>
--color '#ffe6a8' --width 3`) and the boar's collision box and capsule (`ludo toolbox sprite collide boar.png --grid
6x6`).

## Licence

Code: MIT. Art and sound: CC BY 4.0, made with Ludo AI.
