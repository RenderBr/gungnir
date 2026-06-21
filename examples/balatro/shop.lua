-- shop.lua: shop building, buying, rerolling, and enhance packs.

function shop_layout()
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

function buy_item(item)
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

function reroll_shop()
  local cost = 5
  if money < cost then show("Not enough money to reroll") return end
  money = money - cost
  play_sound("reroll")
  build_shop()
end

-- == Enhancement pack =====================================================
local ENH_LIST = {"bonus", "mult", "glass", "gold"}
local ENH_W = {bonus=0.40, mult=0.30, glass=0.15, gold=0.15}
function pick_enh()
  local r = rand()
  local acc = 0
  for _, k in ipairs(ENH_LIST) do
    acc = acc + ENH_W[k]
    if r < acc then return k end
  end
  return "bonus"
end
