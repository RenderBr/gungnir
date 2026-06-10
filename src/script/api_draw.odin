package script

import "core:c"
import lua "vendor:lua/5.4"
import rl "vendor:raylib"

register_draw :: proc(L: ^lua.State) {
	reg(L, "set_color", l_set_color)
	reg(L, "set_clear_color", l_set_clear_color)
	reg(L, "draw_rect", l_draw_rect)
	reg(L, "draw_circle", l_draw_circle)
	reg(L, "draw_line", l_draw_line)
	reg(L, "draw_text", l_draw_text)
	reg(L, "set_camera", l_set_camera)
	reg(L, "screen_size", l_screen_size)
}

l_set_color :: proc "c" (L: ^lua.State) -> c.int {
	r := arg_u8(L, 1)
	g := arg_u8(L, 2)
	b := arg_u8(L, 3)
	a := opt_u8(L, 4, 255)
	g_eng.draw_color = {r, g, b, a}
	return 0
}

l_set_clear_color :: proc "c" (L: ^lua.State) -> c.int {
	r := arg_u8(L, 1)
	g := arg_u8(L, 2)
	b := arg_u8(L, 3)
	g_eng.clear_color = {r, g, b, 255}
	return 0
}

l_draw_rect :: proc "c" (L: ^lua.State) -> c.int {
	x := arg_f32(L, 1)
	y := arg_f32(L, 2)
	w := arg_f32(L, 3)
	h := arg_f32(L, 4)
	rl.DrawRectangleV({x, y}, {w, h}, g_eng.draw_color)
	return 0
}

l_draw_circle :: proc "c" (L: ^lua.State) -> c.int {
	x := arg_f32(L, 1)
	y := arg_f32(L, 2)
	r := arg_f32(L, 3)
	rl.DrawCircleV({x, y}, r, g_eng.draw_color)
	return 0
}

l_draw_line :: proc "c" (L: ^lua.State) -> c.int {
	x1 := arg_f32(L, 1)
	y1 := arg_f32(L, 2)
	x2 := arg_f32(L, 3)
	y2 := arg_f32(L, 4)
	thick := opt_f32(L, 5, 1)
	rl.DrawLineEx({x1, y1}, {x2, y2}, thick, g_eng.draw_color)
	return 0
}

l_draw_text :: proc "c" (L: ^lua.State) -> c.int {
	text := lua.L_checkstring(L, 1)
	x := arg_f32(L, 2)
	y := arg_f32(L, 3)
	size := opt_f32(L, 4, 20)
	rl.DrawText(text, i32(x), i32(y), i32(size), g_eng.draw_color)
	return 0
}

// set_camera(x, y [, zoom, rot]) — centers the 2D camera on (x, y).
// Never calling it leaves screen coords == world coords (top-left origin).
l_set_camera :: proc "c" (L: ^lua.State) -> c.int {
	x := arg_f32(L, 1)
	y := arg_f32(L, 2)
	zoom := opt_f32(L, 3, 1)
	rot := opt_f32(L, 4, 0)
	g_eng.cam2d = {
		target   = {x, y},
		offset   = {f32(rl.GetScreenWidth()) / 2, f32(rl.GetScreenHeight()) / 2},
		zoom     = zoom,
		rotation = rot,
	}
	return 0
}

l_screen_size :: proc "c" (L: ^lua.State) -> c.int {
	lua.pushnumber(L, lua.Number(rl.GetScreenWidth()))
	lua.pushnumber(L, lua.Number(rl.GetScreenHeight()))
	return 2
}
