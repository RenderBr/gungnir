package gen

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

WaveKind :: enum {
	Sine,
	Square,
	Saw,
	Triangle,
	Noise,
}

SoundOpts :: struct {
	wave:   WaveKind,
	freq:   f32, // Hz
	slide:  f32, // Hz per second, applied over the duration
	len:    f32, // seconds
	attack: f32, // seconds of fade-in
	vol:    f32, // 0..1
	seed:   u64, // for the noise waveform
}

default_sound_opts :: proc() -> SoundOpts {
	return {wave = .Square, freq = 440, len = 0.15, attack = 0.005, vol = 0.8}
}

SAMPLE_RATE :: 44100

// sfxr-lite: one oscillator, linear attack, linear decay to silence.
// Sample data is allocated with rl.MemAlloc so rl.UnloadWave can free it.
gen_sound_wave :: proc(opts: SoundOpts) -> rl.Wave {
	state := rand.create(opts.seed)
	context.random_generator = rand.default_random_generator(&state)

	n := max(int(opts.len * SAMPLE_RATE), 1)
	data := ([^]i16)(rl.MemAlloc(u32(n * size_of(i16))))

	phase: f32 = 0
	for i in 0 ..< n {
		t := f32(i) / SAMPLE_RATE
		freq := max(opts.freq + opts.slide * t, 1)
		phase += freq / SAMPLE_RATE
		frac := phase - math.floor(phase)

		s: f32
		switch opts.wave {
		case .Sine:
			s = math.sin(2 * math.PI * frac)
		case .Square:
			s = frac < 0.5 ? 1 : -1
		case .Saw:
			s = 2 * frac - 1
		case .Triangle:
			s = 4 * abs(frac - 0.5) - 1
		case .Noise:
			s = rand.float32() * 2 - 1
		}

		env: f32 = 1
		if opts.attack > 0 && t < opts.attack {
			env = t / opts.attack
		}
		remain := opts.len - t
		decay := opts.len - opts.attack
		if decay > 0 && remain < decay {
			env = min(env, remain / decay)
		}

		data[i] = i16(clamp(s * env * opts.vol, -1, 1) * 32767)
	}

	return {
		frameCount = u32(n),
		sampleRate = SAMPLE_RATE,
		sampleSize = 16,
		channels   = 1,
		data       = data,
	}
}
