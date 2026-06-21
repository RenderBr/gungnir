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
-- text_width for centering, set_maximized, generated sound.

-- == Layout (scales to fill the window) ====================================
local _CW, _CH, _GAP, _SEL = 70, 98, 14, 24
local _JW, _JH, _JG = 62, 84, 10
local _BARH, _BTNW, _BTNH = 50, 180, 42
local _SPW, _SPH = 460, 90
local _SHOPW, _SHOPH, _SHOPG = 150, 200, 30
S = 1
CW, CH, GAP, SEL_RISE = _CW, _CH, _GAP, _SEL
JW, JH, JGAP = _JW, _JH, _JG
W, H = 960, 600
CX0, HAND_Y, PX0, PLAY_Y, JX0, JY, BTN_Y = 0, 0, 0, 0, 0, 0, 0
SP_Y = 0
BARH = _BARH
BTNW, BTNH = _BTNW, _BTNH
DECK_X, DECK_Y = 0, 0

local function FS(sz) return math.max(1, math.floor(sz * S)) end
local function ctext(str, sz, cx, y)
  draw_text(str, cx - text_width(str, FS(sz)) / 2, y, FS(sz))
end

-- word-wrap a string to max_w pixels, left-aligned; returns height used
local function draw_wrapped(str, x, y, max_w, sz, line_h)
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
local function draw_wrapped_center(str, cx, y, max_w, sz, line_h)
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

-- == Poker hands ==========================================================
HAND_BASE = {
  ["High Card"]       = {chips=5,   mult=1},
  ["Pair"]            = {chips=10,  mult=2},
  ["Two Pair"]        = {chips=20,  mult=2},
  ["Three of a Kind"] = {chips=40,  mult=3},
  ["Straight"]        = {chips=30,  mult=4},
  ["Flush"]           = {chips=35,  mult=4},
  ["Full House"]      = {chips=40,  mult=4},
  ["Four of a Kind"]  = {chips=60,  mult=7},
  ["Straight Flush"]  = {chips=100, mult=8},
  ["Royal Flush"]     = {chips=100, mult=8},
}
HAND_UP = {
  ["High Card"]       = {chips=5,  mult=1},
  ["Pair"]            = {chips=10, mult=1},
  ["Two Pair"]        = {chips=15, mult=1},
  ["Three of a Kind"] = {chips=20, mult=2},
  ["Straight"]        = {chips=25, mult=3},
  ["Flush"]           = {chips=25, mult=2},
  ["Full House"]      = {chips=25, mult=2},
  ["Four of a Kind"]  = {chips=35, mult=3},
  ["Straight Flush"]  = {chips=40, mult=3},
  ["Royal Flush"]     = {chips=40, mult=3},
}
HAND_ORDER = {
  "Royal Flush","Straight Flush","Four of a Kind","Full House","Flush",
  "Straight","Three of a Kind","Two Pair","Pair","High Card",
}

-- == Ante table ===========================================================
ANTE = {
  {300,450,600}, {800,1200,1600}, {2000,3000,4000}, {5000,7000,9000},
  {11000,13000,15000}, {17000,19000,21000}, {23000,25000,27000}, {29000,31000,33000},
}
BLIND_REWARD = {3,4,5}
BLIND_NAME = {"Small Blind","Big Blind","Boss Blind"}

-- == Ranks & suits ========================================================
RANKS = {"A","2","3","4","5","6","7","8","9","10","J","Q","K"}
SUITS = {"H","D","C","S"}
RANK_VAL = {A=14,["2"]=2,["3"]=3,["4"]=4,["5"]=5,["6"]=6,["7"]=7,["8"]=8,["9"]=9,["10"]=10,J=11,Q=12,K=13}

-- pip layout positions as fractions of the card content area (0..1)
-- arranged like a real playing card (top-left origin)
PIPS = {
  ["2"] = {{0.5,0.16},{0.5,0.84}},
  ["3"] = {{0.5,0.16},{0.5,0.5},{0.5,0.84}},
  ["4"] = {{0.28,0.16},{0.72,0.16},{0.28,0.84},{0.72,0.84}},
  ["5"] = {{0.28,0.16},{0.72,0.16},{0.5,0.5},{0.28,0.84},{0.72,0.84}},
  ["6"] = {{0.28,0.16},{0.72,0.16},{0.28,0.5},{0.72,0.5},{0.28,0.84},{0.72,0.84}},
  ["7"] = {{0.28,0.16},{0.72,0.16},{0.5,0.33},{0.28,0.5},{0.72,0.5},{0.28,0.84},{0.72,0.84}},
  ["8"] = {{0.28,0.16},{0.72,0.16},{0.5,0.33},{0.28,0.5},{0.72,0.5},{0.5,0.67},{0.28,0.84},{0.72,0.84}},
  ["9"] = {{0.28,0.14},{0.72,0.14},{0.28,0.37},{0.72,0.37},{0.5,0.5},{0.28,0.63},{0.72,0.63},{0.28,0.86},{0.72,0.86}},
  ["10"]= {{0.28,0.14},{0.72,0.14},{0.5,0.24},{0.28,0.37},{0.72,0.37},{0.28,0.63},{0.72,0.63},{0.5,0.76},{0.28,0.86},{0.72,0.86}},
}

local function rank_chips(c)
  local r = c.rank
  if r=="A" then return 11 end
  if r=="K" or r=="Q" or r=="J" then return 10 end
  return tonumber(r)
end
local function is_face(c) return c.rank=="J" or c.rank=="Q" or c.rank=="K" end
local function is_even(r) return r=="2" or r=="4" or r=="6" or r=="8" or r=="10" end
local function is_odd(r)  return r=="A" or r=="3" or r=="5" or r=="7" or r=="9" end
local function is_fib(r)  return r=="A" or r=="2" or r=="3" or r=="5" or r=="8" end

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

-- == Jokers ===============================================================
JOKERS = {}
JOKER_LIST = {}
local function J(id, name, cost, rarity, desc, f)
  local d = {id=id, name=name, cost=cost, rarity=rarity, desc=desc, apply=f}
  JOKERS[id] = d; table.insert(JOKER_LIST, d)
end
J("joker","Joker",2,"common","+4 Mult",
  function(c) if not c.card then return 0,4,1 end end)
J("greedy","Greedy Joker",5,"common","+3 Mult per Diamond",
  function(c) if c.card and c.card.suit=="D" then return 0,3,1 end end)
J("lusty","Lusty Joker",5,"common","+3 Mult per Heart",
  function(c) if c.card and c.card.suit=="H" then return 0,3,1 end end)
J("wrathful","Wrathful Joker",5,"common","+3 Mult per Spade",
  function(c) if c.card and c.card.suit=="S" then return 0,3,1 end end)
J("gluttonous","Gluttonous Joker",5,"common","+3 Mult per Club",
  function(c) if c.card and c.card.suit=="C" then return 0,3,1 end end)
J("jolly","Jolly Joker",3,"common","+8 Mult if hand has a Pair",
  function(c) if not c.card and c.has_pair then return 0,8,1 end end)
J("zany","Zany Joker",4,"common","+12 Mult if hand has 3 of a Kind",
  function(c) if not c.card and c.has_three then return 0,12,1 end end)
J("mad","Mad Joker",4,"common","+10 Mult if hand has Two Pair",
  function(c) if not c.card and c.has_two_pair then return 0,10,1 end end)
J("crazy","Crazy Joker",4,"common","+12 Mult if hand has a Straight",
  function(c) if not c.card and c.has_straight then return 0,12,1 end end)
J("sly","Sly Joker",3,"common","+50 Chips if hand has a Pair",
  function(c) if not c.card and c.has_pair then return 50,0,1 end end)
J("wily","Wily Joker",4,"common","+100 Chips if hand has 3 of a Kind",
  function(c) if not c.card and c.has_three then return 100,0,1 end end)
J("crafty","Crafty Joker",4,"common","+80 Chips if hand has a Flush",
  function(c) if not c.card and c.has_flush then return 80,0,1 end end)
J("even_steven","Even Steven",4,"common","+4 Mult per even card (2,4,6,8,10)",
  function(c) if c.card and is_even(c.card.rank) then return 0,4,1 end end)
J("odd_todd","Odd Todd",4,"common","+31 Chips per odd card (A,3,5,7,9)",
  function(c) if c.card and is_odd(c.card.rank) then return 31,0,1 end end)
J("scholar","Scholar",4,"common","+20 Chips & +4 Mult per Ace",
  function(c) if c.card and c.card.rank=="A" then return 20,4,1 end end)
J("scary_face","Scary Face",6,"common","+30 Chips per face card (J,Q,K)",
  function(c) if c.card and is_face(c.card) then return 30,0,1 end end)
J("smiley_face","Smiley Face",6,"common","+5 Mult per face card (J,Q,K)",
  function(c) if c.card and is_face(c.card) then return 0,5,1 end end)
J("abstract","Abstract Joker",6,"common","+3 Mult per Joker owned",
  function(c) if not c.card then return 0, 3*#c.jokers, 1 end end)
J("fibonacci","Fibonacci",8,"uncommon","+8 Mult per A,2,3,5,8",
  function(c) if c.card and is_fib(c.card.rank) then return 0,8,1 end end)

local RARITY_W = {common=1.0, uncommon=0.35}

-- == Boss blinds ==========================================================
BOSSES = {
  {id="hook",   name="The Hook",   desc="2 random cards discarded at round start"},
  {id="needle", name="The Needle", desc="Only 1 hand this round"},
  {id="wall",   name="The Wall",   desc="Score requirement doubled"},
  {id="pillar", name="The Pillar", desc="Face cards (J,Q,K) are debuffed"},
  {id="manacle",name="The Manacle",desc="Draw 7 cards instead of 8"},
  {id="club",   name="The Club",   desc="Clubs are debuffed"},
}
local function boss_debuffs(card)
  if not boss then return false end
  if boss.id=="pillar" and is_face(card) then return true end
  if boss.id=="club" and card.suit=="C" then return true end
  return false
end

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
local function cstr(t) return t[1],t[2],t[3],t[4] or 255 end
local function rr(x,y,w,h,r) draw_rounded_rect(x,y,w,h,r or 0.15) end
local function rro(x,y,w,h,r,t) draw_rounded_rect_outline(x,y,w,h,r or 0.15,(t or 2)*S) end
local function hit(mx,my,x,y,w,h) return mx>=x and mx<=x+w and my>=y and my<=y+h end
local function fmt(n) return tostring(math.floor(n)) end
local function show(msg) toast = msg; toast_t = 1.8 end
local function lerp(a,b,t) return a + (b-a)*t end
local function clamp_l(v,lo,hi) return v<lo and lo or (v>hi and hi or v) end

local function copy_levels()
  local t={}
  for _,ht in ipairs(HAND_ORDER) do
    t[ht] = {chips=HAND_BASE[ht].chips, mult=HAND_BASE[ht].mult, level=1}
  end
  return t
end
local function hand_level(ht) return hand_levels[ht] end

local uid_n = 0
local function uid_counter() uid_n = uid_n + 1 return uid_n end

local function new_card(rank, suit, enh)
  return {uid=uid_counter(), rank=rank, suit=suit, enh=enh,
          ax=nil, ay=nil, pulse=0, deal=0}
end

local function build_deck()
  master_deck = {}
  for _,s in ipairs(SUITS) do
    for _,r in ipairs(RANKS) do
      table.insert(master_deck, new_card(r, s, nil))
    end
  end
end

local function shuffle(t)
  for i=#t,2,-1 do
    local j = math.floor(rand(1, i+1))
    t[i], t[j] = t[j], t[i]
  end
end

local function draw_to_fill()
  while #hand < hand_size and #drawpile > 0 do
    local c = table.remove(drawpile)
    -- deal animation: start from deck position with stagger
    c.ax = DECK_X
    c.ay = DECK_Y
    c.deal = #hand * 0.05
    table.insert(hand, c)
  end
end

local function selected_list()
  local out={}
  for _,c in ipairs(hand) do if selected[c.uid] then table.insert(out,c) end end
  return out
end
local function selected_count() local n=0 for _ in pairs(selected) do n=n+1 end return n end
local function clear_selection() selected = {} end

local function remove_from_hand(cards)
  local want={}
  for _,c in ipairs(cards) do want[c.uid]=true end
  local keep={}
  for _,c in ipairs(hand) do if not want[c.uid] then table.insert(keep,c) end end
  hand = keep
end

local function find_master(uid)
  for i,c in ipairs(master_deck) do if c.uid==uid then return i,c end end
  return nil
end

-- == Poker hand evaluation ===============================================
local function evaluate(cards)
  local n = #cards
  if n == 0 then return nil end
  local counts = {}
  local suitcount = {}
  for _,c in ipairs(cards) do
    counts[c.rank] = (counts[c.rank] or 0) + 1
    suitcount[c.suit] = (suitcount[c.suit] or 0) + 1
  end
  local is_flush = n==5 and suitcount[cards[1].suit]==5
  local is_straight = false
  if n==5 then
    local seen, vals = {}, {}
    for _,c in ipairs(cards) do
      local v = RANK_VAL[c.rank]
      if not seen[v] then seen[v]=true; table.insert(vals, v) end
    end
    if seen[14] then table.insert(vals, 1) end
    table.sort(vals)
    for i=0, #vals-5 do
      local ok=true
      for j=0,3 do if vals[i+1+j+1] ~= vals[i+1+j]+1 then ok=false break end end
      if ok then is_straight=true break end
    end
  end
  local groups = {}
  for r,c2 in pairs(counts) do table.insert(groups, {n=c2, rank=r}) end
  table.sort(groups, function(a,b) return a.n>b.n or (a.n==b.n and RANK_VAL[a.rank]>RANK_VAL[b.rank]) end)
  local g1 = groups[1] and groups[1].n or 0
  local g2 = groups[2] and groups[2].n or 0

  if is_straight and is_flush then
    if counts["10"] and counts["J"] and counts["Q"] and counts["K"] and counts["A"] then
      return "Royal Flush", cards
    end
    return "Straight Flush", cards
  end
  if g1==4 then
    local sc={} for _,c in ipairs(cards) do if c.rank==groups[1].rank then table.insert(sc,c) end end
    return "Four of a Kind", sc
  end
  if g1==3 and g2==2 then return "Full House", cards end
  if is_flush then return "Flush", cards end
  if is_straight then return "Straight", cards end
  if g1==3 then
    local sc={} for _,c in ipairs(cards) do if c.rank==groups[1].rank then table.insert(sc,c) end end
    return "Three of a Kind", sc
  end
  if g1==2 and g2==2 then
    local sc={} for _,c in ipairs(cards) do
      if c.rank==groups[1].rank or c.rank==groups[2].rank then table.insert(sc,c) end
    end
    return "Two Pair", sc
  end
  if g1==2 then
    local sc={} for _,c in ipairs(cards) do if c.rank==groups[1].rank then table.insert(sc,c) end end
    return "Pair", sc
  end
  local best = cards[1]
  for _,c in ipairs(cards) do if RANK_VAL[c.rank] > RANK_VAL[best.rank] then best=c end end
  return "High Card", {best}
end

-- == Scoring ==============================================================
local function make_ctx(ht, scoring, played_cards)
  local counts={}
  for _,c in ipairs(played_cards) do counts[c.rank]=(counts[c.rank] or 0)+1 end
  local pk, has3 = 0, false
  for _,n in pairs(counts) do if n>=2 then pk=pk+1 end if n>=3 then has3=true end end
  return {
    hand_type=ht, scoring=scoring, played=played_cards, jokers=jokers,
    has_pair=pk>=1, has_two_pair=pk>=2, has_three=has3,
    has_straight=(ht=="Straight" or ht=="Straight Flush" or ht=="Royal Flush"),
    has_flush=(ht=="Flush" or ht=="Straight Flush" or ht=="Royal Flush"),
    card=nil,
  }
end

local function build_events(ht, scoring, played_cards)
  local lv = hand_level(ht)
  local ctx = make_ctx(ht, scoring, played_cards)
  local evs = {}
  local function ad(label, ch, mu, xm, kind, ci, col)
    table.insert(evs, {label=label, chips=ch or 0, mult=mu or 0, xmult=xm or 1, kind=kind, card_idx=ci, col=col})
  end
  ad(ht, lv.chips, lv.mult, 1, "hand", nil, COL.gold)
  local pos = {}
  for i,c in ipairs(played_cards) do pos[c.uid]=i end
  for _,card in ipairs(scoring) do
    local ci = pos[card.uid]
    ctx.card = card
    if boss_debuffs(card) then
      ad(card.rank .. card.suit .. " (debuff)", 0, 0, 1, "debuff", ci, COL.dim)
    else
      local ch = rank_chips(card)
      local mu = 0
      local xm = 1
      if card.enh=="bonus" then ch = ch + 30 end
      if card.enh=="mult"  then mu = mu + 4 end
      if card.enh=="glass" then xm = xm * 2 end
      ad(card.rank .. card.suit, ch, mu, xm, "card", ci, COL.chips)
      for _,j in ipairs(jokers) do
        local jch, jmu, jxm = j.def.apply(ctx)
        if (jch and jch~=0) or (jmu and jmu~=0) or (jxm and jxm~=1) then
          ad(j.def.name, jch, jmu, jxm, "joker", ci, COL.mult)
        end
      end
      if card.enh=="glass" then
        if rand() < 0.25 then table.insert(breaks, card) end
      end
    end
  end
  ctx.card = nil
  for _,j in ipairs(jokers) do
    local jch, jmu, jxm = j.def.apply(ctx)
    if (jch and jch~=0) or (jmu and jmu~=0) or (jxm and jxm~=1) then
      ad(j.def.name, jch, jmu, jxm, "joker", nil, COL.mult)
    end
  end
  return evs
end

-- == Particles ============================================================
local function spawn_particles(x, y, n, col)
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

local function update_particles(dt)
  for i=#particles,1,-1 do
    local p = particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.vy = p.vy + 300 * dt
    p.life = p.life - dt
    if p.life <= 0 then table.remove(particles, i) end
  end
end

local function draw_particles()
  for _,p in ipairs(particles) do
    local a = clamp_l(p.life * 400, 0, 255)
    set_color(p.col[1], p.col[2], p.col[3], a)
    draw_circle(p.x, p.y, p.size * clamp_l(p.life * 1.5, 0.2, 1))
  end
end

-- == Run / blind flow =====================================================
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

-- == Shop =================================================================
local function pick_joker_def()
  local total = 0
  for _,d in ipairs(JOKER_LIST) do total = total + RARITY_W[d.rarity] end
  local r = rand(total)
  local acc = 0
  for _,d in ipairs(JOKER_LIST) do
    acc = acc + RARITY_W[d.rarity]
    if r < acc then return d end
  end
  return JOKER_LIST[#JOKER_LIST]
end

function build_shop()
  shop_items = {}
  for i=1,2 do
    local d = pick_joker_def()
    table.insert(shop_items, {kind="joker", def=d, cost=d.cost})
  end
  local ht = HAND_ORDER[math.floor(rand(1, #HAND_ORDER+1))]
  local up = HAND_UP[ht]
  local cur = hand_levels[ht]
  table.insert(shop_items, {kind="planet", ht=ht, cost=5,
    label="Planet: "..ht, desc="L"..(cur.level+1).."  +"..up.chips.." chips, +"..up.mult.." mult"})
  table.insert(shop_items, {kind="pack", cost=4, label="Enhance Pack",
    desc="Enhance a card in your hand"})
end

local function buy_item(item)
  if money < item.cost then show("Not enough money") return end
  if item.kind=="joker" then
    if #jokers >= joker_slots then show("No joker slots") return end
    money = money - item.cost
    table.insert(jokers, {def=item.def, uid=uid_counter()})
    play_sound("buy")
    item.bought = true
  elseif item.kind=="planet" then
    money = money - item.cost
    local up = HAND_UP[item.ht]
    local cur = hand_levels[item.ht]
    cur.level = cur.level + 1
    cur.chips = cur.chips + up.chips
    cur.mult = cur.mult + up.mult
    play_sound("buy")
    item.bought = true
    show(item.ht .. " -> Level " .. cur.level)
  elseif item.kind=="pack" then
    money = money - item.cost
    play_sound("buy")
    pack_kind = "enhance"
    state = "PACK"
    item.bought = true
  end
end

local function reroll_shop()
  local cost = 5
  if money < cost then show("Not enough money to reroll") return end
  money = money - cost
  play_sound("reroll")
  build_shop()
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

-- == Enhancement pack =====================================================
local ENH_LIST = {"bonus", "mult", "glass", "gold"}
local ENH_W = {bonus=0.40, mult=0.30, glass=0.15, gold=0.15}
local function pick_enh()
  local r = rand()
  local acc = 0
  for _, k in ipairs(ENH_LIST) do
    acc = acc + ENH_W[k]
    if r < acc then return k end
  end
  return "bonus"
end

-- == Drawing: background ==================================================
local function draw_background()
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

-- == Drawing: suit symbols ===============================================
local function tri_fill(ax, ay, by, hw)
  local h = by - ay
  local steps = math.max(1, math.ceil(math.abs(h)))
  for i=0,steps do
    local t = i/steps
    draw_line(ax - hw*t, ay + h*t, ax + hw*t, ay + h*t, 1.2*S)
  end
end
local function diamond_fill(cx, cy, hw, hh)
  local steps = math.max(1, math.ceil(hw))
  for i=0,steps do local t=i/steps draw_line(cx-hw*t, cy-hh+hh*t, cx+hw*t, cy-hh+hh*t, 1.2*S) end
  for i=1,steps do local t=i/steps draw_line(cx-hw*(1-t), cy+hh*t, cx+hw*(1-t), cy+hh*t, 1.2*S) end
end
local function draw_suit(suit, cx, cy, s, col)
  set_color(cstr(col))
  if suit=="D" then
    diamond_fill(cx, cy, s*0.32, s*0.42)
  elseif suit=="H" then
    local r = s*0.2
    draw_circle(cx - r*0.9, cy - r*0.4, r)
    draw_circle(cx + r*0.9, cy - r*0.4, r)
    tri_fill(cx, cy + s*0.42, cy - r*0.2, r*1.5)
  elseif suit=="S" then
    local r = s*0.2
    draw_circle(cx - r*0.9, cy + r*0.2, r)
    draw_circle(cx + r*0.9, cy + r*0.2, r)
    tri_fill(cx, cy - s*0.4, cy + r*0.2, r*1.4)
    draw_rounded_rect(cx - s*0.05, cy + s*0.3, s*0.1, s*0.14, 0.3)
  elseif suit=="C" then
    local r = s*0.18
    draw_circle(cx, cy - r*0.9, r)
    draw_circle(cx - r*0.9, cy + r*0.4, r)
    draw_circle(cx + r*0.9, cy + r*0.4, r)
    draw_rounded_rect(cx - s*0.05, cy + s*0.2, s*0.1, s*0.16, 0.3)
  end
end

-- == Drawing: card content ===============================================
local function suit_col(suit) return (suit=="H" or suit=="D") and COL.red or COL.black end

local function draw_pips(suit, rank, x, y, w, h, scol)
  local pips = PIPS[rank]
  if not pips then return end
  local pip_size = 13 * S
  local ax = x + w * 0.18
  local aw = w * 0.64
  local ay = y + h * 0.12
  local ah = h * 0.76
  for _,p in ipairs(pips) do
    draw_suit(suit, ax + p[1]*aw, ay + p[2]*ah, pip_size, scol)
  end
end

-- sprite dimensions (pixel art generated in on_init via gen_face_sprites)
FACE_SPRITE_W = 10
FACE_SPRITE_H = 14
JOKER_SPRITE_W = 12
JOKER_SPRITE_H = 14

local function face_sprite(rank, suit)
  local is_red = (suit=="H" or suit=="D")
  local suffix = is_red and "_r" or "_d"
  local prefix = rank=="K" and "face_k" or (rank=="Q" and "face_q" or "face_j")
  return prefix .. suffix
end

local function draw_face_card(rank, suit, x, y, w, h, scol)
  -- draw the pixel-art portrait sprite in the center
  local sprite = face_sprite(rank, suit)
  local target_w = w * 0.72
  local target_h = h * 0.72
  -- draw_sprite is centered, so use card center
  local cx, cy = x + w/2, y + h/2 + 2*S
  -- scale to fit: pick the smaller scale so the sprite fits
  local sw, sh = FACE_SPRITE_W, FACE_SPRITE_H
  local sx = target_w / sw
  local sy = target_h / sh
  local sc = math.min(sx, sy)
  draw_sprite(sprite, cx, cy, 0, sc)
  -- decorative inner frame around the portrait
  set_color(scol[1], scol[2], scol[3], 100)
  rro(x + w*0.12, y + h*0.08, w*0.76, h*0.84, 0.06, 1)
end

local function draw_card(c, x, y, opts)
  opts = opts or {}
  local scale = opts.scale or 1
  local w, h = CW * scale, CH * scale
  -- recenter on original slot
  local dx = x + (CW - w) / 2
  local dy = y + (CH - h) / 2
  local dim = opts.dim
  local hl = opts.highlight
  local scol = dim and COL.dim or suit_col(c.suit)

  -- glow behind selected card
  if hl then
    local pulse = 0.5 + 0.5 * math.sin(time * 6)
    set_color(COL.gold[1], COL.gold[2], COL.gold[3], 50 + pulse * 60)
    rr(dx - 6*S, dy - 6*S, w + 12*S, h + 12*S, 0.15)
  end

  -- shadow
  set_color(0, 0, 0, 90)
  rr(dx + 3*S, dy + 4*S, w, h, 0.12)
  -- face
  if dim then set_color(180,180,190) else set_color(cstr(COL.card)) end
  rr(dx, dy, w, h, 0.12)
  -- enhancement fill tint
  if c.enh and not dim then
    local ec = COL.enh[c.enh]
    set_color(ec[1], ec[2], ec[3], 30)
    rr(dx, dy, w, h, 0.12)
  end
  -- border
  if c.enh then
    local ec = COL.enh[c.enh]
    set_color(ec[1], ec[2], ec[3], 220)
    rro(dx, dy, w, h, 0.12, 2)
  else
    set_color(cstr(COL.card_edge))
    rro(dx, dy, w, h, 0.12, 1.5)
  end
  -- highlight border
  if hl then
    local pulse = 0.5 + 0.5 * math.sin(time * 6)
    set_color(COL.gold[1], COL.gold[2], COL.gold[3], 200 + pulse * 55)
    rro(dx - 2*S, dy - 2*S, w + 4*S, h + 4*S, 0.12, 2.5)
  end

  if dim then
    set_color(160, 160, 170)
  else
    set_color(cstr(scol))
  end

  -- corner: rank + small suit below it
  local corner_sz = FS(13)
  local corner_w = text_width(c.rank, corner_sz)
  local corner_x = dx + 4*S
  local corner_y = dy + 3*S
  if dim then set_color(160,160,170) else set_color(cstr(scol)) end
  draw_text(c.rank, corner_x, corner_y, corner_sz)
  -- small suit symbol centered under the rank
  draw_suit(c.suit, corner_x + corner_w/2, corner_y + corner_sz + 8*S, 9*S, dim and COL.dim or scol)
  -- bottom-right corner (mirrored)
  local br_x = dx + w - corner_w - 4*S
  local br_y = dy + h - corner_sz - 3*S
  if dim then set_color(160,160,170) else set_color(cstr(scol)) end
  draw_text(c.rank, br_x, br_y, corner_sz)
  draw_suit(c.suit, br_x + corner_w/2, br_y - 10*S, 9*S, dim and COL.dim or scol)

  -- center content
  local r = c.rank
  if r == "A" then
    draw_suit(c.suit, dx + w/2, dy + h/2 + 2*S, 36*S, dim and COL.dim or scol)
  elseif r == "J" or r == "Q" or r == "K" then
    draw_face_card(r, c.suit, dx, dy, w, h, dim and COL.dim or scol)
  else
    draw_pips(c.suit, r, dx, dy, w, h, dim and COL.dim or scol)
  end

  -- enhancement tag
  if c.enh then
    local tag = (c.enh=="bonus" and "+Ch") or (c.enh=="mult" and "+Mu") or
                (c.enh=="glass" and "x2") or (c.enh=="gold" and "$$")
    local ec = COL.enh[c.enh]
    set_color(ec[1], ec[2], ec[3], 220)
    draw_text(tag, dx + 4*S, dy + h - 14*S, FS(10))
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
local function draw_top_bar()
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

local function draw_score_panel()
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

local function draw_joker_row()
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

local function draw_tooltips()
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

local function draw_hand()
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

local function draw_played_area()
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

local function draw_deck_icon()
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

local function draw_buttons()
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
local function shop_layout()
  local top = JY + JH + 8*S
  local px = 40*S
  local py = top + 4*S
  local iy = py + 52*S
  local ih = _SHOPH*S
  local by = iy + ih + 20*S
  local pw = W - 80*S
  local ph = by + 54*S - py
  return px, py, pw, ph, iy, by
end

local function draw_shop()
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

local function draw_pack()
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
local function draw_menu()
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

local function draw_over()
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

local function draw_win()
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
local function draw_toast()
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

-- == Sprite generation (pixel art for face cards + joker) =================
local KING_ROWS = {
  ".g..g..g..",
  "gggggggggg",
  "gRgggggRgg",
  "gggggggggg",
  ".ffffffff.",
  ".f.dd.dd.f",
  ".f.dd.dd.f",
  ".ffff.ffff",
  ".ff.aa.ff.",
  ".ffffffff.",
  "..hhhhhh..",
  ".bbbbbbbb.",
  ".bbbbbbbb.",
  "..bbbbbb..",
}
local QUEEN_ROWS = {
  "....gg....",
  "...gRgGg..",
  "..gGgggGg.",
  "gggggggggg",
  ".hfffffhh.",
  ".hh.dd.hh.",
  ".hh.dd.hh.",
  ".hfff.fffh",
  ".hff.aa.fh",
  ".hfff.fffh",
  ".hhfffffhh",
  ".hhhhhhhh.",
  ".bbbbbbbb.",
  "..bbbbbb..",
}
local JACK_ROWS = {
  ".....r....",
  "....rrr...",
  "...rrGrr..",
  "..rrgggrr.",
  ".rrggggrr.",
  "rrggggggrr",
  ".gggggggg.",
  ".ffffffff.",
  ".f.dd.dd.f",
  ".f.dd.dd.f",
  ".ffff.ffff",
  ".ffffffff.",
  ".bbbbbbbb.",
  "..bbbbbb..",
}
local JOKER_ROWS = {
  "....gggg....",
  "...gffffg...",
  "..gffGGffg..",
  "..gfGGGGfg..",
  "..gfGddGfg..",
  "..gfGGGGfg..",
  "..gffGGffg..",
  "..gffffffg..",
  "...gffffg...",
  "....gffg....",
  "....gbbg....",
  "...gggggg...",
  "..g.gggg.g..",
  "..gggggggg..",
}

local function gen_face_sprites()
  local common = {g="#d4af37", G="#f0d050", r="#e04050", R="#c02030",
                  f="#e8c890", d="#1a1a2a", a="#c87060"}
  local red_pal = {}
  for k,v in pairs(common) do red_pal[k] = v end
  red_pal.b = "#c83838"; red_pal.h = "#a04030"
  local blk_pal = {}
  for k,v in pairs(common) do blk_pal[k] = v end
  blk_pal.b = "#2a2a3a"; blk_pal.h = "#1a1a2a"
  gen_pixels("face_k_r", KING_ROWS,  red_pal)
  gen_pixels("face_k_d", KING_ROWS,  blk_pal)
  gen_pixels("face_q_r", QUEEN_ROWS, red_pal)
  gen_pixels("face_q_d", QUEEN_ROWS, blk_pal)
  gen_pixels("face_j_r", JACK_ROWS,  red_pal)
  gen_pixels("face_j_d", JACK_ROWS,  blk_pal)
  gen_pixels("joker_face", JOKER_ROWS,
    {g="#d4af37", G="#f0d050", f="#e8c890", d="#1a1a2a", b="#4a4a6a"})
  -- planet icon: a simple circle with ring
  gen_pixels("planet_icon", {
    "...bbbb...",
    "..bwwwwb..",
    ".bwwwwwwb.",
    "bwwGGGGwwb",
    "bwGGGGGGwb",
    "bwGGGGGGwb",
    "bwwGGGGwwb",
    ".bwwwwwwb.",
    "..bwwwwb..",
    "...bbbb...",
  }, {b="#3a5a8a", w="#6a9ad4", G="#a0c8f0"})
  -- pack icon: a small gift box
  gen_pixels("pack_icon", {
    "...rrrr...",
    "..rrrrrr..",
    ".rrggggrr.",
    "rrggggggrr",
    "rggggggggr",
    "rggggggggr",
    "rggggggggr",
    "rggggggggr",
    ".gggggggg.",
    "..gggggg..",
  }, {r="#d4404a", g="#e8a050"})
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
