# Godot sample projects from the Ludo.ai videos

Free, complete Godot 4 projects from the [Ludo.ai YouTube channel](https://www.youtube.com/@ludoai). Each folder
under `samples/` is the game you see in one video: open its `project.godot` in Godot 4.7 or later and press Play.
Every sprite, animation, background, sound effect and piece of music in them was made with
[Ludo.ai](https://ludo.ai?utm_source=github&utm_medium=repo&utm_campaign=godot-samples&utm_content=readme), the AI game
asset generator. The code is ours, written for the videos.

| Project | What it shows | Video | itch.io |
|---|---|---|---|
| [enemy-sprites](samples/enemy-sprites) | Five AI enemy sprites in one Godot level: wind-ups that warn, one attack each, a boss | [AI enemy sprites](https://youtu.be/C4eFFyOqRwA) | [Mossgrove](https://ludoaigames.itch.io/mossgrove-godot-enemy-sprites) |
| [game-polish](samples/game-polish) | Lamplight: one Godot level in seven passes, from flat sprites to parallax, normal-map lighting and juice | [Make your game look good](https://youtu.be/fLdvpvgbKn4) | [Lamplight](https://ludoaigames.itch.io/lamplight-godot-game-polish) |
| [rotoscoping](samples/rotoscoping) | Harbour Jump: a knight's jump made from a real person's clip, with the reference timing, root motion and feet that stay planted | [Is rotoscoping cheating?](https://youtube.com/shorts/X2dV6rmTAnQ) | [Harbour Jump](https://ludoaigames.itch.io/harbour-jump-godot-rotoscoping) |
| [deckbuilder](samples/deckbuilder) | Storm Keeper: a roguelike deckbuilder battle with a card hand fan, enemy intents, rewards and hits that land; every card from one painting's style. Now with two holiday packs, Winter Lights (Christmas) and Hallow's Tide (Halloween), switched at launch with `-- pack=` | [How to make a game like Slay the Spire in Godot](https://youtu.be/AnD9mlPijDk); the packs: [Claude Code game assets](https://youtu.be/a1FJQzbUf6g) | [Storm Keeper](https://ludoaigames.itch.io/storm-keeper-godot-deckbuilder) |
| [ai-vfx-for-games](samples/ai-vfx-for-games) | Cinder's Fight: a fox mage's battle with AI-made explosions, fireballs, lightning and an aura, set up with Add blend, one-shot effects that free themselves and effect lights | [AI VFX for games](https://youtu.be/eAcue8riqqo) | [Cinder's Fight](https://ludoaigames.itch.io/cinders-fight-godot-vfx) |
| [ai-3d-props-one-level](samples/ai-3d-props-one-level) | Smuggler's Cove: one Godot level dressed with 25 AI 3D props (barrels, crates, a cannon, a rowboat), reskinned with AI textures, with collision built in code and lights | [AI 3D props for one level](https://youtu.be/MRzamkv3hIQ) | [Smuggler's Cove](https://ludoaigames.itch.io/smugglers-cove-godot-3d-props) |

## Use them

- **Code:** MIT (see `LICENSE`). Copy it, change it, ship it.
- **Art and audio:** CC BY 4.0 (see `ASSETS.md`). Use them in your own games, free or commercial, with credit to Ludo.ai.
- Each project's own `README.md` says what to look at first, which script does what, and how the assets were made
  (the prompts and settings), so you can make your own in the same style.

## Make your own assets

The videos show each step in the app. Start free at
[ludo.ai](https://ludo.ai?utm_source=github&utm_medium=repo&utm_campaign=godot-samples&utm_content=readme). The free,
offline [Ludo toolbox](https://ludo.ai/developers/toolbox?utm_source=github&utm_medium=repo&utm_campaign=godot-samples&utm_content=readme)
(`ludo toolbox`, no account) packs sprite sheets, finds pivots and exports SpriteFrames for Godot.

## For maintainers

`python3 tools/package.py <ludo-videos project dir> <slug> --dry-run`, then without `--dry-run` once the video's final
cut is accepted: copies the project into `samples/<slug>` without the editor cache, capture scripts and raw takes,
refuses fonts we may not redistribute and files over 50 MB, and zips `dist/<slug>.zip` for itch.io. Then write the
project's own README and add its row above.
