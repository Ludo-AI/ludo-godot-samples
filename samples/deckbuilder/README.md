# Storm Keeper

A small roguelike deckbuilder battle in Godot 4, from the Ludo video "How to make a game like Slay the Spire in Godot":
a lighthouse keeper plays cards against a crab knight and an anglerfish on a stormy shore. Every card, fighter, icon,
animation, background and sound was made with Ludo (ludo.ai); the code is ours.

Open the folder in Godot 4 and press Play: the battle plays itself (four fights in a row, with a card reward or a relic between them).
Run it from the command line with arguments after `--`:

```
godot --path .                     # the played run, as in the video
godot --path . -- mode=show        # the showcase: the deck fanned, a card taken apart, the deck by type
godot --path . -- slow=0.35        # the whole game, the sea too, in slow motion
```

Where things are:

- `card.tscn` + `card.gd`: one card scene (the art clipped to the frame's window, the frame, the tinted ribbon, the cost and the text).
- `card_data.gd` + `cards/*.tres`: each card's numbers and picture; a new card is a new `.tres` file, not new code.
- `main.gd`: the battle (the hand fan, hover and play tweens, the turn loop, enemy intents, damage through block, rewards, sound).
- `flash.gdshader`: the white hit flash.
- `art/bg/`: the background loop as JPEG frames, read at run time (the folder has a `.gdignore`). To export a build, add `art/bg/*` to
  the export preset's "Filters to export non-resource files/folders" (Project > Export > Resources); running in the editor needs nothing.

## How the art and sound were made (Ludo)

Card Art in the Inked Painterly style made the first card, Harpoon Strike; every other picture is either the same art style or
Generate with Style with that card as the reference, so the whole deck shares one look. The keeper's cards were then held to
the same man with Edit Image, the Harpoon Strike art as Image 2.

| Piece | Ludo tool and settings | Prompt |
| --- | --- | --- |
| Harpoon Strike (`art/cards/harpoon.png`) | Image Generator, Card Art, Inked Painterly | "a lighthouse keeper in a yellow oilskin coat hurling a glowing harpoon, stormy teal sea and a lighthouse beam behind, dramatic low angle, no text" |
| Brace (`art/cards/brace.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), Card Art; then Edit Image with the Harpoon Strike art as Image 2 | "a lighthouse keeper in a yellow oilskin coat and sou'wester hat planting his boots on a wet black rock, holding a round iron shield up as a teal wave crashes into it in a burst of spray, his face in three-quarter view, dramatic low angle, no text"; edit: "Make the lighthouse keeper the same man as the keeper in the reference image: the same age, the same face, brown hair and short brown stubble, the same sou'wester hat and yellow oilskin coat. Keep his pose, the scene and the art style exactly." |
| Gull Swarm (`art/cards/gulls.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), Card Art | "three big white seagulls diving beak first at an armoured crab knight on a wet black rock, stormy teal sea, seen from low" |
| Patch the Hull (`art/cards/patch.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), Card Art; then Edit Image with the Harpoon Strike art as Image 2 | "a lighthouse keeper in a yellow oilskin coat hammering planks over a hole in a boat hull in the rain, sparks of determination, dramatic, no text"; edit: "Make the lighthouse keeper the same man as the keeper in the reference image: the same face, stubble, sou'wester hat and yellow oilskin coat. Keep his pose, the scene and the art style exactly." |
| Tide Chart (`art/cards/chart.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), Card Art | "an old sea chart unrolled on a wooden table, a glowing brass compass and candle on top, warm light, no text, no letters" |
| Undertow (`art/cards/undertow.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), Card Art | "a towering teal wave dragging an armoured crab knight off the rocks into the sea, foam and spray, dramatic, no text" |
| Foghorn (`art/cards/foghorn.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), Card Art | "a giant brass foghorn on a lighthouse gallery blasting a visible shockwave over a stormy sea, dramatic, no text" |
| Lantern Flare (`art/cards/flare.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), Card Art | "a brass ship lantern blazing with blinding white light, a giant crab recoiling from the glare on wet rocks at night, dramatic, no text" |
| Keeper's Watch (`art/cards/watch.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), Card Art | "the great lamp of a lighthouse blazing gold, its beam sweeping across a storm, seen from the gallery railing, dramatic, no text" |
| Rogue Wave (`art/cards/wave.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), Card Art | "a towering rogue wave crashing down on an armoured crab knight and an orange anglerfish brute, stormy teal sea" |
| Beacon Fire (`art/cards/beacon.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), Card Art | "a signal fire blazing on the iron gallery of a lighthouse at night, sparks flying into the rain, stormy teal sea" |
| Tidal Ward (`art/cards/ward.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), Card Art; then Edit Image with the Harpoon Strike art as Image 2 | "a lighthouse keeper in a yellow oilskin coat and sou'wester hat sweeping one arm up as a glowing teal wave curls around him like a protective dome, stormy coast, his face in three-quarter view, dramatic low angle, no text"; edit: "Make the lighthouse keeper the same man as the keeper in the reference image: the same age, the same face, brown hair and short brown stubble, the same sou'wester hat and yellow oilskin coat. Keep his pose, the scene and the art style exactly." |
| the first Gull Swarm (the hand-size example; not in the deck) (`art/cards/gulls_old.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), Card Art | "a swarm of white seagulls diving at a jellyfish monster over a stormy teal sea, dramatic, no text" |
| The card frame (`art/frame.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), UI Element | "an empty playing card frame, portrait orientation, weathered driftwood and brass border, blank rectangular art window in the top half, blank parchment text panel below, a small round gem socket in the top left corner, no text" |
| The energy orb (`art/orb.png`) | Image Generator, Generate with Style (the Harpoon Strike art as the style), UI Element | "a round brass energy orb with a glowing teal sea-glass core, game UI element, no text" |
| The attack intent (`art/i_attack.png`) | Image Generator, Item Icon, Inked Painterly | "a rusty pirate cutlass, single game icon, stormy teal coast, bold ink outlines, warm yellow and rust against cold teal" |
| The block intent (`art/i_block.png`) | Image Generator, Item Icon, Inked Painterly | "a round barnacle-crusted iron shield, single game icon, stormy teal coast, bold ink outlines, warm yellow and rust against cold teal" |
| The buff intent (`art/i_buff.png`) | Image Generator, Item Icon, Inked Painterly | "a swirling teal whirlpool with a white crest, single game icon, stormy teal coast, bold ink outlines, warm yellow and rust against cold teal" |
| The Brass Compass relic (`art/r_compass.png`) | Image Generator, Item Icon, Inked Painterly | "an old brass compass with a teal face, single game icon, stormy teal coast, bold ink outlines, warm yellow and rust against cold teal" |
| The relic (`art/r_feather.png`) | Image Generator, Item Icon, Inked Painterly | "a white gull feather tied with a red string, single game icon, stormy teal coast, bold ink outlines, warm yellow and rust against cold teal" |
| The relic (`art/r_jar.png`) | Image Generator, Item Icon, Inked Painterly | "a glass jar of teal sea glass pebbles, single game icon, stormy teal coast, bold ink outlines, warm yellow and rust against cold teal" |
| The keeper, still (the First Frame of its animations) | Image Generator, Sprite, Inked Painterly, Side-Scroll | "full body lighthouse keeper in a yellow oilskin coat and sou'wester hat, stubble, gripping a long iron harpoon with a wooden gun stock in both hands, side view facing right, ready stance, bold ink outlines" |
| The crab, still (the First Frame of its animations) | Image Generator, Sprite, Inked Painterly, Side-Scroll | "a hulking armoured crab knight with a rusty cutlass in one claw and a barnacle shield in the other, side view facing left, menacing, bold ink outlines" |
| The anglerfish, still (the First Frame of its animations) | Image Generator, Sprite, Inked Painterly, Side-Scroll | "a hulking orange anglerfish brute walking on stubby fins, a glowing lure lantern over its huge toothy jaws, side view facing left, menacing, bold ink outlines" |
| The shore (the background's first and last frame) | Image Generator, Generate with Style (the Harpoon Strike art as the style), Background | "a rocky shore at the foot of a lighthouse at dusk, stormy teal sea, a wide flat rock shelf across the lower third for a battle, no characters, no text" |
| The background loop (`art/bg/f*.jpg`, 24 fps) | Video Generator, the shore as first and last frame, 8 s (looped by `tools/bg_loop.py` in the video folder, not shipped) | "the stormy sea heaves and big waves crash into spray against the rocks, rain sweeps across, dark clouds drift slowly, the lighthouse lamp glows, static camera" |
| Keeper idle (`art/anim/keeper_idle.png`) | Sprite Generator, Animate, Ignis, 2 s, 36 frames, loop | "idle breathing in a ready stance, the coat stirring in the wind" |
| Keeper attack (`art/anim/keeper_attack.png`) | Sprite Generator, Animate, Ignis, 2 s, 25 frames, no loop, horizontal margin 0.8 (so the harpoon gun stays inside the canvas) | "thrusts the harpoon forward in a hard stab, then pulls back to the ready stance" |
| Keeper hurt (`art/anim/keeper_hurt.png`) | Sprite Generator, Animate, Ignis, 1.5 s, 25 frames, no loop | "flinches backward from a hit to the chest, then recovers to the ready stance" |
| Crab idle (`art/anim/crab_idle.png`) | Sprite Generator, Animate, Ignis, 2 s, 36 frames, loop | "idle breathing, claws slowly opening and closing" |
| Crab attack (`art/anim/crab_attack.png`) | Sprite Generator, Animate, Ignis, 2 s, 25 frames, no loop | "lunges forward and snaps its big claw shut, then settles back" |
| Crab hurt (`art/anim/crab_hurt.png`) | Sprite Generator, Animate, Ignis, 1.5 s, 25 frames, no loop | "recoils backward from a hit, shell jolting, then settles back" |
| Crab death (`art/anim/crab_death.png`) | Sprite Generator, Animate, Ignis, 2 s, 36 frames, no loop | "is struck down: it rears back, its legs buckle and it collapses flat onto the ground, claws going limp, and lies still" |
| Anglerfish idle (`art/anim/angler_idle.png`) | Sprite Generator, Animate, Ignis, 2 s, 36 frames, loop | "idle, body swelling gently, the glowing lure swaying, fins fluttering" |
| Anglerfish attack (`art/anim/angler_attack.png`) | Sprite Generator, Animate, Ignis, 2 s, 25 frames, no loop | "lunges forward and bites with its jaws wide open, then settles back" |
| Anglerfish hurt (`art/anim/angler_hurt.png`) | Sprite Generator, Animate, Ignis, 1.5 s, 25 frames, no loop | "recoils backward from a hit, body jolting, then settles back" |
| Anglerfish death (`art/anim/angler_death.png`) | Sprite Generator, Animate, Ignis, 2 s, 36 frames, no loop | "is struck down: it jolts, goes limp, rolls belly up and sinks down, the glowing lure flickering out, and lies still" |
| Sound `sfx/swish.wav` | Sound Effects, 0.6 s | "a single playing card swished quickly off a table, crisp paper whoosh" |
| Sound `sfx/thunk.wav` | Sound Effects, 1 s | "a heavy iron harpoon thunking into a crab's armoured shell, wet crunch" |
| Sound `sfx/block.wav` | Sound Effects, 1.5 s | "a small wave crashing against a wooden shield, splash and a dull thud" |
| Sound `sfx/draw.wav` | Sound Effects, 0.8 s | "a single playing card flicked off a deck onto a wooden table, crisp paper snap" |
| Sound `sfx/hit.wav` | Sound Effects, 1 s | "a heavy crab claw clacking into a raincoat, wet slap and a grunt-free thud" |
| Sound `sfx/chime.wav` | Sound Effects, 1.5 s | "a warm brass bell chime with a sparkle, a reward appearing" |
| Sound `sfx/sink.wav` | Sound Effects, 1.5 s | "a monster sinking into the sea, a deep bubbling splash" |

## License

Code (`*.gd`, `*.tscn`, `*.tres`, `*.gdshader`, `project.godot`): MIT. Art and sound (`art/`, `sfx/`): CC BY 4.0, made with Ludo
(ludo.ai). The font, `art/Gelasio-Bold.ttf`, is Gelasio under the SIL Open Font License 1.1 (`art/Gelasio-OFL.md`).
