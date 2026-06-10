package gen

import "core:math/rand"
import rl "vendor:raylib"

TextureKind :: enum {
	Noise,
	Gradient,
	Checker,
	Circle,
}

TextureOpts :: struct {
	kind:   TextureKind,
	seed:   i64,
	scale:  f64, // noise feature size in pixels
	cells:  f64, // checker cell size in pixels
	horizontal: bool, // gradient direction
	color:  rl.Color,
	color2: rl.Color,
}

default_texture_opts :: proc() -> TextureOpts {
	return {scale = 16, cells = 8, color = rl.WHITE, color2 = {0, 0, 0, 255}}
}

// Caller must rl.UnloadImage (or hand it to LoadTextureFromImage and unload).
gen_texture_image :: proc(w, h: i32, opts: TextureOpts) -> rl.Image {
	img := rl.GenImageColor(w, h, rl.BLANK)
	pixels := ([^]rl.Color)(img.data)

	switch opts.kind {
	case .Noise:
		scale := max(opts.scale, 0.001)
		for y in 0 ..< h {
			for x in 0 ..< w {
				v := fbm2(opts.seed, f64(x) / scale, f64(y) / scale)
				t := clamp((v + 1) / 2, 0, 1)
				pixels[y * w + x] = lerp_color(opts.color2, opts.color, t)
			}
		}
	case .Gradient:
		for y in 0 ..< h {
			for x in 0 ..< w {
				t := opts.horizontal ? f32(x) / f32(max(w - 1, 1)) : f32(y) / f32(max(h - 1, 1))
				pixels[y * w + x] = lerp_color(opts.color, opts.color2, t)
			}
		}
	case .Checker:
		cells := max(i32(opts.cells), 1)
		for y in 0 ..< h {
			for x in 0 ..< w {
				even := ((x / cells) + (y / cells)) % 2 == 0
				pixels[y * w + x] = even ? opts.color : opts.color2
			}
		}
	case .Circle:
		cx := f32(w) / 2
		cy := f32(h) / 2
		r := min(cx, cy) - 0.5
		for y in 0 ..< h {
			for x in 0 ..< w {
				dx := f32(x) + 0.5 - cx
				dy := f32(y) + 0.5 - cy
				if dx * dx + dy * dy <= r * r {
					pixels[y * w + x] = opts.color
				}
			}
		}
	}
	return img
}

// Mirrored random pixels colored from a palette, plus a dark outline:
// instant aliens, ships, and items. Deterministic per seed.
gen_sprite_image :: proc(w, h: i32, seed: u64, palette: []rl.Color) -> rl.Image {
	state := rand.create(seed)
	context.random_generator = rand.default_random_generator(&state)

	img := rl.GenImageColor(w, h, rl.BLANK)
	pixels := ([^]rl.Color)(img.data)
	half := (w + 1) / 2

	for y in 0 ..< h {
		for x in 0 ..< half {
			edge := y == 0 || y == h - 1 || x == 0
			density: f32 = edge ? 0.3 : 0.55
			if rand.float32() < density {
				color := rl.GRAY
				if len(palette) > 0 {
					color = palette[rand.int_max(len(palette))]
				}
				pixels[y * w + x] = color
				pixels[y * w + (w - 1 - x)] = color
			}
		}
	}

	// One-pixel dark outline around filled regions.
	outline := rl.Color{20, 20, 25, 255}
	for y in 0 ..< h {
		for x in 0 ..< w {
			if pixels[y * w + x].a != 0 {
				continue
			}
			neighbor :: proc(pixels: [^]rl.Color, w, h, x, y: i32) -> bool {
				if x < 0 || x >= w || y < 0 || y >= h {
					return false
				}
				c := pixels[y * w + x]
				return c.a != 0 && c != (rl.Color{20, 20, 25, 255})
			}
			if neighbor(pixels, w, h, x - 1, y) || neighbor(pixels, w, h, x + 1, y) ||
			   neighbor(pixels, w, h, x, y - 1) || neighbor(pixels, w, h, x, y + 1) {
				pixels[y * w + x] = outline
			}
		}
	}
	return img
}

@(private)
lerp_color :: proc(a, b: rl.Color, t: f32) -> rl.Color {
	return {
		u8(f32(a.r) + (f32(b.r) - f32(a.r)) * t),
		u8(f32(a.g) + (f32(b.g) - f32(a.g)) * t),
		u8(f32(a.b) + (f32(b.b) - f32(a.b)) * t),
		u8(f32(a.a) + (f32(b.a) - f32(a.a)) * t),
	}
}
