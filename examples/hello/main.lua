-- hello: a bouncing ball you can push with the arrow keys.
-- Edit this file while the game runs -- it hot-reloads on save.

function on_init()
  x, y = 480, 300
  vx, vy = 180, 140
  r = 24
end

function on_update(dt)
  local w, h = screen_size()

  if key_down("left")  then vx = vx - 400 * dt end
  if key_down("right") then vx = vx + 400 * dt end
  if key_down("up")    then vy = vy - 400 * dt end
  if key_down("down")  then vy = vy + 400 * dt end

  x = x + vx * dt
  y = y + vy * dt

  if x < r and vx < 0 then vx = -vx end
  if x > w - r and vx > 0 then vx = -vx end
  if y < r and vy < 0 then vy = -vy end
  if y > h - r and vy > 0 then vy = -vy end
end

function on_draw()
  set_color(80, 200, 255)
  draw_circle(x, y, r)
  set_color(80, 200, 255, 90)
  draw_circle(x - vx * 0.05, y - vy * 0.05, r * 0.8)
end

function on_gui()
  set_color(255, 255, 255)
  draw_text("hello from lua -- arrow keys push the ball, edit me!", 10, 10, 20)
end
