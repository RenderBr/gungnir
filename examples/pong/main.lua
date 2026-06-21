-- pong: one paddle, keep the ball alive. up/down to move.
-- GameObject + clamp + rect_hit showcase: position lives on the objects,
-- collisions and bounds use the new helpers (no get_pos/set_pos dance).

function on_init()
  W, H = screen_size()
  ball = GameObject{shape="circle", x=W/2, y=H/2, w=16, tint={255,255,255}}
  pad  = GameObject{shape="rect",   x=40,   y=H/2, w=14, h=110, tint={120,220,120}}
  score_label = spawn_text("0", W/2 - 10, 16, 36)
  set_tint(score_label, 255, 255, 255, 160)
  ball.vx, ball.vy = 260, 180
  score = 0
end

function on_update(dt)
  ball:move(ball.vx * dt, ball.vy * dt)

  if ball.y < 8  and ball.vy < 0 then ball.vy = -ball.vy end
  if ball.y > H-8 and ball.vy > 0 then ball.vy = -ball.vy end
  if ball.x > W-8 and ball.vx > 0 then ball.vx = -ball.vx end

  if key_down("up")   then pad:move(0, -360 * dt) end
  if key_down("down") then pad:move(0,  360 * dt) end
  pad.y = clamp(pad.y, 55, H - 55)

  -- paddle collision: generous AABB around ball vs paddle (16x16 vs 14x110)
  if ball.vx < 0 and rect_hit(ball, pad, 32, 126) then
    ball.vx = -ball.vx * 1.04            -- speed up a little each return
    ball.vy = ball.vy + (ball.y - pad.y) * 4
    score = score + 1
    set_text(score_label, tostring(score))
  end

  if ball.x < -20 then -- missed: reset
    ball:set_pos(W/2, H/2)
    ball.vx, ball.vy = 260, 180
    score = 0
    set_text(score_label, "0")
  end
end

function on_draw()
  set_color(255, 255, 255, 40)
  draw_line(W / 2, 0, W / 2, H, 2)
end

function on_gui()
  set_color(255, 255, 255, 120)
  draw_text("up/down to move", 10, 10, 16)
end
