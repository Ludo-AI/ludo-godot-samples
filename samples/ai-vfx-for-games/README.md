# Cinder's Fight: AI VFX for games (Godot 4)

The sample project from the Ludo.ai video "AI VFX for games". Cinder the fox mage holds a moonlit ruin while slimes hop
in and bats swoop. Every effect started as one still picture made with Ludo's Image Generator (image type **VFX
Sprite**), animated in the Sprite Generator, and dropped into Godot as SpriteFrames by Ludo's free toolbox:

    ludo toolbox sprite export art/fx_explosion.png --engine godot

Open the folder in Godot 4.7 or newer and press Play. Command line options: `-- scene=main` (the fight), `scene=blend`
(the same lightning strike with Normal and Add blend side by side), `scene=pixel` (the fight drawn at 480x270).

## How the effects are set up (scripts/main.gd)

- **Glowing effects use Add blend** (fireball, lightning, aura): a CanvasItemMaterial with Blend Mode Add, so they
  brighten what is behind them. The explosion has a dark outline and smoke, so it stays on the normal blend.
- **One-shots play once and free themselves**: the explosion, the lightning and Cinder's cast have Loop unticked in
  their SpriteFrames, so `animation_finished` fires, and one line fades the node out and removes it:
  `sprite.animation_finished.connect(fade_out.bind(sprite, 0.15))`.
- **Effects sit in the scene**: each one fades in over a few frames and casts a soft light of its own colour on the
  ruin and the cast (a PointLight2D with a radial GradientTexture2D: orange for the fireball and the explosion, violet
  for the lightning, green for the aura). The cast gets the same moonlight tint as the ruin.
- **The aura is centred on Cinder**: it is a child of Cinder at the middle of the body, drawn in front with Add blend,
  so the halo wraps the fox instead of standing behind it, and follows the middle of the body through the strike. The
  fireball leaves the staff's orb on the cast frame where the strike lands; a cast while Cinder still holds the aim
  fires again from the aim. The idle and cast sprites swap with a 0.1 s fade, so the change never pops.
- **Loops** (fireball, aura, Cinder's idle, the slime and the bat) keep Loop on.

## How each asset was made (Ludo.ai)

| file | made with | settings |
|---|---|---|
| fx_explosion | VFX Sprite still "a fiery explosion at its peak", Cel-Shaded, Side-Scroll; animated on Hydra | 3 s, 25 frames, Loop off, prompt "burst, flare, and break apart into smoke that fades away"; top edge softened and 64 px of margin added |
| fx_lightning | VFX Sprite still "a magic lightning strike, a branching bolt of white and violet lightning ... a small ring of electric sparks where it hits the ground"; animated on Ignis | 1.5 s, 16 frames, Loop off, prompt "the lightning bolt strikes down with a bright flash, crackles, then fades away to nothing"; frames 1 to 10 kept with `ludo toolbox sprite frames fx_lightning.png --order 1-10` (after frame 10 the bolt just hangs) |
| fx_fireball | VFX Sprite still, a fireball flying right; animated on Ignis | 2 s, 16 frames, Loop on, prompt "the flames flicker and swirl as the fireball flies"; best of four takes by `ludo toolbox sprite loop` (0.73 on the published toolbox 0.4.0: it loops with a small seam) |
| fx_aura | VFX Sprite still "a green healing aura effect, a tall soft oval halo of glowing green light ..."; animated on Ignis | 2 s, 16 frames, Loop on, prompt "the halo of light pulses gently while the sparkles rise and twinkle" (loop check 0.87) |
| fx_fireball_px | VFX Sprite still in 16-Bit Pixel, brought to its native 128 px grid; animated on Ignis Pixel | 2 s, 16 frames, Loop on (loop check 0.72, first try) |
| cinder_idle, cinder_cast | Sprite still "Cinder, a small fox wizard wearing a tall pointed purple wizard hat with little stars and a long purple mage robe with a red scarf, gripping a long wooden wizard staff with a curled top holding a glowing ember orb, the staff held diagonally across the body in both paws", Cel-Shaded, Side-Scroll; animated on Ignis | idle 2 s Loop on; cast 2 s, 25 frames, Loop off, margins 0.55 x 0.25 "quickly pulls the staff back, then thrusts it forward and aims the orb at the target ahead, holds the aim, then eases back to the starting stance" (scaled to the idle's size in the sheet) |
| slime, bat | Sprite stills (a round purple slime, a small dark purple bat), Cel-Shaded, Side-Scroll; animated on Ignis | slime "wobbles and squishes in place like jelly", bat "flapping its wings up and down while flying"; the hops and swoops are code |
| heart | Asset still "a glowing red heart pickup", background removed | |
| bg | Side-scrolling background "a moonlit ruined temple arena at night" | darkened in code so the effects read |
| sfx/* | each sound came back with its animation (boom, lightning, fireball, aura, slime, bat) | |

## Licence

Code: MIT. Art and sound: CC BY 4.0, made with Ludo.ai (https://ludo.ai).
