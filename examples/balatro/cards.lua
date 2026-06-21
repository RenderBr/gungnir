-- cards.lua: card data, creation, drawing, and pixel-art sprite generation.

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

function rank_chips(c)
  local r = c.rank
  if r=="A" then return 11 end
  if r=="K" or r=="Q" or r=="J" then return 10 end
  return tonumber(r)
end
function is_face(c) return c.rank=="J" or c.rank=="Q" or c.rank=="K" end
function is_even(r) return r=="2" or r=="4" or r=="6" or r=="8" or r=="10" end
function is_odd(r)  return r=="A" or r=="3" or r=="5" or r=="7" or r=="9" end
function is_fib(r)  return r=="A" or r=="2" or r=="3" or r=="5" or r=="8" end

-- == Card creation & deck management =======================================
local uid_n = 0
function uid_counter() uid_n = uid_n + 1 return uid_n end

local function new_card(rank, suit, enh)
  return {uid=uid_counter(), rank=rank, suit=suit, enh=enh,
          ax=nil, ay=nil, pulse=0, deal=0}
end

function build_deck()
  master_deck = {}
  for _,s in ipairs(SUITS) do
    for _,r in ipairs(RANKS) do
      table.insert(master_deck, new_card(r, s, nil))
    end
  end
end

function shuffle(t)
  for i=#t,2,-1 do
    local j = math.floor(rand(1, i+1))
    t[i], t[j] = t[j], t[i]
  end
end

function draw_to_fill()
  while #hand < hand_size and #drawpile > 0 do
    local c = table.remove(drawpile)
    -- deal animation: start from deck position with stagger
    c.ax = DECK_X
    c.ay = DECK_Y
    c.deal = #hand * 0.05
    table.insert(hand, c)
  end
end

function selected_list()
  local out={}
  for _,c in ipairs(hand) do if selected[c.uid] then table.insert(out,c) end end
  return out
end
function selected_count() local n=0 for _ in pairs(selected) do n=n+1 end return n end
function clear_selection() selected = {} end

function remove_from_hand(cards)
  local want={}
  for _,c in ipairs(cards) do want[c.uid]=true end
  local keep={}
  for _,c in ipairs(hand) do if not want[c.uid] then table.insert(keep,c) end end
  hand = keep
end

function find_master(uid)
  for i,c in ipairs(master_deck) do if c.uid==uid then return i,c end end
  return nil
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

function draw_card(c, x, y, opts)
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

function gen_face_sprites()
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
