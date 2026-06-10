package gen

import "core:fmt"
import "core:math/rand"
import "core:strconv"
import rl "vendor:raylib"

// Seeded color scheme: a base hue with analogous spread and varied
// value/saturation, dark to light. Caller owns the slice.
gen_palette :: proc(seed: u64, n: int, allocator := context.allocator) -> []rl.Color {
	state := rand.create(seed)
	context.random_generator = rand.default_random_generator(&state)

	colors := make([]rl.Color, n, allocator)
	base_hue := rand.float32() * 360
	hue_spread := 20 + rand.float32() * 50
	for i in 0 ..< n {
		t := n > 1 ? f32(i) / f32(n - 1) : 0.5
		hue := base_hue + (t - 0.5) * hue_spread + (rand.float32() - 0.5) * 10
		hue = abs(f32(int(hue) %% 360))
		sat := 0.5 + 0.4 * (1 - abs(t - 0.5) * 2) + (rand.float32() - 0.5) * 0.1
		val := 0.25 + 0.7 * t
		colors[i] = rl.ColorFromHSV(hue, clamp(sat, 0, 1), clamp(val, 0, 1))
	}
	return colors
}

// "#rrggbb" or "#rrggbbaa" (leading # optional) -> color. White on parse failure.
parse_hex_color :: proc(s: string) -> rl.Color {
	hex := s
	if len(hex) > 0 && hex[0] == '#' {
		hex = hex[1:]
	}
	if len(hex) != 6 && len(hex) != 8 {
		return rl.WHITE
	}
	v, ok := strconv.parse_u64_of_base(hex, 16)
	if !ok {
		return rl.WHITE
	}
	if len(hex) == 6 {
		return {u8(v >> 16), u8(v >> 8), u8(v), 255}
	}
	return {u8(v >> 24), u8(v >> 16), u8(v >> 8), u8(v)}
}

color_to_hex :: proc(c: rl.Color, allocator := context.allocator) -> string {
	if c.a == 255 {
		return fmt.aprintf("#%02x%02x%02x", c.r, c.g, c.b, allocator = allocator)
	}
	return fmt.aprintf("#%02x%02x%02x%02x", c.r, c.g, c.b, c.a, allocator = allocator)
}
