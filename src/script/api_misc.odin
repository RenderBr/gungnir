package script

import "core:c"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strings"
import "core:time"
import lua "vendor:lua/5.4"
import rl "vendor:raylib"
import "../engine"

// Command-line args to expose via get_args(). Populated from main.odin.
Args: [dynamic]string

register_misc :: proc(L: ^lua.State) {
	reg(L, "rand", l_rand)
	reg(L, "srand", l_srand)
	reg(L, "session_seed", l_session_seed)
	reg(L, "quit", l_quit)
	reg(L, "play_sound", l_play_sound)
	reg(L, "load_sound_slice", l_load_sound_slice)
	reg(L, "clamp", l_clamp)
	reg(L, "circle_hit", l_circle_hit)
	reg(L, "rect_hit", l_rect_hit)
	reg(L, "clear_scene", l_clear_scene)
	reg(L, "load_level", l_load_level)
	reg(L, "save_level", l_save_level)
	reg(L, "set_crt", l_set_crt)
	reg(L, "set_screen_shader", l_set_screen_shader)
	reg(L, "set_shader_param", l_set_shader_param)
	reg(L, "set_fullscreen", l_set_fullscreen)
	reg(L, "set_maximized", l_set_maximized)
	reg(L, "set_lighting", l_set_lighting)
	reg(L, "set_ambient", l_set_ambient)
	reg(L, "set_time_scale", l_set_time_scale)
	reg(L, "get_time_scale", l_get_time_scale)
	reg(L, "pause", l_pause)
	reg(L, "step", l_step)
	reg(L, "get_args", l_get_args)
}

// session_seed() -> positive integer derived from wall-clock nanoseconds.
// Intended for run-unique procedural systems; deterministic content should
// continue using explicit srand seeds.
l_session_seed :: proc "c" (L: ^lua.State) -> c.int {
	context = g_ctx
	n := time.to_unix_nanoseconds(time.now())
	lua.pushinteger(L, lua.Integer(u64(n) & 0x7fff_ffff))
	return 1
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

// set_maximized(on) — maximize the window (keeps title bar, unlike fullscreen).
l_set_maximized :: proc "c" (L: ^lua.State) -> c.int {
	on := b32(lua.toboolean(L, 1))
	context = g_ctx
	if bool(on) {
		rl.MaximizeWindow()
	} else {
		rl.RestoreWindow()
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

// load_sound_slice(name, file, start, end) -> ok
// Loads [start,end) seconds of assets/<file> and registers it as <name>, so
// play_sound(name) plays the slice. false = missing/undecodable file or bad
// range; play_sound on a failed slice is a silent no-op.
l_load_sound_slice :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	file := lua.L_checkstring(L, 2)
	start := f32(lua.L_checknumber(L, 3))
	end := f32(lua.L_checknumber(L, 4))
	context = g_ctx
	ok := engine.load_sound_slice(g_eng, string(name), string(file), start, end)
	lua.pushboolean(L, b32(ok))
	return 1
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

// -- math/collision helpers --------------------------------------------------

// Resolves an argument to an (x,y) pair: a entity id, or a table/GameObject
// with .x/.y. Raises on a bad argument. Tolerant by design so hit tests work
// whether the caller tracks positions on entities or in Lua tables.
@(private)
arg_xy :: proc "c" (L: ^lua.State, n: c.int, what: cstring) -> (f32, f32) {
	if b32(lua.isnumber(L, n)) {
		id := engine.EntityId(lua.L_checkinteger(L, n))
		context = g_ctx
		ent := engine.get(&g_eng.scene, id)
		if ent == nil {
			lua.L_error(L, "%s: entity does not exist", what)
		}
		return ent.pos.x, ent.pos.y
	}
	if b32(lua.istable(L, n)) {
		lua.getfield(L, n, "x")
		lua.getfield(L, n, "y")
		if lua.isnumber(L, -2) && lua.isnumber(L, -1) {
			x := f32(lua.tonumber(L, -2))
			y := f32(lua.tonumber(L, -1))
			lua.pop(L, 2)
			return x, y
		}
		lua.pop(L, 2)
	}
	lua.L_error(L, "%s: expected entity id or {x=,y=} table", what)
	return 0, 0
}

// clamp(x, lo, hi) — replaces the math.max(lo, math.min(hi, x)) idiom.
l_clamp :: proc "c" (L: ^lua.State) -> c.int {
	x := f32(lua.L_checknumber(L, 1))
	lo := f32(lua.L_checknumber(L, 2))
	hi := f32(lua.L_checknumber(L, 3))
	lua.pushnumber(L, lua.Number(clamp(x, lo, hi)))
	return 1
}

// circle_hit(a, b, r) -> bool — circular collision; a/b accept entity id or
// {x=,y=} (GameObjects work too); r is the sum of radii or a single radius.
l_circle_hit :: proc "c" (L: ^lua.State) -> c.int {
	ax, ay := arg_xy(L, 1, "circle_hit")
	bx, by := arg_xy(L, 2, "circle_hit")
	r := arg_f32(L, 3)
	dx, dy := ax - bx, ay - by
	lua.pushboolean(L, b32(dx*dx + dy*dy < r*r))
	return 1
}

// rect_hit(a, b, w, h) -> bool — AABB overlap centered on each position;
// w/h are the full widths/heights of the rects. a/b accept entity id or
// {x=,y=} (GameObjects work too).
l_rect_hit :: proc "c" (L: ^lua.State) -> c.int {
	ax, ay := arg_xy(L, 1, "rect_hit")
	bx, by := arg_xy(L, 2, "rect_hit")
	w := arg_f32(L, 3) * 0.5
	h := arg_f32(L, 4) * 0.5
	lua.pushboolean(L, b32(math.abs(ax - bx) < w && math.abs(ay - by) < h))
	return 1
}

// -- time scale / pause / step ------------------------------------------------

// set_time_scale(n) — game speed multiplier. 0 = pause, 0.25 = quarter speed,
// 1 = normal. Restores previous speed when set to non-zero while paused.
l_set_time_scale :: proc "c" (L: ^lua.State) -> c.int {
	n := f32(lua.L_checknumber(L, 1))
	context = g_ctx
	if n == 0 {
		g_scr.paused = true
		g_scr.prev_time_scale = g_scr.time_scale
		g_scr.time_scale = 0
	} else {
		g_scr.time_scale = n
		g_scr.paused = false
	}
	return 0
}

// get_time_scale() -> n
l_get_time_scale :: proc "c" (L: ^lua.State) -> c.int {
	lua.pushnumber(L, lua.Number(g_scr.time_scale))
	return 1
}

// pause() — freeze the game (time_scale = 0). Use step() to advance one frame.
l_pause :: proc "c" (L: ^lua.State) -> c.int {
	context = g_ctx
	g_scr.paused = true
	g_scr.prev_time_scale = g_scr.time_scale
	g_scr.time_scale = 0
	return 0
}

// step() — advance one frame while paused, then pause again.
l_step :: proc "c" (L: ^lua.State) -> c.int {
	context = g_ctx
	g_scr.step_count = 1
	return 0
}

// get_args() -> {arg0, arg1, ...} — command-line args passed after the game dir.
l_get_args :: proc "c" (L: ^lua.State) -> c.int {
	context = g_ctx
	n := len(Args)
	lua.createtable(L, c.int(n), 0)
	for i in 0 ..< n {
		arg := Args[i]
		lua.pushlstring(L, strings.clone_to_cstring(arg, context.temp_allocator), uint(len(arg)))
		lua.rawseti(L, -2, lua.Integer(i + 1))
	}
	return 1
}

// -- console ------------------------------------------------------------------

register_console :: proc(L: ^lua.State) {
	reg(L, "console_log", l_console_log)
	reg(L, "console_dump", l_console_dump)
}

// console_log(message [, level]) — append to the in-engine console overlay.
// level: "info" (default), "warn", "error".
l_console_log :: proc "c" (L: ^lua.State) -> c.int {
	msg := lua.L_checkstring(L, 1)
	level := lua.L_optstring(L, 2, "info")
	context = g_ctx
	console_push(string(msg), string(level))
	return 0
}

// console_dump() -> {entry, ...} — returns the full console log as an array
// of {message=, level=} tables. Useful for saving debug output.
l_console_dump :: proc "c" (L: ^lua.State) -> c.int {
	context = g_ctx
	n := console_count
	lua.createtable(L, c.int(n), 0)
	start := (console_head - n) %% CONSOLE_MAX
	for i in 0 ..< n {
		idx := (start + i) %% CONSOLE_MAX
		entry := console_log[idx]

		lua.createtable(L, 0, 2)

		msg := strings.clone_to_cstring(entry.message, context.temp_allocator)
		lua.pushlstring(L, msg, uint(len(entry.message)))
		lua.setfield(L, -2, "message")

		lvl := strings.clone_to_cstring(entry.level, context.temp_allocator)
		lua.pushlstring(L, lvl, uint(len(entry.level)))
		lua.setfield(L, -2, "level")

		lua.rawseti(L, -2, lua.Integer(i + 1))
	}
	return 1
}
