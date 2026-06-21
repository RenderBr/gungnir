-- invaders: every sprite and sound generated from seeds.
-- Change SEED for a whole new skin. GameObject + move + clamp + rect_hit
-- showcase: positions live on the objects (no parallel x/y tables), the
-- ship and bullets use move(), collisions use rect_hit.

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

  ship = GameObject{sprite="ship", x=W/2, y=H-50, scale=4, tag="ship"}

  aliens = {}
  for row = 0, 3 do
    for col = 0, 9 do
      local kind = "alien" .. (row % 3 + 1)
      local x, y = 120 + col*75, 70 + row*60
      local a = GameObject{sprite=kind, x=x, y=y, scale=4, tag="alien"}
      a.home_x, a.home_y = x, y
      aliens[#aliens + 1] = a
    end
  end

  stars = {}
  for i = 1, 60 do
    stars[i] = { x = rand(W), y = rand(H), speed = 20 + rand(60) }
  end

  t, score = 0, 0
  score_label = spawn_text("score 0", 12, H - 30, 20)
  set_tint(score_label, 255, 255, 255, 170)
end

function on_update(dt)
  t = t + dt

  -- ship
  if key_down("left")  then ship:move(-380 * dt, 0) end
  if key_down("right") then ship:move( 380 * dt, 0) end
  ship.x = clamp(ship.x, 30, W - 30)

  if key_pressed("space") then
    local b = GameObject{sprite="bullet", x=ship.x, y=ship.y - 30, tag="bullet"}
    b:add_component{
      update = function(self, go, dt)
        go:move(0, -600 * dt)
        if go.y < -20 then go:destroy() end
      end,
    }
    play_sound("shoot")
  end

  -- alien swarm marches side to side
  local shift = math.sin(t * 1.2) * 60
  local drop = t * 6
  for _, a in ipairs(aliens) do
    if a:alive() then a:set_pos(a.home_x + shift, a.home_y + drop) end
  end

  -- collisions: each bullet vs each live alien
  for _, b in ipairs(GameObject.with_tag("bullet")) do
    for _, a in ipairs(GameObject.with_tag("alien")) do
      if b:alive() and a:alive() and rect_hit(b, a, 26, 22) then
        b:destroy()
        a:destroy()
        play_sound("boom")
        score = score + 10
        set_text(score_label, "score " .. score)
        break
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
