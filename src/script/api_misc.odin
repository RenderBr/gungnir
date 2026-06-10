package script

import "core:c"
import "core:fmt"
import "core:math/rand"
import lua "vendor:lua/5.4"
import rl "vendor:raylib"
import "../engine"

register_misc :: proc(L: ^lua.State) {
	reg(L, "rand", l_rand)
	reg(L, "srand", l_srand)
	reg(L, "quit", l_quit)
	reg(L, "play_sound", l_play_sound)
	reg(L, "clear_scene", l_clear_scene)
	reg(L, "load_level", l_load_level)
	reg(L, "save_level", l_save_level)
	reg(L, "set_crt", l_set_crt)
	reg(L, "set_screen_shader", l_set_screen_shader)
	reg(L, "set_shader_param", l_set_shader_param)
	reg(L, "set_fullscreen", l_set_fullscreen)
	reg(L, "set_lighting", l_set_lighting)
	reg(L, "set_ambient", l_set_ambient)
}

// set_lighting(on) — 2D lightmap over the world + per-model lit 3D shading.
l_set_lighting :: proc "c" (L: ^lua.State) -> c.int {
	on := b32(lua.toboolean(L, 1))
	context = g_ctx
	engine.lighting_enable(g_eng, bool(on))
	return 0
}

// set_ambient(r, g, b) — base light level when lighting is on.
l_set_ambient :: proc "c" (L: ^lua.State) -> c.int {
	r := arg_u8(L, 1)
	g := arg_u8(L, 2)
	b := arg_u8(L, 3)
	g_eng.lighting.ambient = {r, g, b, 255}
	return 0
}

// set_screen_shader(name | nil) — full-screen pass over the game image;
// applies before the CRT filter when both are on.
l_set_screen_shader :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_optstring(L, 1, "")
	context = g_ctx
	if string(name) != "" && !engine.has_shader(g_eng, string(name)) {
		lua.L_error(L, "set_screen_shader: unknown shader '%s' (call gen_shader first)", name)
	}
	engine.postfx_set_screen_shader(g_eng, string(name))
	return 0
}

// set_shader_param(shader, param, x [, y, z, w]) — float/vec2/vec3/vec4.
l_set_shader_param :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	param := lua.L_checkstring(L, 2)
	n := lua.gettop(L) - 2
	if n < 1 || n > 4 {
		lua.L_error(L, "set_shader_param: pass 1 to 4 numbers")
	}
	vals: [4]f32
	for i in 0 ..< n {
		vals[i] = f32(lua.L_checknumber(L, 3 + i))
	}
	context = g_ctx
	if !engine.set_shader_param(g_eng, string(name), string(param), vals[:n]) {
		lua.L_error(L, "set_shader_param: unknown shader '%s' (call gen_shader first)", name)
	}
	return 0
}

// set_crt(on) — arcade CRT filter: curvature, scanlines, grille, glow.
// The game renders at 960x600 and upscales, like a real cab.
l_set_crt :: proc "c" (L: ^lua.State) -> c.int {
	on := b32(lua.toboolean(L, 1))
	context = g_ctx
	engine.postfx_enable(g_eng, bool(on))
	return 0
}

// set_fullscreen(on) — borderless fullscreen on the current monitor.
l_set_fullscreen :: proc "c" (L: ^lua.State) -> c.int {
	on := b32(lua.toboolean(L, 1))
	context = g_ctx
	if bool(on) != rl.IsWindowState({.BORDERLESS_WINDOWED_MODE}) {
		rl.ToggleBorderlessWindowed()
	}
	return 0
}

// save_level([name]) — writes the current scene + recipes to <game_dir>/<name>.json
l_save_level :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_optstring(L, 1, "level")
	context = g_ctx
	path := fmt.tprintf("%s/%s.json", g_eng.game_dir, string(name))
	ok := engine.save_level(g_eng, path)
	lua.pushboolean(L, b32(ok))
	return 1
}

// load_level(name) — loads <game_dir>/<name>.json, replacing the scene.
l_load_level :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	context = g_ctx
	path := fmt.tprintf("%s/%s.json", g_eng.game_dir, string(name))
	ok := engine.load_level(g_eng, path)
	lua.pushboolean(L, b32(ok))
	return 1
}

// play_sound(name [, volume, pitch])
l_play_sound :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	volume := opt_f32(L, 2, 1)
	pitch := opt_f32(L, 3, 1)
	context = g_ctx
	if snd, ok := engine.get_sound(g_eng, string(name)); ok {
		rl.SetSoundVolume(snd, volume)
		rl.SetSoundPitch(snd, pitch)
		rl.PlaySound(snd)
	}
	return 0
}

l_clear_scene :: proc "c" (L: ^lua.State) -> c.int {
	context = g_ctx
	engine.clear_scene(&g_eng.scene)
	return 0
}

// rand() -> [0,1) | rand(a) -> [0,a) | rand(a,b) -> [a,b)
l_rand :: proc "c" (L: ^lua.State) -> c.int {
	n := lua.gettop(L)
	a, b: f64
	switch {
	case n == 0:
		a, b = 0, 1
	case n == 1:
		a, b = 0, f64(lua.L_checknumber(L, 1))
	case:
		a = f64(lua.L_checknumber(L, 1))
		b = f64(lua.L_checknumber(L, 2))
	}
	context = g_ctx
	lua.pushnumber(L, lua.Number(a + rand.float64() * (b - a)))
	return 1
}

l_srand :: proc "c" (L: ^lua.State) -> c.int {
	seed := lua.L_checkinteger(L, 1)
	context = g_ctx
	rand.reset(u64(seed))
	g_noise_seed = i64(seed)
	return 0
}

l_quit :: proc "c" (L: ^lua.State) -> c.int {
	g_eng.should_quit = true
	return 0
}
