package script

// GameObject prelude: a Unity-style object/component layer written in pure
// Lua over the flat entity API. The engine's only hook is the global
// __gungnir_update(dt) dispatcher (see call_update in lua_state.odin).
// Constraint: this is an Odin raw string — the Lua source must not contain
// backticks. Every flat-API call below is guarded by exists(): arg_entity
// raises on stale ids and GameObject methods must never raise.
@(private)
GAMEOBJECT_PRELUDE :: `
local objects = {}   -- ordered registry of GameObjects, pruned each frame
local tag_sets = {}  -- tag name -> set (GameObject -> true)

local GO = {}        -- methods
local GO_mt = {}     -- instance metatable

local function is_live(o)
	return not o._dead and exists(o._id)
end

-- Pull the live engine position into the Lua-side cache (kept so reads
-- still work after despawn: methods become no-ops, never errors).
local function refresh(o)
	if exists(o._id) then
		o._px, o._py, o._pz = get_pos(o._id)
	end
end

-- Re-base a parented object's local offset from current world transforms
-- (called when a child is moved/rotated directly, Unity localPosition style).
local function update_offset(o)
	local p = o._parent
	if not p then return end
	refresh(p)
	local dx, dy, dz = o._px - p._px, o._py - p._py, o._pz - p._pz
	local r = -math.rad(p._rot)
	local c, s = math.cos(r), math.sin(r)
	o._off = { x = dx * c - dy * s, y = dx * s + dy * c, z = dz, rot = o._rot - p._rot }
end

-- Fires on_destroy exactly once and unhooks the object from tags/parent.
-- Reached from :destroy() (immediate) or the prune pass (external despawn).
local function finalize(o)
	if o._finalized then return end
	o._finalized = true
	o._dead = true
	for i = 1, #o._components do
		local c = o._components[i]
		if not c._removed then
			c._removed = true
			if c.on_destroy then c.on_destroy(c, o) end
		end
	end
	for t in pairs(o._tags) do
		local set = tag_sets[t]
		if set then set[o] = nil end
	end
	local p = o._parent
	if p then
		for i = #p._children, 1, -1 do
			if p._children[i] == o then table.remove(p._children, i) end
		end
		o._parent = false
	end
end

GO_mt.__index = function(o, k)
	if k == "x" or k == "y" or k == "z" then
		refresh(o)
		if k == "x" then return o._px end
		if k == "y" then return o._py end
		return o._pz
	elseif k == "name" then
		return o._name
	elseif k == "id" then
		return o._id
	end
	return GO[k]
end

GO_mt.__newindex = function(o, k, v)
	if k == "x" or k == "y" or k == "z" then
		refresh(o)
		if k == "x" then o._px = v elseif k == "y" then o._py = v else o._pz = v end
		if exists(o._id) then set_pos(o._id, o._px, o._py, o._pz) end
		update_offset(o)
	elseif k == "name" then
		o._name = v
		if exists(o._id) then set_name(o._id, v) end
	else
		rawset(o, k, v)
	end
end

GO_mt.__tostring = function(o)
	return "GameObject(" .. tostring(o._name) .. ")"
end

-- All internal fields are rawset up front so later plain assignments hit
-- the raw slots and never re-enter __newindex.
local function new_object(id, name, x, y, z)
	local o = {}
	rawset(o, "_id", id)
	rawset(o, "_name", name or "")
	rawset(o, "_px", x or 0)
	rawset(o, "_py", y or 0)
	rawset(o, "_pz", z or 0)
	rawset(o, "_rot", 0)
	rawset(o, "_dead", false)
	rawset(o, "_finalized", false)
	rawset(o, "_components", {})
	rawset(o, "_tags", {})
	rawset(o, "_parent", false)
	rawset(o, "_children", {})
	rawset(o, "_off", false)
	setmetatable(o, GO_mt)
	objects[#objects + 1] = o
	return o
end

function GO:pos()
	refresh(self)
	return self._px, self._py, self._pz
end

function GO:set_pos(x, y, z)
	refresh(self)
	self._px = x or self._px
	self._py = y or self._py
	self._pz = z or self._pz
	if exists(self._id) then set_pos(self._id, self._px, self._py, self._pz) end
	update_offset(self)
	return self
end

function GO:move(dx, dy, dz)
	refresh(self)
	return self:set_pos(self._px + (dx or 0), self._py + (dy or 0), self._pz + (dz or 0))
end

function GO:rotate(deg)
	self._rot = self._rot + deg
	if exists(self._id) then set_rot(self._id, self._rot) end
	update_offset(self)
	return self
end

function GO:set_scale(s)
	if exists(self._id) then set_scale(self._id, s) end
	return self
end

function GO:tint(r, g, b, a)
	if exists(self._id) then set_tint(self._id, r, g, b, a) end
	return self
end

function GO:alive()
	return is_live(self)
end

function GO:destroy()
	if self._dead then return end
	self._dead = true
	for i = #self._children, 1, -1 do
		local ch = self._children[i]
		if ch and not ch._dead then ch:destroy() end
	end
	finalize(self)
	if exists(self._id) then despawn(self._id) end
end

local function component_remove(c)
	if c._removed then return end
	c._removed = true
	if c.on_destroy then c.on_destroy(c, c.gameobject) end
end

function GO:add_component(c)
	c = c or {}
	c.gameobject = self
	c._started = false
	c._removed = false
	c.remove = component_remove
	local cs = self._components
	cs[#cs + 1] = c
	return c
end

function GO:tag(name)
	self._tags[name] = true
	local set = tag_sets[name]
	if not set then
		set = {}
		tag_sets[name] = set
	end
	set[self] = true
	return self
end

function GO:untag(name)
	self._tags[name] = nil
	local set = tag_sets[name]
	if set then set[self] = nil end
	return self
end

function GO:has_tag(name)
	return self._tags[name] == true
end

function GO:set_parent(parent)
	local old = self._parent
	if old then
		for i = #old._children, 1, -1 do
			if old._children[i] == self then table.remove(old._children, i) end
		end
	end
	self._parent = parent or false
	self._off = false
	if parent then
		parent._children[#parent._children + 1] = self
		refresh(self)
		update_offset(self)
	end
	return self
end

local function construct(opts)
	if type(opts) == "string" then
		opts = { name = opts }
	end
	opts = opts or {}
	local x, y = opts.x or 0, opts.y or 0
	local id
	if opts.sprite then
		id = spawn_sprite(opts.sprite, x, y)
	elseif opts.text then
		id = spawn_text(opts.text, x, y, opts.size)
	elseif opts.mesh then
		id = spawn_mesh(opts.mesh, x, y, opts.z or 0)
	else
		-- shape form; with no visual key at all you get a 16x16 rect
		id = spawn_shape(opts.shape or "rect", x, y, opts.w or 16, opts.h)
	end
	local o = new_object(id, opts.name, x, y, opts.z)
	if opts.name then set_name(id, opts.name) end
	if opts.z and not opts.mesh then set_pos(id, x, y, opts.z) end
	if opts.rot then o:rotate(opts.rot) end
	if opts.scale then o:set_scale(opts.scale) end
	if opts.tint then o:tint(opts.tint[1], opts.tint[2], opts.tint[3], opts.tint[4]) end
	if opts.tag then o:tag(opts.tag) end
	return o
end

GameObject = setmetatable({}, {
	__call = function(_, opts) return construct(opts) end,
})

-- Adopt an existing entity id (level-loaded or flat-API spawned).
-- Its current rotation is unknown to the prelude and assumed 0.
function GameObject.wrap(id)
	if not exists(id) then return nil end
	local x, y, z = get_pos(id)
	return new_object(id, "", x, y, z)
end

function GameObject.find(name)
	for i = 1, #objects do
		local o = objects[i]
		if o._name == name and is_live(o) then return o end
	end
	return nil
end

function GameObject.all()
	local out = {}
	for i = 1, #objects do
		local o = objects[i]
		if is_live(o) then out[#out + 1] = o end
	end
	return out
end

function GameObject.with_tag(name)
	local out = {}
	local set = tag_sets[name]
	if set then
		for i = 1, #objects do
			local o = objects[i]
			if set[o] and is_live(o) then out[#out + 1] = o end
		end
	end
	return out
end

-- Children follow parent position + z-rotation only (2D simplification:
-- parent x/y euler rotation does not propagate).
local function sync_children(o)
	refresh(o)
	for i = 1, #o._children do
		local ch = o._children[i]
		if not ch._dead and ch._off then
			local r = math.rad(o._rot)
			local c, s = math.cos(r), math.sin(r)
			local off = ch._off
			ch._px = o._px + off.x * c - off.y * s
			ch._py = o._py + off.x * s + off.y * c
			ch._pz = o._pz + off.z
			ch._rot = o._rot + off.rot
			if exists(ch._id) then
				set_pos(ch._id, ch._px, ch._py, ch._pz)
				set_rot(ch._id, ch._rot)
			end
			sync_children(ch)
		end
	end
end

-- Engine dispatcher: call_update invokes this instead of on_update when it
-- exists. Order: user logic, component start/update, parenting, prune.
function __gungnir_update(dt)
	if type(on_update) == "function" then on_update(dt) end

	local snap = {}
	for i = 1, #objects do snap[i] = objects[i] end
	for i = 1, #snap do
		local o = snap[i]
		if is_live(o) then
			local cs = o._components
			local n = #cs -- components added mid-frame start next frame
			local removed_any = false
			for j = 1, n do
				local c = cs[j]
				if not c._removed then
					if not c._started then
						c._started = true
						if c.start then c.start(c, o) end
					end
					if c.update and not c._removed and is_live(o) then
						c.update(c, o, dt)
					end
				end
				if c._removed then removed_any = true end
			end
			if removed_any then
				local keep = {}
				for j = 1, #cs do
					if not cs[j]._removed then keep[#keep + 1] = cs[j] end
				end
				o._components = keep
			end
		end
	end

	for i = 1, #objects do
		local o = objects[i]
		if not o._parent and not o._dead and #o._children > 0 then
			sync_children(o)
		end
	end

	local keep = {}
	for i = 1, #objects do
		local o = objects[i]
		if o._dead or not exists(o._id) then
			finalize(o)
		else
			keep[#keep + 1] = o
		end
	end
	objects = keep
end
`
