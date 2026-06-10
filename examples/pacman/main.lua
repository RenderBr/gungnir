-- pacman: the real thing. arrows to move, space to restart after game over.

T = 18 -- tile size in pixels
COLS, ROWS = 28, 31
OX = (960 - COLS * T) / 2
OY = (600 - ROWS * T) / 2

MAZE = {
  "############################",
  "#............##............#",
  "#.####.#####.##.#####.####.#",
  "#o####.#####.##.#####.####o#",
  "#.####.#####.##.#####.####.#",
  "#..........................#",
  "#.####.##.########.##.####.#",
  "#.####.##.########.##.####.#",
  "#......##....##....##......#",
  "######.##### ## #####.######",
  "     #.##### ## #####.#     ",
  "     #.##          ##.#     ",
  "     #.## ###--### ##.#     ",
  "######.## #      # ##.######",
  "      .   #      #   .      ",
  "######.## #      # ##.######",
  "     #.## ######## ##.#     ",
  "     #.##          ##.#     ",
  "     #.## ######## ##.#     ",
  "######.## ######## ##.######",
  "#............##............#",
  "#.####.#####.##.#####.####.#",
  "#.####.#####.##.#####.####.#",
  "#o..##.......  .......##..o#",
  "###.##.##.########.##.##.###",
  "###.##.##.########.##.##.###",
  "#......##....##....##......#",
  "#.##########.##.##########.#",
  "#.##########.##.##########.#",
  "#..........................#",
  "############################",
}

EPS = 1e-4

function px(x) return OX + x * T end
function py(y) return OY + y * T end

function tile_char(tx, ty)
  if ty < 0 or ty >= ROWS or tx < 0 or tx >= COLS then return "#" end
  return MAZE[ty + 1]:sub(tx + 1, tx + 1)
end

function passable(tx, ty)
  if ty == 14 and (tx < 0 or tx >= COLS) then return true end -- tunnel
  local ch = tile_char(tx, ty)
  return ch ~= "#" and ch ~= "-"
end

-- ---------------------------------------------------------------- setup

function on_init()
  set_clear_color(0, 0, 0)

  gen_sound("waka1", { wave = "triangle", freq = 420, slide = -260, len = 0.07, vol = 0.30 })
  gen_sound("waka2", { wave = "triangle", freq = 300, slide = 260, len = 0.07, vol = 0.30 })
  gen_sound("power", { wave = "square", freq = 180, slide = 480, len = 0.35, vol = 0.4 })
  gen_sound("eatghost", { wave = "square", freq = 520, slide = 900, len = 0.25, vol = 0.45 })
  gen_sound("death", { wave = "saw", freq = 640, slide = -520, len = 1.1, vol = 0.45 })

  walls, power_ids = {}, {}
  for ty = 0, ROWS - 1 do
    for tx = 0, COLS - 1 do
      local ch = tile_char(tx, ty)
      if ch == "#" then
        local w = spawn_shape("rect", px(tx + 0.5), py(ty + 0.5), T - 1, T - 1)
        set_tint(w, 28, 28, 160)
        walls[#walls + 1] = w
      elseif ch == "-" then
        local d = spawn_shape("rect", px(tx + 0.5), py(ty + 0.5), T, 4)
        set_tint(d, 255, 184, 222)
      end
    end
  end

  score, lives, level = 0, 3, 1
  score_label = spawn_text("score 0", 10, 4, 18)
  set_tint(score_label, 255, 255, 255)
  level_label = spawn_text("level 1", 870, 4, 18)
  set_tint(level_label, 255, 255, 255)
  life_icons = {}

  pac = { id = spawn_shape("circle", 0, 0, T * 1.5) }
  set_tint(pac.id, 255, 255, 0)
  set_pos(pac.id, 0, 0, 1.1)

  ghosts = {}
  GHOST_DEFS = {
    { name = "blinky", color = { 255, 0, 0 },     corner = { 26, 1 } },
    { name = "pinky",  color = { 255, 184, 255 }, corner = { 1, 1 } },
    { name = "inky",   color = { 0, 255, 255 },   corner = { 26, 29 } },
    { name = "clyde",  color = { 255, 184, 82 },  corner = { 1, 29 } },
  }
  for i, d in ipairs(GHOST_DEFS) do
    local g = { id = spawn_shape("circle", 0, 0, T * 1.5), color = d.color, corner = d.corner }
    set_pos(g.id, 0, 0, 1)
    ghosts[i] = g
  end

  spawn_pellets()
  reset_positions(true)
  sync_actors()
  enter_ready()
end

function spawn_pellets()
  pellets, pellet_count, power_ids = {}, 0, {}
  for ty = 0, ROWS - 1 do
    for tx = 0, COLS - 1 do
      local ch = tile_char(tx, ty)
      if ch == "." or ch == "o" then
        local d = ch == "o" and 13 or 5
        local id = spawn_shape("circle", px(tx + 0.5), py(ty + 0.5), d)
        set_tint(id, 255, 184, 174)
        set_pos(id, px(tx + 0.5), py(ty + 0.5), 0.1)
        pellets[ty * COLS + tx] = { id = id, power = ch == "o" }
        pellet_count = pellet_count + 1
        if ch == "o" then power_ids[#power_ids + 1] = id end
      end
    end
  end
end

function reset_positions(first)
  pac.x, pac.y = 14.0, 23.5
  pac.dx, pac.dy, pac.wdx, pac.wdy = -1, 0, -1, 0
  pac.mouth = 0
  set_scale(pac.id, 1)

  local house = { { 14.0, 11.5 }, { 13.5, 14.5 }, { 11.5, 14.5 }, { 16.5, 14.5 } }
  local delays = first and { -1, 2, 5, 8 } or { -1, 1, 2, 3 }
  for i, g in ipairs(ghosts) do
    g.x, g.y = house[i][1], house[i][2]
    g.dx, g.dy = -1, 0
    g.glide = nil
    if delays[i] < 0 then
      g.state = "normal"
    else
      g.state = "house"
      g.timer = delays[i]
    end
    set_tint(g.id, g.color[1], g.color[2], g.color[3])
  end

  mode, mode_timer = "scatter", 7
  fright_timer, combo, chomp = 0, 0, 0
  blink_t = 0
end

-- ---------------------------------------------------------------- states

function enter_ready()
  state, state_timer = "ready", 2
  if ready_label then despawn(ready_label) end
  ready_label = spawn_text("READY!", px(11.6), py(16.8), 22)
  set_tint(ready_label, 255, 255, 0)
  refresh_lives()
end

function refresh_lives()
  for _, id in ipairs(life_icons) do despawn(id) end
  life_icons = {}
  for i = 1, lives - 1 do
    local id = spawn_shape("circle", OX + i * 24 - 8, 588, 14)
    set_tint(id, 255, 255, 0)
    life_icons[#life_icons + 1] = id
  end
end

-- ---------------------------------------------------------------- movement

function step_actor(a, speed, dt, decide)
  local rem = speed * dt
  local guard = 0
  while rem > EPS and guard < 8 do
    guard = guard + 1
    local cx = math.floor(a.x) + 0.5
    local cy = math.floor(a.y) + 0.5
    if math.abs(a.x - cx) < EPS and math.abs(a.y - cy) < EPS then
      a.x, a.y = cx, cy
      decide(a)
      if a.dx == 0 and a.dy == 0 then return end
      if not passable(math.floor(a.x) + a.dx, math.floor(a.y) + a.dy) then return end
      local m = math.min(rem, 1)
      a.x = a.x + a.dx * m
      a.y = a.y + a.dy * m
      rem = rem - m
    else
      local dist
      if a.dx > 0 then dist = (math.floor(a.x) + 0.5) - a.x
      elseif a.dx < 0 then dist = a.x - (math.floor(a.x) + 0.5)
      elseif a.dy > 0 then dist = (math.floor(a.y) + 0.5) - a.y
      elseif a.dy < 0 then dist = a.y - (math.floor(a.y) + 0.5)
      else return end
      if dist <= EPS then dist = dist + 1 end
      local m = math.min(rem, dist)
      a.x = a.x + a.dx * m
      a.y = a.y + a.dy * m
      rem = rem - m
    end
    if a.x < 0 then a.x = a.x + COLS elseif a.x >= COLS then a.x = a.x - COLS end
  end
end

function pac_decide(p)
  local tx, ty = math.floor(p.x), math.floor(p.y)
  if (p.wdx ~= p.dx or p.wdy ~= p.dy) and passable(tx + p.wdx, ty + p.wdy) then
    p.dx, p.dy = p.wdx, p.wdy
  end
  if not passable(tx + p.dx, ty + p.dy) then p.dx, p.dy = 0, 0 end
end

function ghost_target(g, i)
  if g.state == "eyes" then return 13.5, 11.5 end
  if mode == "scatter" then return g.corner[1] + 0.5, g.corner[2] + 0.5 end
  if i == 1 then return pac.x, pac.y end
  if i == 2 then return pac.x + 4 * pac.dx, pac.y + 4 * pac.dy end
  if i == 3 then
    local bx, by = ghosts[1].x, ghosts[1].y
    local ax, ay = pac.x + 2 * pac.dx, pac.y + 2 * pac.dy
    return 2 * ax - bx, 2 * ay - by
  end
  local d2 = (g.x - pac.x) ^ 2 + (g.y - pac.y) ^ 2
  if d2 > 64 then return pac.x, pac.y end
  return g.corner[1] + 0.5, g.corner[2] + 0.5
end

DIRS = { { 0, -1 }, { -1, 0 }, { 0, 1 }, { 1, 0 } } -- classic priority: up left down right

function ghost_decide_for(i)
  return function(g)
    local tx, ty = math.floor(g.x), math.floor(g.y)
    local choices = {}
    for _, d in ipairs(DIRS) do
      if not (d[1] == -g.dx and d[2] == -g.dy) and passable(tx + d[1], ty + d[2]) then
        choices[#choices + 1] = d
      end
    end
    if #choices == 0 then g.dx, g.dy = -g.dx, -g.dy return end
    if g.state == "fright" then
      local d = choices[math.floor(rand(#choices)) + 1]
      g.dx, g.dy = d[1], d[2]
      return
    end
    local txx, tyy = ghost_target(g, i)
    local best, bd
    for _, d in ipairs(choices) do
      local ddx = (tx + d[1] + 0.5) - txx
      local ddy = (ty + d[2] + 0.5) - tyy
      local dist = ddx * ddx + ddy * ddy
      if not bd or dist < bd then bd, best = dist, d end
    end
    g.dx, g.dy = best[1], best[2]
  end
end

function ghost_speed(g)
  if g.state == "eyes" then return 13 end
  if g.state == "fright" then return 4.4 end
  if math.floor(g.y) == 14 and (g.x < 6 or g.x > 22) then return 4.5 end -- tunnel slow
  return 6.6 + level * 0.15
end

function start_glide(g, tox, toy, dur, next_state)
  g.glide = { fx = g.x, fy = g.y, tx = tox, ty = toy, t = 0, dur = dur, next_state = next_state }
end

function update_ghost(g, i, dt)
  if g.state == "house" then
    g.timer = g.timer - dt
    g.y = g.y + math.sin(t * 4 + i) * 0.4 * dt
    if g.timer <= 0 then
      g.state = "glide"
      start_glide(g, 14.0, 11.5, 0.8, "normal")
    end
  elseif g.state == "glide" then
    local gl = g.glide
    gl.t = math.min(gl.t + dt, gl.dur)
    local k = gl.t / gl.dur
    g.x = gl.fx + (gl.tx - gl.fx) * k
    g.y = gl.fy + (gl.ty - gl.fy) * k
    if gl.t >= gl.dur then
      g.state = gl.next_state
      g.glide = nil
      if g.state == "normal" then g.dx, g.dy = -1, 0 end
      if g.state == "house" then g.timer = 0.6 end
      apply_ghost_tint(g)
    end
  else
    step_actor(g, ghost_speed(g), dt, ghost_decide_for(i))
    if g.state == "eyes" and math.abs(g.x - 13.5) < 0.1 and math.abs(g.y - 11.5) < 0.1 then
      g.state = "glide"
      start_glide(g, 13.5, 14.5, 0.7, "house")
    end
  end
  set_pos(g.id, px(g.x), py(g.y))
end

function apply_ghost_tint(g)
  if g.state == "eyes" then
    set_tint(g.id, 255, 255, 255, 0)
  elseif g.state == "fright" then
    if fright_timer < 2 and math.floor(fright_timer * 4) % 2 == 0 then
      set_tint(g.id, 222, 222, 255)
    else
      set_tint(g.id, 33, 33, 222)
    end
  else
    set_tint(g.id, g.color[1], g.color[2], g.color[3])
  end
end

-- ---------------------------------------------------------------- update

t = 0
function on_update(dt)
  t = t + dt

  if key_down("left") then pac.wdx, pac.wdy = -1, 0 end
  if key_down("right") then pac.wdx, pac.wdy = 1, 0 end
  if key_down("up") then pac.wdx, pac.wdy = 0, -1 end
  if key_down("down") then pac.wdx, pac.wdy = 0, 1 end

  -- power pellet blink
  blink_t = blink_t + dt
  local on = math.floor(blink_t * 4) % 2 == 0
  for _, id in ipairs(power_ids) do
    if exists(id) then set_tint(id, 255, 184, 174, on and 255 or 60) end
  end

  if state == "ready" then
    state_timer = state_timer - dt
    if state_timer <= 0 then
      despawn(ready_label)
      ready_label = nil
      state = "play"
    end
    return
  elseif state == "dying" then
    state_timer = state_timer - dt
    set_scale(pac.id, math.max(state_timer / 1.4, 0.05))
    if state_timer <= 0 then
      lives = lives - 1
      if lives <= 0 then
        state = "gameover"
        ready_label = spawn_text("GAME OVER", px(10.2), py(16.8), 22)
        set_tint(ready_label, 255, 60, 60)
        refresh_lives()
      else
        reset_positions(false)
        sync_actors()
        enter_ready()
      end
    end
    return
  elseif state == "clear" then
    state_timer = state_timer - dt
    local flash = math.floor(state_timer * 4) % 2 == 0
    for _, id in ipairs(walls) do
      set_tint(id, flash and 222 or 28, flash and 222 or 28, flash and 255 or 160)
    end
    if state_timer <= 0 then
      for _, id in ipairs(walls) do set_tint(id, 28, 28, 160) end
      level = level + 1
      set_text(level_label, "level " .. level)
      spawn_pellets()
      reset_positions(true)
      sync_actors()
      enter_ready()
    end
    return
  elseif state == "gameover" then
    if key_pressed("space") then
      score, lives, level = 0, 3, 1
      set_text(score_label, "score 0")
      set_text(level_label, "level 1")
      for _, p in pairs(pellets) do despawn(p.id) end
      despawn(ready_label)
      ready_label = nil
      spawn_pellets()
      reset_positions(true)
      sync_actors()
      enter_ready()
    end
    return
  end

  -- play
  if pac.wdx == -pac.dx and pac.wdy == -pac.dy and (pac.dx ~= 0 or pac.dy ~= 0) then
    pac.dx, pac.dy = pac.wdx, pac.wdy -- reverse anywhere
  end
  step_actor(pac, 7.4 + level * 0.1, dt, pac_decide)
  sync_pac()

  -- eat pellets
  local ptx, pty = math.floor(pac.x), math.floor(pac.y)
  local key = pty * COLS + ptx
  local pe = pellets[key]
  if pe then
    despawn(pe.id)
    pellets[key] = nil
    pellet_count = pellet_count - 1
    chomp = chomp + 1
    play_sound(chomp % 2 == 0 and "waka1" or "waka2")
    if pe.power then
      add_score(50)
      fright_timer, combo = 6.5, 0
      play_sound("power")
      for _, g in ipairs(ghosts) do
        if g.state == "normal" then
          g.state = "fright"
          g.dx, g.dy = -g.dx, -g.dy
          apply_ghost_tint(g)
        end
      end
    else
      add_score(10)
    end
    if pellet_count == 0 then
      state, state_timer = "clear", 1.6
      return
    end
  end

  -- mode + fright timers
  if fright_timer > 0 then
    fright_timer = fright_timer - dt
    if fright_timer <= 0 then
      for _, g in ipairs(ghosts) do
        if g.state == "fright" then g.state = "normal" apply_ghost_tint(g) end
      end
    end
  else
    mode_timer = mode_timer - dt
    if mode_timer <= 0 then
      if mode == "scatter" then mode, mode_timer = "chase", 20 else mode, mode_timer = "scatter", 7 end
      for _, g in ipairs(ghosts) do
        if g.state == "normal" then g.dx, g.dy = -g.dx, -g.dy end
      end
    end
  end

  for i, g in ipairs(ghosts) do
    update_ghost(g, i, dt)
    if g.state == "fright" then apply_ghost_tint(g) end

    local d2 = (g.x - pac.x) ^ 2 + (g.y - pac.y) ^ 2
    if d2 < 0.36 then
      if g.state == "fright" then
        combo = combo + 1
        add_score(100 * 2 ^ combo)
        play_sound("eatghost")
        g.state = "eyes"
        apply_ghost_tint(g)
      elseif g.state == "normal" then
        state, state_timer = "dying", 1.4
        play_sound("death")
        return
      end
    end
  end
end

function add_score(n)
  score = score + n
  set_text(score_label, "score " .. score)
end

function sync_pac()
  pac.mouth = pac.mouth + 1
  set_pos(pac.id, px(pac.x), py(pac.y))
end

function sync_actors()
  sync_pac()
  for _, g in ipairs(ghosts) do set_pos(g.id, px(g.x), py(g.y)) end
end

-- ---------------------------------------------------------------- draw

function on_draw()
  -- pacman's chomping mouth: a clear-color bite in the movement direction
  if state ~= "dying" and (pac.dx ~= 0 or pac.dy ~= 0) then
    local open = (math.sin(t * 18) + 1) / 2
    local r = T * 0.42 * open
    if r > 1 then
      set_color(0, 0, 0)
      draw_circle(px(pac.x) + pac.dx * T * 0.45, py(pac.y) + pac.dy * T * 0.45, r)
    end
  end

  -- ghost eyes
  for _, g in ipairs(ghosts) do
    if g.state ~= "house" or true then
      local gx, gy = px(g.x), py(g.y)
      local sep = T * 0.22
      set_color(255, 255, 255)
      draw_circle(gx - sep, gy - T * 0.1, T * 0.16)
      draw_circle(gx + sep, gy - T * 0.1, T * 0.16)
      set_color(40, 40, 255)
      draw_circle(gx - sep + g.dx * 2, gy - T * 0.1 + g.dy * 2, T * 0.08)
      draw_circle(gx + sep + g.dx * 2, gy - T * 0.1 + g.dy * 2, T * 0.08)
    end
  end
end

function on_gui()
  if state == "gameover" then
    set_color(255, 255, 255, 180)
    draw_text("press space to restart", px(9.4), py(18.5), 16)
  end
end
