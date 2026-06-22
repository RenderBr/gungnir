# Architecture

Gungnir is a small game engine in [Odin](https://odin-lang.org) on top of
raylib. It is structured as four internal packages (`engine`, `script`, `gen`,
`editor`) wired together by a thin `main.odin`.

## Package map

```
main.odin ──┬── engine ── scene, entities, assets, rendering, lighting, postfx, recipes
             ├── script ── Lua VM, hot reload, API bindings (api_*.odin)
             ├── gen    ── procedural generation (noise, palette, texture, sprite, mesh, audio)
             └── editor ── edit/play state, cameras, picking, inspector
```

## Engine (`src/engine/`)

### Engine (engine.odin)

The single top-level struct holding all subsystem state:

| Field | Type | Role |
|-------|------|------|
| `scene` | `Scene` | Dense entity array + free list |
| `assets` | `Assets` | Texture/sound/model/shader/recipe registries |
| `postfx` | `Postfx` | Render texture, screen shader, render resolution |
| `lighting` | `Lighting` | 2D lightmap, 3D per-pixel shader, ambient |
| `cam2d` / `cam3d` | raylib Camera | Active 2D/3D views |

### Entity (entity.odin)

Entities are stored in a dense array with generation-tagged IDs. The `Variant`
union discriminates the type:

```
Entity :: struct {
    id, name, alive, pos, rot, scale, tint,
    variant: union { Sprite, MeshRef, Shape, Label, Light }
}
```

- **Sprite** — named texture + flip flags
- **MeshRef** — named 3D model
- **Shape** — rect or circle with size
- **Label** — text string + size
- **Light** — point or directional, radius + intensity

### Scene (scene.odin)

- `entities: [dynamic]Entity` — dense array, slots reused via free list
- `EntityId` packs a 32-bit slot index + 32-bit generation counter
- `get()` returns nil for stale IDs (generation mismatch)
- `despawn()` bumps generation and adds slot to `free_slots`

### Assets (assets.odin)

Lazy-loading registries for textures, sounds, models, and shaders. Textures
and sounds fall back to `assets/<name>.<ext>` on disk.

`ShaderAsset` wraps `rl.Shader` with cached uniform locations (`time`,
`resolution`, and user uniforms via `set_shader_param`).

### Postfx (postfx.odin)

Optional render-to-texture pipeline. When active (screen shader is set), the
scene renders into a texture at `render_w × render_h` (or native window size),
then the shader is applied when blitting to the window.

Preset shaders live in `presets/<name>.fs` and are auto-loaded by
`set_screen_shader(name)`.

### Render (render.odin)

Per-frame pass order (driven by `main.odin`):

1. `lighting_render_lightmap` — 2D lightmap into a separate texture
2. `begin_frame` — open render texture (if postfx) or begin direct drawing
3. `begin_3d` / `draw_entities_3d` / `end_3d` — 3D world (meshes)
4. `begin_2d` / `draw_entities_2d` / `end_2d` — 2D world (sprites, shapes, labels)
5. `lighting_composite_2d` — multiply lightmap onto the scene
6. `end_frame` — close render texture, apply screen shader, present

### Lighting (lighting.odin)

- 2D lightmap: render-to-texture with additive point lights
- 3D: per-pixel Lambert + Blinn-Phong + fog + micro-normal detail
- `lightmap` texture matches the `logical_size()` of the active render
- Recreated on window resize or editor enter/exit

### Recipes (recipes.odin)

Serializable descriptors for generated assets (seed + params instead of pixels).
`apply_recipe()` dispatches on `r.kind` to call the appropriate generator.

| Kind | Function | Generator |
|------|----------|-----------|
| `"texture"` | Noise/gradient/checker/circle textures | `gen/gen_texture_image` |
| `"sprite"` | Mirrored pixel-art sprites | `gen/gen_sprite_image` |
| `"pixels"` | Hand-drawn char-map pixel art | inline image fill |
| `"terrain"` | 3D heightmap mesh | `gen/gen_terrain_model` |
| `"mesh"` | Primitive meshes (cube/sphere/etc.) | `gen/gen_primitive_model` |
| `"sound"` | Synthesized waveforms | `gen/gen_sound_wave` |
| `"shader"` | GLSL 330 fragment shaders | `register_shader` (compile) |

## Script (`src/script/`)

### Lua state (lua_state.odin)

- Single Lua 5.4 VM per game
- `call_update`, `call_draw`, `call_draw_3d`, `call_gui` — safe wrappers that
  catch errors and mark the script as broken
- Hot reload: tracks file mtimes, calls `on_reload()`, re-runs changed modules
- Time scale: `time_scale` multiplier, `paused` flag, `step_count` for frame stepping
- Error harness: broken scripts show a banner + error details overlay

### API bindings (api_*.odin)

Each `api_*.odin` file registers a group of Lua globals:

| File | Functions |
|------|-----------|
| `api_draw.odin` | `draw_rect`, `draw_circle`, `draw_text`, `draw_sprite`, `draw_cube`, ... |
| `api_entity.odin` | `spawn_sprite`, `despawn`, `set_pos`, `get_pos`, `set_rot`, `set_scale`, ... |
| `api_gen.odin` | `gen_shader`, `gen_texture`, `gen_sprite`, `gen_sound`, `gen_mesh`, `noise`, ... |
| `api_input.odin` | `key_down`, `key_pressed`, `mouse_pos`, `mouse_down`, `mouse_wheel`, ... |
| `api_misc.odin` | `set_crt`, `set_render_resolution`, `set_screen_shader`, `set_lighting`, ... |
| `api.odin` | Registration hub, argument helpers, GameObject prelude |

### GameObject prelude (prelude.odin)

A ~370-line Lua source string injected into every VM. Provides the
`GameObject` class (Unity-style objects, components, parenting, tags).
The engine's only hook is `__gungnir_update(dt)` which calls all live
component updates.

## Generation (`src/gen/`)

Stateless pure-Odin generators driven by seeds:

| File | Output |
|------|--------|
| `noise.odin` | OpenSimplex2 noise (2D/3D) |
| `palette.odin` | Color palette generation |
| `texture.odin` | Sprite images, noise textures, pixel-art |
| `mesh.odin` | Terrain heightfields, primitive shapes |
| `audio.odin` | Synthesized waveforms (square/sine/saw/noise) |

All generators are deterministic given the same seed.

## Editor (`src/editor/`)

The editor runs as a state layer over the engine:

- **Edit mode**: free camera, grid snapping, entity selection, inspector panels
- **Play mode**: snapshot scene → run script → restore on stop
- **Inspector**: transforms, tint, text, recipe params (live drag seed)
- **Undo**: snapshot-based (scene save before each action)
- **3D view**: orbit camera, 3D entity creation

The editor is entirely optional — games run without it.

## Main loop (`src/main.odin`)

The frame loop switches between editing and running:

```
┌─ parse flags ──────────────────────────┐
│ game_dir, --editor, --3d, --hot, --shot │
└──────────────┬──────────────────────────┘
               ▼
┌─ init ──────────────────────────────────┐
│ raylib window, Engine, Script, Editor   │
└──────────────┬──────────────────────────┘
               ▼
     ┌─── frame loop ───┐
     │                  │
     ▼                  ▼
  editing            running
  ───────            ───────
  editor.update      script.tick_hot_reload
                     script.call_update
     │                  │
     └── render ────────┘
     │
     ├─ lighting_render_lightmap
     ├─ begin_frame
     ├─ 3D pass (entities + script on_draw_3d)
     ├─ 2D pass (entities + script on_draw)
     ├─ lighting_composite_2d
     ├─ script on_gui
     ├─ editor panels (if enabled)
     └─ end_frame
     │
     └── screenshot (--shot)
```

## Adding features

To add a Lua API function: write `l_my_func` in the relevant `api_*.odin`,
register it, add to `.luarc.json`, and add to `docs/api.md`. See each
`api_*.odin` file for the pattern.

To add a shader preset: write a `.fs` file to `presets/`. It becomes
available via `set_screen_shader("basename")`.
