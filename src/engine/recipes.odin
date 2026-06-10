package engine

import rl "vendor:raylib"
import "../gen"

// A recipe is the serializable description of one generated asset: levels
// save recipes (seed + params), not pixels, and regenerate on load.
GenRecipe :: struct {
	name:    string, // owned
	kind:    string, // owned: "texture" | "sprite" | "sound"
	variant: string, // owned: texture kind ("noise"...) or wave name ("square"...)
	seed:    i64,
	w, h:    i32,
	params:  map[string]f64, // owned keys
	colors:  [dynamic]rl.Color,
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
}

@(private = "file")
param :: proc(r: GenRecipe, key: string, def: f64) -> f64 {
	if v, ok := r.params[key]; ok {
		return v
	}
	return def
}

// Takes ownership of the recipe, generates the asset, registers both.
// The single code path for scripts, level loading, and editor regen.
apply_recipe :: proc(e: ^Engine, r: GenRecipe) {
	generate_from_recipe(e, r)
	store_recipe(e, r)
}

// Regenerates the asset without touching recipe storage. The editor calls
// this after mutating a stored recipe's fields in place.
generate_from_recipe :: proc(e: ^Engine, r: GenRecipe) {
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
	}
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
