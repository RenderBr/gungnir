package editor

import "core:strings"
import rl "vendor:raylib"
import "../engine"
import "../script"

GRID_DEFAULT :: 8

Editor :: struct {
	enabled: bool, // editor UI present (launched --editor or F1)
	playing: bool, // false = edit mode
	cam:     rl.Camera2D,

	selected: engine.EntityId,
	dragging: bool,
	drag_grab: rl.Vector2, // world offset from entity pos at grab

	snap: bool,
	grid: f32,

	snapshot:     [dynamic]engine.Entity,
	has_snapshot: bool,

	// panel state (inspector.odin)
	hierarchy_scroll: i32,
	drag_num_id:      int, // active drag-number widget, -1 = none
	drag_num_start:   f32,
	drag_num_value:   f32,
	name_edit:        bool,
	name_buf:         [64]u8,
	text_edit:        bool,
	text_buf:         [128]u8,
	tex_edit:         bool,
	tex_buf:          [64]u8,
	status:           string, // static literals only
	status_timer:     f32,
}

init :: proc(ed: ^Editor, enabled: bool) {
	ed.enabled = enabled
	ed.playing = false
	ed.cam = {zoom = 1}
	ed.grid = GRID_DEFAULT
	ed.snap = true
	ed.drag_num_id = -1
	ed.selected = ~engine.EntityId(0)
}

destroy :: proc(ed: ^Editor) {
	drop_snapshot(ed)
}

set_status :: proc(ed: ^Editor, msg: string) {
	ed.status = msg
	ed.status_timer = 3
}

// -- play/stop ---------------------------------------------------------------

take_snapshot :: proc(ed: ^Editor, e: ^engine.Engine) {
	drop_snapshot(ed)
	for &ent in e.scene.entities {
		if ent.alive {
			append(&ed.snapshot, engine.entity_clone(ent))
		}
	}
	ed.has_snapshot = true
}

restore_snapshot :: proc(ed: ^Editor, e: ^engine.Engine) {
	if !ed.has_snapshot {
		return
	}
	engine.clear_scene(&e.scene)
	for ent in ed.snapshot {
		engine.spawn(&e.scene, ent) // transfers string ownership to scene
	}
	clear(&ed.snapshot)
	ed.has_snapshot = false
	ed.selected = ~engine.EntityId(0)
}

drop_snapshot :: proc(ed: ^Editor) {
	for &ent in ed.snapshot {
		engine.entity_free(&ent)
	}
	clear(&ed.snapshot)
	ed.has_snapshot = false
}

// Play: snapshot the authored scene, then run the script fresh on top of it.
enter_play :: proc(ed: ^Editor, e: ^engine.Engine, s: ^script.Script) {
	take_snapshot(ed, e)
	script.play_start(s)
	ed.playing = true
	ed.selected = ~engine.EntityId(0)
}

// Stop: the authored scene comes back exactly as it was.
enter_edit :: proc(ed: ^Editor, e: ^engine.Engine, s: ^script.Script) {
	restore_snapshot(ed, e)
	ed.playing = false
}

toggle_play :: proc(ed: ^Editor, e: ^engine.Engine, s: ^script.Script) {
	if ed.playing {
		enter_edit(ed, e, s)
	} else {
		enter_play(ed, e, s)
	}
}

// -- edit-mode update ---------------------------------------------------------

update :: proc(ed: ^Editor, e: ^engine.Engine, dt: f32) {
	ed.status_timer = max(0, ed.status_timer - dt)

	mouse := rl.GetMousePosition()
	over_ui := ui_blocks_mouse(mouse)
	editing_text := ed.name_edit || ed.text_edit || ed.tex_edit

	// camera: right/middle drag pans, wheel zooms around the cursor
	if rl.IsMouseButtonDown(.RIGHT) || rl.IsMouseButtonDown(.MIDDLE) {
		delta := rl.GetMouseDelta()
		ed.cam.target -= delta / ed.cam.zoom
	}
	if wheel := rl.GetMouseWheelMove(); wheel != 0 && !over_ui {
		before := rl.GetScreenToWorld2D(mouse, ed.cam)
		ed.cam.zoom = clamp(ed.cam.zoom * (1 + wheel * 0.1), 0.1, 10)
		after := rl.GetScreenToWorld2D(mouse, ed.cam)
		ed.cam.target += before - after
	}

	// picking + dragging
	world := rl.GetScreenToWorld2D(mouse, ed.cam)
	if rl.IsMouseButtonPressed(.LEFT) && !over_ui && ed.drag_num_id == -1 {
		ed.selected = pick(e, world)
		if ent := engine.get(&e.scene, ed.selected); ent != nil {
			ed.dragging = true
			ed.drag_grab = {world.x - ent.pos.x, world.y - ent.pos.y}
			refresh_buffers(ed, ent)
		}
	}
	if ed.dragging {
		if ent := engine.get(&e.scene, ed.selected); ent != nil {
			x := world.x - ed.drag_grab.x
			y := world.y - ed.drag_grab.y
			if ed.snap && ed.grid > 0 {
				x = f32(int(x / ed.grid + 0.5)) * ed.grid
				y = f32(int(y / ed.grid + 0.5)) * ed.grid
			}
			ent.pos.x = x
			ent.pos.y = y
		}
		if rl.IsMouseButtonReleased(.LEFT) {
			ed.dragging = false
		}
	}

	// shortcuts (suppressed while a textbox is being edited)
	if !editing_text {
		if rl.IsKeyPressed(.BACKSPACE) || rl.IsKeyPressed(.DELETE) {
			if engine.get(&e.scene, ed.selected) != nil {
				engine.despawn(&e.scene, ed.selected)
				ed.selected = ~engine.EntityId(0)
			}
		}
		super := rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER)
		if super && rl.IsKeyPressed(.D) {
			if ent := engine.get(&e.scene, ed.selected); ent != nil {
				dup := engine.entity_clone(ent^)
				dup.pos.x += 16
				dup.pos.y += 16
				ed.selected = engine.spawn(&e.scene, dup)
			}
		}
		if super && rl.IsKeyPressed(.S) {
			save(ed, e)
		}
	}
}

save :: proc(ed: ^Editor, e: ^engine.Engine) {
	path := engine.level_path(e, context.temp_allocator)
	if engine.save_level(e, path) {
		set_status(ed, "saved level.json")
	} else {
		set_status(ed, "save FAILED")
	}
}

// Topmost hit: highest pos.z wins, ties go to the most recently spawned.
pick :: proc(e: ^engine.Engine, world: rl.Vector2) -> engine.EntityId {
	best := ~engine.EntityId(0)
	best_z := min(f32)
	for &ent in e.scene.entities {
		if !ent.alive {
			continue
		}
		if _, is_mesh := ent.variant.(engine.MeshRef); is_mesh {
			continue // 3D picking lands in phase 6
		}
		if rl.CheckCollisionPointRec(world, entity_bounds(e, &ent)) && ent.pos.z >= best_z {
			best = ent.id
			best_z = ent.pos.z
		}
	}
	return best
}

// Screen-space 2D bounds used for picking and the selection outline.
entity_bounds :: proc(e: ^engine.Engine, ent: ^engine.Entity) -> rl.Rectangle {
	switch v in ent.variant {
	case engine.Sprite:
		tex := engine.get_texture(e, v.texture)
		w := f32(tex.width) * abs(ent.scale.x)
		h := f32(tex.height) * abs(ent.scale.y)
		return {ent.pos.x - w / 2, ent.pos.y - h / 2, w, h}
	case engine.Shape:
		w := v.size.x * abs(ent.scale.x)
		h := v.size.y * abs(ent.scale.y)
		if v.kind == .Circle {
			h = w
		}
		return {ent.pos.x - w / 2, ent.pos.y - h / 2, w, h}
	case engine.Label:
		text := strings.clone_to_cstring(v.text, context.temp_allocator)
		w := f32(rl.MeasureText(text, i32(v.size)))
		return {ent.pos.x, ent.pos.y, max(w, 20), v.size}
	case engine.MeshRef:
	}
	return {ent.pos.x - 8, ent.pos.y - 8, 16, 16}
}

// Grid, origin axes, and the selection outline. Runs inside the 2D pass.
draw_world :: proc(ed: ^Editor, e: ^engine.Engine) {
	draw_grid_2d(ed)
	if ent := engine.get(&e.scene, ed.selected); ent != nil {
		b := entity_bounds(e, ent)
		rl.DrawRectangleLinesEx({b.x - 2, b.y - 2, b.width + 4, b.height + 4}, 1.5 / ed.cam.zoom, rl.GOLD)
	}
}

@(private)
draw_grid_2d :: proc(ed: ^Editor) {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	top_left := rl.GetScreenToWorld2D({0, 0}, ed.cam)
	bottom_right := rl.GetScreenToWorld2D({w, h}, ed.cam)

	step: f32 = 64
	for step * ed.cam.zoom < 24 {
		step *= 4
	}
	color := rl.Color{255, 255, 255, 18}
	x := f32(int(top_left.x / step)) * step
	for ; x < bottom_right.x; x += step {
		rl.DrawLineV({x, top_left.y}, {x, bottom_right.y}, color)
	}
	y := f32(int(top_left.y / step)) * step
	for ; y < bottom_right.y; y += step {
		rl.DrawLineV({top_left.x, y}, {bottom_right.x, y}, color)
	}
	axis := rl.Color{120, 160, 255, 80}
	rl.DrawLineV({0, top_left.y}, {0, bottom_right.y}, axis)
	rl.DrawLineV({top_left.x, 0}, {bottom_right.x, 0}, axis)
}
