-- ui.lua: all drawing functions — background, HUD, cards, jokers, shop, overlays.

-- == Particles ============================================================
function spawn_particles(x, y, n, col)
  for i=1,n do
    table.insert(particles, {
      x=x + rand(-20,20)*S, y=y + rand(-10,10)*S,
      vx=rand(-100,100)*S, vy=rand(-160,-50)*S,
      life=rand(0.35,0.7),
      col=col,
      size=rand(2,5)*S,
    })
  end
end

function update_particles(dt)
  for i=#particles,1,-1 do
    local p = particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.vy = p.vy + 300 * dt
    p.life = p.life - dt
    if p.life <= 0 then table.remove(particles, i) end
  end
end

function draw_particles()
  for _,p in ipairs(particles) do
    local a = clamp_l(p.life * 400, 0, 255)
    set_color(p.col[1], p.col[2], p.col[3], a)
    draw_circle(p.x, p.y, p.size * clamp_l(p.life * 1.5, 0.2, 1))
  end
end

-- == Drawing: background ==================================================
function draw_background()
  local steps = 30
  for i=0,steps do
    local t = i/steps
    local r = lerp(COL.bg_top[1], COL.bg_bot[1], t)
    local g = lerp(COL.bg_top[2], COL.bg_bot[2], t)
    local b = lerp(COL.bg_top[3], COL.bg_bot[3], t)
    set_color(r, g, b)
    draw_rect(0, t * H, W, H/steps + 2)
  end
end

-- == Drawing: joker card ==================================================
local function draw_joker(j, x, y, opts)
  opts = opts or {}
  local w, h = JW, JH
  local rc = RARITY_COL[j.def.rarity] or RARITY_COL.common
  -- glow on hover
  if opts.highlight then
    local pulse = 0.5 + 0.5 * math.sin(time * 5)
    set_color(rc[1], rc[2], rc[3], 50 + pulse * 60)
    rr(x - 5*S, y - 5*S, w + 10*S, h + 10*S, 0.15)
  end
  -- shadow
  set_color(0,0,0,90); rr(x+2*S, y+3*S, w, h, 0.15)
  -- body
  set_color(cstr(COL.jokerbg)); rr(x, y, w, h, 0.15)
  -- rarity border
  set_color(rc[1], rc[2], rc[3], 230); rro(x, y, w, h, 0.15, 2.5)
  -- joker face sprite in upper area
  local spr_h = h * 0.52
  local sc = spr_h / JOKER_SPRITE_H
  draw_sprite("joker_face", x + w/2, y + spr_h/2 + 4*S, 0, sc)
  -- name
  set_color(cstr(COL.text))
  local name_y = y + spr_h + 6*S
  -- truncate name to fit
  local name = j.def.name
  if text_width(name, FS(9)) > w - 6*S then
    while #name > 3 and text_width(name .. "...", FS(9)) > w - 6*S do
      name = string.sub(name, 1, #name - 1)
    end
    name = name .. "..."
  end
  ctext(name, 9, x + w/2, name_y)
  -- cost (shop only)
  if opts.shop then
    set_color(cstr(COL.money))
    ctext("$"..j.def.cost, 13, x + w/2, y + h - 18*S)
  end
end

-- == Drawing: HUD ========================================================
function draw_top_bar()
  set_color(cstr(COL.panel))
  draw_rect(0, 0, W, BARH)
  set_color(cstr(COL.panel2))
  draw_rect(0, BARH - 2*S, W, 2*S)
  -- left: ante + blind name (+ boss desc below)
  set_color(cstr(COL.text))
  local bname = BLIND_NAME[blind_index]
  if blind_index==3 and boss then bname = boss.name end
  draw_text("Ante " .. ante .. "/8", 14*S, 6*S, FS(15))
  set_color(cstr(COL.gold))
  draw_text(bname, 14*S, 22*S, FS(13))
  if boss then
    set_color(cstr(COL.mult))
    draw_text(boss.desc, 14*S, 38*S, FS(10))
  end
  -- center: target / score with progress bar
  local bar_x, bar_y = 200*S, 10*S
  local bar_w, bar_h = 240*S, 12*S
  set_color(cstr(COL.panel2))
  rr(bar_x, bar_y, bar_w, bar_h, 0.3)
  local progress = target > 0 and math.min(1, round_score / target) or 0
  if progress > 0 then
    local pc = progress >= 1 and COL.gold or COL.chips
    set_color(pc[1], pc[2], pc[3])
    rr(bar_x, bar_y, bar_w * progress, bar_h, 0.3)
  end
  set_color(cstr(COL.dim))
  rro(bar_x, bar_y, bar_w, bar_h, 0.3, 1)
  set_color(cstr(COL.chips))
  ctext(fmt(round_score) .. " / " .. fmt(target), 12, bar_x + bar_w/2, bar_y + bar_h + 4*S)
  -- right: money + hands/discards
  set_color(cstr(COL.money))
  local money_str = "$" .. money
  local mw = text_width(money_str, FS(20))
  draw_text(money_str, W - mw - 16*S, 6*S, FS(20))
  set_color(cstr(COL.text))
  local hd_str = "Hands " .. hands_left .. "  Disc " .. discards_left
  local hw = text_width(hd_str, FS(13))
  draw_text(hd_str, W - hw - 16*S, 30*S, FS(13))
end

local function draw_score_num(str, sz, col, x, y, pop)
  local s = FS(sz * (1 + (pop or 0) * 0.25))
  local w = text_width(str, s)
  set_color(col[1], col[2], col[3], 30)
  rr(x - 6*S, y - 2*S, w + 12*S, s + 4*S, 0.2)
  set_color(col[1], col[2], col[3])
  draw_text(str, x, y, s)
  return w
end

function draw_score_panel()
  local w, h = _SPW*S, _SPH*S
  local x, y = W/2 - w/2, SP_Y
  set_color(cstr(COL.panel)); rr(x, y, w, h, 0.08)
  set_color(cstr(COL.panel2)); rr(x, y, w, h*0.45, 0.08)
  set_color(cstr(COL.dim)); rro(x, y, w, h, 0.08, 1.5)
  if state=="SCORE" then
    local ev = events[ev_i]
    if ev then
      set_color(ev.col[1], ev.col[2], ev.col[3])
      ctext(ev.label, 14, W/2, y + 6*S)
    end
    local cy = y + 30*S
    local ch_str, mu_str, tot_str = fmt(cur_chips), fmt(cur_mult), fmt(cur_chips*cur_mult)
    local ns = 30
    local chw = text_width(ch_str, FS(ns))
    local muw = text_width(mu_str, FS(ns))
    local totw = text_width(tot_str, FS(ns))
    local xw = text_width("x", FS(22))
    local eqw = text_width("=", FS(22))
    local g = 14*S
    local total_w = chw + g + xw + g + muw + g + eqw + g + totw
    local cx = W/2 - total_w/2
    draw_score_num(ch_str, ns, COL.chips, cx, cy, chips_pop)
    cx = cx + chw + g
    set_color(cstr(COL.dim)); ctext("x", 22, cx + xw/2, cy + 6*S)
    cx = cx + xw + g
    draw_score_num(mu_str, ns, COL.mult, cx, cy, mult_pop)
    cx = cx + muw + g
    set_color(cstr(COL.dim)); ctext("=", 22, cx + eqw/2, cy + 6*S)
    cx = cx + eqw + g
    draw_score_num(tot_str, ns, COL.gold, cx, cy, 0)
  else
    local sel = selected_list()
    if #sel >= 1 then
      local ht = evaluate(sel)
      local lv = hand_level(ht)
      set_color(cstr(COL.text))
      ctext(ht, 16, W/2, y + 6*S)
      local cy = y + 34*S
      local ch_str, mu_str = fmt(lv.chips), fmt(lv.mult)
      local ns = 26
      local chw = text_width(ch_str, FS(ns))
      local muw = text_width(mu_str, FS(ns))
      local xw = text_width("x", FS(20))
      local g = 12*S
      local total_w = chw + g + xw + g + muw
      local cx = W/2 - total_w/2
      draw_score_num(ch_str, ns, COL.chips, cx, cy, 0)
      cx = cx + chw + g
      set_color(cstr(COL.dim)); ctext("x", 20, cx + xw/2, cy + 4*S)
      cx = cx + xw + g
      draw_score_num(mu_str, ns, COL.mult, cx, cy, 0)
    else
      set_color(cstr(COL.dim))
      ctext("select cards to play", 16, W/2, y + 34*S)
    end
  end
end

tooltip_data = nil

function draw_joker_row()
  local mx,my = mouse_pos()
  for i,j in ipairs(jokers) do
    local x = JX0 + (i-1)*(JW+JGAP)
    local hov = hit(mx,my,x,JY,JW,JH)
    draw_joker(j, x, JY, {highlight=hov})
    if hov then
      tooltip_data = {x=x, desc=j.def.desc, sell=math.floor(j.def.cost/2)}
    end
  end
  -- empty joker slots
  for i = #jokers+1, joker_slots do
    local x = JX0 + (i-1)*(JW+JGAP)
    set_color(cstr(COL.panel))
    rr(x, JY, JW, JH, 0.15)
    set_color(60, 62, 80)
    rro(x, JY, JW, JH, 0.15, 1.5)
    set_color(80, 82, 100)
    ctext("+", 20, x + JW/2, JY + JH/2 - 10*S)
  end
end

function draw_tooltips()
  if not tooltip_data then return end
  local tw, th = 240*S, 44*S
  local tx = clamp_l(tooltip_data.x, 0, W - tw)
  local ty = JY + JH + 4*S
  -- shadow
  set_color(0, 0, 0, 120)
  rr(tx + 2*S, ty + 3*S, tw, th, 0.1)
  set_color(cstr(COL.panel))
  rr(tx, ty, tw, th, 0.1)
  set_color(cstr(COL.gold))
  rro(tx, ty, tw, th, 0.1, 1.5)
  set_color(cstr(COL.text))
  draw_text(tooltip_data.desc, tx + 8*S, ty + 6*S, FS(11))
  set_color(cstr(COL.money))
  draw_text("sell: $"..tooltip_data.sell, tx + 8*S, ty + 24*S, FS(10))
end

function draw_hand()
  local mx,my = mouse_pos()
  for i,c in ipairs(hand) do
    local tx = CX0 + (i-1)*(CW+GAP)
    local ty = HAND_Y - (selected[c.uid] and SEL_RISE or 0)
    -- hover lift
    local is_hov = state=="BLIND" and hit(mx,my,tx,HAND_Y - (selected[c.uid] and SEL_RISE or 0),CW,CH) and not selected[c.uid]
    if is_hov then ty = ty - 6*S end
    -- animated position
    if c.ax == nil then c.ax = tx; c.ay = ty end
    if c.deal > 0 then
      -- waiting for deal delay
    else
      c.ax = lerp(c.ax, tx, 0.18)
      c.ay = lerp(c.ay, ty, 0.18)
    end
    draw_card(c, c.ax, c.ay, {highlight=selected[c.uid]})
  end
end

function draw_played_area()
  if state ~= "SCORE" then return end
  for i,c in ipairs(played) do
    local tx = PX0 + (i-1)*(CW+GAP)
    local ty = PLAY_Y
    -- fly from hand position to played position
    if c.ax == nil then c.ax = tx; c.ay = ty end
    c.ax = lerp(c.ax, tx, 0.15)
    c.ay = lerp(c.ay, ty, 0.15)
    local scoring = false
    for _,sc in ipairs(scoring_cards) do if sc.uid==c.uid then scoring=true break end end
    local hl = (cur_card == i)
    -- pulse on trigger
    local scale = 1 + (c.pulse or 0) * 0.3
    draw_card(c, c.ax, c.ay, {dim=not scoring, highlight=hl, scale=scale})
  end
end

function draw_deck_icon()
  if state == "MENU" or state == "OVER" or state == "WIN" then return end
  local x, y = DECK_X, DECK_Y
  -- stacked card backs
  for i = 0, 2 do
    set_color(0, 0, 0, 60)
    rr(x + 3*S + i*2*S, y + 4*S - i*2*S, CW*0.5, CH*0.5, 0.12)
    set_color(40 + i*6, 46 + i*6, 86 + i*6)
    rr(x + i*2*S, y - i*2*S, CW*0.5, CH*0.5, 0.12)
    set_color(80, 86, 130)
    rro(x + i*2*S, y - i*2*S, CW*0.5, CH*0.5, 0.12, 1)
  end
  set_color(cstr(COL.dim))
  ctext(#drawpile, 13, x + CW*0.25, y - CH*0.25 - 18*S)
end

function draw_buttons()
  local px,py,pw,ph = W/2-300*S, BTN_Y, BTNW, BTNH
  local mx,my = mouse_pos()
  local hov = hit(mx,my,px,py,pw,ph)
  set_color(0,0,0,80); rr(px+2*S, py+3*S, pw, ph, 0.2)
  set_color(cstr(COL.play))
  if hov then set_color(COL.play[1]+25, COL.play[2]+25, COL.play[3]+25) end
  rr(px,py,pw,ph,0.2)
  set_color(cstr(COL.dim)); rro(px,py,pw,ph,0.2,1.5)
  set_color(255,255,255); ctext("Play Hand", 18, px+pw/2, py+6*S)
  set_color(255,255,255,140); ctext("enter", 10, px+pw/2, py+ph-14*S)
  local dx,dy,dw,dh = W/2+120*S, BTN_Y, BTNW, BTNH
  local hov2 = hit(mx,my,dx,dy,dw,dh)
  set_color(0,0,0,80); rr(dx+2*S, dy+3*S, dw, dh, 0.2)
  set_color(cstr(COL.discard))
  if hov2 then set_color(COL.discard[1]+25, COL.discard[2]+25, COL.discard[3]+25) end
  rr(dx,dy,dw,dh,0.2)
  set_color(cstr(COL.dim)); rro(dx,dy,dw,dh,0.2,1.5)
  set_color(255,255,255); ctext("Discard", 18, dx+dw/2, dy+6*S)
  set_color(255,255,255,140); ctext("D", 10, dx+dw/2, dy+dh-14*S)
end

-- == Shop / pack overlays =================================================
function draw_shop()
  local top = JY + JH + 8*S
  set_color(0, 0, 0, 175)
  draw_rect(0, top, W, H - top)
  local px, py, pw, ph, iy, by = shop_layout()
  set_color(cstr(COL.panel)); rr(px, py, pw, ph, 0.04)
  set_color(cstr(COL.panel2)); rr(px, py, pw, 40*S, 0.04)
  set_color(cstr(COL.gold)); rro(px, py, pw, ph, 0.04, 2.5)
  set_color(cstr(COL.gold)); draw_text("SHOP", px + 20*S, py + 10*S, FS(24))
  set_color(cstr(COL.money))
  local ms = "$" .. money
  draw_text(ms, px + pw - text_width(ms, FS(20)) - 20*S, py + 12*S, FS(20))
  local iw,ih = _SHOPW*S, _SHOPH*S
  local n = #shop_items
  local total = n*iw + (n-1)*_SHOPG*S
  local ix0 = W/2 - total/2
  for i,it in ipairs(shop_items) do
    local x = ix0 + (i-1)*(iw+_SHOPG*S)
    local y = iy
    local mx,my = mouse_pos()
    local hov = hit(mx,my,x,y,iw,ih)
    if it.bought then set_color(35,37,55) else set_color(cstr(COL.panel)) end
    rr(x,y,iw,ih,0.06)
    if hov and not it.bought then
      local pulse = 0.5 + 0.5 * math.sin(time * 5)
      set_color(COL.gold[1], COL.gold[2], COL.gold[3], 150 + pulse * 80)
      rro(x,y,iw,ih,0.06,2.5)
    else
      set_color(cstr(COL.dim)); rro(x,y,iw,ih,0.06,1.5)
    end
    if it.kind=="joker" then
      draw_joker({def=it.def}, x+iw/2-JW/2, y+14*S, {shop=true})
      set_color(cstr(COL.dim)); draw_wrapped(it.def.desc, x+10*S, y+JH+24*S, iw - 20*S, 10, 13*S)
      local rc = RARITY_COL[it.def.rarity] or RARITY_COL.common
      set_color(rc[1], rc[2], rc[3])
      ctext(it.def.rarity, 9, x+iw/2, y+ih-18*S)
    elseif it.kind=="planet" then
      local icon_sc = (ih * 0.30) / 10
      draw_sprite("planet_icon", x+iw/2, y+ih*0.22, 0, icon_sc)
      set_color(cstr(COL.text)); draw_wrapped_center(it.ht, x+iw/2, y+ih*0.42, iw - 16*S, 11, 14*S)
      set_color(cstr(COL.chips)); ctext("L" .. (hand_levels[it.ht].level+1), 16, x+iw/2, y+ih*0.58)
      set_color(cstr(COL.dim)); ctext("+" .. HAND_UP[it.ht].chips .. " chips", 10, x+iw/2, y+ih*0.70)
      set_color(cstr(COL.mult)); ctext("+" .. HAND_UP[it.ht].mult .. " mult", 10, x+iw/2, y+ih*0.80)
      set_color(cstr(COL.money)); ctext("$" .. it.cost, 16, x+iw/2, y+ih-24*S)
    elseif it.kind=="pack" then
      local icon_sc = (ih * 0.38) / 10
      draw_sprite("pack_icon", x+iw/2, y+ih*0.26, 0, icon_sc)
      set_color(cstr(COL.text)); ctext(it.label, 12, x+iw/2, y+ih*0.50)
      set_color(cstr(COL.dim)); draw_wrapped_center(it.desc, x+iw/2, y+ih*0.60, iw - 16*S, 10, 13*S)
      set_color(cstr(COL.money)); ctext("$" .. it.cost, 16, x+iw/2, y+ih-24*S)
    end
    if it.bought then
      set_color(100,100,120)
      ctext("SOLD", 16, x+iw/2, y+ih/2)
    end
  end
  local mx,my = mouse_pos()
  local rx,ry,rw,rh = W/2-190*S, by, 170*S, 44*S
  local hov1 = hit(mx,my, rx,ry,rw,rh)
  set_color(0,0,0,80); rr(rx+2*S, ry+3*S, rw, rh, 0.2)
  set_color(cstr(COL.money)); rr(rx,ry,rw,rh,0.2)
  if hov1 then set_color(255,210,110) end; rr(rx,ry,rw,rh,0.2)
  set_color(20,20,30); ctext("Reroll ($5)", 16, rx+rw/2, ry+12*S)
  local sx,sy,sw,sh = W/2+20*S, by, 170*S, 44*S
  local hov2 = hit(mx,my, sx,sy,sw,sh)
  set_color(0,0,0,80); rr(sx+2*S, sy+3*S, sw, sh, 0.2)
  set_color(cstr(COL.play)); rr(sx,sy,sw,sh,0.2)
  if hov2 then set_color(120,210,130) end; rr(sx,sy,sw,sh,0.2)
  set_color(255,255,255); ctext("Skip -> Next", 16, sx+sw/2, sy+12*S)
end

function draw_pack()
  set_color(0,0,0,190); draw_rect(0,0,W,H)
  set_color(cstr(COL.gold)); ctext("Enhance Pack", 22, W/2, 100*S)
  set_color(cstr(COL.text)); ctext("click a card to enhance it (random)", 15, W/2, 130*S)
  set_color(cstr(COL.dim)); ctext("right-click to skip", 13, W/2, 154*S)
  local mx,my = mouse_pos()
  for i,c in ipairs(hand) do
    local x = CX0 + (i-1)*(CW+GAP)
    local y = HAND_Y
    if c.ax == nil then c.ax = x; c.ay = y end
    if c.deal > 0 then
      -- waiting for deal delay; stay at deck
    else
      c.ax = lerp(c.ax, x, 0.18)
      c.ay = lerp(c.ay, y, 0.18)
    end
    local hov = hit(mx,my,c.ax,c.ay,CW,CH)
    local scale = hov and 1.08 or 1
    draw_card(c, c.ax, c.ay, {scale=scale, highlight=hov})
  end
end

-- == Overlays =============================================================
function draw_menu()
  draw_background()
  set_color(cstr(COL.gold))
  local tp = 1 + math.sin(time * 2) * 0.03
  draw_text("BALATRO", W/2 - text_width("BALATRO", FS(56*tp))/2, H*0.16, FS(56*tp))
  set_color(cstr(COL.text))
  ctext("a poker roguelike deck-builder", 20, W/2, H*0.30)
  if math.sin(time * 3) > 0 then
    set_color(cstr(COL.gold))
    ctext("click or press enter to start a run", 18, W/2, H*0.42)
  end
  set_color(cstr(COL.dim))
  ctext("beat 8 antes to win", 15, W/2, H*0.48)
  ctext("click cards to select  |  enter = play  |  D = discard  |  right-click joker = sell", 12, W/2, H*0.54)
  -- fanned poker hand at the bottom (royal flush of hearts)
  local hand_cards = {
    {rank="10", suit="H", enh=nil, pulse=0},
    {rank="J", suit="H", enh=nil, pulse=0},
    {rank="Q", suit="H", enh=nil, pulse=0},
    {rank="K", suit="H", enh=nil, pulse=0},
    {rank="A", suit="H", enh=nil, pulse=0},
  }
  local sc = 0.88
  local step = CW * sc * 0.5
  local bob = math.sin(time * 1.5) * 6 * S
  local base_cy = H * 0.76 + bob
  for i, c in ipairs(hand_cards) do
    local di = i - 3
    local cx = W/2 + di * step
    local cy = base_cy + di * di * 5 * S
    draw_card(c, cx - CW/2, cy - CH/2, {scale=sc})
  end
end

function draw_over()
  set_color(0,0,0,210); draw_rect(0,0,W,H)
  set_color(cstr(COL.mult))
  ctext("GAME OVER", 52, W/2, H*0.30)
  set_color(cstr(COL.text))
  ctext("the blind was not beaten", 18, W/2, H*0.42)
  set_color(cstr(COL.gold))
  ctext("reached ante " .. ante .. "  blind " .. blind_index, 16, W/2, H*0.50)
  set_color(cstr(COL.dim))
  ctext("jokers owned: " .. #jokers .. "    money: $" .. money, 14, W/2, H*0.55)
  if math.sin(time * 3) > 0 then
    set_color(cstr(COL.text))
    ctext("click or press enter to try again", 16, W/2, H*0.63)
  end
end

function draw_win()
  set_color(0,0,0,210); draw_rect(0,0,W,H)
  -- gold particle burst
  for i = 1, 20 do
    local t = time + i * 0.3
    local x = W/2 + math.cos(t * 1.5 + i) * 200 * S
    local y = H*0.4 + math.sin(t * 2 + i) * 100 * S
    set_color(COL.gold[1], COL.gold[2], COL.gold[3], 120)
    draw_circle(x, y, 3*S)
  end
  set_color(cstr(COL.gold))
  local tp = 1 + math.sin(time * 3) * 0.05
  ctext("YOU WIN", 60*tp, W/2, H*0.30)
  set_color(cstr(COL.text))
  ctext("ante 8 conquered", 20, W/2, H*0.44)
  set_color(cstr(COL.dim))
  ctext("jokers owned: " .. #jokers .. "    money: $" .. money, 14, W/2, H*0.50)
  if math.sin(time * 3) > 0 then
    set_color(cstr(COL.text))
    ctext("click or press enter to play again", 16, W/2, H*0.58)
  end
end

-- == Toast ================================================================
function draw_toast()
  if toast_t > 0 then
    local a = math.min(255, math.floor(toast_t * 180))
    local tw = text_width(toast, FS(15))
    local bw = tw + 32*S
    local bx = W/2 - bw/2
    local by = H - 130*S
    set_color(0, 0, 0, a * 0.6)
    rr(bx + 2*S, by + 3*S, bw, 34*S, 0.2)
    set_color(COL.panel[1], COL.panel[2], COL.panel[3], a)
    rr(bx, by, bw, 34*S, 0.2)
    set_color(COL.gold[1], COL.gold[2], COL.gold[3], a)
    rro(bx, by, bw, 34*S, 0.2, 1.5)
    set_color(COL.text[1], COL.text[2], COL.text[3], a)
    draw_text(toast, bx + 16*S, by + 9*S, FS(15))
  end
end
