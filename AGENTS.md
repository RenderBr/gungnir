# Gungnir — Agent Guide

## Build & run

```bash
./build.sh              # macOS / Linux
./run.sh examples/hello # build + run

.\build.bat             # Windows
.\run.bat examples\hello
```

Flags: `--editor`, `--3d`, `--hot`, `--shot=<path>`, `-- <passthrough-args>`

## Project structure

```
src/
  main.odin        Entry point, main loop, mode routing (edit vs play)
  engine/          Core engine — scene, entities, assets, rendering, lighting, postfx, recipes
  script/          Lua state, hot reload, all Lua API bindings
  gen/             Procedural generation — noise, palettes, textures, sprites, meshes, audio
  editor/          Level editor — edit/play state, cameras, picking, inspector panels
examples/          Nine example games, from minimal (hello) to full arcade (pacman, balatro)
presets/           Built-in shader presets (crt.fs)
docs/api.md        Lua API reference
```

## Code conventions

- **Odin style**: PascalCase for exported procs, camelCase for locals, snake_case for file names.
- **`@(private)`** marks internal-only entities (38 occurrences).
- Every Lua-facing `l_*` C function has a comment above it: `// set_crt(on) — ...`.
- Lua CFunction convention (see `src/script/api.odin:7`): extract args first (can longjmp),
  then `context = g_ctx`, then allocate.
- Avoid `defer` across any call that can raise a Lua error.
- Inline comments only — no docstring generators.

## Engine data flow (per frame)

1. **lighting_render_lightmap** — 2D lightmap (if enabled)
2. **begin_frame** — opens render texture (if postfx active) or begins drawing
3. **3D pass** — begin_3d → draw_entities_3d → script on_draw_3d → end_3d
4. **2D pass** — begin_2d → draw_entities_2d → script on_draw → end_2d
5. **lighting_composite_2d** — multiply lightmap onto scene
6. **script on_gui** — screen-space, never darkened by lighting
7. **end_frame** — closes RT, applies screen shader, blits to window

## Key types

| Type | File | Role |
|------|------|------|
| `Engine` | `engine/engine.odin` | Top-level state: scene, assets, cameras, postfx, lighting |
| `Entity` | `engine/entity.odin` | Position, rotation, scale, tint + variant (Sprite/MeshRef/Shape/Label/Light) |
| `Scene` | `engine/scene.odin` | Dense entity array + free-list; generation-tagged IDs |
| `Assets` | `engine/assets.odin` | Texture/sound/model/shader/recipe registries with lazy file loading |
| `Postfx` | `engine/postfx.odin` | Render texture, screen shader, render resolution |
| `Lighting` | `engine/lighting.odin` | 2D lightmap, 3D per-pixel shader, ambient |
| `Script` | `script/lua_state.odin` | Lua VM, hot reload, time scale, error harness |
| `Editor` | `editor/editor.odin` | Edit/play mode, entity selection, undo |

## Adding a Lua API function

1. Write `l_my_func` in the appropriate `api_*.odin` file with a doc comment.
2. Register it in the corresponding `register_*` proc.
3. Add to `.luarc.json` globals list.
4. Add to `docs/api.md`.
5. Add an example usage in the relevant example or a new example.

## Preset shaders

`presets/<name>.fs` is auto-discovered by `set_screen_shader(name)`.
Create a new `.fs` file and reference it by its basename.
