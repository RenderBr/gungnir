-- pong: one paddle, keep the ball alive. up/down to move.

function on_init()
  W, H = screen_size()
  ball = spawn_shape("circle", W / 2, H / 2, 16)
  set_tint(ball, 255, 255, 255)
  pad = spawn_shape("rect", 40, H / 2, 14, 110)
  set_tint(pad, 120, 220, 120)
  score_label = spawn_text("0", W / 2 - 10, 16, 36)
  set_tint(score_label, 255, 255, 255, 160)
  vx, vy = 260, 180
  score = 0
end

function on_update(dt)
  local x, y = get_pos(ball)
  x, y = x + vx * dt, y + vy * dt

  if y < 8 and vy < 0 then vy = -vy end
  if y > H - 8 and vy > 0 then vy = -vy end
  if x > W - 8 and vx > 0 then vx = -vx end

  local px, py = get_pos(pad)
  if key_down("up") then py = py - 360 * dt end
  if key_down("down") then py = py + 360 * dt end
  py = math.max(55, math.min(H - 55, py))
  set_pos(pad, px, py)

  if x < 55 and x > 40 and vx < 0 and math.abs(y - py) < 65 then
    vx = -vx * 1.04 -- speed up a little each return
    vy = vy + (y - py) * 4
    score = score + 1
    set_text(score_label, tostring(score))
  end

  if x < -20 then -- missed: reset
    x, y = W / 2, H / 2
    vx, vy = 260, 180
    score = 0
    set_text(score_label, "0")
  end

  set_pos(ball, x, y)
end

function on_draw()
  set_color(255, 255, 255, 40)
  draw_line(W / 2, 0, W / 2, H, 2)
end

function on_gui()
  set_color(255, 255, 255, 120)
  draw_text("up/down to move", 10, 10, 16)
end
