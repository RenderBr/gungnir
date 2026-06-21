-- balatro: a poker roguelike deck-builder (one-to-one clone of the core loop).
--
-- Play poker hands to beat a blind's target score within limited hands.
-- Score = chips x mult. Cards add chip values; jokers modify the total.
-- Earn money, buy jokers in the shop, level up hand types with planet cards,
-- enhance your cards, and survive eight antes of escalating blinds.
--
-- Controls:
--   click cards     select / deselect (max 5)
--   Play Hand       score the selected poker hand
--   Discard         throw away selected cards and draw replacements
--   right-click joker   sell for half its price
--   click shop items    buy joker / planet card / enhance pack
--   enter / space   play hand (or start run on menu/over/win)
--   D               discard
--
-- Visuals: pip-pattern cards, smooth lerp animations, deal/play/fly
-- transitions, scoring pulse + particles, glow on selected cards, background
-- gradient, animated score panel. Engine features: rounded-rect draws,
-- text_width for centering, set_maximized, generated sound, multi-file
-- project via require().

require("cards")
require("poker")
require("shop")
require("ui")

-- == Layout (scales to fill the window) ====================================
local _CW, _CH, _GAP, _SEL = 70, 98, 14, 24
local _JW, _JH, _JG = 62, 84, 10
local _BARH, _BTNW, _BTNH = 50, 180, 42
_SPW, _SPH = 460, 90
_SHOPW, _SHOPH, _SHOPG = 150, 200, 30
S = 1
CW, CH, GAP, SEL_RISE = _CW, _CH, _GAP, _SEL
JW, JH, JGAP = _JW, _JH, _JG
W, H = 960, 600
CX0, HAND_Y, PX0, PLAY_Y, JX0, JY, BTN_Y = 0, 0, 0, 0, 0, 0, 0
SP_Y = 0
BARH = _BARH
BTNW, BTNH = _BTNW, _BTNH
DECK_X, DECK_Y = 0, 0

function FS(sz) return math.max(1, math.floor(sz * S)) end
function ctext(str, sz, cx, y)
  draw_text(str, cx - text_width(str, FS(sz)) / 2, y, FS(sz))
end

-- word-wrap a string to max_w pixels, left-aligned; returns height used
function draw_wrapped(str, x, y, max_w, sz, line_h)
  local sz_i = FS(sz)
  local cy = y
  local line = ""
  for w in string.gmatch(str, "%S+") do
    local test = line == "" and w or (line .. " " .. w)
    if text_width(test, sz_i) > max_w and line ~= "" then
      draw_text(line, x, cy, sz_i)
      cy = cy + line_h
      line = w
    else
      line = test
    end
  end
  if line ~= "" then draw_text(line, x, cy, sz_i); cy = cy + line_h end
  return cy - y
end

-- word-wrap centered on cx; returns height used
function draw_wrapped_center(str, cx, y, max_w, sz, line_h)
  local sz_i = FS(sz)
  local cy = y
  local line = ""
  local function emit(l) draw_text(l, cx - text_width(l, sz_i) / 2, cy, sz_i) end
  for w in string.gmatch(str, "%S+") do
    local test = line == "" and w or (line .. " " .. w)
    if text_width(test, sz_i) > max_w and line ~= "" then
      emit(line)
      cy = cy + line_h
      line = w
    else
      line = test
    end
  end
  if line ~= "" then emit(line); cy = cy + line_h end
  return cy - y
end

local function layout()
  S = math.min(W / 960, H / 600)
  CW, CH, GAP, SEL_RISE = _CW*S, _CH*S, _GAP*S, _SEL*S
  JW, JH, JGAP = _JW*S, _JH*S, _JG*S
  BARH = _BARH * S
  BTNW, BTNH = _BTNW*S, _BTNH*S
  CX0 = (W - (8*CW + 7*GAP)) / 2
  PX0 = (W - (5*CW + 4*GAP)) / 2
  JX0 = (W - (5*JW + 4*JGAP)) / 2
  JY = BARH + 12*S
  PLAY_Y = JY + JH + GAP
  SP_Y = PLAY_Y + CH + math.floor(7*S)
  HAND_Y = H - CH - GAP - BTNH - 20*S
  BTN_Y = H - BTNH - 10*S
  DECK_X, DECK_Y = W - 80*S, BTN_Y - 10*S
end

-- == Colors ===============================================================
COL = {
  bg_top = {14,16,32},
  bg_bot = {26,22,52},
  panel   = {32,36,60},
  panel2  = {40,44,72},
  card    = {250,246,235},
  card_edge = {200,195,180},
  red     = {210,56,78},
  black   = {44,46,64},
  chips   = {74,134,220},
  mult    = {226,64,84},
  money   = {222,182,72},
  play    = {70,176,96},
  discard = {200,80,92},
  gold    = {240,200,90},
  text    = {235,235,245},
  dim     = {150,152,170},
  jokerbg = {28,30,52},
  enh     = {bonus={80,140,220}, mult={210,70,90}, glass={130,220,240}, gold={240,200,90}},
}
RARITY_COL = {common={120,150,210}, uncommon={110,210,130}, rare={230,180,80}, legendary={220,100,220}}

-- == State ================================================================
state = "MENU"
run_seed = 2026
ante = 1
blind_index = 1
boss = nil
target = 0
round_score = 0
hands_left = 4
discards_left = 3
hand_size = 8
money = 4
joker_slots = 5
master_deck = {}
drawpile = {}
hand = {}
selected = {}
jokers = {}
hand_levels = {}
shop_items = {}
pack_kind = nil
played = {}
scoring_cards = {}
events = {}
ev_i = 0
ev_timer = 0
cur_chips = 0
cur_mult = 0
cur_card = 0
score_done_timer = 0
breaks = {}
toast = ""
toast_t = 0
last_round_reward = 0
time = 0
flash = 0
particles = {}
chips_pop = 0
mult_pop = 0

-- == Helpers ==============================================================
function cstr(t) return t[1],t[2],t[3],t[4] or 255 end
function rr(x,y,w,h,r) draw_rounded_rect(x,y,w,h,r or 0.15) end
function rro(x,y,w,h,r,t) draw_rounded_rect_outline(x,y,w,h,r or 0.15,(t or 2)*S) end
function hit(mx,my,x,y,w,h) return mx>=x and mx<=x+w and my>=y and my<=y+h end
function fmt(n) return tostring(math.floor(n)) end
function show(msg) toast = msg; toast_t = 1.8 end
function lerp(a,b,t) return a + (b-a)*t end
function clamp_l(v,lo,hi) return v<lo and lo or (v>hi and hi or v) end

-- == Run / blind flow =====================================================
function start_blind()
  drawpile = {}
  for _,c in ipairs(master_deck) do table.insert(drawpile, c) end
  shuffle(drawpile)
  hand = {}
  selected = {}
  round_score = 0
  breaks = {}
  hand_size = 8
  hands_left = 4
  discards_left = 3
  boss = nil
  if blind_index == 3 then
    boss = BOSSES[math.floor(rand(1, #BOSSES+1))]
    if boss.id=="needle"  then hands_left = 1 end
    if boss.id=="manacle" then hand_size = 7 end
  end
  local base_target = ANTE[ante][blind_index]
  if boss and boss.id=="wall" then base_target = base_target * 2 end
  target = base_target
  draw_to_fill()
  if boss and boss.id=="hook" then
    for k=1,2 do
      if #hand > 0 then
        local i = math.floor(rand(1, #hand+1))
        table.remove(hand, i)
      end
    end
    draw_to_fill()
  end
  state = "BLIND"
end

local function start_run()
  srand(run_seed)
  build_deck()
  hand_levels = copy_levels()
  ante = 1
  blind_index = 1
  money = 4
  jokers = {}
  start_blind()
end

local function blind_won()
  local reward = BLIND_REWARD[blind_index]
  local interest = math.min(math.floor(money/5), 5)
  local hand_bonus = hands_left
  last_round_reward = reward + interest + hand_bonus
  money = money + last_round_reward
  local gold = 0
  for _,c in ipairs(hand) do if c.enh=="gold" then gold = gold + 3 end end
  money = money + gold
  last_round_reward = last_round_reward + gold
  play_sound("win")
  show("Blind beaten! +$" .. last_round_reward)
  flash = 0.6
  state = "SHOP"
  build_shop()
end

local function blind_lost()
  play_sound("lose")
  state = "OVER"
end

local function next_blind()
  if blind_index == 3 then
    if ante >= 8 then state = "WIN"; play_sound("win"); return end
    ante = ante + 1
    blind_index = 1
  else
    blind_index = blind_index + 1
  end
  start_blind()
end

-- == Playing a hand / discarding =========================================
local function play_hand()
  local sel = selected_list()
  if #sel < 1 or #sel > 5 then show("Select 1-5 cards") return end
  local ht, sc = evaluate(sel)
  played = sel
  scoring_cards = sc
  remove_from_hand(sel)
  clear_selection()
  hands_left = hands_left - 1
  events = build_events(ht, sc, sel)
  ev_i = 0
  ev_timer = 0
  cur_chips = 0
  cur_mult = 0
  cur_card = 0
  score_done_timer = 0
  breaks = {}
  state = "SCORE"
  play_sound("play")
end

local function discard_hand()
  local sel = selected_list()
  if #sel < 1 or #sel > 5 then show("Select 1-5 cards") return end
  if discards_left <= 0 then show("No discards left") return end
  remove_from_hand(sel)
  clear_selection()
  discards_left = discards_left - 1
  draw_to_fill()
  play_sound("discard")
end

local function resolve_score()
  local gained = cur_chips * cur_mult
  round_score = round_score + gained
  for _,c in ipairs(breaks) do
    local idx = find_master(c.uid)
    if idx then table.remove(master_deck, idx) end
    for di=#drawpile,1,-1 do
      if drawpile[di].uid == c.uid then table.remove(drawpile, di) break end
    end
  end
  breaks = {}
  if round_score >= target then
    blind_won()
  elseif hands_left <= 0 then
    blind_lost()
  else
    draw_to_fill()
    state = "BLIND"
  end
end

-- == Input ================================================================
local function handle_click()
  local mx,my = mouse_pos()
  if state=="MENU" then
    run_seed = run_seed + 1; start_run(); return
  end
  if state=="OVER" or state=="WIN" then
    run_seed = run_seed + 1; start_run(); return
  end
  if state=="BLIND" then
    for i,c in ipairs(hand) do
      local x = CX0 + (i-1)*(CW+GAP)
      local y = HAND_Y - (selected[c.uid] and SEL_RISE or 0)
      if hit(mx,my,x,y,CW,CH) then
        if selected[c.uid] then selected[c.uid]=nil
        elseif selected_count()<5 then selected[c.uid]=true; play_sound("select")
        else show("Max 5 cards") end
        return
      end
    end
    if hit(mx,my,W/2-300*S,BTN_Y,BTNW,BTNH) then play_hand(); return end
    if hit(mx,my,W/2+120*S,BTN_Y,BTNW,BTNH) then discard_hand(); return end
  elseif state=="SHOP" then
    local px, py, pw, ph, iy, by = shop_layout()
    local iw,ih = _SHOPW*S, _SHOPH*S
    local n=#shop_items
    local total=n*iw+(n-1)*_SHOPG*S
    local ix0 = W/2-total/2
    for i,it in ipairs(shop_items) do
      local x = ix0 + (i-1)*(iw+_SHOPG*S)
      local y = iy
      if hit(mx,my,x,y,iw,ih) and not it.bought then buy_item(it); return end
    end
    if hit(mx,my,W/2-190*S,by,170*S,44*S) then reroll_shop(); return end
    if hit(mx,my,W/2+20*S,by,170*S,44*S) then next_blind(); return end
  elseif state=="PACK" then
    for i,c in ipairs(hand) do
      local x = CX0 + (i-1)*(CW+GAP)
      local y = HAND_Y
      if hit(mx,my,x,y,CW,CH) then
        local enh = pick_enh()
        c.enh = enh
        play_sound("buy")
        show("Card enhanced: " .. enh)
        state = "SHOP"
        return
      end
    end
  end
end

local function handle_right_click()
  local mx,my = mouse_pos()
  if state=="PACK" then state = "SHOP"; return end
  if state=="BLIND" or state=="SHOP" then
    for i,j in ipairs(jokers) do
      local x = JX0 + (i-1)*(JW+JGAP)
      if hit(mx,my,x,JY,JW,JH) then
        local refund = math.floor(j.def.cost/2)
        money = money + refund
        table.remove(jokers, i)
        show("Sold for $" .. refund)
        play_sound("buy")
        return
      end
    end
  end
end

-- == Callbacks ============================================================
function on_init()
  set_maximized(true)
  W, H = screen_size()
  layout()
  set_clear_color(cstr(COL.bg_top))
  gen_face_sprites()
  gen_sound("select", {wave="sine",     freq=600, slide=900,  len=0.07, vol=0.25})
  gen_sound("play",   {wave="triangle", freq=500, slide=180,  len=0.18, vol=0.35})
  gen_sound("discard",{wave="noise",    freq=240,             len=0.14, vol=0.28})
  gen_sound("score",  {wave="square",   freq=900,             len=0.04, vol=0.18})
  gen_sound("win",    {wave="sine",     freq=520, slide=1100, len=0.45, vol=0.4})
  gen_sound("lose",   {wave="saw",      freq=420, slide=90,   len=0.55, vol=0.4})
  gen_sound("buy",    {wave="square",   freq=1200,slide=1700, len=0.10, vol=0.3})
  gen_sound("reroll", {wave="noise",    freq=700,             len=0.18, vol=0.28})
  state = "MENU"
end

function on_update(dt)
  time = time + dt
  local nw, nh = screen_size()
  if nw ~= W or nh ~= H then
    W, H = nw, nh
    layout()
  end
  if toast_t > 0 then toast_t = toast_t - dt end
  if flash > 0 then flash = flash - dt * 2 end
  -- decay deal delays
  for _,c in ipairs(hand) do
    if c.deal > 0 then c.deal = c.deal - dt end
    if c.pulse and c.pulse > 0 then c.pulse = math.max(0, c.pulse - dt * 4) end
  end
  for _,c in ipairs(played) do
    if c.pulse and c.pulse > 0 then c.pulse = math.max(0, c.pulse - dt * 4) end
  end
  -- decay pop timers
  chips_pop = math.max(0, chips_pop - dt * 4)
  mult_pop = math.max(0, mult_pop - dt * 4)
  update_particles(dt)

  if state=="SCORE" then
    ev_timer = ev_timer + dt
    local STEP = 0.12
    while ev_timer >= STEP and ev_i < #events do
      ev_timer = ev_timer - STEP
      ev_i = ev_i + 1
      local ev = events[ev_i]
      cur_chips = cur_chips + ev.chips
      cur_mult = cur_mult + ev.mult
      cur_mult = cur_mult * ev.xmult
      if ev.chips ~= 0 then chips_pop = 1 end
      if ev.mult ~= 0 then mult_pop = 1 end
      if ev.card_idx then
        cur_card = ev.card_idx
        if played[ev.card_idx] then played[ev.card_idx].pulse = 1 end
      end
      -- spawn particles at score panel
      local px = W/2
      local py = SP_Y + _SPH*S*0.5
      spawn_particles(px, py, 5, ev.col)
      play_sound("score")
    end
    if ev_i >= #events then
      score_done_timer = score_done_timer + dt
      if score_done_timer > 0.6 then
        resolve_score()
      end
    end
  end
  if mouse_pressed("left") then handle_click() end
  if mouse_pressed("right") then handle_right_click() end
  -- keyboard shortcuts
  if state=="BLIND" then
    if key_pressed("enter") or key_pressed("space") then play_hand() end
    if key_pressed("d") then discard_hand() end
  elseif state=="MENU" or state=="OVER" or state=="WIN" then
    if key_pressed("enter") or key_pressed("space") then
      run_seed = run_seed + 1; start_run()
    end
  end
end

function on_gui()
  tooltip_data = nil
  if state=="MENU" then draw_menu(); draw_toast(); return end
  draw_background()
  draw_particles()
  if state=="OVER" then
    draw_top_bar(); draw_joker_row(); draw_over(); draw_toast(); return
  end
  if state=="WIN" then
    draw_top_bar(); draw_joker_row(); draw_win(); draw_toast(); return
  end
  draw_top_bar()
  draw_joker_row()
  if state ~= "SHOP" and state ~= "PACK" then
    draw_score_panel()
    draw_played_area()
    draw_hand()
    draw_deck_icon()
    draw_buttons()
  end
  if state=="SHOP" then draw_shop() end
  if state=="PACK" then draw_pack() end
  -- flash overlay
  if flash > 0 then
    set_color(255, 255, 255, flash * 120)
    draw_rect(0, 0, W, H)
  end
  draw_tooltips()
  draw_toast()
end
