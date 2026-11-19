# Godot sample projects from the Ludo.ai videos

Free, complete Godot 4 projects from the [Ludo.ai YouTube channel](https://www.youtube.com/@ludoai). Each folder
under `samples/` is the game you see in one video: open its `project.godot` in Godot 4.7 or later and press Play.
Every sprite, animation, background, sound effect and piece of music in them was made with
[Ludo.ai](https://ludo.ai?utm_source=github&utm_medium=repo&utm_campaign=godot-samples&utm_content=readme), the AI game
asset generator. The code is ours, written for the videos.

| Project | What it shows | Video | itch.io |
|---|---|---|---|
| [enemy-sprites](samples/enemy-sprites) | Five AI enemy sprites in one Godot level: wind-ups that warn, one attack each, a boss | [AI enemy sprites](https://youtu.be/C4eFFyOqRwA) | _(soon)_ |

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
