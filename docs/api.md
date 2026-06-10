# Lua API reference

Everything is a global function. Positions are entity centers (text: top-left).
Colors are 0–255 RGB(A); hex colors are `"#rrggbb"` or `"#rrggbbaa"` strings.

## Callbacks (define any you need)

| Callback | When |
|---|---|
| `on_init()` | once at start (and on restart / editor Play) |
| `on_update(dt)` | every frame; `dt` in seconds |
| `on_draw()` | 2D world space (camera applies) |
| `on_draw_3d()` | 3D world space (camera 3D applies) |
| `on_gui()` | screen space, drawn last |

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
| `set_rot(id, deg)` / `set_rot(id, x, y, z)` | |
| `set_scale(id, s)` / `set_scale(id, sx, sy [, sz])` | |
| `set_tint(id, r, g, b [, a])` | |
| `set_name(id, name)` | |
| `set_text(id, str)` | text entities only |
| `set_flip(id, flip_x, flip_y)` | sprites only |

## Drawing (immediate)

`set_color(r, g, b [, a])` sets the color used by the shape/text calls below.

| Function | Context |
|---|---|
| `draw_rect(x, y, w, h)` | `on_draw` / `on_gui` |
| `draw_circle(x, y, r)` | |
| `draw_line(x1, y1, x2, y2 [, thickness])` | |
| `draw_text(str, x, y [, size])` | |
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

## Input

| Function | Notes |
|---|---|
| `key_down(name)` / `key_pressed(name)` | `"a"`…`"z"`, `"0"`…`"9"`, `"up"`, `"down"`, `"left"`, `"right"`, `"space"`, `"enter"`, `"escape"`, `"tab"`, `"shift"`, `"ctrl"`, `"alt"`, `"cmd"` |
| `mouse_pos() -> x, y` | screen coordinates |
| `mouse_down([btn])` / `mouse_pressed([btn])` | btn `"left"` (default), `"right"`, `"middle"` |
| `mouse_wheel() -> delta` | |

## Procedural generation

All generation is seeded and deterministic. Generated assets are referenced
by name everywhere a file asset would be, and saved into levels as recipes.

| Function | Notes |
|---|---|
| `gen_sprite(name, w, h, seed [, palette])` | mirrored pixel sprite; palette = array of hex strings |
| `gen_texture(name, w, h [, opts])` | opts: `kind` (`"noise"`, `"gradient"`, `"checker"`, `"circle"`), `seed`, `scale`, `cells`, `horizontal`, `color`, `color2` |
| `gen_palette(n [, seed]) -> {hex, ...}` | |
| `gen_sound(name [, opts])` | opts: `wave` (`"sine"`, `"square"`, `"saw"`, `"triangle"`, `"noise"`), `freq`, `slide`, `len`, `attack`, `vol`, `seed` |
| `gen_mesh(name, kind [, a, b, c])` | `"cube"` (w,h,d), `"sphere"` (r), `"plane"` (w,d), `"cylinder"` (r,h) |
| `gen_mesh_terrain(name, cells_w, cells_d [, opts])` | opts: `seed`, `cell`, `height`, `scale`, `ridged`, `colors` |
| `noise(x, y [, z]) -> -1..1` | OpenSimplex2, seeded by `srand` |
| `srand(seed)` / `rand([a [, b]])` | `rand()` → [0,1), `rand(a)` → [0,a), `rand(a,b)` → [a,b) |

## Scene & misc

| Function | Notes |
|---|---|
| `load_level(name) -> bool` | loads `<game>/<name>.json`, replacing the scene |
| `save_level([name]) -> bool` | writes scene + recipes to `<game>/<name>.json` |
| `clear_scene()` | |
| `play_sound(name [, volume, pitch])` | |
| `set_clear_color(r, g, b)` | background |
| `set_crt(on)` | arcade CRT filter: curvature, scanlines, grille, glow; renders at 960x600 and upscales |
| `set_fullscreen(on)` | borderless fullscreen |
| `log(...)` | print to console |
| `quit()` | |
