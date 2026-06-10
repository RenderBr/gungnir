package script

import "core:c"
import "core:strings"
import lua "vendor:lua/5.4"
import "../engine"

register_entity :: proc(L: ^lua.State) {
	reg(L, "spawn_sprite", l_spawn_sprite)
	reg(L, "spawn_shape", l_spawn_shape)
	reg(L, "spawn_text", l_spawn_text)
	reg(L, "spawn_mesh", l_spawn_mesh)
	reg(L, "despawn", l_despawn)
	reg(L, "exists", l_exists)
	reg(L, "find", l_find)
	reg(L, "get_pos", l_get_pos)
	reg(L, "set_pos", l_set_pos)
	reg(L, "set_rot", l_set_rot)
	reg(L, "set_scale", l_set_scale)
	reg(L, "set_tint", l_set_tint)
	reg(L, "set_name", l_set_name)
	reg(L, "set_text", l_set_text)
	reg(L, "set_flip", l_set_flip)
	reg(L, "set_texture", l_set_texture)
}

// set_texture(id, name) — swap a sprite entity's texture (animation frames).
l_set_texture :: proc "c" (L: ^lua.State) -> c.int {
	ent := arg_entity(L, 1, "set_texture")
	name := lua.L_checkstring(L, 2)
	context = g_ctx
	sprite, ok := &ent.variant.(engine.Sprite)
	if !ok {
		lua.L_error(L, "set_texture: entity is not a sprite")
	}
	if sprite.texture != string(name) {
		delete(sprite.texture)
		sprite.texture = strings.clone(string(name))
	}
	return 0
}

// Resolves an entity argument or raises a Lua error (caught by the pcall
// harness — shows in the error banner, never crashes the engine).
@(private)
arg_entity :: proc "c" (L: ^lua.State, n: c.int, what: cstring) -> ^engine.Entity {
	id := engine.EntityId(lua.L_checkinteger(L, n))
	context = g_ctx
	ent := engine.get(&g_eng.scene, id)
	if ent == nil {
		lua.L_error(L, "%s: entity does not exist (stale id after despawn?)", what)
	}
	return ent
}

l_spawn_sprite :: proc "c" (L: ^lua.State) -> c.int {
	tex := lua.L_checkstring(L, 1)
	x := arg_f32(L, 2)
	y := arg_f32(L, 3)
	context = g_ctx
	id := engine.spawn_sprite(&g_eng.scene, string(tex), x, y)
	lua.pushinteger(L, lua.Integer(id))
	return 1
}

l_spawn_shape :: proc "c" (L: ^lua.State) -> c.int {
	kind_name := lua.L_checkstring(L, 1)
	x := arg_f32(L, 2)
	y := arg_f32(L, 3)
	w := arg_f32(L, 4)
	h := opt_f32(L, 5, 0)
	context = g_ctx
	kind: engine.ShapeKind = string(kind_name) == "circle" ? .Circle : .Rect
	if h == 0 {
		h = w
	}
	id := engine.spawn_shape(&g_eng.scene, kind, x, y, w, h)
	lua.pushinteger(L, lua.Integer(id))
	return 1
}

l_spawn_text :: proc "c" (L: ^lua.State) -> c.int {
	text := lua.L_checkstring(L, 1)
	x := arg_f32(L, 2)
	y := arg_f32(L, 3)
	size := opt_f32(L, 4, 20)
	context = g_ctx
	id := engine.spawn_label(&g_eng.scene, string(text), x, y, size)
	lua.pushinteger(L, lua.Integer(id))
	return 1
}

l_spawn_mesh :: proc "c" (L: ^lua.State) -> c.int {
	model := lua.L_checkstring(L, 1)
	x := arg_f32(L, 2)
	y := arg_f32(L, 3)
	z := arg_f32(L, 4)
	context = g_ctx
	id := engine.spawn_mesh(&g_eng.scene, string(model), x, y, z)
	lua.pushinteger(L, lua.Integer(id))
	return 1
}

l_despawn :: proc "c" (L: ^lua.State) -> c.int {
	id := engine.EntityId(lua.L_checkinteger(L, 1))
	context = g_ctx
	engine.despawn(&g_eng.scene, id)
	return 0
}

l_exists :: proc "c" (L: ^lua.State) -> c.int {
	id := engine.EntityId(lua.L_checkinteger(L, 1))
	context = g_ctx
	lua.pushboolean(L, b32(engine.get(&g_eng.scene, id) != nil))
	return 1
}

l_find :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	context = g_ctx
	if id, ok := engine.find_by_name(&g_eng.scene, string(name)); ok {
		lua.pushinteger(L, lua.Integer(id))
	} else {
		lua.pushnil(L)
	}
	return 1
}

l_get_pos :: proc "c" (L: ^lua.State) -> c.int {
	ent := arg_entity(L, 1, "get_pos")
	lua.pushnumber(L, lua.Number(ent.pos.x))
	lua.pushnumber(L, lua.Number(ent.pos.y))
	lua.pushnumber(L, lua.Number(ent.pos.z))
	return 3
}

l_set_pos :: proc "c" (L: ^lua.State) -> c.int {
	ent := arg_entity(L, 1, "set_pos")
	ent.pos.x = arg_f32(L, 2)
	ent.pos.y = arg_f32(L, 3)
	ent.pos.z = opt_f32(L, 4, ent.pos.z)
	return 0
}

// set_rot(id, deg) for 2D | set_rot(id, x, y, z) for 3D
l_set_rot :: proc "c" (L: ^lua.State) -> c.int {
	ent := arg_entity(L, 1, "set_rot")
	if lua.gettop(L) >= 4 {
		ent.rot = {arg_f32(L, 2), arg_f32(L, 3), arg_f32(L, 4)}
	} else {
		ent.rot.z = arg_f32(L, 2)
	}
	return 0
}

// set_scale(id, s) uniform | set_scale(id, sx, sy [, sz])
l_set_scale :: proc "c" (L: ^lua.State) -> c.int {
	ent := arg_entity(L, 1, "set_scale")
	sx := arg_f32(L, 2)
	if lua.gettop(L) >= 3 {
		ent.scale = {sx, arg_f32(L, 3), opt_f32(L, 4, 1)}
	} else {
		ent.scale = {sx, sx, sx}
	}
	return 0
}

l_set_tint :: proc "c" (L: ^lua.State) -> c.int {
	ent := arg_entity(L, 1, "set_tint")
	ent.tint = {arg_u8(L, 2), arg_u8(L, 3), arg_u8(L, 4), opt_u8(L, 5, 255)}
	return 0
}

l_set_name :: proc "c" (L: ^lua.State) -> c.int {
	ent := arg_entity(L, 1, "set_name")
	name := lua.L_checkstring(L, 2)
	context = g_ctx
	delete(ent.name)
	ent.name = strings.clone(string(name))
	return 0
}

l_set_text :: proc "c" (L: ^lua.State) -> c.int {
	ent := arg_entity(L, 1, "set_text")
	text := lua.L_checkstring(L, 2)
	context = g_ctx
	if !engine.set_label_text(ent, string(text)) {
		lua.L_error(L, "set_text: entity is not a text entity")
	}
	return 0
}

l_set_flip :: proc "c" (L: ^lua.State) -> c.int {
	ent := arg_entity(L, 1, "set_flip")
	fx := b32(lua.toboolean(L, 2))
	fy := b32(lua.toboolean(L, 3))
	if sprite, ok := &ent.variant.(engine.Sprite); ok {
		sprite.flip_x = bool(fx)
		sprite.flip_y = bool(fy)
	}
	return 0
}
