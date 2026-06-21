# Gungnir Engine

A small game engine written in [Odin](https://odin-lang.org) on top of raylib — named for Odin's spear:

- **Lua scripting** with a dead-simple API — a playable game in ~30 lines; split across files with `require()`
- **2D and 3D in one scene** — sprites, shapes, text, meshes; 2D HUD over a 3D world for free
- **In-engine level designer** — edit, play, stop; the authored level always comes back intact
- **Procedural assets** — generated sprites, textures, palettes, terrain, and synthesized sound effects, all from seeds; levels store recipes, not pixels
- **Hot reload** — pass `--hot` and save any `.lua` file in your game directory; the running game updates (modules and all), script errors show a banner instead of crashing

## Requirements

- Odin (tested with `dev-2026-05`)
- macOS: `brew install lua@5.4` (keg-only; `build.sh` passes the linker path)
- Linux: no extra steps — Odin's `vendor:lua/5.4` bundles a static `liblua54.a`
- Windows: no extra steps — `vendor:lua/5.4` bundles `lua54.dll` (copied to `bin\` by `build.bat`)

## Run

```sh
./run.sh examples/hello                # bouncing ball
./run.sh examples/hello --hot          # edit the file while it runs
./run.sh examples/pong                 # entities, sound, score
./run.sh examples/invaders             # every asset generated from a seed
./run.sh examples/terrain3d            # fly over generated terrain, 2D HUD on top
./run.sh examples/pong --editor        # open the level designer
```

On Windows use `build.bat` / `run.bat` instead:

```bat
run.bat examples\hello
```

A game is a folder with a `main.lua` (plus optional `level.json` and `assets/`).
Split logic across files with `require()` — see `examples/balatro` and
`examples/pacman` for multi-file project structure.

## A complete game

```lua
function on_init()
  gen_sprite("hero", 12, 12, 7)        -- generated from seed 7
  player = spawn_sprite("hero", 480, 300)
  set_scale(player, 4)
end

function on_update(dt)
  local x, y = get_pos(player)
  if key_down("left")  then x = x - 200 * dt end
  if key_down("right") then x = x + 200 * dt end
  set_pos(player, x, y)
end

function on_gui()
  draw_text("arrows to move", 10, 10, 20)
end
```

See [docs/api.md](docs/api.md) for the full API reference.

## Editor

`--editor` starts in edit mode (or press **F1** in a running game).

- **Left click** select, **drag** move (grid snap toggle in toolbar)
- **Right/middle drag** pan (2D) or orbit/pan (3D view), **wheel** zoom
- **Backspace** delete, **cmd+D** duplicate, **cmd+S** save
- **Play** snapshots the scene and runs the script fresh; **Stop** restores the
  authored scene exactly
- The inspector edits transforms, tint, text, and — for generated assets —
  the **recipe** (drag the seed and watch the asset regenerate live)
- Levels save to `<game>/level.json`: entities plus asset recipes, regenerated
  deterministically on load

## Keys (in game)

- **cmd+R** full restart (fresh scene + script state)
- **F1** open the editor over the running game
- **F3** toggle FPS / entity count / time scale overlay
- **F5** step one frame (while paused)
- **F6** unpause
- **`** toggle in-engine console (last 8 log entries + errors)

## Layout

```
src/
  gen/      procedural generation (noise, palettes, textures, sprites, meshes, audio)
  engine/   entities, scene, assets, recipes, rendering, level io
  script/   lua state, error harness, hot reload, the script-facing API
  editor/   edit/play state machine, cameras, picking, panels
  main.odin loop ownership and mode routing
examples/   hello, pong, invaders, asteroids, nightfall, orbit, pacman, balatro, terrain3d
```
