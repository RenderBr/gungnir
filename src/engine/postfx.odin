package engine

import rl "vendor:raylib"

// CRT post-processing: the frame renders into a fixed logical-resolution
// canvas, then draws to the window through the shader below, aspect-fit
// with black bars. The editor bypasses it (main sets `bypass`).
Postfx :: struct {
	enabled:  bool,
	bypass:   bool,
	ready:    bool,
	rt:       rl.RenderTexture2D,
	shader:   rl.Shader,
	time_loc: i32,
	res_loc:  i32,
	w, h:     i32,
}

LOGICAL_W :: 960
LOGICAL_H :: 600

postfx_enable :: proc(e: ^Engine, on: bool) {
	e.postfx.enabled = on
	if on && !e.postfx.ready {
		e.postfx.w, e.postfx.h = LOGICAL_W, LOGICAL_H
		e.postfx.rt = rl.LoadRenderTexture(e.postfx.w, e.postfx.h)
		rl.SetTextureFilter(e.postfx.rt.texture, .BILINEAR)
		e.postfx.shader = rl.LoadShaderFromMemory(nil, CRT_FS)
		e.postfx.time_loc = rl.GetShaderLocation(e.postfx.shader, "time")
		e.postfx.res_loc = rl.GetShaderLocation(e.postfx.shader, "resolution")
		e.postfx.ready = true
	}
}

postfx_active :: proc(e: ^Engine) -> bool {
	return e.postfx.enabled && !e.postfx.bypass && e.postfx.ready
}

postfx_destroy :: proc(e: ^Engine) {
	if e.postfx.ready {
		rl.UnloadRenderTexture(e.postfx.rt)
		rl.UnloadShader(e.postfx.shader)
		e.postfx.ready = false
	}
}

// The size scripts should lay out against: the CRT canvas when active,
// otherwise the real window.
logical_size :: proc(e: ^Engine) -> (i32, i32) {
	if postfx_active(e) {
		return e.postfx.w, e.postfx.h
	}
	return rl.GetScreenWidth(), rl.GetScreenHeight()
}

// Mouse position in logical coordinates (inverts the aspect-fit mapping).
mouse_logical :: proc(e: ^Engine) -> rl.Vector2 {
	m := rl.GetMousePosition()
	if !postfx_active(e) {
		return m
	}
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	scale := min(sw / f32(e.postfx.w), sh / f32(e.postfx.h))
	ox := (sw - f32(e.postfx.w) * scale) / 2
	oy := (sh - f32(e.postfx.h) * scale) / 2
	return {(m.x - ox) / scale, (m.y - oy) / scale}
}

@(private = "file")
CRT_FS :: `#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;
uniform vec2 resolution;
out vec4 finalColor;

vec2 curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 off = abs(uv.yx) / vec2(5.5, 4.5);
    uv = uv + uv * off * off;
    return uv * 0.5 + 0.5;
}

void main() {
    vec2 uv = curve(fragTexCoord);
    vec3 col = vec3(0.0);
    if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
        // slight chromatic aberration
        float ca = 0.0012;
        col.r = texture(texture0, uv + vec2(ca, 0.0)).r;
        col.g = texture(texture0, uv).g;
        col.b = texture(texture0, uv - vec2(ca, 0.0)).b;

        // phosphor glow: cheap neighbor bleed
        vec3 blur = texture(texture0, uv + vec2(0.0,  1.5 / resolution.y)).rgb
                  + texture(texture0, uv - vec2(0.0,  1.5 / resolution.y)).rgb
                  + texture(texture0, uv + vec2(1.5 / resolution.x, 0.0)).rgb
                  + texture(texture0, uv - vec2(1.5 / resolution.x, 0.0)).rgb;
        col += blur * 0.07;

        // scanlines
        float sl = 0.80 + 0.20 * sin(uv.y * resolution.y * 3.14159265);
        col *= sl;

        // aperture grille
        float m = mod(gl_FragCoord.x, 3.0);
        vec3 mask = (m < 1.0) ? vec3(1.07, 0.95, 0.95)
                  : (m < 2.0) ? vec3(0.95, 1.07, 0.95)
                              : vec3(0.95, 0.95, 1.07);
        col *= mask;

        // vignette + curved-corner falloff
        float vig = pow(16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y), 0.3);
        col *= vig;

        // 60hz flicker
        col *= 0.985 + 0.015 * sin(time * 120.0);

        col *= 1.25; // brightness compensation
    }
    finalColor = vec4(col, 1.0) * colDiffuse * fragColor;
}
`
