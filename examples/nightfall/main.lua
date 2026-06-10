-- nightfall: a moonlit meadow, built entirely from generated assets.
-- A teaching example for the lighting system (set_lighting / set_ambient /
-- spawn_light / set_light) and custom shaders (gen_shader / set_screen_shader).
--
-- Controls: arrow keys carry the lantern around the meadow.

W, H = 960, 600

-- One tasteful custom shader: "night air" over the whole screen.
-- The image sways very slightly (like warm air shimmering) and the corners
-- fade into darkness (a vignette). The engine feeds `time` automatically;
-- `strength` is ours, set below with set_shader_param.
gen_shader("nightair", [[
#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;
uniform float strength;
out vec4 finalColor;
void main() {
    // ripple: nudge the sample point with two slow sine waves
    vec2 uv = fragTexCoord;
    uv.x += sin(uv.y * 24.0 + time * 1.3) * 0.0015 * strength;
    uv.y += sin(uv.x * 18.0 + time * 1.7) * 0.0015 * strength;
    vec4 c = texture(texture0, uv) * colDiffuse * fragColor;
    // vignette: darken by squared distance from the screen center
    vec2 d = uv - vec2(0.5);
    float vig = 1.0 - dot(d, d) * 1.2;
    finalColor = vec4(c.rgb * vig, c.a);
}
]])

function on_init()
  set_clear_color(7, 8, 18)         -- near-black night sky
  set_lighting(true)                -- lights only matter once this is on
  set_ambient(34, 38, 64)           -- dim blue "moonlight" base level
  set_screen_shader("nightair")
  set_shader_param("nightair", "strength", 1.0)

  -- == scenery ==
  -- grass: two-tone seeded noise, stretched to cover the lower screen
  gen_texture("grass", 240, 80, {kind="noise", seed=11, scale=7,
                                 color="#2c5a33", color2="#16331e"})
  local ground = spawn_sprite("grass", W/2, H-160)
  set_scale(ground, 4)              -- 240x80 -> 960x320
  set_pos(ground, W/2, H-160, 0)    -- z=0: behind everything

  -- full moon: a bright disc, plus a big cold light so the sky near it glows
  gen_texture("moon", 56, 56, {kind="circle", color="#f3eed7"})
  spawn_sprite("moon", 790, 100)
  local moonglow = spawn_light(790, 100)
  set_light(moonglow, 320, 0.9)
  set_tint(moonglow, 180, 195, 255)

  -- pine silhouettes: hand-drawn pixel art (gen_pixels), scaled way up
  gen_pixels("pine", {
    "....g....",
    "...ggg...",
    "..ggggg..",
    "...ggg...",
    "..ggggg..",
    ".ggggggg.",
    "..ggggg..",
    ".ggggggg.",
    "ggggggggg",
    "....t....",
    "....t....",
  }, {g="#14401f", t="#3a2614"})
  for i, x in ipairs({90, 210, 700, 880}) do
    local tree = spawn_sprite("pine", x, H-310)
    set_scale(tree, 7 + (i % 2) * 2)  -- vary the heights a little
    set_pos(tree, x, H-310, 1)
  end

  -- == the player and their lantern ==
  gen_pixels("walker", {
    ".hh.",
    ".hh.",
    "bbbb",
    ".bb.",
    ".bb.",
    "l..l",
  }, {h="#e8c890", b="#5a4a8a", l="#3a3050"})
  px, py = W/2, H-130
  player = spawn_sprite("walker", px, py)
  set_scale(player, 6)
  set_pos(player, px, py, 3)
  -- the "lantern" is just a warm point light we keep glued to the player
  lantern = spawn_light(px, py)
  set_light(lantern, 240, 2.2)
  set_tint(lantern, 255, 165, 80)   -- orange firelight

  -- == fireflies: tiny sprites, each paired with a small green light ==
  gen_pixels("spark", {"yy", "yy"}, {y="#eaffb0"})
  fireflies = {}
  srand(2026)                       -- seeds both rand() and noise()
  for i = 1, 10 do
    local f = {
      x = rand(60, W-60), y = rand(H-320, H-70),
      t = rand(0, 6.28),            -- personal clock so the blinks desync
      speed = rand(0.5, 1.3),
    }
    f.body = spawn_sprite("spark", f.x, f.y)
    set_scale(f.body, 2)
    set_pos(f.body, f.x, f.y, 4)
    f.glow = spawn_light(f.x, f.y)
    set_tint(f.glow, 170, 255, 120) -- firefly green
    fireflies[i] = f
  end
end

function on_update(dt)
  -- carry the lantern with the arrow keys, clamped to the meadow
  local sp = 220
  if key_down("left")  then px = px - sp * dt end
  if key_down("right") then px = px + sp * dt end
  if key_down("up")    then py = py - sp * dt end
  if key_down("down")  then py = py + sp * dt end
  px = math.max(40, math.min(W-40, px))
  py = math.max(H-330, math.min(H-60, py))
  set_pos(player, px, py, 3)
  set_pos(lantern, px, py - 20)     -- light rides a little above the sprite

  -- drift each firefly on noise, and blink it on its own clock
  for i, f in ipairs(fireflies) do
    f.t = f.t + dt * f.speed
    f.x = f.x + noise(i * 10, f.t) * 40 * dt
    f.y = f.y + noise(f.t, i * 10) * 30 * dt
    set_pos(f.body, f.x, f.y, 4)
    set_pos(f.glow, f.x, f.y)
    local blink = 0.7 + 0.7 * math.sin(f.t * 3)  -- fade out, flare back in
    set_light(f.glow, 70, blink)
    set_tint(f.body, 255, 255, 255, 120 + blink * 90)  -- body dims too
  end
end

function on_gui()
  -- on_gui draws after the lighting pass, so this text is never darkened
  set_color(200, 205, 230)
  draw_text("nightfall -- arrow keys carry the lantern", 10, 10, 20)
end
