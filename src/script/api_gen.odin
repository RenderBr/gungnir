package script

import "core:c"
import "core:strings"
import lua "vendor:lua/5.4"
import rl "vendor:raylib"
import "../engine"
import "../gen"

// Seed used by the noise() global; srand() updates it.
g_noise_seed: i64

register_gen :: proc(L: ^lua.State) {
	reg(L, "gen_texture", l_gen_texture)
	reg(L, "gen_sprite", l_gen_sprite)
	reg(L, "gen_sound", l_gen_sound)
	reg(L, "gen_palette", l_gen_palette)
	reg(L, "gen_mesh_terrain", l_gen_mesh_terrain)
	reg(L, "gen_mesh", l_gen_mesh)
	reg(L, "gen_pixels", l_gen_pixels)
	reg(L, "gen_shader", l_gen_shader)
	reg(L, "noise", l_noise)
}

// gen_shader(name, fragment_code) -> ok
// Full GLSL 330 fragment source; raylib's default vertex shader provides
// fragTexCoord/fragColor. Compile failure returns false (old shader, if
// any, stays registered) and prints the GLSL log to the console.
l_gen_shader :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	code := lua.L_checkstring(L, 2)
	context = g_ctx

	r: engine.GenRecipe
	r.name = strings.clone(string(name))
	r.kind = strings.clone("shader")
	r.variant = strings.clone("fragment")
	it := string(code)
	for line in strings.split_lines_iterator(&it) {
		append(&r.rows, strings.clone(line))
	}
	ok := engine.apply_recipe(g_eng, r)
	lua.pushboolean(L, b32(ok))
	return 1
}

// gen_pixels(name, rows, palette) — pixel-art texture from an array of row
// strings; palette maps chars to hex colors, e.g. {r="#ff0000"}. '.' and ' '
// are transparent. Width = longest row.
l_gen_pixels :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	if !b32(lua.istable(L, 2)) {
		lua.L_error(L, "gen_pixels: rows must be a table of strings")
	}
	if !b32(lua.istable(L, 3)) {
		lua.L_error(L, "gen_pixels: palette must be a table {char=\"#hex\"}")
	}
	context = g_ctx

	r: engine.GenRecipe
	r.name = strings.clone(string(name))
	r.kind = strings.clone("pixels")

	n := lua.Integer(lua.rawlen(L, 2))
	for i in 1 ..= n {
		lua.rawgeti(L, 2, i)
		if b32(lua.isstring(L, -1)) {
			row := strings.clone(string(lua.tostring(L, -1)))
			append(&r.rows, row)
			r.w = max(r.w, i32(len(row)))
		}
		lua.pop(L, 1)
	}
	r.h = i32(len(r.rows))

	charset := strings.builder_make()
	lua.pushnil(L)
	for lua.next(L, 3) != 0 {
		if b32(lua.isstring(L, -2)) && b32(lua.isstring(L, -1)) {
			key := string(lua.tostring(L, -2))
			if len(key) == 1 {
				strings.write_byte(&charset, key[0])
				append(&r.colors, gen.parse_hex_color(string(lua.tostring(L, -1))))
			}
		}
		lua.pop(L, 1)
	}
	r.variant = strings.to_string(charset) // builder memory transfers

	engine.apply_recipe(g_eng, r)
	return 0
}

// -- option-table helpers ----------------------------------------------------
// All of these may run before context is set; they only touch the Lua stack
// except tbl_color/tbl_string which clone with explicit allocators.

@(private = "file")
tbl_f64 :: proc "c" (L: ^lua.State, idx: c.int, key: cstring, def: f64) -> f64 {
	lua.getfield(L, idx, key)
	v := def
	if lua.isnumber(L, -1) {
		v = f64(lua.tonumber(L, -1))
	}
	lua.pop(L, 1)
	return v
}

// Clones into the current context allocator. Returns def (not cloned) on absence.
@(private = "file")
tbl_string :: proc(L: ^lua.State, idx: c.int, key: cstring, def: string) -> string {
	lua.getfield(L, idx, key)
	v := def
	if b32(lua.isstring(L, -1)) {
		v = strings.clone(string(lua.tostring(L, -1)))
	}
	lua.pop(L, 1)
	return v
}

@(private = "file")
tbl_color :: proc(L: ^lua.State, idx: c.int, key: cstring) -> (rl.Color, bool) {
	lua.getfield(L, idx, key)
	defer lua.pop(L, 1)
	if b32(lua.isstring(L, -1)) {
		return gen.parse_hex_color(string(lua.tostring(L, -1))), true
	}
	return {}, false
}

// Reads an array-style table of "#rrggbb" strings at idx into colors.
@(private = "file")
read_palette :: proc(L: ^lua.State, idx: c.int, colors: ^[dynamic]rl.Color) {
	if !b32(lua.istable(L, idx)) {
		return
	}
	n := lua.Integer(lua.rawlen(L, idx))
	for i in 1 ..= n {
		lua.rawgeti(L, idx, i)
		if b32(lua.isstring(L, -1)) {
			append(colors, gen.parse_hex_color(string(lua.tostring(L, -1))))
		}
		lua.pop(L, 1)
	}
}

// -- API ----------------------------------------------------------------------

// gen_texture(name, w, h [, opts])
// opts: kind ("noise"|"gradient"|"checker"|"circle"), seed, scale, cells,
//       horizontal (bool), color, color2 (hex strings)
l_gen_texture :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	w := i32(lua.L_checkinteger(L, 2))
	h := i32(lua.L_checkinteger(L, 3))
	has_opts := b32(lua.istable(L, 4))
	context = g_ctx

	r: engine.GenRecipe
	r.name = strings.clone(string(name))
	r.kind = strings.clone("texture")
	r.w, r.h = w, h
	r.variant = strings.clone("noise")
	if has_opts {
		delete(r.variant)
		r.variant = tbl_string(L, 4, "kind", "")
		if r.variant == "" {
			r.variant = strings.clone("noise")
		}
		r.seed = i64(tbl_f64(L, 4, "seed", 0))
		if scale := tbl_f64(L, 4, "scale", 0); scale != 0 {
			r.params[strings.clone("scale")] = scale
		}
		if cells := tbl_f64(L, 4, "cells", 0); cells != 0 {
			r.params[strings.clone("cells")] = cells
		}
		if tbl_f64(L, 4, "horizontal", 0) != 0 {
			r.params[strings.clone("horizontal")] = 1
		}
		if color, ok := tbl_color(L, 4, "color"); ok {
			append(&r.colors, color)
		}
		if color2, ok := tbl_color(L, 4, "color2"); ok {
			if len(r.colors) == 0 {
				append(&r.colors, rl.WHITE)
			}
			append(&r.colors, color2)
		}
	}
	engine.apply_recipe(g_eng, r)
	return 0
}

// gen_sprite(name, w, h, seed [, palette])  palette = array of hex strings
l_gen_sprite :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	w := i32(lua.L_checkinteger(L, 2))
	h := i32(lua.L_checkinteger(L, 3))
	seed := i64(lua.L_checkinteger(L, 4))
	context = g_ctx

	r: engine.GenRecipe
	r.name = strings.clone(string(name))
	r.kind = strings.clone("sprite")
	r.variant = strings.clone("")
	r.w, r.h = w, h
	r.seed = seed
	read_palette(L, 5, &r.colors)
	engine.apply_recipe(g_eng, r)
	return 0
}

// gen_sound(name [, opts])
// opts: wave ("sine"|"square"|"saw"|"triangle"|"noise"), freq, slide, len,
//       attack, vol, seed
l_gen_sound :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	has_opts := b32(lua.istable(L, 2))
	context = g_ctx

	r: engine.GenRecipe
	r.name = strings.clone(string(name))
	r.kind = strings.clone("sound")
	r.variant = strings.clone("square")
	if has_opts {
		delete(r.variant)
		r.variant = tbl_string(L, 2, "wave", "")
		if r.variant == "" {
			r.variant = strings.clone("square")
		}
		r.seed = i64(tbl_f64(L, 2, "seed", 0))
		for key in ([]cstring{"freq", "slide", "len", "attack", "vol"}) {
			if v := tbl_f64(L, 2, key, max(f64)); v != max(f64) {
				r.params[strings.clone(string(key))] = v
			}
		}
	}
	engine.apply_recipe(g_eng, r)
	return 0
}

// gen_palette(n [, seed]) -> { "#rrggbb", ... }
l_gen_palette :: proc "c" (L: ^lua.State) -> c.int {
	n := int(lua.L_checkinteger(L, 1))
	seed := u64(lua.L_optinteger(L, 2, 0))
	context = g_ctx

	colors := gen.gen_palette(seed, n, context.temp_allocator)
	lua.createtable(L, c.int(n), 0)
	for color, i in colors {
		hex := gen.color_to_hex(color, context.temp_allocator)
		chex := strings.clone_to_cstring(hex, context.temp_allocator)
		lua.pushstring(L, chex)
		lua.rawseti(L, -2, lua.Integer(i + 1))
	}
	free_all(context.temp_allocator)
	return 1
}

// gen_mesh_terrain(name, cells_w, cells_d [, opts])
// opts: seed, cell, height, scale, ridged (bool-ish), colors (hex array)
l_gen_mesh_terrain :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	w := i32(lua.L_checkinteger(L, 2))
	d := i32(lua.L_checkinteger(L, 3))
	has_opts := b32(lua.istable(L, 4))
	context = g_ctx

	r: engine.GenRecipe
	r.name = strings.clone(string(name))
	r.kind = strings.clone("terrain")
	r.variant = strings.clone("")
	r.w, r.h = w, d
	if has_opts {
		r.seed = i64(tbl_f64(L, 4, "seed", 0))
		for key in ([]cstring{"cell", "height", "scale", "ridged"}) {
			if v := tbl_f64(L, 4, key, max(f64)); v != max(f64) {
				r.params[strings.clone(string(key))] = v
			}
		}
		lua.getfield(L, 4, "colors")
		read_palette(L, lua.gettop(L), &r.colors)
		lua.pop(L, 1)
	}
	engine.apply_recipe(g_eng, r)
	return 0
}

// gen_mesh(name, kind [, a, b, c])  kind: "cube"|"sphere"|"plane"|"cylinder"|"torus"
// cube: a,b,c = w,h,d | sphere: a = radius | plane: a,b | cylinder: a=r, b=h | torus: a=radius,b=tube
l_gen_mesh :: proc "c" (L: ^lua.State) -> c.int {
	name := lua.L_checkstring(L, 1)
	kind := lua.L_checkstring(L, 2)
	a := f64(lua.L_optnumber(L, 3, 1))
	b := f64(lua.L_optnumber(L, 4, 1))
	cc := f64(lua.L_optnumber(L, 5, 1))
	context = g_ctx

	r: engine.GenRecipe
	r.name = strings.clone(string(name))
	r.kind = strings.clone("mesh")
	r.variant = strings.clone(string(kind))
	r.params[strings.clone("a")] = a
	r.params[strings.clone("b")] = b
	r.params[strings.clone("c")] = cc
	engine.apply_recipe(g_eng, r)
	return 0
}

// noise(x, y [, z]) -> [-1, 1], seeded by srand()
l_noise :: proc "c" (L: ^lua.State) -> c.int {
	x := f64(lua.L_checknumber(L, 1))
	y := f64(lua.L_checknumber(L, 2))
	context = g_ctx
	v: f32
	if lua.gettop(L) >= 3 {
		z := f64(lua.tonumber(L, 3))
		v = gen.noise3(g_noise_seed, x, y, z)
	} else {
		v = gen.noise2(g_noise_seed, x, y)
	}
	lua.pushnumber(L, lua.Number(v))
	return 1
}
