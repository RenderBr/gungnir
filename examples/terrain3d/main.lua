-- terrain3d: fly over generated terrain. WASD to move, q/e to turn.
-- 2D HUD over a 3D world in one scene.

SEED = 42

function on_init()
  srand(SEED)
  gen_mesh_terrain("ground", 128, 128, {
    seed = SEED, cell = 2, height = 22, scale = 28,
  })
  terrain = spawn_mesh("ground", 0, 0, 0)

  gen_mesh("marker", "cube", 2, 6, 2)
  marker = spawn_mesh("marker", 0, 14, 0)
  set_tint(marker, 255, 80, 80)

  gen_sprite("compass", 10, 10, SEED)

  cx, cz = 0, 90      -- camera position on the XZ plane
  angle = -math.pi / 2 -- facing -z (toward origin)
  cam_h = 35
end

function on_update(dt)
  local speed = 40
  if key_down("q") then angle = angle - 1.6 * dt end
  if key_down("e") then angle = angle + 1.6 * dt end

  local fx, fz = math.cos(angle), math.sin(angle)
  if key_down("w") then cx = cx + fx * speed * dt; cz = cz + fz * speed * dt end
  if key_down("s") then cx = cx - fx * speed * dt; cz = cz - fz * speed * dt end
  if key_down("a") then cx = cx + fz * speed * dt; cz = cz - fx * speed * dt end
  if key_down("d") then cx = cx - fz * speed * dt; cz = cz + fx * speed * dt end

  set_camera_3d(cx, cam_h, cz, cx + fx * 30, cam_h - 12, cz + fz * 30)
  set_rot(marker, 0, angle * 57.3, 0)
end

function on_draw_3d()
  set_color(255, 255, 255, 60)
  draw_grid(40, 8)
end

function on_gui()
  local w, h = screen_size()
  set_color(255, 255, 255)
  draw_text("wasd to fly, q/e to turn", 10, 10, 20)
  draw_sprite("compass", w - 40, 40, angle * 57.3 + 90, 4)
  set_color(120, 220, 120, 150)
  draw_text(string.format("pos %.0f, %.0f", cx, cz), 10, h - 30, 18)
end
