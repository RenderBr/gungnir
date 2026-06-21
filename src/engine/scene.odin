package engine

import "core:strings"
import rl "vendor:raylib"

Scene :: struct {
	entities:   [dynamic]Entity,
	free_slots: [dynamic]u32,
}

spawn :: proc(s: ^Scene, e: Entity) -> EntityId {
	e := e
	index, gen: u32
	if len(s.free_slots) > 0 {
		index = pop(&s.free_slots)
		gen = id_gen(s.entities[index].id) // bumped at despawn
	} else {
		index = u32(len(s.entities))
		append(&s.entities, Entity{})
		gen = 1
	}
	e.id = make_id(index, gen)
	e.alive = true
	s.entities[index] = e
	return e.id
}

get :: proc(s: ^Scene, id: EntityId) -> ^Entity {
	index := id_index(id)
	if int(index) >= len(s.entities) {
		return nil
	}
	ent := &s.entities[index]
	if !ent.alive || ent.id != id {
		return nil
	}
	return ent
}

despawn :: proc(s: ^Scene, id: EntityId) {
	ent := get(s, id)
	if ent == nil {
		return
	}
	entity_free(ent)
	ent.alive = false
	ent.id = make_id(id_index(id), id_gen(id) + 1)
	append(&s.free_slots, id_index(id))
}

find_by_name :: proc(s: ^Scene, name: string) -> (EntityId, bool) {
	for &ent in s.entities {
		if ent.alive && ent.name == name {
			return ent.id, true
		}
	}
	return {}, false
}

clear_scene :: proc(s: ^Scene) {
	for &ent in s.entities {
		if ent.alive {
			entity_free(&ent)
			ent.alive = false
		}
	}
	clear(&s.entities)
	clear(&s.free_slots)
}

alive_count :: proc(s: ^Scene) -> int {
	n: int
	for ent in s.entities {
		if ent.alive {
			n += 1
		}
	}
	return n
}

scene_destroy :: proc(s: ^Scene) {
	clear_scene(s)
	delete(s.entities)
	delete(s.free_slots)
}

// -- convenience constructors (used by the script API and the editor) -------

spawn_sprite :: proc(s: ^Scene, texture: string, x, y: f32) -> EntityId {
	e := entity_defaults()
	e.pos = {x, y, 0}
	e.variant = Sprite{texture = strings.clone(texture)}
	return spawn(s, e)
}

spawn_shape :: proc(s: ^Scene, kind: ShapeKind, x, y, w, h: f32) -> EntityId {
	e := entity_defaults()
	e.pos = {x, y, 0}
	e.variant = Shape{kind = kind, size = {w, h}}
	return spawn(s, e)
}

spawn_label :: proc(s: ^Scene, text: string, x, y, size: f32) -> EntityId {
	e := entity_defaults()
	e.pos = {x, y, 0}
	e.variant = Label{text = strings.clone(text), size = size}
	return spawn(s, e)
}

spawn_mesh :: proc(s: ^Scene, model: string, x, y, z: f32) -> EntityId {
	e := entity_defaults()
	e.pos = {x, y, z}
	e.variant = MeshRef{model = strings.clone(model)}
	return spawn(s, e)
}

spawn_light :: proc(s: ^Scene, x, y, z: f32) -> EntityId {
	e := entity_defaults()
	e.pos = {x, y, z}
	e.variant = Light{kind = .Point, radius = 160, intensity = 1}
	return spawn(s, e)
}

_ :: rl
