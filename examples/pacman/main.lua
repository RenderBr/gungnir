-- pacman: the real thing. arrows to move, space to restart after game over.

T = 18 -- tile size in pixels
COLS, ROWS = 28, 31
OX = (960 - COLS * T) / 2
OY = (600 - ROWS * T) / 2

-- arcade audio slice durations (see assets/pacman_slices.txt)
AMBIENT_DUR = { 0.402, 0.327, 0.298, 0.264 } -- siren levels 1..4
FRIGHT_DUR  = 0.538
EYES_DUR    = 0.268
START_DUR   = 4.191
CUTSCENE_DUR = 5.255

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

-- ------------------------------------------------- arcade sprites (14x14)
-- Geometry from the original arcade sprite outlines (via shaunlebron/pacman):
-- ghost head dome, two skirt frames, directional eyes, frightened face, and
-- pacman's mouth wedge (hinged 3px behind center, half-angles atan(4/5) and
-- atan(6/3)).

GHOST_BODY_A = {
  ".....####.....",
  "...########...",
  "..##########..",
  ".############.",
  ".############.",
  "##############",
  "##############",
  "##############",
  "##############",
  "##############",
  "##############",
  "##############",
  "##.###..###.##",
  "#...##..##...#",
}
GHOST_BODY_B = {
  ".....####.....",
  "...########...",
  "..##########..",
  ".############.",
  ".############.",
  "##############",
  "##############",
  "##############",
  "##############",
  "##############",
  "##############",
  "##############",
  "####.####.####",
  ".##...##...##.",
}

local function new_grid()
  local g = {}
  for y = 1, 14 do g[y] = {} for x = 1, 14 do g[y][x] = "." end end
  return g
end

local function grid_rows(g)
  local rows = {}
  for y = 1, 14 do rows[y] = table.concat(g[y]) end
  return rows
end

local function plot(g, x, y, ch)
  if x >= 0 and x < 14 and y >= 0 and y < 14 then g[y + 1][x + 1] = ch end
end

-- eyeball: 4x5 rounded oval at (ox,oy); pupil 2x2 at (ox+px_, oy+py_)
local function eyeball(g, ox, oy, px_, py_)
  for _, p in ipairs({ {1,0},{2,0}, {0,1},{1,1},{2,1},{3,1}, {0,2},{1,2},{2,2},{3,2},
                       {0,3},{1,3},{2,3},{3,3}, {1,4},{2,4} }) do
    plot(g, ox + p[1], oy + p[2], "w")
  end
  for dy = 0, 1 do for dx = 0, 1 do plot(g, ox + px_ + dx, oy + py_ + dy, "p") end end
end

local function build_eye_textures()
  local eye_off = { r = {1, 0}, l = {-1, 0}, u = {0, -1}, d = {0, 1} }
  local pup_off = { r = {2, 2}, l = {0, 2}, u = {1, 0}, d = {1, 3} }
  for dir, eo in pairs(eye_off) do
    local g = new_grid()
    local po = pup_off[dir]
    eyeball(g, 2 + eo[1], 3 + eo[2], po[1], po[2])
    eyeball(g, 8 + eo[1], 3 + eo[2], po[1], po[2])
    gen_pixels("eyes_" .. dir, grid_rows(g), { w = "#ffffff", p = "#2121ff" })
  end
end

local function build_scared_faces()
  for name, color in pairs({ face_n = "#ffb8ae", face_f = "#ff0000" }) do
    local g = new_grid()
    for dy = 0, 1 do for dx = 0, 1 do
      plot(g, 4 + dx, 5 + dy, "f")
      plot(g, 8 + dx, 5 + dy, "f")
    end end
    for _, x in ipairs({ 2, 3, 6, 7, 10, 11 }) do plot(g, x, 9, "f") end
    for _, x in ipairs({ 1, 4, 5, 8, 9, 12 }) do plot(g, x, 10, "f") end
    gen_pixels(name, grid_rows(g), { f = color })
  end
end

-- circle r=6.5 minus a mouth wedge with its hinge 3px behind center
local function pac_rows(half_angle)
  local g = new_grid()
  local edge_angle = math.atan(6.5 * math.sin(half_angle), 6.5 * math.cos(half_angle) + 3)
  for y = 0, 13 do
    for x = 0, 13 do
      local vx, vy = x + 0.5 - 7, y + 0.5 - 7
      if vx * vx + vy * vy <= 6.5 * 6.5 then
        local wx, wy = vx + 3, vy
        local in_mouth = half_angle > 0 and wx > 0
          and math.atan(math.abs(wy), wx) <= edge_angle
        if not in_mouth then plot(g, x, y, "y") end
      end
    end
  end
  return grid_rows(g)
end

GHOST_COLORS = { "#ff0000", "#ffb8ff", "#00ffff", "#ffb852" }

function build_sprites()
  gen_pixels("pac0", pac_rows(0), { y = "#ffff00" })
  gen_pixels("pac1", pac_rows(math.atan(4, 5)), { y = "#ffff00" })
  gen_pixels("pac2", pac_rows(math.atan(6, 3)), { y = "#ffff00" })

  for i, color in ipairs(GHOST_COLORS) do
    gen_pixels("g" .. i .. "a", GHOST_BODY_A, { ["#"] = color })
    gen_pixels("g" .. i .. "b", GHOST_BODY_B, { ["#"] = color })
  end
  gen_pixels("fra", GHOST_BODY_A, { ["#"] = "#2121ff" })
  gen_pixels("frb", GHOST_BODY_B, { ["#"] = "#2121ff" })
  gen_pixels("fwa", GHOST_BODY_A, { ["#"] = "#dedeff" })
  gen_pixels("fwb", GHOST_BODY_B, { ["#"] = "#dedeff" })

  build_eye_textures()
  build_scared_faces()
end

SPRITE_SCALE = 2

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
  set_fullscreen(true)
  set_crt(true)

  -- real arcade audio: slices of assets/pacman10_*.ogg (see pacman_slices.txt)
  load_sound_slice("waka1",    "pacman10_regular.ogg", 5.134, 5.264)
  load_sound_slice("waka2",    "pacman10_regular.ogg", 6.265, 6.395)
  load_sound_slice("eatghost", "pacman10_regular.ogg", 8.604, 9.178)
  load_sound_slice("death",    "pacman10_regular.ogg", 2.410, 4.134)
  load_sound_slice("start",    "pacman10_looped.ogg",  19.518, 23.709)
  load_sound_slice("cutscene", "pacman10_looped.ogg",  8.099, 13.354)
  load_sound_slice("ambient1", "pacman10_looped.ogg",  0.000, 0.402)
  load_sound_slice("ambient2", "pacman10_looped.ogg",  1.402, 1.729)
  load_sound_slice("ambient3", "pacman10_looped.ogg",  2.729, 3.027)
  load_sound_slice("ambient4", "pacman10_looped.ogg",  4.027, 4.291)
  load_sound_slice("fright",   "pacman10_looped.ogg",  6.560, 7.098)
  load_sound_slice("eyes",     "pacman10_looped.ogg",  5.292, 5.560)

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

  build_sprites()

  pac = { id = spawn_sprite("pac1", 0, 0) }
  set_scale(pac.id, SPRITE_SCALE)
  set_pos(pac.id, 0, 0, 1.1)

  ghosts = {}
  GHOST_DEFS = {
    { name = "blinky", corner = { 26, 1 } },
    { name = "pinky",  corner = { 1, 1 } },
    { name = "inky",   corner = { 26, 29 } },
    { name = "clyde",  corner = { 1, 29 } },
  }
  for i, d in ipairs(GHOST_DEFS) do
    local g = { id = spawn_sprite("g" .. i .. "a", 0, 0), corner = d.corner }
    set_scale(g.id, SPRITE_SCALE)
    set_pos(g.id, 0, 0, 1)
    ghosts[i] = g
  end

  spawn_pellets()
  reset_positions(true)
  sync_actors()
  enter_ready(true)
end

function spawn_pellets()
  pellets, pellet_count, power_ids = {}, 0, {}
  for ty = 0, ROWS - 1 do
    for tx = 0, COLS - 1 do
      local ch = tile_char(tx, ty)
      if ch == "." or ch == "o" then
        local id
        if ch == "o" then
          id = spawn_shape("circle", px(tx + 0.5), py(ty + 0.5), 13)
        else
          id = spawn_shape("rect", px(tx + 0.5), py(ty + 0.5), 4, 4) -- arcade square dot
        end
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
  set_scale(pac.id, SPRITE_SCALE)

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
    apply_ghost_skin(g, i)
  end

  mode, mode_timer = "scatter", 7
  fright_timer, combo, chomp = 0, 0, 0
  blink_t = 0
  siren_timer = 0
end

-- ---------------------------------------------------------------- states

function enter_ready(jingle)
  state, state_timer = "ready", jingle and START_DUR or 2
  if ready_label then despawn(ready_label) end
  ready_label = spawn_text("READY!", px(11.6), py(16.8), 22)
  set_tint(ready_label, 255, 255, 0)
  refresh_lives()
  if jingle then play_sound("start") end
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
    end
  else
    step_actor(g, ghost_speed(g), dt, ghost_decide_for(i))
    if g.state == "eyes" and math.abs(g.x - 13.5) < 0.1 and math.abs(g.y - 11.5) < 0.1 then
      g.state = "glide"
      start_glide(g, 13.5, 14.5, 0.7, "house")
    end
  end
  apply_ghost_skin(g, i)
  set_pos(g.id, px(g.x), py(g.y))
end

-- pick the right body texture: color/frame, blue/white frightened, or
-- hidden entirely when only the eyes are racing home
function apply_ghost_skin(g, i)
  local frame = math.floor(t * 7) % 2 == 0 and "a" or "b"
  if g.state == "eyes" then
    set_tint(g.id, 255, 255, 255, 0)
    return
  end
  set_tint(g.id, 255, 255, 255, 255)
  if g.state == "fright" then
    local flash = fright_timer < 2 and math.floor(fright_timer * 4) % 2 == 0
    set_texture(g.id, (flash and "fw" or "fr") .. frame)
  else
    set_texture(g.id, "g" .. i .. frame)
  end
end

function ghost_fright_flashing(g)
  return g.state == "fright" and fright_timer < 2 and math.floor(fright_timer * 4) % 2 == 0
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
    set_scale(pac.id, SPRITE_SCALE * math.max(state_timer / 1.4, 0.05))
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
    local flashing = state_timer > CUTSCENE_DUR - 1.5
    local flash = flashing and math.floor(state_timer * 4) % 2 == 0
    for _, id in ipairs(walls) do
      set_tint(id, flash and 222 or 28, flash and 222 or 28, flash and 255 or 160)
    end
    if state_timer <= 0 then
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
      enter_ready(true)
    end
    return
  end

  -- play
  -- background siren: eyes > fright > level siren, replayed on a timer
  siren_timer = siren_timer - dt
  if siren_timer <= 0 then
    local any_eyes = false
    for _, g in ipairs(ghosts) do if g.state == "eyes" then any_eyes = true end end
    if any_eyes then
      play_sound("eyes", 0.6); siren_timer = EYES_DUR
    elseif fright_timer > 0 then
      play_sound("fright", 0.6); siren_timer = FRIGHT_DUR
    else
      local i = math.min(level, 4)
      play_sound("ambient" .. i, 0.6); siren_timer = AMBIENT_DUR[i]
    end
  end

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
    play_sound(chomp % 2 == 0 and "waka1" or "waka2", 0.5)
    if pe.power then
      add_score(50)
      fright_timer, combo = 6.5, 0
      play_sound("fright", 0.6)
      siren_timer = FRIGHT_DUR
      for _, g in ipairs(ghosts) do
        if g.state == "normal" then
          g.state = "fright"
          g.dx, g.dy = -g.dx, -g.dy
        end
      end
    else
      add_score(10)
    end
    if pellet_count == 0 then
      state, state_timer = "clear", CUTSCENE_DUR
      play_sound("cutscene")
      return
    end
  end

  -- mode + fright timers
  if fright_timer > 0 then
    fright_timer = fright_timer - dt
    if fright_timer <= 0 then
      for _, g in ipairs(ghosts) do
        if g.state == "fright" then g.state = "normal" end
      end
      siren_timer = 0
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

    local d2 = (g.x - pac.x) ^ 2 + (g.y - pac.y) ^ 2
    if d2 < 0.36 then
      if g.state == "fright" then
        combo = combo + 1
        add_score(100 * 2 ^ combo)
        play_sound("eatghost")
        g.state = "eyes"
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

PAC_FRAMES = { "pac0", "pac1", "pac2", "pac1" }

function sync_pac()
  local moving = pac.dx ~= 0 or pac.dy ~= 0
  if moving then
    set_texture(pac.id, PAC_FRAMES[math.floor(t * 14) % 4 + 1])
  else
    set_texture(pac.id, "pac1")
  end
  local rot = 0
  if pac.dx < 0 then rot = 180
  elseif pac.dy > 0 then rot = 90
  elseif pac.dy < 0 then rot = 270 end
  set_rot(pac.id, rot)
  set_pos(pac.id, px(pac.x), py(pac.y))
end

function sync_actors()
  sync_pac()
  for _, g in ipairs(ghosts) do set_pos(g.id, px(g.x), py(g.y)) end
end

-- ---------------------------------------------------------------- draw

function dir_char(g)
  if g.dy < 0 then return "u" end
  if g.dy > 0 then return "d" end
  if g.dx > 0 then return "r" end
  return "l"
end

function on_draw()
  -- ghost faces: directional eyes, or the frightened face
  for _, g in ipairs(ghosts) do
    local gx, gy = px(g.x), py(g.y)
    if g.state == "fright" then
      draw_sprite(ghost_fright_flashing(g) and "face_f" or "face_n", gx, gy, 0, SPRITE_SCALE)
    else
      draw_sprite("eyes_" .. dir_char(g), gx, gy, 0, SPRITE_SCALE)
    end
  end
end

function on_gui()
  if state == "gameover" then
    set_color(255, 255, 255, 180)
    draw_text("press space to restart", px(9.4), py(18.5), 16)
  end
end
