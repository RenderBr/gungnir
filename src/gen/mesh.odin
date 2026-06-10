package gen

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

TerrainOpts :: struct {
	seed:   i64,
	cells_w: int, // grid cells along x
	cells_d: int, // grid cells along z
	cell:   f32, // world units per cell
	height: f32, // peak amplitude in world units
	scale:  f64, // noise feature size in cells
	ridged: bool,
	colors: []rl.Color, // height ramp, low to high; empty = generated
}

default_terrain_opts :: proc() -> TerrainOpts {
	return {cells_w = 64, cells_d = 64, cell = 1, height = 8, scale = 24}
}

terrain_height :: proc(opts: TerrainOpts, x, z: f64) -> f32 {
	scale := max(opts.scale, 0.001)
	if opts.ridged {
		return ridged2(opts.seed, x / scale, z / scale) * opts.height
	}
	return (fbm2(opts.seed, x / scale, z / scale) + 1) / 2 * opts.height
}

// Hand-built heightfield mesh with per-vertex colors (palette ramp by
// height, lambert shading baked in — raylib's default material is unlit).
// Mesh arrays use rl.MemAlloc so rl.UnloadModel can free them. The mesh is
// centered on the origin in x/z.
gen_terrain_model :: proc(opts: TerrainOpts) -> rl.Model {
	opts := opts
	// u16 indices cap the grid at 65535 vertices
	opts.cells_w = clamp(opts.cells_w, 1, 254)
	opts.cells_d = clamp(opts.cells_d, 1, 254)
	palette: []rl.Color
	if len(opts.colors) > 0 {
		palette = opts.colors
	} else {
		palette = gen_palette(u64(opts.seed), 5, context.temp_allocator)
	}

	vw := opts.cells_w + 1
	vd := opts.cells_d + 1
	vert_count := vw * vd
	tri_count := opts.cells_w * opts.cells_d * 2

	mesh: rl.Mesh
	mesh.vertexCount = i32(vert_count)
	mesh.triangleCount = i32(tri_count)
	mesh.vertices = ([^]f32)(rl.MemAlloc(u32(vert_count * 3 * size_of(f32))))
	mesh.normals = ([^]f32)(rl.MemAlloc(u32(vert_count * 3 * size_of(f32))))
	mesh.colors = ([^]u8)(rl.MemAlloc(u32(vert_count * 4)))
	mesh.indices = ([^]u16)(rl.MemAlloc(u32(tri_count * 3 * size_of(u16))))

	half_w := f32(opts.cells_w) * opts.cell / 2
	half_d := f32(opts.cells_d) * opts.cell / 2
	light := linalg.normalize([3]f32{-0.5, 1, -0.3})

	for z in 0 ..< vd {
		for x in 0 ..< vw {
			i := z * vw + x
			h := terrain_height(opts, f64(x), f64(z))
			mesh.vertices[i * 3 + 0] = f32(x) * opts.cell - half_w
			mesh.vertices[i * 3 + 1] = h
			mesh.vertices[i * 3 + 2] = f32(z) * opts.cell - half_d

			// normal via central differences
			hl := terrain_height(opts, f64(x) - 1, f64(z))
			hr := terrain_height(opts, f64(x) + 1, f64(z))
			hu := terrain_height(opts, f64(x), f64(z) - 1)
			hd := terrain_height(opts, f64(x), f64(z) + 1)
			n := linalg.normalize([3]f32{hl - hr, 2 * opts.cell, hu - hd})
			mesh.normals[i * 3 + 0] = n.x
			mesh.normals[i * 3 + 1] = n.y
			mesh.normals[i * 3 + 2] = n.z

			// palette ramp by height, lambert baked in
			t := clamp(h / max(opts.height, 0.001), 0, 1)
			fi := t * f32(len(palette) - 1)
			lo := int(math.floor(fi))
			hi := min(lo + 1, len(palette) - 1)
			base := lerp_color(palette[lo], palette[hi], fi - f32(lo))
			lambert := 0.45 + 0.55 * max(linalg.dot(n, light), 0)
			mesh.colors[i * 4 + 0] = u8(f32(base.r) * lambert)
			mesh.colors[i * 4 + 1] = u8(f32(base.g) * lambert)
			mesh.colors[i * 4 + 2] = u8(f32(base.b) * lambert)
			mesh.colors[i * 4 + 3] = 255
		}
	}

	idx := 0
	for z in 0 ..< opts.cells_d {
		for x in 0 ..< opts.cells_w {
			i := u16(z * vw + x)
			mesh.indices[idx + 0] = i
			mesh.indices[idx + 1] = i + u16(vw)
			mesh.indices[idx + 2] = i + 1
			mesh.indices[idx + 3] = i + 1
			mesh.indices[idx + 4] = i + u16(vw)
			mesh.indices[idx + 5] = i + u16(vw) + 1
			idx += 6
		}
	}

	rl.UploadMesh(&mesh, false)
	return rl.LoadModelFromMesh(mesh)
}

MeshPrimitive :: enum {
	Cube,
	Sphere,
	Plane,
	Cylinder,
}

gen_primitive_model :: proc(kind: MeshPrimitive, a, b, c: f32) -> rl.Model {
	mesh: rl.Mesh
	switch kind {
	case .Cube:
		mesh = rl.GenMeshCube(a, b, c)
	case .Sphere:
		mesh = rl.GenMeshSphere(a, 16, 24)
	case .Plane:
		mesh = rl.GenMeshPlane(a, b, 4, 4)
	case .Cylinder:
		mesh = rl.GenMeshCylinder(a, b, 16)
	}
	return rl.LoadModelFromMesh(mesh)
}
