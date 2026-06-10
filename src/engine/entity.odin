package engine

import "core:strings"
import rl "vendor:raylib"

// Low 32 bits: slot index. High 32 bits: generation. A despawn bumps the
// slot's generation, so stale ids held by scripts resolve to nil safely.
EntityId :: distinct u64

ShapeKind :: enum {
	Rect,
	Circle,
}

Sprite :: struct {
	texture:        string, // owned; key into the asset registry
	flip_x, flip_y: bool,
}

MeshRef :: struct {
	model: string, // owned; key into the asset registry
}

Shape :: struct {
	kind: ShapeKind,
	size: rl.Vector2,
}

Label :: struct {
	text: string, // owned
	size: f32,
}

Variant :: union {
	Sprite,
	MeshRef,
	Shape,
	Label,
}

Entity :: struct {
	id:      EntityId,
	name:    string, // owned
	alive:   bool,
	pos:     rl.Vector3, // 2D entities use x,y; z doubles as draw layer
	rot:     rl.Vector3, // euler degrees; 2D uses only z
	scale:   rl.Vector3,
	tint:    rl.Color,
	variant: Variant,
}

make_id :: proc(index, gen: u32) -> EntityId {
	return EntityId(u64(gen) << 32 | u64(index))
}

id_index :: proc(id: EntityId) -> u32 {
	return u32(u64(id) & 0xffff_ffff)
}

id_gen :: proc(id: EntityId) -> u32 {
	return u32(u64(id) >> 32)
}

// Default-initialized entity; callers fill in the variant and position.
entity_defaults :: proc() -> Entity {
	return {scale = {1, 1, 1}, tint = rl.WHITE}
}

// Deep copy: clones owned strings. Used by editor snapshots and duplicate.
entity_clone :: proc(ent: Entity) -> Entity {
	cloned := ent
	cloned.name = strings.clone(ent.name)
	switch v in ent.variant {
	case Sprite:
		s := v
		s.texture = strings.clone(v.texture)
		cloned.variant = s
	case MeshRef:
		m := v
		m.model = strings.clone(v.model)
		cloned.variant = m
	case Label:
		l := v
		l.text = strings.clone(v.text)
		cloned.variant = l
	case Shape:
	}
	return cloned
}

entity_free :: proc(ent: ^Entity) {
	delete(ent.name)
	ent.name = ""
	switch &v in ent.variant {
	case Sprite:
		delete(v.texture)
	case MeshRef:
		delete(v.model)
	case Label:
		delete(v.text)
	case Shape:
	}
	ent.variant = nil
}

set_label_text :: proc(ent: ^Entity, text: string) -> bool {
	label, ok := &ent.variant.(Label)
	if !ok {
		return false
	}
	delete(label.text)
	label.text = strings.clone(text)
	return true
}
