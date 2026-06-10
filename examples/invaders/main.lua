-- invaders: every sprite and sound generated from seeds.
-- Change SEED for a whole new skin.

SEED = 7

function on_init()
  W, H = screen_size()
  srand(SEED)

  local alien_colors = gen_palette(4, SEED)
  local ship_colors = gen_palette(4, SEED + 99)

  gen_sprite("alien1", 12, 10, SEED + 1, alien_colors)
  gen_sprite("alien2", 12, 10, SEED + 2, alien_colors)
  gen_sprite("alien3", 12, 10, SEED + 3, alien_colors)
  gen_sprite("ship", 14, 12, SEED + 4, ship_colors)
  gen_texture("bullet", 4, 10, { kind = "gradient", color = "#ffffaa", color2 = "#ff8800" })
  gen_texture("star", 2, 2, { kind = "circle", color = "#ffffff" })

  gen_sound("shoot", { wave = "square", freq = 880, slide = -1200, len = 0.12 })
  gen_sound("boom", { wave = "noise", freq = 100, len = 0.25, vol = 0.6 })

  ship = spawn_sprite("ship", W / 2, H - 50)
  set_scale(ship, 4)

  aliens = {}
  for row = 0, 3 do
    for col = 0, 9 do
      local kind = "alien" .. (row % 3 + 1)
      local a = spawn_sprite(kind, 120 + col * 75, 70 + row * 60)
      set_scale(a, 4)
      aliens[#aliens + 1] = { id = a, x = 120 + col * 75, y = 70 + row * 60 }
    end
  end

  stars = {}
  for i = 1, 60 do
    stars[i] = { x = rand(W), y = rand(H), speed = 20 + rand(60) }
  end

  bullets = {}
  dir, t, score = 1, 0, 0
  score_label = spawn_text("score 0", 12, H - 30, 20)
  set_tint(score_label, 255, 255, 255, 170)
end

function on_update(dt)
  t = t + dt

  -- ship
  local sx, sy = get_pos(ship)
  if key_down("left") then sx = sx - 380 * dt end
  if key_down("right") then sx = sx + 380 * dt end
  sx = math.max(30, math.min(W - 30, sx))
  set_pos(ship, sx, sy)

  if key_pressed("space") then
    bullets[#bullets + 1] = spawn_sprite("bullet", sx, sy - 30)
    play_sound("shoot")
  end

  -- bullets
  for i = #bullets, 1, -1 do
    local b = bullets[i]
    local bx, by = get_pos(b)
    by = by - 600 * dt
    if by < -20 then
      despawn(b)
      table.remove(bullets, i)
    else
      set_pos(b, bx, by)
    end
  end

  -- alien swarm marches side to side
  local shift = math.sin(t * 1.2) * 60
  local drop = t * 6
  for _, a in ipairs(aliens) do
    if exists(a.id) then
      set_pos(a.id, a.x + shift, a.y + drop)
    end
  end

  -- collisions
  for i = #bullets, 1, -1 do
    local b = bullets[i]
    if exists(b) then
      local bx, by = get_pos(b)
      for _, a in ipairs(aliens) do
        if exists(a.id) then
          local ax, ay = get_pos(a.id)
          if math.abs(bx - ax) < 26 and math.abs(by - ay) < 22 then
            despawn(a.id)
            despawn(b)
            table.remove(bullets, i)
            play_sound("boom")
            score = score + 10
            set_text(score_label, "score " .. score)
            break
          end
        end
      end
    end
  end

  -- starfield
  for _, s in ipairs(stars) do
    s.y = s.y + s.speed * dt
    if s.y > H then s.y = 0; s.x = rand(W) end
  end
end

function on_draw()
  for _, s in ipairs(stars) do
    draw_sprite("star", s.x, s.y)
  end
end

function on_gui()
  set_color(255, 255, 255, 110)
  draw_text("left/right to move, space to shoot  (seed " .. SEED .. ")", 10, 10, 16)
end
