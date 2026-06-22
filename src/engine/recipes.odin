package engine

import "core:strings"
import rl "vendor:raylib"
import "../gen"

// A recipe is the serializable description of one generated asset: levels
// save recipes (seed + params), not pixels, and regenerate on load.
GenRecipe :: struct {
	name:    string, // owned
	kind:    string, // owned: "texture" | "sprite" | "sound" | "pixels" | ...
	variant: string, // owned: texture kind / wave name / pixels charset
	seed:    i64,
	w, h:    i32,
	params:  map[string]f64, // owned keys
	colors:  [dynamic]rl.Color,
	rows:    [dynamic]string, // owned; "pixels" art, chars index variant/colors
}

recipe_free :: proc(r: ^GenRecipe) {
	delete(r.name)
	delete(r.kind)
	delete(r.variant)
	for key in r.params {
		delete(key)
	}
	delete(r.params)
	delete(r.colors)
	for row in r.rows {
		delete(row)
	}
	delete(r.rows)
}

@(private = "file")
param :: proc(r: GenRecipe, key: string, def: f64) -> f64 {
	if v, ok := r.params[key]; ok {
		return v
	}
	return def
}

// Takes ownership of the recipe, generates the asset, registers both.
// Returns false (recipe freed, nothing stored) if generation failed —
// today only "shader" can fail (GLSL compile error).
apply_recipe :: proc(e: ^Engine, r: GenRecipe) -> bool {
	if !generate_from_recipe(e, r) {
		r := r
		recipe_free(&r)
		return false
	}
	store_recipe(e, r)
	return true
}

// Regenerates the asset without touching recipe storage. The editor calls
// this after mutating a stored recipe's fields in place.
generate_from_recipe :: proc(e: ^Engine, r: GenRecipe) -> bool {
	switch r.kind {
	case "texture":
		opts := gen.default_texture_opts()
		opts.seed = r.seed
		opts.scale = param(r, "scale", opts.scale)
		opts.cells = param(r, "cells", opts.cells)
		opts.horizontal = param(r, "horizontal", 0) != 0
		switch r.variant {
		case "gradient": opts.kind = .Gradient
		case "checker":  opts.kind = .Checker
		case "circle":   opts.kind = .Circle
		case:            opts.kind = .Noise
		}
		if len(r.colors) > 0 do opts.color = r.colors[0]
		if len(r.colors) > 1 do opts.color2 = r.colors[1]
		img := gen.gen_texture_image(r.w, r.h, opts)
		register_texture(e, r.name, rl.LoadTextureFromImage(img))
		rl.UnloadImage(img)

	case "sprite":
		palette := r.colors[:]
		generated: []rl.Color
		if len(palette) == 0 {
			generated = gen.gen_palette(u64(r.seed), 4, context.temp_allocator)
			palette = generated
		}
		img := gen.gen_sprite_image(r.w, r.h, u64(r.seed), palette)
		register_texture(e, r.name, rl.LoadTextureFromImage(img))
		rl.UnloadImage(img)

	case "pixels":
		// Hand-drawn pixel art: rows of chars, each char indexing a palette
		// color via position in the charset string (variant). '.' and ' '
		// are transparent.
		img := rl.GenImageColor(r.w, r.h, rl.BLANK)
		pixels := ([^]rl.Color)(img.data)
		for row, y in r.rows {
			if i32(y) >= r.h {
				break
			}
			for x in 0 ..< min(len(row), int(r.w)) {
				ch := row[x]
				if ch == '.' || ch == ' ' {
					continue
				}
				for vc, ci in transmute([]u8)r.variant {
					if vc == ch && ci < len(r.colors) {
						pixels[y * int(r.w) + x] = r.colors[ci]
						break
					}
				}
			}
		}
		register_texture(e, r.name, rl.LoadTextureFromImage(img))
		rl.UnloadImage(img)

	case "terrain":
		opts := gen.default_terrain_opts()
		opts.seed = r.seed
		opts.cells_w = int(r.w)
		opts.cells_d = int(r.h)
		opts.cell = f32(param(r, "cell", f64(opts.cell)))
		opts.height = f32(param(r, "height", f64(opts.height)))
		opts.scale = param(r, "scale", opts.scale)
		opts.ridged = param(r, "ridged", 0) != 0
		opts.colors = r.colors[:]
		register_model(e, r.name, gen.gen_terrain_model(opts))

	case "mesh":
		kind: gen.MeshPrimitive
		switch r.variant {
		case "sphere":   kind = .Sphere
		case "plane":    kind = .Plane
		case "cylinder": kind = .Cylinder
		case "torus":    kind = .Torus
		case:            kind = .Cube
		}
		a := f32(param(r, "a", 1))
		b := f32(param(r, "b", 1))
		c := f32(param(r, "c", 1))
		register_model(e, r.name, gen.gen_primitive_model(kind, a, b, c))

	case "sound":
		opts := gen.default_sound_opts()
		opts.seed = u64(r.seed)
		opts.freq = f32(param(r, "freq", f64(opts.freq)))
		opts.slide = f32(param(r, "slide", 0))
		opts.len = f32(param(r, "len", f64(opts.len)))
		opts.attack = f32(param(r, "attack", f64(opts.attack)))
		opts.vol = f32(param(r, "vol", f64(opts.vol)))
		switch r.variant {
		case "sine":     opts.wave = .Sine
		case "saw":      opts.wave = .Saw
		case "triangle": opts.wave = .Triangle
		case "noise":    opts.wave = .Noise
		case:            opts.wave = .Square
		}
		wave := gen.gen_sound_wave(opts)
		register_sound(e, r.name, rl.LoadSoundFromWave(wave))
		rl.UnloadWave(wave)

	case "shader":
		code := strings.join(r.rows[:], "\n", context.temp_allocator)
		return register_shader(e, r.name, code)
	}
	return true
}

@(private = "file")
store_recipe :: proc(e: ^Engine, r: GenRecipe) {
	if old, ok := &e.assets.recipes[r.name]; ok {
		key := old.name
		recipe_free(old)
		delete_key(&e.assets.recipes, key)
	}
	e.assets.recipes[r.name] = r
}
