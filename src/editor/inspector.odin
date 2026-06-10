package editor

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import "../engine"
import "../script"

TOOLBAR_H :: 36
LEFT_W :: 190
RIGHT_W :: 250
BOTTOM_H :: 40

@(private)
ui_blocks_mouse :: proc(mouse: rl.Vector2) -> bool {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	return mouse.y < TOOLBAR_H ||
	       mouse.y > h - BOTTOM_H ||
	       mouse.x < LEFT_W ||
	       mouse.x > w - RIGHT_W
}

@(private)
refresh_buffers :: proc(ed: ^Editor, ent: ^engine.Entity) {
	copy_to_buf(ed.name_buf[:], ent.name)
	#partial switch v in ent.variant {
	case engine.Sprite:
		copy_to_buf(ed.tex_buf[:], v.texture)
	case engine.Label:
		copy_to_buf(ed.text_buf[:], v.text)
	case engine.MeshRef:
		copy_to_buf(ed.tex_buf[:], v.model)
	}
}

@(private)
copy_to_buf :: proc(buf: []u8, s: string) {
	n := min(len(s), len(buf) - 1)
	copy(buf, s[:n])
	buf[n] = 0
}

@(private)
buf_to_string :: proc(buf: []u8) -> string {
	return string(cstring(raw_data(buf)))
}

// Screen-space editor UI. In play mode only the slim toolbar shows.
draw_panels :: proc(ed: ^Editor, e: ^engine.Engine, s: ^script.Script) {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	// -- toolbar (both modes) --
	rl.DrawRectangleRec({0, 0, w, TOOLBAR_H}, {30, 30, 42, 240})
	if ed.playing {
		if rl.GuiButton({8, 6, 70, 24}, "#133#Stop") || rl.IsKeyPressed(.F1) {
			enter_edit(ed, e, s)
		}
		rl.DrawText("PLAYING (f1 to stop)", 90, 12, 14, {140, 220, 140, 255})
		return
	}
	if rl.GuiButton({8, 6, 70, 24}, "#131#Play") || rl.IsKeyPressed(.F1) {
		enter_play(ed, e, s)
		return
	}
	if rl.GuiButton({86, 6, 60, 24}, "Save") {
		save(ed, e)
	}
	if rl.GuiButton({154, 6, 60, 24}, "Load") {
		if engine.load_default_level(e) {
			set_status(ed, "loaded level.json")
		} else {
			set_status(ed, "no level.json")
		}
		ed.selected = ~engine.EntityId(0)
	}
	rl.GuiCheckBox({230, 10, 16, 16}, "snap", &ed.snap)
	if ed.status_timer > 0 {
		msg := strings.clone_to_cstring(ed.status, context.temp_allocator)
		rl.DrawText(msg, i32(w) - 250, 12, 14, {220, 220, 140, 255})
	}

	draw_hierarchy(ed, e, h)
	draw_inspector(ed, e, w)
	draw_spawn_bar(ed, e, w, h)
}

@(private)
draw_hierarchy :: proc(ed: ^Editor, e: ^engine.Engine, h: f32) {
	bounds := rl.Rectangle{0, TOOLBAR_H, LEFT_W, h - TOOLBAR_H - BOTTOM_H}

	sb := strings.builder_make(context.temp_allocator)
	ids := make([dynamic]engine.EntityId, context.temp_allocator)
	active := i32(-1)
	for &ent in e.scene.entities {
		if !ent.alive {
			continue
		}
		if len(ids) > 0 {
			strings.write_byte(&sb, ';')
		}
		if ent.id == ed.selected {
			active = i32(len(ids))
		}
		if ent.name != "" {
			strings.write_string(&sb, ent.name)
		} else {
			strings.write_string(&sb, variant_label(&ent))
		}
		append(&ids, ent.id)
	}
	items := strings.clone_to_cstring(strings.to_string(sb), context.temp_allocator)

	prev := active
	rl.GuiListView(bounds, items, &ed.hierarchy_scroll, &active)
	if active != prev && active >= 0 && int(active) < len(ids) {
		ed.selected = ids[active]
		if ent := engine.get(&e.scene, ed.selected); ent != nil {
			refresh_buffers(ed, ent)
		}
	}
}

@(private)
variant_label :: proc(ent: ^engine.Entity) -> string {
	switch v in ent.variant {
	case engine.Sprite:  return v.texture
	case engine.Shape:   return v.kind == .Circle ? "circle" : "rect"
	case engine.Label:   return "text"
	case engine.MeshRef: return v.model
	}
	return "entity"
}

@(private)
draw_inspector :: proc(ed: ^Editor, e: ^engine.Engine, w: f32) {
	x := w - RIGHT_W
	bounds := rl.Rectangle{x, TOOLBAR_H, RIGHT_W, f32(rl.GetScreenHeight()) - TOOLBAR_H - BOTTOM_H}
	rl.GuiPanel(bounds, "inspector")

	ent := engine.get(&e.scene, ed.selected)
	if ent == nil {
		rl.DrawText("nothing selected", i32(x) + 12, TOOLBAR_H + 36, 13, rl.GRAY)
		return
	}

	pad := x + 10
	fw: f32 = RIGHT_W - 20 // field width
	y: f32 = TOOLBAR_H + 30

	// name
	if rl.GuiTextBox({pad, y, fw, 22}, cstring(raw_data(ed.name_buf[:])), len(ed.name_buf), ed.name_edit) {
		ed.name_edit = !ed.name_edit
		if !ed.name_edit { // committed
			delete(ent.name)
			ent.name = strings.clone(buf_to_string(ed.name_buf[:]))
		}
	}
	y += 30

	// transform
	drag_number(ed, 1, {pad, y, fw / 2 - 2, 20}, "x", &ent.pos.x, 1)
	drag_number(ed, 2, {pad + fw / 2 + 2, y, fw / 2 - 2, 20}, "y", &ent.pos.y, 1)
	y += 24
	drag_number(ed, 3, {pad, y, fw / 2 - 2, 20}, "layer", &ent.pos.z, 0.05)
	drag_number(ed, 4, {pad + fw / 2 + 2, y, fw / 2 - 2, 20}, "rot", &ent.rot.z, 1)
	y += 24
	drag_number(ed, 5, {pad, y, fw / 2 - 2, 20}, "sx", &ent.scale.x, 0.05)
	drag_number(ed, 6, {pad + fw / 2 + 2, y, fw / 2 - 2, 20}, "sy", &ent.scale.y, 0.05)
	y += 30

	// variant-specific
	#partial switch &v in ent.variant {
	case engine.Sprite:
		rl.DrawText("texture", i32(pad), i32(y) + 4, 12, rl.GRAY)
		if rl.GuiTextBox({pad + 60, y, fw - 60, 22}, cstring(raw_data(ed.tex_buf[:])), len(ed.tex_buf), ed.tex_edit) {
			ed.tex_edit = !ed.tex_edit
			if !ed.tex_edit {
				delete(v.texture)
				v.texture = strings.clone(buf_to_string(ed.tex_buf[:]))
			}
		}
		y += 30
	case engine.Shape:
		drag_number(ed, 7, {pad, y, fw / 2 - 2, 20}, "w", &v.size.x, 1)
		if v.kind == .Rect {
			drag_number(ed, 8, {pad + fw / 2 + 2, y, fw / 2 - 2, 20}, "h", &v.size.y, 1)
		}
		y += 30
	case engine.Label:
		if rl.GuiTextBox({pad, y, fw, 22}, cstring(raw_data(ed.text_buf[:])), len(ed.text_buf), ed.text_edit) {
			ed.text_edit = !ed.text_edit
			if !ed.text_edit {
				engine.set_label_text(ent, buf_to_string(ed.text_buf[:]))
			}
		}
		y += 26
		drag_number(ed, 9, {pad, y, fw / 2 - 2, 20}, "size", &v.size, 0.5)
		y += 30
	}

	// tint
	rl.GuiColorPicker({pad, y, fw - 30, 120}, nil, &ent.tint)
}

// Click-drag horizontally to change the value. The id disambiguates
// concurrent widgets; only one drags at a time.
@(private)
drag_number :: proc(ed: ^Editor, id: int, bounds: rl.Rectangle, label: cstring, v: ^f32, speed: f32) {
	mouse := rl.GetMousePosition()
	hover := rl.CheckCollisionPointRec(mouse, bounds)

	if ed.drag_num_id == id {
		v^ = ed.drag_num_value + (mouse.x - ed.drag_num_start) * speed
		if speed >= 1 {
			v^ = f32(int(v^))
		}
		if rl.IsMouseButtonReleased(.LEFT) {
			ed.drag_num_id = -1
		}
	} else if hover && rl.IsMouseButtonPressed(.LEFT) && ed.drag_num_id == -1 {
		ed.drag_num_id = id
		ed.drag_num_start = mouse.x
		ed.drag_num_value = v^
	}

	bg := rl.Color{45, 45, 60, 255}
	if ed.drag_num_id == id {
		bg = {70, 70, 110, 255}
	} else if hover {
		bg = {55, 55, 75, 255}
	}
	rl.DrawRectangleRec(bounds, bg)
	rl.DrawRectangleLinesEx(bounds, 1, {90, 90, 120, 255})
	rl.DrawText(label, i32(bounds.x) + 4, i32(bounds.y) + 4, 12, rl.GRAY)
	value := fmt.ctprintf("%.4g", v^)
	tw := rl.MeasureText(value, 12)
	rl.DrawText(value, i32(bounds.x + bounds.width) - tw - 6, i32(bounds.y) + 4, 12, rl.RAYWHITE)
}

@(private)
draw_spawn_bar :: proc(ed: ^Editor, e: ^engine.Engine, w, h: f32) {
	rl.DrawRectangleRec({0, h - BOTTOM_H, w, BOTTOM_H}, {30, 30, 42, 240})
	center := rl.GetScreenToWorld2D({w / 2, h / 2}, ed.cam)
	y := h - BOTTOM_H + 8

	spawned := ~engine.EntityId(0)
	if rl.GuiButton({10, y, 70, 24}, "+ rect") {
		spawned = engine.spawn_shape(&e.scene, .Rect, center.x, center.y, 64, 64)
	}
	if rl.GuiButton({86, y, 70, 24}, "+ circle") {
		spawned = engine.spawn_shape(&e.scene, .Circle, center.x, center.y, 48, 48)
	}
	if rl.GuiButton({162, y, 70, 24}, "+ text") {
		spawned = engine.spawn_label(&e.scene, "text", center.x, center.y, 24)
	}
	if rl.GuiButton({238, y, 70, 24}, "+ sprite") {
		name := "sprite"
		for tex_name in e.assets.textures {
			name = tex_name
			break
		}
		spawned = engine.spawn_sprite(&e.scene, name, center.x, center.y)
	}
	if ent := engine.get(&e.scene, spawned); ent != nil {
		ed.selected = spawned
		refresh_buffers(ed, ent)
	}
}
