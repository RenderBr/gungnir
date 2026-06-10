package gen

import "core:math/noise"

// Fractal brownian motion over OpenSimplex2. Output roughly in [-1, 1].
fbm2 :: proc(seed: i64, x, y: f64, octaves := 4, lacunarity := 2.0, gain := 0.5) -> f32 {
	sum, amp, freq: f32 = 0, 1, 1
	norm: f32 = 0
	for i in 0 ..< octaves {
		sum += amp * noise.noise_2d(seed + i64(i), {x * f64(freq), y * f64(freq)})
		norm += amp
		amp *= f32(gain)
		freq *= f32(lacunarity)
	}
	return sum / norm
}

// Ridged multifractal: sharp creases, good for mountains. Output in [0, 1].
ridged2 :: proc(seed: i64, x, y: f64, octaves := 4, lacunarity := 2.0, gain := 0.5) -> f32 {
	sum, amp, freq: f32 = 0, 1, 1
	norm: f32 = 0
	for i in 0 ..< octaves {
		v := 1 - abs(noise.noise_2d(seed + i64(i), {x * f64(freq), y * f64(freq)}))
		sum += amp * v * v
		norm += amp
		amp *= f32(gain)
		freq *= f32(lacunarity)
	}
	return sum / norm
}

noise2 :: proc(seed: i64, x, y: f64) -> f32 {
	return noise.noise_2d(seed, {x, y})
}

noise3 :: proc(seed: i64, x, y, z: f64) -> f32 {
	return noise.noise_3d_fallback(seed, {x, y, z})
}
