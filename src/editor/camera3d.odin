package editor

import "core:math"
import rl "vendor:raylib"
import "../engine"

// Orbit edit camera: right-drag orbits, shift+right-drag pans the target
// on XZ, wheel dollies. Kept separate from the game's cam3d.
Orbit :: struct {
	target: rl.Vector3,
	yaw:    f32, // radians
	pitch:  f32,
	dist:   f32,
}

orbit_defaults :: proc() -> Orbit {
	return {yaw = -math.PI / 4, pitch = 0.6, dist = 90}
}

orbit_camera :: proc(o: Orbit) -> rl.Camera3D {
	cp := math.cos(o.pitch)
	dir := rl.Vector3{math.cos(o.yaw) * cp, math.sin(o.pitch), math.sin(o.yaw) * cp}
	return {
		position   = o.target + dir * o.dist,
		target     = o.target,
		up         = {0, 1, 0},
		fovy       = 60,
		projection = .PERSPECTIVE,
	}
}

orbit_update :: proc(o: ^Orbit, over_ui: bool) {
	if rl.IsMouseButtonDown(.RIGHT) || rl.IsMouseButtonDown(.MIDDLE) {
		delta := rl.GetMouseDelta()
		shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsMouseButtonDown(.MIDDLE)
		if shift {
			// pan on XZ relative to view yaw
			fx := math.cos(o.yaw)
			fz := math.sin(o.yaw)
			pan := o.dist * 0.0016
			o.target.x += (-delta.x * -fz + delta.y * fx) * pan
			o.target.z += (-delta.x * fx + delta.y * fz) * pan
		} else {
			o.yaw += delta.x * 0.005
			o.pitch = clamp(o.pitch + delta.y * 0.005, -1.4, 1.5)
		}
	}
	if wheel := rl.GetMouseWheelMove(); wheel != 0 && !over_ui {
		o.dist = clamp(o.dist * (1 - wheel * 0.1), 2, 600)
	}
}

entity_box :: proc(e: ^engine.Engine, ent: ^engine.Entity) -> rl.BoundingBox {
	mref, is_mesh := ent.variant.(engine.MeshRef)
	if !is_mesh {
		return {ent.pos - 0.5, ent.pos + 0.5}
	}
	mdl, ok := engine.get_model(e, mref.model)
	if !ok {
		return {ent.pos - 1, ent.pos + 1}
	}
	box := rl.GetModelBoundingBox(mdl)
	return {
		min = ent.pos + box.min * ent.scale,
		max = ent.pos + box.max * ent.scale,
	}
}

// Nearest mesh or light entity under the cursor.
pick_3d :: proc(e: ^engine.Engine, cam: rl.Camera3D, mouse: rl.Vector2) -> engine.EntityId {
	ray := rl.GetScreenToWorldRay(mouse, cam)
	best := ~engine.EntityId(0)
	best_dist := max(f32)
	for &ent in e.scene.entities {
		if !ent.alive {
			continue
		}
		#partial switch _ in ent.variant {
		case engine.MeshRef, engine.Light:
		case:
			continue
		}
		hit := rl.GetRayCollisionBox(ray, entity_box(e, &ent))
		if hit.hit && hit.distance < best_dist {
			best = ent.id
			best_dist = hit.distance
		}
	}
	return best
}

// Where the cursor ray crosses the horizontal plane y=plane_y.
ray_on_plane_y :: proc(cam: rl.Camera3D, mouse: rl.Vector2, plane_y: f32) -> (rl.Vector3, bool) {
	ray := rl.GetScreenToWorldRay(mouse, cam)
	if abs(ray.direction.y) < 0.0001 {
		return {}, false
	}
	t := (plane_y - ray.position.y) / ray.direction.y
	if t < 0 {
		return {}, false
	}
	return ray.position + ray.direction * t, true
}

// Edit-mode interaction for the 3D view: orbit, pick, drag on XZ.
update_3d :: proc(ed: ^Editor, e: ^engine.Engine) {
	mouse := rl.GetMousePosition()
	over_ui := ui_blocks_mouse(mouse)
	cam := orbit_camera(ed.orbit)

	orbit_update(&ed.orbit, over_ui)

	if rl.IsMouseButtonPressed(.LEFT) && !over_ui && ed.drag_num_id == -1 {
		ed.selected = pick_3d(e, cam, mouse)
		if ent := engine.get(&e.scene, ed.selected); ent != nil {
			if hit, ok := ray_on_plane_y(cam, mouse, ent.pos.y); ok {
				ed.dragging = true
				ed.drag_grab = {hit.x - ent.pos.x, hit.z - ent.pos.z}
				refresh_buffers(ed, ent)
			}
		}
	}
	if ed.dragging {
		if ent := engine.get(&e.scene, ed.selected); ent != nil {
			if hit, ok := ray_on_plane_y(cam, mouse, ent.pos.y); ok {
				x := hit.x - ed.drag_grab.x
				z := hit.z - ed.drag_grab.y
				if ed.snap && ed.grid > 0 {
					x = f32(int(x / ed.grid + 0.5)) * ed.grid
					z = f32(int(z / ed.grid + 0.5)) * ed.grid
				}
				ent.pos.x = x
				ent.pos.z = z
			}
		}
		if rl.IsMouseButtonReleased(.LEFT) {
			ed.dragging = false
		}
	}
}

// Grid and selection box. Runs inside the 3D pass while editing in 3D view.
draw_world_3d :: proc(ed: ^Editor, e: ^engine.Engine) {
	rl.DrawGrid(64, 8)
	for &ent in e.scene.entities {
		if !ent.alive {
			continue
		}
		if _, is_light := ent.variant.(engine.Light); is_light {
			rl.DrawSphereWires(ent.pos, 1, 6, 6, ent.tint)
		}
	}
	if ent := engine.get(&e.scene, ed.selected); ent != nil {
		if _, is_mesh := ent.variant.(engine.MeshRef); is_mesh {
			rl.DrawBoundingBox(entity_box(e, ent), rl.GOLD)
		}
	}
}
