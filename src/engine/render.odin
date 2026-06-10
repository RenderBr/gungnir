package engine

import "core:slice"
import "core:strings"
import rl "vendor:raylib"

// Frame pass order is strict: 3D first, then 2D, then screen space.
// The 2D pass disables depth writes, so 3D after 2D produces sorting
// artifacts. main.odin composes these; nothing else may open rl modes.

begin_frame :: proc(e: ^Engine) {
	rl.BeginDrawing()
	rl.ClearBackground(e.clear_color)
}

end_frame :: proc(e: ^Engine) {
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
