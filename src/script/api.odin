package script

import "core:c"
import lua "vendor:lua/5.4"

// Convention for every l_* CFunction:
//   1. `context = g_ctx` first if the body allocates or calls core procs.
//   2. All L_check* argument extraction BEFORE any allocation — these
//      longjmp on bad args, which skips Odin defers.
//   3. No defer across any call that can raise a Lua error.

@(private)
reg :: proc(L: ^lua.State, name: cstring, fn: lua.CFunction) {
	lua.pushcfunction(L, fn)
	lua.setglobal(L, name)
}

register_api :: proc(L: ^lua.State) {
	register_draw(L)
	register_input(L)
	register_misc(L)
	register_entity(L)

	// Lua-side bootstrap for trivial aliases.
	bootstrap :: `log = print`
	lua.L_dostring(L, bootstrap)
}

// -- shared argument helpers ------------------------------------------------

@(private)
arg_f32 :: proc "c" (L: ^lua.State, n: c.int) -> f32 {
	return f32(lua.L_checknumber(L, n))
}

@(private)
opt_f32 :: proc "c" (L: ^lua.State, n: c.int, def: f32) -> f32 {
	return f32(lua.L_optnumber(L, n, lua.Number(def)))
}

@(private)
arg_u8 :: proc "c" (L: ^lua.State, n: c.int) -> u8 {
	return u8(clamp(lua.L_checknumber(L, n), 0, 255))
}

@(private)
opt_u8 :: proc "c" (L: ^lua.State, n: c.int, def: u8) -> u8 {
	return u8(clamp(lua.L_optnumber(L, n, lua.Number(def)), 0, 255))
}
