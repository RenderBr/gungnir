package script

import "core:c"
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
