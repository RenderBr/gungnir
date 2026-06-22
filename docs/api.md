# Lua API reference

Everything is a global function. Positions are entity centers (text: top-left).
Colors are 0–255 RGB(A); hex colors are `"#rrggbb"` or `"#rrggbbaa"` strings.

## Callbacks (define any you need)

| Callback | When |
|---|---|
| `on_init()` | once at start (and on restart / editor Play) |
| `on_update(dt)` | every frame; `dt` in seconds (scaled by time_scale) |
| `on_draw()` | 2D world space (camera applies) |
| `on_draw_3d()` | 3D world space (camera 3D applies) |
| `on_gui()` | screen space, drawn last |
| `on_reload()` | after a successful hot reload (with `--hot`); re-gen textures, restore state that didn't survive |

## Modules

Your game directory is on `package.path`, so `require("foo")` loads
`<game_dir>/foo.lua`. Split large games across files freely:

```lua
-- jokers.lua
local M = {}
function M.list() return {"joker_a", "joker_b"} end
return M

-- main.lua
local jokers = require("jokers")
function on_init() print(jokers.list()) end
```

With `--hot`, saving **any** `.lua` file in the game directory triggers a
reload — not just `main.lua`. Required modules are cleared from
`package.loaded` on reload, so edits to `jokers.lua` are picked up without
restarting.

With `--hot`, saving `.png`/`.wav`/`.ogg` files in `assets/` also
hot-reloads them — already-loaded textures and sounds are re-read from
disk. Edit a sprite in Aseprite, save, and see it live.

## Entities

| Function | Notes |
|---|---|
| `spawn_sprite(texture, x, y) -> id` | texture by name (generated or `assets/<name>.png`) |
| `spawn_shape(kind, x, y, w [, h]) -> id` | kind `"rect"` or `"circle"` (w = diameter) |
| `spawn_text(str, x, y [, size]) -> id` | |
| `spawn_mesh(model, x, y, z) -> id` | model by name (generated) |
| `despawn(id)` | |
| `exists(id) -> bool` | ids are safe after despawn — they just stop resolving |
| `find(name) -> id or nil` | |
| `get_pos(id) -> x, y, z` | |
| `set_pos(id, x, y [, z])` | z = draw layer in 2D, world z for meshes |
| `move(id, dx, dy [, dz])` | adds to current position; flat-API parity with `obj:move()`, avoids the get_pos/set_pos dance |
| `set_rot(id, deg)` / `set_rot(id, x, y, z)` | |
| `set_scale(id, s)` / `set_scale(id, sx, sy [, sz])` | |
| `set_tint(id, r, g, b [, a])` | |
| `set_name(id, name)` | |
| `set_text(id, str)` | text entities only |
| `set_flip(id, flip_x, flip_y)` | sprites only |
| `set_texture(id, name)` | sprites only; swap texture (animation frames) |
| `set_model_texture(model, texture)` | binds `assets/<texture>.png/.jpg` to a generated 3D model; enables repeat wrapping and 16x anisotropic filtering |

## GameObjects (optional layer)

A Unity-style layer over the entity API, written in pure Lua. Fully opt-in:
the flat functions above keep working, and the two mix freely (`obj.id` is
the raw entity id, `GameObject.wrap(id)` adopts an existing entity).

| Constructor / static | Notes |
|---|---|
| `GameObject{name=, sprite=, x=, y=, ...} -> obj` | visual forms: `sprite="tex"`, `shape="rect"/"circle"` (`w=`, `h=`), `text="str"` (`size=`), `mesh="model"` (`z=`); no visual key = 16x16 rect. Extra opts: `z`, `rot`, `scale`, `tint={r,g,b[,a]}`, `tag` |
| `GameObject("name")` | name-only shorthand (placeholder rect) |
| `GameObject.wrap(id) -> obj or nil` | adopt an existing entity; its current rotation is assumed 0 |
| `GameObject.find(name) -> obj or nil` | first live object with that name |
| `GameObject.all() -> {obj, ...}` | |
| `GameObject.with_tag(tag) -> {obj, ...}` | |

| Method | Notes |
|---|---|
| `obj:pos() -> x, y, z` | |
| `obj:set_pos(x, y [, z])` / `obj:move(dx, dy [, dz])` | |
| `obj:rotate(deg)` | relative; rotation is tracked Lua-side — do not mix with flat `set_rot` on the same entity |
| `obj:set_scale(s)` / `obj:tint(r, g, b [, a])` | |
| `obj:destroy()` | destroys children too; pruned from the registry at end of frame |
| `obj:alive() -> bool` | |
| `obj:set_parent(other_or_nil)` | keeps current world offset; see parenting below |
| `obj:tag(t)` / `obj:untag(t)` / `obj:has_tag(t)` | |
| `obj:add_component{start=, update=, on_destroy=} -> comp` | `comp:remove()` detaches it |

Properties: `obj.x`, `obj.y`, `obj.z`, `obj.name` read/write; `obj.id` read.
Any other field is yours (`obj.vx = 5`). Setters return `obj` for chaining.
Every method is safe after the entity is despawned — no-op, never an error.

Components: `start(self, go)` runs once, right before the first
`update(self, go, dt)`; updates run every frame after your `on_update(dt)`.
`on_destroy(self, go)` fires exactly once — on `obj:destroy()`,
`comp:remove()`, or when the entity dies externally (`despawn`,
`clear_scene`, `load_level`; pruned at end of frame).

Parenting: children follow the parent's position and z-rotation each frame
(2D simplification — parent x/y euler rotation does not propagate). Moving
or rotating a parented child re-bases its local offset, Unity-style.

## Drawing (immediate)

`set_color(r, g, b [, a])` sets the color used by the shape/text calls below.

| Function | Context |
|---|---|
| `draw_rect(x, y, w, h)` | `on_draw` / `on_gui`; top-left corner |
| `draw_rect_outline(x, y, w, h [, thickness])` | top-left corner; thickness default 1 |
| `draw_rounded_rect(x, y, w, h [, roundness])` | top-left corner; roundness 0..1 (0 = square, 1 = fully rounded), default 0.2 |
| `draw_rounded_rect_outline(x, y, w, h [, roundness, thickness])` | defaults 0.2, 2 |
| `draw_circle(x, y, r)` | centered on x,y |
| `draw_line(x1, y1, x2, y2 [, thickness])` | |
| `draw_text(str, x, y [, size])` | top-left corner |
| `text_width(str, size) -> px` | width in the default font; use to center text |
| `draw_sprite(texture, x, y [, rot, scale])` | centered |
| `draw_cube(x, y, z, w, h, d)` | `on_draw_3d` only |
| `draw_sphere(x, y, z, r)` | `on_draw_3d` only |
| `draw_grid([slices, spacing])` | `on_draw_3d` only |

## Camera & screen

| Function | Notes |
|---|---|
| `set_camera(x, y [, zoom, rot])` | centers the 2D camera on x,y |
| `set_camera_3d(px, py, pz, tx, ty, tz [, fov])` | position + look-at target |
| `screen_size() -> w, h` | |

## Lighting

Lights are entities: move them with `set_pos`, color them with `set_tint`,
name/save them like anything else (the editor has a "+ light" button).
The 2D world (and any 3D beneath it) is multiplied by ambient + lights;
`on_gui` is never darkened. 3D models get per-pixel Lambert + Blinn-Phong
specular, distance fog (squared falloff, mixed with `set_clear_color` up to
72%), and micro-normal detail derived from the bound albedo texture for
photo-realistic grazing response.

| Function | Notes |
|---|---|
| `set_lighting(on)` | enables the lighting system (off by default) |
| `set_ambient(r, g, b)` | base light level (default 60, 60, 75) |
| `spawn_light(x, y [, z]) -> id` | point light; default radius 160, intensity 1 |
| `spawn_directional_light() -> id` | sunlight-style infinite light; aim it with `set_rot` and color with `set_tint` |
| `set_light(id, radius [, intensity])` | radius in world units; intensity 0–4 |

## Input

| Function | Notes |
|---|---|
| `key_down(name)` / `key_pressed(name)` | `"a"`…`"z"`, `"0"`…`"9"`, `"up"`, `"down"`, `"left"`, `"right"`, `"space"`, `"enter"`, `"escape"`, `"tab"`, `"shift"`, `"ctrl"`, `"alt"`, `"cmd"` |
| `mouse_pos() -> x, y` | screen coordinates |
| `mouse_delta() -> dx, dy` | cursor delta since last frame; use with `disable_cursor` for FPS-style look |
| `mouse_down([btn])` / `mouse_pressed([btn])` | btn `"left"` (default), `"right"`, `"middle"` |
| `mouse_wheel() -> delta` | |
| `disable_cursor()` | hide and lock cursor to window center |
| `enable_cursor()` | show and unlock cursor |

## Procedural generation

All generation is seeded and deterministic. Generated assets are referenced
by name everywhere a file asset would be, and saved into levels as recipes.

| Function | Notes |
|---|---|
| `gen_sprite(name, w, h, seed [, palette])` | mirrored pixel sprite; palette = array of hex strings |
| `gen_pixels(name, rows, palette)` | hand-drawn pixel art: rows = array of strings, palette maps chars to hex (`{y="#ffff00"}`); `.` and space = transparent |
| `gen_texture(name, w, h [, opts])` | opts: `kind` (`"noise"`, `"gradient"`, `"checker"`, `"circle"`), `seed`, `scale`, `cells`, `horizontal`, `color`, `color2` |
| `gen_palette(n [, seed]) -> {hex, ...}` | |
| `gen_sound(name [, opts])` | opts: `wave` (`"sine"`, `"square"`, `"saw"`, `"triangle"`, `"noise"`), `freq`, `slide`, `len`, `attack`, `vol`, `seed` |
| `gen_mesh(name, kind [, a, b, c])` | `"cube"` (w,h,d), `"sphere"` (r), `"plane"` (w,d), `"cylinder"` (r,h), `"torus"` (radius,tube) |
| `gen_mesh_terrain(name, cells_w, cells_d [, opts])` | opts: `seed`, `cell`, `height`, `scale`, `ridged`, `colors` |
| `gen_shader(name, code) -> ok` | compile a GLSL 330 fragment shader; `false` + console log on compile error (previous version kept) |
| `noise(x, y [, z]) -> -1..1` | OpenSimplex2, seeded by `srand` |
| `srand(seed)` / `rand([a [, b]])` | `rand()` → [0,1), `rand(a)` → [0,a), `rand(a,b)` → [a,b) |
| `session_seed() -> integer` | run-unique wall-clock seed for non-repeatable procedural systems |

## Scene & misc

| Function | Notes |
|---|---|
| `load_level(name) -> bool` | loads `<game>/<name>.json`, replacing the scene |
| `save_level([name]) -> bool` | writes scene + recipes to `<game>/<name>.json` |
| `clear_scene()` | |
| `play_sound(name [, volume, pitch])` | plays a sound by name (generated, or loaded via `load_sound_slice` / the `assets/<name>.wav`/`.ogg` fallback); missing name = silent no-op |
| `load_sound_slice(name, file, start, end) -> bool` | loads `[start, end)` seconds of `assets/<file>` and registers it as `<name>`; `play_sound(name)` then plays just that slice. `false` = missing/undecodable file or bad range; a failed slice never crashes |
| `clamp(x, lo, hi) -> x` | clamps x to `[lo, hi]`; replaces `math.max(lo, math.min(hi, x))` |
| `circle_hit(a, b, r) -> bool` | true if `a` and `b` are within `r` (circular collision). `a`/`b` accept an entity id or a `{x=,y=}` table (GameObjects work too); `r` is the sum of radii or a single radius |
| `rect_hit(a, b, w, h) -> bool` | true if the axis-aligned rects centered on `a` and `b` overlap. `w`/`h` are full widths/heights. `a`/`b` accept entity id or `{x=,y=}` table |
| `set_clear_color(r, g, b)` | background |
| `set_crt(on)` | arcade CRT preset: curvature, scanlines, grille, glow; loads the `presets/crt.fs` shader and sets render resolution to 960x600 |
| `set_render_resolution(w, h)` | set the internal render resolution (0, 0 = native window size for hi-res); screen shaders apply at this resolution |
| `set_entity_shader(id, name)` | draw this entity through a custom shader; `nil`/`""` restores default |
| `set_screen_shader(name)` | full-screen shader pass; `name` can be a user shader (`gen_shader`) or a built-in preset (`presets/<name>.fs`); `nil` clears |
| `set_shader_param(shader, param, x [,y,z,w])` | set a uniform: 1 number = float, 2 = vec2, 3 = vec3, 4 = vec4 |
| `set_fullscreen(on)` | borderless fullscreen |
| `set_maximized(on)` | maximize window (keeps title bar, unlike fullscreen) |
| `log(...)` | print to console (also goes to the in-engine console overlay) |
| `quit()` | |

## Time scale & pause

| Function | Notes |
|---|---|
| `set_time_scale(n)` | game speed multiplier; `0` = pause, `0.25` = quarter speed, `1` = normal. Setting to non-zero while paused unpauses |
| `get_time_scale() -> n` | returns current time scale |
| `pause()` | freeze the game (`time_scale = 0`) |
| `step()` | advance exactly one frame while paused, then pause again |

`on_update(dt)` receives `dt * time_scale` when not paused. When paused,
only `step()` advances the game. Use F5 to step and F6 to unpause at the
keyboard.

## Console overlay

| Function | Notes |
|---|---|
| `console_log(msg [, level])` | append to the in-engine console; level: `"info"` (default), `"warn"`, `"error"` |
| `console_dump() -> {entry, ...}` | returns the full log as an array of `{message=, level=}` tables |

Toggle the console with **`** (backtick). The last 8 log entries are
shown in a dark panel at the bottom of the screen. `console_log` also
appears in the console overlay, so you can see `log()` output without a
terminal window.

## Args passthrough

| Function | Notes |
|---|---|
| `get_args() -> {arg1, ...}` | command-line args passed after `--` (e.g. `game -- --seed=42` → `{"--seed=42"}`) |

Unrecognized CLI flags (`--anything`) are also captured and available via
`get_args()`, so games can read config from the command line without
engine changes.

## Debug overlay

Press **F3** to toggle FPS, entity count, and time scale on screen.
Shows `"PAUSED"` when the game is frozen, with F5/F6 hints.

## Custom shaders

`gen_shader` compiles a full GLSL 330 fragment shader against raylib's default
vertex shader. The boilerplate contract:

- inputs: `in vec2 fragTexCoord;` and `in vec4 fragColor;`
- uniforms: `uniform sampler2D texture0;` and `uniform vec4 colDiffuse;`
- output: `out vec4 finalColor;`
- auto-fed each frame when declared: `uniform float time;` (seconds) and
  `uniform vec2 resolution;` (the canvas the shader's output is measured in)
- other uniforms read as 0 until `set_shader_param` sets them; setting a
  uniform the compiler stripped is a silent no-op
- per-entity shaders force a batch flush per shaded entity — fine for dozens
  of entities, not thousands
- shapes draw from a small white texture, so `texture0` samples ~white and
  `fragTexCoord` is ~constant — color/time effects work, UV gradients don't
- text samples the font atlas: UVs are atlas-space, alpha comes from the glyph

```lua
-- color-cycle shader: hue-shifts whatever it draws over time
gen_shader("cycle", [[
#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;
uniform float speed;
out vec4 finalColor;
void main() {
    vec4 c = texture(texture0, fragTexCoord) * colDiffuse * fragColor;
    float a = time * speed;
    vec3 shift = vec3(0.5 + 0.5*sin(a),
                      0.5 + 0.5*sin(a + 2.094),
                      0.5 + 0.5*sin(a + 4.188));
    finalColor = vec4(c.rgb * shift, c.a);
}
]])

function on_init()
  set_shader_param("cycle", "speed", 2.0)
  gen_sprite("ship", 16, 16, 42)
  ship = spawn_sprite("ship", 480, 300)
  set_scale(ship, 6)
  set_entity_shader(ship, "cycle")   -- per-entity
  -- set_screen_shader("cycle")      -- or whole screen shader
end
```
