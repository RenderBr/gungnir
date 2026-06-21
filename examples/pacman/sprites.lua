-- sprites.lua: arcade sprite generation — ghost bodies, eyes, faces, and pacman.
--
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
SPRITE_SCALE = 2

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
