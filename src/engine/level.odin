package engine

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"
import "../gen"

// Flat DTOs for level.json — the union and rl types stay out of the file
// format. Generated assets are stored as recipes and regenerated on load.

LevelEntityDTO :: struct {
	kind:      string, // "sprite" | "rect" | "circle" | "label" | "mesh"
	name:      string,
	ref:       string, // texture/model name, or label text
	pos:       [3]f32,
	rot:       [3]f32,
	scale:     [3]f32,
	tint:      string, // hex
	size:      [2]f32, // shapes
	text_size: f32,    // labels
}

RecipeDTO :: struct {
	name:    string,
	kind:    string,
	variant: string,
	seed:    i64,
	w, h:    i32,
	params:  map[string]f64,
	colors:  []string,
	rows:    []string,
}

LevelDTO :: struct {
	name:        string,
	clear_color: string,
	assets:      []RecipeDTO,
	entities:    []LevelEntityDTO,
}

level_path :: proc(e: ^Engine, allocator := context.allocator) -> string {
	return fmt.aprintf("%s/level.json", e.game_dir, allocator = allocator)
}

// Serializes recipes + alive entities. Uses temp allocator for the DTO; the
// written file is the output.
save_level :: proc(e: ^Engine, path: string) -> bool {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	dto: LevelDTO
	dto.name = "level"
	dto.clear_color = gen.color_to_hex(e.clear_color)

	recipes := make([dynamic]RecipeDTO)
	for _, r in e.assets.recipes {
		colors := make([]string, len(r.colors))
		for color, i in r.colors {
			colors[i] = gen.color_to_hex(color)
		}
		append(&recipes, RecipeDTO{
			name = r.name, kind = r.kind, variant = r.variant,
			seed = r.seed, w = r.w, h = r.h,
			params = r.params, colors = colors, rows = r.rows[:],
		})
	}
	dto.assets = recipes[:]

	ents := make([dynamic]LevelEntityDTO)
	for &ent in e.scene.entities {
		if !ent.alive {
			continue
		}
		d := LevelEntityDTO{
			name  = ent.name,
			pos   = {ent.pos.x, ent.pos.y, ent.pos.z},
			rot   = {ent.rot.x, ent.rot.y, ent.rot.z},
			scale = {ent.scale.x, ent.scale.y, ent.scale.z},
			tint  = gen.color_to_hex(ent.tint),
		}
		switch v in ent.variant {
		case Sprite:
			d.kind = "sprite"
			d.ref = v.texture
		case Shape:
			d.kind = v.kind == .Circle ? "circle" : "rect"
			d.size = {v.size.x, v.size.y}
		case Label:
			d.kind = "label"
			d.ref = v.text
			d.text_size = v.size
		case MeshRef:
			d.kind = "mesh"
			d.ref = v.model
		}
		append(&ents, d)
	}
	dto.entities = ents[:]

	data, err := json.marshal(dto, {pretty = true})
	if err != nil {
		fmt.eprintln("save_level: marshal failed:", err)
		return false
	}
	return os.write_entire_file(path, data) == nil
}

// Clears the scene, regenerates recipe assets, spawns entities.
load_level :: proc(e: ^Engine, path: string) -> bool {
	data, rerr := os.read_entire_file(path, context.temp_allocator)
	if rerr != nil {
		return false
	}

	dto: LevelDTO
	if err := json.unmarshal(data, &dto, allocator = context.temp_allocator); err != nil {
		fmt.eprintln("load_level: bad json:", err)
		return false
	}

	clear_scene(&e.scene)
	if dto.clear_color != "" {
		e.clear_color = gen.parse_hex_color(dto.clear_color)
	}

	for rd in dto.assets {
		r: GenRecipe
		r.name = strings.clone(rd.name)
		r.kind = strings.clone(rd.kind)
		r.variant = strings.clone(rd.variant)
		r.seed = rd.seed
		r.w, r.h = rd.w, rd.h
		for key, v in rd.params {
			r.params[strings.clone(key)] = v
		}
		for hex in rd.colors {
			append(&r.colors, gen.parse_hex_color(hex))
		}
		for row in rd.rows {
			append(&r.rows, strings.clone(row))
		}
		apply_recipe(e, r)
	}

	for d in dto.entities {
		ent := entity_defaults()
		ent.name = strings.clone(d.name)
		ent.pos = {d.pos.x, d.pos.y, d.pos.z}
		ent.rot = {d.rot.x, d.rot.y, d.rot.z}
		if d.scale != {} {
			ent.scale = {d.scale.x, d.scale.y, d.scale.z}
		}
		if d.tint != "" {
			ent.tint = gen.parse_hex_color(d.tint)
		}
		switch d.kind {
		case "sprite":
			ent.variant = Sprite{texture = strings.clone(d.ref)}
		case "rect":
			ent.variant = Shape{kind = .Rect, size = {d.size.x, d.size.y}}
		case "circle":
			ent.variant = Shape{kind = .Circle, size = {d.size.x, d.size.y}}
		case "label":
			ent.variant = Label{text = strings.clone(d.ref), size = d.text_size > 0 ? d.text_size : 20}
		case "mesh":
			ent.variant = MeshRef{model = strings.clone(d.ref)}
		case:
			continue
		}
		spawn(&e.scene, ent)
	}

	free_all(context.temp_allocator)
	return true
}

// Loads <game_dir>/level.json when present. Returns whether a level loaded.
load_default_level :: proc(e: ^Engine) -> bool {
	path := level_path(e, context.temp_allocator)
	if !os.exists(path) {
		return false
	}
	return load_level(e, path)
}

_ :: rl
