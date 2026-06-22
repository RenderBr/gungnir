package engine

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// Generated and file-based assets share one registry, so scripts, level
// files, and the editor reference everything by plain name. Lookup falls
// back to <game_dir>/assets/<name>.<ext> on miss.
Assets :: struct {
	textures:    map[string]rl.Texture2D,
	sounds:      map[string]rl.Sound,
	models:      map[string]rl.Model,
	shaders:     map[string]ShaderAsset,
	recipes:     map[string]GenRecipe, // keyed by recipe.name (map owns via recipe)
	missing:     rl.Texture2D, // magenta checker placeholder
	asset_mtimes: map[string]i64, // file mtime (unix ns) per registered asset
}

// Compiled fragment shader + cached uniform locations. 'time'/'resolution'
// are auto-fed each frame the shader is used; other locs cache lazily.
ShaderAsset :: struct {
	shader:   rl.Shader,
	time_loc: i32,
	res_loc:  i32,
	locs:     map[string]i32, // owned keys; -1 entries cache misses too
}

shader_asset_free :: proc(sa: ^ShaderAsset) {
	rl.UnloadShader(sa.shader)
	for key in sa.locs {
		delete(key)
	}
	delete(sa.locs)
}

assets_init :: proc(a: ^Assets) {
	a.asset_mtimes = make(map[string]i64)
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
	for name, &sa in a.shaders {
		shader_asset_free(&sa)
		delete(name)
	}
	delete(a.shaders)
	for _, &recipe in a.recipes {
		recipe_free(&recipe)
	}
	delete(a.recipes)
	delete(a.textures)
	delete(a.sounds)
	delete(a.models)
	delete(a.asset_mtimes)
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
	for ext in ([]string{"png", "jpg"}) {
		path := fmt.tprintf("%s/assets/%s.%s", e.game_dir, name, ext)
		if os.exists(path) {
			tex := rl.LoadTexture(strings.clone_to_cstring(path, context.temp_allocator))
			if tex.id != 0 {
				e.assets.textures[strings.clone(name)] = tex
				if info, err := os.stat(path, context.temp_allocator); err == nil {
					e.assets.asset_mtimes[strings.clone(name)] = time.to_unix_nanoseconds(info.modification_time)
				}
				return tex
			}
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
				if info, err := os.stat(path, context.temp_allocator); err == nil {
					e.assets.asset_mtimes[strings.clone(name)] = time.to_unix_nanoseconds(info.modification_time)
				}
				return snd, true
			}
		}
	}
	return {}, false
}

// Loads [start, end) seconds of <game_dir>/assets/<file> into a Sound and
// registers it under `name`, so play_sound(name) plays just that slice.
// Returns false on missing file, decode failure, or an empty/inverted range;
// play_sound on an unregistered name is a silent no-op, so a failed slice
// never crashes the game.
load_sound_slice :: proc(e: ^Engine, name, file: string, start, end: f32) -> bool {
	path := fmt.tprintf("%s/assets/%s", e.game_dir, file)
	if !os.exists(path) {
		return false
	}
	wave := rl.LoadWave(strings.clone_to_cstring(path, context.temp_allocator))
	if wave.frameCount == 0 {
		return false
	}
	defer rl.UnloadWave(wave)

	init_frame := c.int(max(start * f32(wave.sampleRate), 0))
	final_frame := c.int(clamp(end * f32(wave.sampleRate), 0, f32(wave.frameCount)))
	if final_frame <= init_frame {
		return false
	}
	rl.WaveCrop(&wave, init_frame, final_frame)
	snd := rl.LoadSoundFromWave(wave)
	if !rl.IsSoundValid(snd) {
		return false
	}
	register_sound(e, name, snd)
	return true
}

get_model :: proc(e: ^Engine, name: string) -> (rl.Model, bool) {
	if mdl, ok := e.assets.models[name]; ok {
		return mdl, true
	}
	return {}, false
}

// Binds a file/generated texture to every material in a model. Models are
// registry assets shared by their entities, so the binding is intentionally
// model-wide. Repeat + anisotropic filtering are appropriate for world
// materials and remain harmless for ordinary clamp-safe images.
set_model_texture :: proc(e: ^Engine, model_name, texture_name: string) -> bool {
	mdl, ok := get_model(e, model_name)
	if !ok {
		return false
	}
	tex := get_texture(e, texture_name)
	rl.SetTextureWrap(tex, .REPEAT)
	rl.SetTextureFilter(tex, .ANISOTROPIC_16X)
	for i in 0 ..< mdl.materialCount {
		rl.SetMaterialTexture(&mdl.materials[i], .ALBEDO, tex)
	}
	return true
}

// Compiles fs_code with raylib's default vertex shader. On compile failure
// the previous registration (if any) is kept, so hot reload of a broken
// shader doesn't black out the game.
register_shader :: proc(e: ^Engine, name: string, fs_code: string) -> bool {
	ccode := strings.clone_to_cstring(fs_code, context.temp_allocator)
	sh := rl.LoadShaderFromMemory(nil, ccode)
	// raylib falls back to the default shader on compile failure, which
	// still passes IsShaderValid — the id check is the real test.
	if !rl.IsShaderValid(sh) || sh.id == u32(rlgl.GetShaderIdDefault()) {
		if sh.locs != nil {
			rl.MemFree(sh.locs) // UnloadShader refuses default-id shaders
		}
		fmt.eprintfln("[shader error] %q failed to compile (GLSL log above)", name)
		return false
	}
	sa := ShaderAsset{
		shader   = sh,
		time_loc = i32(rl.GetShaderLocation(sh, "time")),
		res_loc  = i32(rl.GetShaderLocation(sh, "resolution")),
	}
	if old, ok := &e.assets.shaders[name]; ok {
		shader_asset_free(old)
		e.assets.shaders[name] = sa
	} else {
		e.assets.shaders[strings.clone(name)] = sa
	}
	return true
}

// "" is the common fast path (default pipeline). Pointer return: callers may
// mutate the locs cache; map slots are stable until the next insertion, and
// no caller holds the pointer across a register_shader.
get_shader :: proc(e: ^Engine, name: string) -> (^ShaderAsset, bool) {
	if name == "" {
		return nil, false
	}
	if sa, ok := &e.assets.shaders[name]; ok {
		return sa, true
	}
	return nil, false
}

has_shader :: proc(e: ^Engine, name: string) -> bool {
	return name in e.assets.shaders
}

// Not script-exposed; exists for registry symmetry and future editor use.
unload_shader :: proc(e: ^Engine, name: string) {
	if sa, ok := &e.assets.shaders[name]; ok {
		shader_asset_free(sa)
		dkey, _ := delete_key(&e.assets.shaders, name)
		delete(dkey)
	}
}

// Feed the conventional auto-uniforms right before a shader is used.
// w,h = resolution the shader's output is measured in.
shader_set_auto_uniforms :: proc(sa: ^ShaderAsset, w, h: f32) {
	if sa.time_loc >= 0 {
		t := f32(rl.GetTime())
		rl.SetShaderValue(sa.shader, rl.ShaderLocationIndex(sa.time_loc), &t, .FLOAT)
	}
	if sa.res_loc >= 0 {
		res := [2]f32{w, h}
		rl.SetShaderValue(sa.shader, rl.ShaderLocationIndex(sa.res_loc), &res, .VEC2)
	}
}

// 1..4 floats -> float/vec2/vec3/vec4. false = unknown shader name.
// loc -1 (uniform absent/optimized out) is a silent no-op by design.
set_shader_param :: proc(e: ^Engine, shader_name, param: string, vals: []f32) -> bool {
	sa, ok := get_shader(e, shader_name)
	if !ok {
		return false
	}
	loc, cached := sa.locs[param]
	if !cached {
		cparam := strings.clone_to_cstring(param, context.temp_allocator)
		loc = i32(rl.GetShaderLocation(sa.shader, cparam))
		sa.locs[strings.clone(param)] = loc
	}
	if loc < 0 {
		return true
	}
	kind: rl.ShaderUniformDataType
	switch len(vals) {
	case 1: kind = .FLOAT
	case 2: kind = .VEC2
	case 3: kind = .VEC3
	case:   kind = .VEC4
	}
	rl.SetShaderValue(sa.shader, rl.ShaderLocationIndex(loc), raw_data(vals), kind)
	return true
}

// Scans the assets/ directory and returns the newest mtime (unix ns).
// Returns 0 if the directory is missing or unreadable.
scan_assets_mtime :: proc(e: ^Engine) -> i64 {
	dir := fmt.tprintf("%s/assets", e.game_dir)
	entries, err := os.read_directory_by_path(dir, -1, context.temp_allocator)
	if err != nil {
		return 0
	}
	defer os.file_info_slice_delete(entries, context.temp_allocator)
	newest: i64
	for fi in entries {
		if fi.type == .Regular {
			ns := time.to_unix_nanoseconds(fi.modification_time)
			if ns > newest {
				newest = ns
			}
		}
	}
	return newest
}

// Reloads textures and sounds from disk if their source files changed.
// Only re-reads assets already in the registry — avoids loading random files.
reload_assets :: proc(e: ^Engine) {
	dir := fmt.tprintf("%s/assets", e.game_dir)
	for name, &tex in e.assets.textures {
		old_mtime := e.assets.asset_mtimes[name]
		for ext in ([]string{"png", "jpg"}) {
			path := fmt.tprintf("%s/%s.%s", dir, name, ext)
			if os.exists(path) {
				if info, err := os.stat(path, context.temp_allocator); err == nil {
					cur_mtime := time.to_unix_nanoseconds(info.modification_time)
					if cur_mtime > old_mtime {
						loaded := rl.LoadTexture(strings.clone_to_cstring(path, context.temp_allocator))
						if loaded.id != 0 {
							rl.UnloadTexture(tex)
							e.assets.textures[name] = loaded
							e.assets.asset_mtimes[name] = cur_mtime
							fmt.println("[assets] reloaded texture:", name)
						}
					}
				}
				break
			}
		}
	}
	for name, &snd in e.assets.sounds {
		old_mtime := e.assets.asset_mtimes[name]
		for ext in ([]string{"wav", "ogg"}) {
			path := fmt.tprintf("%s/%s.%s", dir, name, ext)
			if os.exists(path) {
				if info, err := os.stat(path, context.temp_allocator); err == nil {
					cur_mtime := time.to_unix_nanoseconds(info.modification_time)
					if cur_mtime > old_mtime {
						loaded := rl.LoadSound(strings.clone_to_cstring(path, context.temp_allocator))
						if rl.IsSoundValid(loaded) {
							rl.UnloadSound(snd)
							e.assets.sounds[name] = loaded
							e.assets.asset_mtimes[name] = cur_mtime
							fmt.println("[assets] reloaded sound:", name)
						}
					}
				}
				break
			}
		}
	}
}
