-- poker.lua: hand tables, evaluation, scoring, jokers, and boss blinds.

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

RARITY_W = {common=1.0, uncommon=0.35}

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

-- == Hand level helpers ===================================================
function copy_levels()
  local t={}
  for _,ht in ipairs(HAND_ORDER) do
    t[ht] = {chips=HAND_BASE[ht].chips, mult=HAND_BASE[ht].mult, level=1}
  end
  return t
end
function hand_level(ht) return hand_levels[ht] end

-- == Poker hand evaluation ===============================================
function evaluate(cards)
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

function build_events(ht, scoring, played_cards)
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

function pick_joker_def()
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
