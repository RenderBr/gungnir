package script

import "core:c"
import lua "vendor:lua/5.4"
import rl "vendor:raylib"
import "../engine"

register_draw :: proc(L: ^lua.State) {
	reg(L, "set_color", l_set_color)
	reg(L, "set_clear_color", l_set_clear_color)
	reg(L, "draw_rect", l_draw_rect)
	reg(L, "draw_sprite", l_draw_sprite)
	reg(L, "draw_circle", l_draw_circle)
	reg(L, "draw_line", l_draw_line)
	reg(L, "draw_text", l_draw_text)
	reg(L, "set_camera", l_set_camera)
	reg(L, "set_camera_3d", l_set_camera_3d)
	reg(L, "screen_size", l_screen_size)
	reg(L, "draw_cube", l_draw_cube)
	reg(L, "draw_sphere", l_draw_sphere)
	reg(L, "draw_grid", l_draw_grid)
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

// draw_sprite(tex, x, y [, rot, scale]) — immediate mode, centered on x,y.
l_draw_sprite :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	x := arg_f32(L, 2)
	y := arg_f32(L, 3)
	rot := opt_f32(L, 4, 0)
	scale := opt_f32(L, 5, 1)
	context = g_ctx
	tex := engine.get_texture(g_eng, string(name))
	w := f32(tex.width) * scale
	h := f32(tex.height) * scale
	rl.DrawTexturePro(tex, {0, 0, f32(tex.width), f32(tex.height)},
		{x, y, w, h}, {w / 2, h / 2}, rot, rl.WHITE)
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
	context = g_ctx
	w, h := engine.logical_size(g_eng)
	g_eng.cam2d = {
		target   = {x, y},
		offset   = {f32(w) / 2, f32(h) / 2},
		zoom     = zoom,
		rotation = rot,
	}
	return 0
}

// set_camera_3d(px, py, pz, tx, ty, tz [, fov])
l_set_camera_3d :: proc "c" (L: ^lua.State) -> c.int {
	px := arg_f32(L, 1)
	py := arg_f32(L, 2)
	pz := arg_f32(L, 3)
	tx := arg_f32(L, 4)
	ty := arg_f32(L, 5)
	tz := arg_f32(L, 6)
	fov := opt_f32(L, 7, 60)
	g_eng.cam3d.position = {px, py, pz}
	g_eng.cam3d.target = {tx, ty, tz}
	g_eng.cam3d.fovy = fov
	return 0
}

// draw_cube(x, y, z, w, h, d) — only valid inside on_draw_3d
l_draw_cube :: proc "c" (L: ^lua.State) -> c.int {
	x := arg_f32(L, 1)
	y := arg_f32(L, 2)
	z := arg_f32(L, 3)
	w := arg_f32(L, 4)
	h := arg_f32(L, 5)
	d := arg_f32(L, 6)
	rl.DrawCube({x, y, z}, w, h, d, g_eng.draw_color)
	return 0
}

l_draw_sphere :: proc "c" (L: ^lua.State) -> c.int {
	x := arg_f32(L, 1)
	y := arg_f32(L, 2)
	z := arg_f32(L, 3)
	r := arg_f32(L, 4)
	rl.DrawSphere({x, y, z}, r, g_eng.draw_color)
	return 0
}

// draw_grid([slices, spacing]) — only valid inside on_draw_3d
l_draw_grid :: proc "c" (L: ^lua.State) -> c.int {
	slices := opt_f32(L, 1, 20)
	spacing := opt_f32(L, 2, 1)
	rl.DrawGrid(i32(slices), spacing)
	return 0
}

l_screen_size :: proc "c" (L: ^lua.State) -> c.int {
	context = g_ctx
	w, h := engine.logical_size(g_eng)
	lua.pushnumber(L, lua.Number(w))
	lua.pushnumber(L, lua.Number(h))
	return 2
}
