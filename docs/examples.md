# Examples

Nine example games demonstrate the engine from minimal to full arcade. Run
any of them:

```bash
./run.sh examples/<name>       # macOS / Linux
.\run.bat examples\<name>      # Windows
```

Add `--hot` to enable script hot reload, or `--editor` to open the level
designer.

---

## 1. hello (37 lines) — start here

Minimal bouncing ball. Covers: `on_init` / `on_update` / `on_draw` / `on_gui`
callbacks, `screen_size`, `draw_circle`, `key_down`, basic movement.

**Key takeaway:** A complete game in one file with no object system.

---

## 2. orbit (20 lines) — simplest parenting

A planet with a moon child object. Click to spawn drifting stars with
component-based movement.

**Key takeaway:** `GameObject` parenting — child transforms are relative to
the parent.

---

## 3. pong (50 lines) — GameObjects + collision

Pong clone using the `GameObject` layer. Covers: `clamp`, `rect_hit`
collision, `spawn_text` for scoring, `set_text` for dynamic HUD updates.

**Key takeaway:** GameObject properties (`ball.vx`, `ball.vy`) and
`rect_hit` for AABB collision.

---

## 4. invaders (104 lines) — procedural assets + components

Space Invaders clone. Every asset is procedurally generated from a seed.
Covers: `gen_sprite`, `gen_sound`, `rand`, `srand`, `add_component`,
`GameObject.with_tag`, `move()`, starfield.

**Key takeaway:** Components for per-entity logic, tags for group queries,
procedural generation.

---

## 5. asteroids (149 lines) — components + parenting + CRT

Asteroids with GameObject components, parenting (thruster flame), and the
CRT arcade look. Covers: `gen_pixels` for hand-drawn sprites, `set_crt`,
parented child transforms, tiered asteroid splitting, wrap-around movement.

**Key takeaway:** `gen_pixels` for pixel-art, `set_crt(true)` for the
arcade CRT preset, child objects for visual effects.

---

## 6. nightfall (143 lines) — lighting + custom shaders

A moonlit meadow demonstrating the lighting system and user-defined screen
shaders. Covers: `set_lighting(true)`, `set_ambient`, `spawn_light`,
`set_light`, `gen_shader`, `set_screen_shader`, `set_shader_param`,
`noise()` for firefly animation.

**Key takeaway:** The lighting pipeline (ambient + point lights) and
custom GLSL screen shaders. `on_gui` is never darkened by lighting.

---

## 7. terrain3d (51 lines) — 3D terrain + 2D HUD

Fly over generated 3D terrain with a 2D HUD overlay. Covers:
`gen_mesh_terrain`, `spawn_mesh`, `set_camera_3d`, WASD+QE camera controls,
`on_draw_3d` callback, `draw_grid`, 2D HUD over 3D world.

**Key takeaway:** 3D and 2D in one scene — the 3D pass runs first, then
2D entities and immediate-mode draws layer on top.

---

## 8. pacman (523 lines over 3 files) — multi-file + full arcade

A faithful Pac-Man clone. Covers: multi-file projects via `require()`,
`gen_pixels` for arcade-accurate sprites, `load_sound_slice` for real arcade
audio, `set_fullscreen`, `set_crt(true)`, state machine
(ready/play/dying/clear/gameover), ghost AI (scatter/chase/fright/eyes),
power pellets, scoring, flashing animations.

**Key takeaway:** Structuring a large game across multiple files. Arcade
audio via `load_sound_slice`.

---

## 9. balatro (1690 lines over 5 files) — complex UI + economy

A Balatro clone, the most complex example. Covers: `set_maximized`,
gen_face_sprites via `gen_pixels`, `draw_rounded_rect`, `text_width` for
centering, word-wrap helpers, generated sounds, UI with particles/tooltips/
toasts, shop/economy system, poker hand evaluation, scaling layout.

**Key takeaway:** Advanced UI patterns and complex game state management
in Lua.

---

## Suggested learning path

Read in order:

1. `hello` — minimal engine usage
2. `pong` — GameObjects and collision
3. `invaders` — procedural assets and components
4. `asteroids` — parenting and CRT effect
5. `nightfall` — lighting and custom shaders
6. `terrain3d` — 3D rendering
7. `pacman` — multi-file project structure
8. `balatro` — complex UI systems
