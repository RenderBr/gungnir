package engine

import "core:slice"
import "core:strings"
import rl "vendor:raylib"

// Frame pass order is strict: 3D first, then 2D, then screen space.
// The 2D pass disables depth writes, so 3D after 2D produces sorting
// artifacts. main.odin composes these; nothing else may open rl modes.

begin_frame :: proc(e: ^Engine) {
	if postfx_active(e) {
		rl.BeginTextureMode(e.postfx.rt)
	} else {
		rl.BeginDrawing()
	}
	rl.ClearBackground(e.clear_color)
}

end_frame :: proc(e: ^Engine) {
	if postfx_active(e) {
		rl.EndTextureMode()
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		t := f32(rl.GetTime())
		rl.SetShaderValue(e.postfx.shader, rl.ShaderLocationIndex(e.postfx.time_loc), &t, .FLOAT)
		res := [2]f32{f32(e.postfx.w), f32(e.postfx.h)}
		rl.SetShaderValue(e.postfx.shader, rl.ShaderLocationIndex(e.postfx.res_loc), &res, .VEC2)

		sw := f32(rl.GetScreenWidth())
		sh := f32(rl.GetScreenHeight())
		scale := min(sw / f32(e.postfx.w), sh / f32(e.postfx.h))
		dw := f32(e.postfx.w) * scale
		dh := f32(e.postfx.h) * scale

		rl.BeginShaderMode(e.postfx.shader)
		rl.DrawTexturePro(
			e.postfx.rt.texture,
			{0, 0, f32(e.postfx.w), -f32(e.postfx.h)}, // RT is vertically flipped
			{(sw - dw) / 2, (sh - dh) / 2, dw, dh},
			{}, 0, rl.WHITE,
		)
		rl.EndShaderMode()
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
draw_entities_3d :: proc(e: ^Engine) {
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
		// Shallow copy so the per-entity euler rotation doesn't stick.
		mdl.transform = rl.MatrixRotateXYZ(
			{ent.rot.x * rl.DEG2RAD, ent.rot.y * rl.DEG2RAD, ent.rot.z * rl.DEG2RAD},
		)
		rl.DrawModelEx(mdl, ent.pos, {0, 1, 0}, 0, ent.scale, ent.tint)
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
}
