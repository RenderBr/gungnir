package engine

import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

// Post-processing chain: the frame renders into a render-texture canvas
// (at render_w x render_h, or native window size if 0), then draws to the
// window through an optional screen shader, aspect-fit with black bars.
// The editor bypasses the whole chain (main sets `bypass`).
Postfx :: struct {
	bypass:        bool,
	ready:         bool,
	frame_active:  bool, // latched by begin_frame, consumed by end_frame
	rt:            rl.RenderTexture2D, // scene canvas
	screen_shader: string, // owned; "" = none; key into assets.shaders
	render_w:      i32,   // 0 = native window size
	render_h:      i32,
}

// Lazily creates the render canvas at the configured resolution.
postfx_ensure :: proc(e: ^Engine) {
	if e.postfx.ready {
		return
	}
	w, h := e.postfx.render_w, e.postfx.render_h
	if w <= 0 || h <= 0 {
		w, h = rl.GetScreenWidth(), rl.GetScreenHeight()
	}
	e.postfx.rt = rl.LoadRenderTexture(w, h)
	rl.SetTextureFilter(e.postfx.rt.texture, .BILINEAR)
	e.postfx.ready = true
}

// Loads a preset shader from the presets/ directory and registers it as a
// shader asset so it can be referenced by name. Returns false on failure.
postfx_load_preset :: proc(e: ^Engine, name: string) -> bool {
	path := fmt.tprintf("presets/%s.fs", name)
	if !os.exists(path) {
		return false
	}
	data, rerr := os.read_entire_file(path, context.temp_allocator)
	if rerr != nil {
		return false
	}
	return register_shader(e, name, string(data))
}

postfx_set_screen_shader :: proc(e: ^Engine, name: string) {
	if name != "" {
		postfx_ensure(e)
	}
	delete(e.postfx.screen_shader)
	e.postfx.screen_shader = strings.clone(name)
}

postfx_set_render_resolution :: proc(e: ^Engine, w, h: i32) {
	e.postfx.render_w, e.postfx.render_h = w, h
	if e.postfx.ready {
		rl.UnloadRenderTexture(e.postfx.rt)
		e.postfx.ready = false
		if e.postfx.screen_shader != "" {
			postfx_ensure(e)
		}
	}
}

postfx_active :: proc(e: ^Engine) -> bool {
	return e.postfx.ready && !e.postfx.bypass && e.postfx.screen_shader != ""
}

postfx_destroy :: proc(e: ^Engine) {
	if e.postfx.ready {
		rl.UnloadRenderTexture(e.postfx.rt)
		e.postfx.ready = false
	}
	delete(e.postfx.screen_shader)
	e.postfx.screen_shader = ""
}

// The size scripts should lay out against: the render canvas when postfx is
// active, otherwise the real window.
logical_size :: proc(e: ^Engine) -> (i32, i32) {
	if postfx_active(e) {
		w, h := e.postfx.render_w, e.postfx.render_h
		if w > 0 && h > 0 {
			return w, h
		}
	}
	return rl.GetScreenWidth(), rl.GetScreenHeight()
}

// Mouse position in logical coordinates (inverts the aspect-fit mapping).
mouse_logical :: proc(e: ^Engine) -> rl.Vector2 {
	m := rl.GetMousePosition()
	if !postfx_active(e) {
		return m
	}
	w := f32(e.postfx.render_w)
	h := f32(e.postfx.render_h)
	if w <= 0 || h <= 0 {
		return m
	}
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	scale := min(sw / w, sh / h)
	ox := (sw - w * scale) / 2
	oy := (sh - h * scale) / 2
	return {(m.x - ox) / scale, (m.y - oy) / scale}
}
