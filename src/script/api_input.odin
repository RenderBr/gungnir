package script

import "core:c"
import lua "vendor:lua/5.4"
import rl "vendor:raylib"
import "../engine"

register_input :: proc(L: ^lua.State) {
	reg(L, "key_down", l_key_down)
	reg(L, "key_pressed", l_key_pressed)
	reg(L, "mouse_pos", l_mouse_pos)
	reg(L, "mouse_delta", l_mouse_delta)
	reg(L, "mouse_down", l_mouse_down)
	reg(L, "mouse_pressed", l_mouse_pressed)
	reg(L, "mouse_wheel", l_mouse_wheel)
	reg(L, "disable_cursor", l_disable_cursor)
	reg(L, "enable_cursor", l_enable_cursor)
}

l_key_down :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	context = g_ctx
	lua.pushboolean(L, b32(rl.IsKeyDown(engine.key_from_name(string(name)))))
	return 1
}

l_key_pressed :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	context = g_ctx
	lua.pushboolean(L, b32(rl.IsKeyPressed(engine.key_from_name(string(name)))))
	return 1
}

l_mouse_pos :: proc "c" (L: ^lua.State) -> c.int {
	context = g_ctx
	pos := engine.mouse_logical(g_eng)
	lua.pushnumber(L, lua.Number(pos.x))
	lua.pushnumber(L, lua.Number(pos.y))
	return 2
}

l_mouse_down :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_optstring(L, 1, "left")
	context = g_ctx
	lua.pushboolean(L, b32(rl.IsMouseButtonDown(engine.mouse_button_from_name(string(name)))))
	return 1
}

l_mouse_pressed :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_optstring(L, 1, "left")
	context = g_ctx
	lua.pushboolean(L, b32(rl.IsMouseButtonPressed(engine.mouse_button_from_name(string(name)))))
	return 1
}

l_mouse_wheel :: proc "c" (L: ^lua.State) -> c.int {
	lua.pushnumber(L, lua.Number(rl.GetMouseWheelMove()))
	return 1
}

l_mouse_delta :: proc "c" (L: ^lua.State) -> c.int {
	d := rl.GetMouseDelta()
	lua.pushnumber(L, lua.Number(d.x))
	lua.pushnumber(L, lua.Number(d.y))
	return 2
}

l_disable_cursor :: proc "c" (L: ^lua.State) -> c.int {
	rl.DisableCursor()
	return 0
}

l_enable_cursor :: proc "c" (L: ^lua.State) -> c.int {
	rl.EnableCursor()
	return 0
}
