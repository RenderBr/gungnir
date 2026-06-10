package engine

import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

// Generated and file-based assets share one registry, so scripts, level
// files, and the editor reference everything by plain name. Lookup falls
// back to <game_dir>/assets/<name>.<ext> on miss.
Assets :: struct {
	textures: map[string]rl.Texture2D,
	sounds:   map[string]rl.Sound,
	models:   map[string]rl.Model,
	recipes:  map[string]GenRecipe, // keyed by recipe.name (map owns via recipe)
	missing:  rl.Texture2D, // magenta checker placeholder
}

assets_init :: proc(a: ^Assets) {
	img := rl.GenImageChecked(32, 32, 8, 8, rl.MAGENTA, rl.BLACK)
	defer rl.UnloadImage(img)
	a.missing = rl.LoadTextureFromImage(img)
}

assets_destroy :: proc(a: ^Assets) {
	for name, tex in a.textures {
		rl.UnloadTexture(tex)
		delete(name)
	}
	for name, snd in a.sounds {
		rl.UnloadSound(snd)
		delete(name)
	}
	for name, mdl in a.models {
		rl.UnloadModel(mdl)
		delete(name)
	}
	for _, &recipe in a.recipes {
		recipe_free(&recipe)
	}
	delete(a.recipes)
	delete(a.textures)
	delete(a.sounds)
	delete(a.models)
	rl.UnloadTexture(a.missing)
}

register_texture :: proc(e: ^Engine, name: string, tex: rl.Texture2D) {
	if old, ok := e.assets.textures[name]; ok {
		rl.UnloadTexture(old)
		e.assets.textures[name] = tex
	} else {
		e.assets.textures[strings.clone(name)] = tex
	}
}

register_sound :: proc(e: ^Engine, name: string, snd: rl.Sound) {
	if old, ok := e.assets.sounds[name]; ok {
		rl.UnloadSound(old)
		e.assets.sounds[name] = snd
	} else {
		e.assets.sounds[strings.clone(name)] = snd
	}
}

register_model :: proc(e: ^Engine, name: string, mdl: rl.Model) {
	if old, ok := e.assets.models[name]; ok {
		rl.UnloadModel(old)
		e.assets.models[name] = mdl
	} else {
		e.assets.models[strings.clone(name)] = mdl
	}
}

// Returns the placeholder texture on total miss, so a typo'd name renders
// as an obvious magenta checker instead of crashing or vanishing.
get_texture :: proc(e: ^Engine, name: string) -> rl.Texture2D {
	if tex, ok := e.assets.textures[name]; ok {
		return tex
	}
	path := fmt.tprintf("%s/assets/%s.png", e.game_dir, name)
	if os.exists(path) {
		tex := rl.LoadTexture(strings.clone_to_cstring(path, context.temp_allocator))
		if tex.id != 0 {
			e.assets.textures[strings.clone(name)] = tex
			return tex
		}
	}
	return e.assets.missing
}

get_sound :: proc(e: ^Engine, name: string) -> (rl.Sound, bool) {
	if snd, ok := e.assets.sounds[name]; ok {
		return snd, true
	}
	for ext in ([]string{"wav", "ogg"}) {
		path := fmt.tprintf("%s/assets/%s.%s", e.game_dir, name, ext)
		if os.exists(path) {
			snd := rl.LoadSound(strings.clone_to_cstring(path, context.temp_allocator))
			if rl.IsSoundValid(snd) {
				e.assets.sounds[strings.clone(name)] = snd
				return snd, true
			}
		}
	}
	return {}, false
}

get_model :: proc(e: ^Engine, name: string) -> (rl.Model, bool) {
	if mdl, ok := e.assets.models[name]; ok {
		return mdl, true
	}
	return {}, false
}
