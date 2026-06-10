-- asteroids: GameObject showcase — components, tags, parenting, all assets generated.

SEED = 11

local function wrap_around(go)
  if go.x < -24 then go.x = W + 24 elseif go.x > W + 24 then go.x = -24 end
  if go.y < -24 then go.y = H + 24 elseif go.y > H + 24 then go.y = -24 end
end

local function hit(a, b, r)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy < r * r
end

function spawn_rock(x, y, tier)
  local rock = GameObject{name="rock", sprite="rock", x=x, y=y, scale=tier * 1.6, tag="asteroid"}
  rock.tier, rock.r = tier, 10 * tier
  local a, sp = rand(0, math.pi * 2), 110 - tier * 25
  rock.vx, rock.vy = math.cos(a) * sp, math.sin(a) * sp
  rock.spin = rand(-120, 120)
  rock:add_component{
    update = function(self, go, dt)
      go:move(go.vx * dt, go.vy * dt)
      go:rotate(go.spin * dt)
      wrap_around(go)
    end,
  }
end

function spawn_wave(n)
  for i = 1, n do
    spawn_rock(rand(W), rand(2) < 1 and rand(H / 4) or H - rand(H / 4), 3)
  end
end

function fire()
  local r = math.rad(ship.angle)
  local dx, dy = math.sin(r), -math.cos(r)
  local b = GameObject{name="bullet", sprite="bullet", x=ship.x + dx * 20, y=ship.y + dy * 20, tag="bullet"}
  b.vx, b.vy = dx * 430 + ship.vx, dy * 430 + ship.vy
  b.life = 1.1
  b:add_component{
    update = function(self, go, dt)
      go:move(go.vx * dt, go.vy * dt)
      go.life = go.life - dt
      if go.life <= 0 then go:destroy() end
      wrap_around(go)
    end,
  }
  play_sound("shoot")
end

local function reset_ship()
  ship:rotate(-ship.angle)
  ship.angle, ship.vx, ship.vy = 0, 0, 0
  ship:set_pos(W / 2, H / 2)
end

function on_init()
  set_crt(true) -- arcade look; also pins the logical canvas to 960x600
  W, H = screen_size()
  srand(SEED)
  set_clear_color(8, 10, 24)

  gen_pixels("ship", {
    "...y...",
    "..yoy..",
    ".yo.oy.",
    ".yoooy.",
    "yo...oy",
    "y..y..y",
  }, { y = "#9fd8ff", o = "#3b6ea5" })
  gen_sprite("rock", 12, 12, SEED, gen_palette(3, SEED))
  gen_texture("bullet", 4, 4, { kind = "circle", color = "#ffee88" })
  gen_sound("shoot", { wave = "square", freq = 900, slide = -1400, len = 0.1 })
  gen_sound("boom", { wave = "noise", freq = 90, len = 0.3, vol = 0.6 })

  score, lives = 0, 3
  stars = {}
  for i = 1, 50 do stars[i] = { x = rand(W), y = rand(H) } end

  ship = GameObject{name="ship", sprite="ship", x=W / 2, y=H / 2, scale=3}
  ship.angle, ship.vx, ship.vy = 0, 0, 0
  ship:add_component{
    update = function(self, go, dt)
      local turn = (key_down("left") and -240 or 0) + (key_down("right") and 240 or 0)
      go:rotate(turn * dt)
      go.angle = go.angle + turn * dt
      local r = math.rad(go.angle)
      if key_down("up") then
        go.vx = go.vx + math.sin(r) * 280 * dt
        go.vy = go.vy - math.cos(r) * 280 * dt
        flame:tint(255, 170, 60, 255)
      else
        flame:tint(255, 170, 60, 0)
      end
      go:move(go.vx * dt, go.vy * dt)
      wrap_around(go)
    end,
  }
  -- thruster: parented child, trails behind the ship as it turns
  flame = GameObject{name="flame", shape="circle", x=W / 2, y=H / 2 + 16, w=10, tint={255, 170, 60, 0}}
  flame:set_parent(ship)

  spawn_wave(5)
end

function on_update(dt)
  if key_pressed("space") then fire() end
  local rocks = GameObject.with_tag("asteroid")
  for _, b in ipairs(GameObject.with_tag("bullet")) do
    for _, rock in ipairs(rocks) do
      if b:alive() and rock:alive() and hit(b, rock, rock.r) then
        b:destroy()
        rock:destroy()
        score = score + (4 - rock.tier) * 25
        play_sound("boom")
        if rock.tier > 1 then
          spawn_rock(rock.x, rock.y, rock.tier - 1)
          spawn_rock(rock.x, rock.y, rock.tier - 1)
        end
      end
    end
  end
  local live = 0
  for _, rock in ipairs(GameObject.with_tag("asteroid")) do
    if rock:alive() then
      live = live + 1
      if hit(ship, rock, rock.r + 9) then
        lives = lives - 1
        play_sound("boom")
        reset_ship()
        if lives <= 0 then score, lives = 0, 3 end
      end
    end
  end
  if live == 0 then spawn_wave(5) end
end

function on_draw()
  set_color(150, 160, 200)
  for _, s in ipairs(stars) do draw_rect(s.x, s.y, 2, 2) end
end

function on_gui()
  set_color(255, 255, 255)
  draw_text("SCORE " .. score, 16, 12, 24)
  draw_text("LIVES " .. lives, W - 110, 12, 24)
end
