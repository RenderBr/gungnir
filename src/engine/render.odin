package engine

import "core:slice"
import "core:strings"
import rl "vendor:raylib"

// Frame pass order is strict: 3D first, then 2D, then screen space.
// The 2D pass disables depth writes, so 3D after 2D produces sorting
// artifacts. main.odin composes these; nothing else may open rl modes.

begin_frame :: proc(e: ^Engine) {
	// Latch: scripts may toggle crt/screen shader mid-frame (on_draw); the
	// end of this frame must match how it began.
	e.postfx.frame_active = postfx_active(e)
	if e.postfx.frame_active {
		rl.BeginTextureMode(e.postfx.rt)
	} else {
		rl.BeginDrawing()
	}
	rl.ClearBackground(e.clear_color)
}

end_frame :: proc(e: ^Engine) {
	if e.postfx.frame_active {
		rl.EndTextureMode()

		w := f32(e.postfx.w)
		h := f32(e.postfx.h)
		user, has_user := get_shader(e, e.postfx.screen_shader)
		crt := e.postfx.crt_enabled

		src := e.postfx.rt
		if has_user && crt {
			// chain stage 1: user shader at logical resolution into rt2,
			// so the CRT pass then warps the already-processed image.
			rl.BeginTextureMode(e.postfx.rt2)
			rl.ClearBackground(rl.BLACK)
			shader_set_auto_uniforms(user, w, h)
			rl.BeginShaderMode(user.shader)
			rl.DrawTexturePro(src.texture, {0, 0, w, -h}, {0, 0, w, h}, {}, 0, rl.WHITE)
			rl.EndShaderMode()
			rl.EndTextureMode()
			src = e.postfx.rt2
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		sw := f32(rl.GetScreenWidth())
		sh := f32(rl.GetScreenHeight())
		scale := min(sw / w, sh / h)
		dw := w * scale
		dh := h * scale

		final: rl.Shader
		use_final := false
		if crt {
			t := f32(rl.GetTime())
			rl.SetShaderValue(e.postfx.crt_shader, rl.ShaderLocationIndex(e.postfx.crt_time_loc), &t, .FLOAT)
			res := [2]f32{w, h}
			rl.SetShaderValue(e.postfx.crt_shader, rl.ShaderLocationIndex(e.postfx.crt_res_loc), &res, .VEC2)
			final = e.postfx.crt_shader
			use_final = true
		} else if has_user {
			shader_set_auto_uniforms(user, w, h)
			final = user.shader
			use_final = true
		}
		if use_final {
			rl.BeginShaderMode(final)
		}
		rl.DrawTexturePro(
			src.texture,
			{0, 0, w, -h}, // RT is vertically flipped
			{(sw - dw) / 2, (sh - dh) / 2, dw, dh},
			{}, 0, rl.WHITE,
		)
		if use_final {
			rl.EndShaderMode()
		}
	}
	rl.EndDrawing()
}

begin_2d :: proc(e: ^Engine) {
	rl.BeginMode2D(e.cam2d)
}

end_2d :: proc(e: ^Engine) {
	rl.EndMode2D()
}

begin_3d :: proc(e: ^Engine) {
	rl.BeginMode3D(e.cam3d)
}

end_3d :: proc(e: ^Engine) {
	rl.EndMode3D()
}

// Draws all alive MeshRef entities. Call between begin_3d and end_3d.
// When lighting has ever been enabled, model materials get the lit (or
// default) shader each frame; the materials pointer is shared with the asset
// registry, so the assignment persists intentionally.
draw_entities_3d :: proc(e: ^Engine) {
	lit := lighting_active(e)
	if lit {
		lighting_upload_3d(e)
	}
	for &ent in e.scene.entities {
		if !ent.alive {
			continue
		}
		mref, is_mesh := ent.variant.(MeshRef)
		if !is_mesh {
			continue
		}
		mdl, ok := get_model(e, mref.model)
		if !ok {
			continue
		}
		if e.lighting.ready {
			sh := lit ? e.lighting.shader3d : e.lighting.default_shader
			for i in 0 ..< mdl.materialCount {
				mdl.materials[i].shader = sh
			}
		}
		// Shallow copy so the per-entity euler rotation doesn't stick.
		mdl.transform = rl.MatrixRotateXYZ(
			{ent.rot.x * rl.DEG2RAD, ent.rot.y * rl.DEG2RAD, ent.rot.z * rl.DEG2RAD},
		)
		// BeginShaderMode doesn't affect DrawModelEx — DrawMesh uses
		// material.shader directly, and materials are shared with the
		// registry model, so swap in and restore after the draw.
		sa, shaded := get_shader(e, ent.shader)
		saved: []rl.Shader
		if shaded {
			lw, lh := logical_size(e)
			shader_set_auto_uniforms(sa, f32(lw), f32(lh))
			saved = make([]rl.Shader, mdl.materialCount, context.temp_allocator)
			for i in 0 ..< mdl.materialCount {
				saved[i] = mdl.materials[i].shader
				mdl.materials[i].shader = sa.shader
			}
		}
		rl.DrawModelEx(mdl, ent.pos, {0, 1, 0}, 0, ent.scale, ent.tint)
		if shaded {
			for i in 0 ..< mdl.materialCount {
				mdl.materials[i].shader = saved[i]
			}
		}
	}
}

// Draws all alive 2D entities (Sprite/Shape/Label), back-to-front by pos.z.
// Call between begin_2d and end_2d.
draw_entities_2d :: proc(e: ^Engine) {
	ents := make([dynamic]^Entity, 0, len(e.scene.entities), context.temp_allocator)
	for &ent in e.scene.entities {
		if !ent.alive {
			continue
		}
		#partial switch _ in ent.variant {
		case Sprite, Shape, Label:
			append(&ents, &ent)
		}
	}
	slice.stable_sort_by(ents[:], proc(a, b: ^Entity) -> bool {
		return a.pos.z < b.pos.z
	})
	for ent in ents {
		draw_entity_2d(e, ent)
	}
}

// Positions are entity centers (labels: top-left), so rotation and scaling
// behave intuitively.
draw_entity_2d :: proc(e: ^Engine, ent: ^Entity) {
	// Per-entity shader: forces a batch flush per shaded entity (fine for
	// dozens, not thousands). Also applies in the editor's 2D view — the
	// editor bypass only disables the post chain.
	sa, shaded := get_shader(e, ent.shader)
	if shaded {
		lw, lh := logical_size(e)
		shader_set_auto_uniforms(sa, f32(lw), f32(lh))
		rl.BeginShaderMode(sa.shader)
	}
	#partial switch v in ent.variant {
	case Sprite:
		tex := get_texture(e, v.texture)
		w := f32(tex.width)
		h := f32(tex.height)
		src := rl.Rectangle{0, 0, v.flip_x ? -w : w, v.flip_y ? -h : h}
		dst := rl.Rectangle{ent.pos.x, ent.pos.y, w * ent.scale.x, h * ent.scale.y}
		rl.DrawTexturePro(tex, src, dst, {dst.width / 2, dst.height / 2}, ent.rot.z, ent.tint)
	case Shape:
		switch v.kind {
		case .Rect:
			w := v.size.x * ent.scale.x
			h := v.size.y * ent.scale.y
			rl.DrawRectanglePro({ent.pos.x, ent.pos.y, w, h}, {w / 2, h / 2}, ent.rot.z, ent.tint)
		case .Circle:
			rl.DrawCircleV({ent.pos.x, ent.pos.y}, v.size.x / 2 * ent.scale.x, ent.tint)
		}
	case Label:
		text := strings.clone_to_cstring(v.text, context.temp_allocator)
		rl.DrawTextPro(rl.GetFontDefault(), text, {ent.pos.x, ent.pos.y}, {}, ent.rot.z,
			v.size * ent.scale.y, v.size / 10, ent.tint)
	}
	if shaded {
		rl.EndShaderMode()
	}
}
