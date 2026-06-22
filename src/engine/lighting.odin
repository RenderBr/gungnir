package engine

import "core:math"
import rl "vendor:raylib"

// Realtime lighting. 2D: lights accumulate additively into a lightmap RT
// (cleared to ambient) which multiplies over the world passes. 3D: a Lambert
// shader with uniform arrays is assigned to model materials each frame.
// All GPU resources load lazily on first lighting_enable(true).

MAX_LIGHTS :: 8
MAX_INTENSITY :: 4 // 2D overdraw cap; >1 stacks additive passes
FALLOFF_RES :: 256

Lighting :: struct {
	enabled:        bool,
	ready:          bool, // shader3d, falloff, default_shader loaded
	ambient:        rl.Color,
	falloff:        rl.Texture2D, // radial gradient, white rgb, quadratic alpha
	lightmap:       rl.RenderTexture2D,
	ready2d:        bool,
	lm_w, lm_h:     i32,
	shader3d:       rl.Shader,
	default_shader: rl.Shader, // raylib default, for restoring materials
	loc_count:      i32,
	loc_ambient:    i32,
	loc_pos:        i32,
	loc_color:      i32,
	loc_radius:     i32,
	loc_view_pos:   i32,
	loc_fog_color:  i32,
}

lighting_enable :: proc(e: ^Engine, on: bool) {
	lt := &e.lighting
	lt.enabled = on
	if on && !lt.ready {
		img := gen_falloff_image(FALLOFF_RES)
		lt.falloff = rl.LoadTextureFromImage(img)
		rl.UnloadImage(img)
		rl.SetTextureFilter(lt.falloff, .BILINEAR)

		lt.shader3d = rl.LoadShaderFromMemory(LIT_VS, LIT_FS)
		lt.loc_count = rl.GetShaderLocation(lt.shader3d, "lightCount")
		lt.loc_ambient = rl.GetShaderLocation(lt.shader3d, "ambient")
		lt.loc_pos = rl.GetShaderLocation(lt.shader3d, "lightPos")
		lt.loc_color = rl.GetShaderLocation(lt.shader3d, "lightColor")
		lt.loc_radius = rl.GetShaderLocation(lt.shader3d, "lightRadius")
		lt.loc_view_pos = rl.GetShaderLocation(lt.shader3d, "viewPos")
		lt.loc_fog_color = rl.GetShaderLocation(lt.shader3d, "fogColor")

		// UnloadMaterial skips the raylib-managed default shader; only maps free.
		tmp := rl.LoadMaterialDefault()
		lt.default_shader = tmp.shader
		rl.UnloadMaterial(tmp)
		lt.ready = true
	}
}

lighting_active :: proc(e: ^Engine) -> bool {
	return e.lighting.enabled && e.lighting.ready
}

lighting_destroy :: proc(e: ^Engine) {
	lt := &e.lighting
	if lt.ready {
		rl.UnloadShader(lt.shader3d)
		rl.UnloadTexture(lt.falloff)
		lt.ready = false
	}
	if lt.ready2d {
		rl.UnloadRenderTexture(lt.lightmap)
		lt.ready2d = false
	}
}

// Lightmap tracks logical_size: render resolution when postfx is active,
// window size otherwise (recreated on resize and on editor enter/exit,
// which flips postfx bypass).
@(private = "file")
lighting_ensure_2d :: proc(e: ^Engine) {
	w, h := logical_size(e)
	lt := &e.lighting
	if lt.ready2d && lt.lm_w == w && lt.lm_h == h {
		return
	}
	if lt.ready2d {
		rl.UnloadRenderTexture(lt.lightmap)
	}
	lt.lightmap = rl.LoadRenderTexture(w, h)
	rl.SetTextureFilter(lt.lightmap.texture, .BILINEAR)
	lt.lm_w, lt.lm_h = w, h
	lt.ready2d = true
}

// Renders ambient + lights into the lightmap. MUST run outside any other
// texture mode — main calls it immediately before begin_frame, because
// begin_frame may open the postfx RT and texture modes cannot nest.
// `cam` is whichever camera the 2D pass will use (game cam2d or editor cam),
// so lights track the 2D camera transform exactly.
lighting_render_lightmap :: proc(e: ^Engine, cam: rl.Camera2D) {
	if !lighting_active(e) {
		return
	}
	lighting_ensure_2d(e)
	lt := &e.lighting
	rl.BeginTextureMode(lt.lightmap)
	rl.ClearBackground({lt.ambient.r, lt.ambient.g, lt.ambient.b, 255})
	rl.BeginBlendMode(.ADDITIVE)

	// directional lights: uniform wash, camera-independent (screen space)
	for &ent in e.scene.entities {
		if !ent.alive {
			continue
		}
		l, is_light := ent.variant.(Light)
		if !is_light || l.kind != .Directional {
			continue
		}
		rem := clamp(l.intensity, 0, MAX_INTENSITY)
		for rem > 0 {
			rl.DrawRectangle(0, 0, lt.lm_w, lt.lm_h, scale_rgb(ent.tint, min(rem, 1)))
			rem -= 1
		}
	}

	rl.BeginMode2D(cam)
	for &ent in e.scene.entities {
		if !ent.alive {
			continue
		}
		l, is_light := ent.variant.(Light)
		if !is_light || l.kind != .Point {
			continue
		}
		r := max(l.radius, 1)
		dst := rl.Rectangle{ent.pos.x, ent.pos.y, r * 2, r * 2}
		rem := clamp(l.intensity, 0, MAX_INTENSITY)
		for rem > 0 {
			rl.DrawTexturePro(lt.falloff, {0, 0, FALLOFF_RES, FALLOFF_RES},
				dst, {r, r}, 0, scale_rgb(ent.tint, min(rem, 1)))
			rem -= 1
		}
	}
	rl.EndMode2D()
	rl.EndBlendMode()
	rl.EndTextureMode()
}

// Multiplies the lightmap over everything drawn so far (the world passes).
// Call in screen space, after end_2d and before on_gui — HUD stays unlit.
lighting_composite_2d :: proc(e: ^Engine) {
	if !lighting_active(e) || !e.lighting.ready2d {
		return
	}
	lt := &e.lighting
	rl.BeginBlendMode(.MULTIPLIED)
	rl.DrawTexturePro(
		lt.lightmap.texture,
		{0, 0, f32(lt.lm_w), -f32(lt.lm_h)}, // RT is vertically flipped
		{0, 0, f32(lt.lm_w), f32(lt.lm_h)},
		{}, 0, rl.WHITE,
	)
	rl.EndBlendMode()
}

// Uploads the light uniform arrays. Called from draw_entities_3d so both the
// game camera path and the editor orbit path are covered (Lambert needs no
// view position). First MAX_LIGHTS lights in scene order win.
lighting_upload_3d :: proc(e: ^Engine) {
	lt := &e.lighting
	pos: [MAX_LIGHTS][4]f32 // xyz + w (1 = point, 0 = directional: xyz is dir)
	col: [MAX_LIGHTS][3]f32 // intensity premultiplied
	rad: [MAX_LIGHTS]f32
	count: i32
	for &ent in e.scene.entities {
		if count >= MAX_LIGHTS {
			break
		}
		if !ent.alive {
			continue
		}
		l, is_light := ent.variant.(Light)
		if !is_light {
			continue
		}
		switch l.kind {
		case .Point:
			pos[count] = {ent.pos.x, ent.pos.y, ent.pos.z, 1}
		case .Directional:
			d := light_direction(ent.rot)
			pos[count] = {d.x, d.y, d.z, 0}
		}
		i := max(l.intensity, 0)
		col[count] = {f32(ent.tint.r) / 255 * i, f32(ent.tint.g) / 255 * i, f32(ent.tint.b) / 255 * i}
		rad[count] = max(l.radius, 0.001)
		count += 1
	}
	rl.SetShaderValue(lt.shader3d, rl.ShaderLocationIndex(lt.loc_count), &count, .INT)
	amb := [3]f32{f32(lt.ambient.r) / 255, f32(lt.ambient.g) / 255, f32(lt.ambient.b) / 255}
	rl.SetShaderValue(lt.shader3d, rl.ShaderLocationIndex(lt.loc_ambient), &amb, .VEC3)
	view := [3]f32{e.cam3d.position.x, e.cam3d.position.y, e.cam3d.position.z}
	fog := [3]f32{f32(e.clear_color.r) / 255, f32(e.clear_color.g) / 255, f32(e.clear_color.b) / 255}
	rl.SetShaderValue(lt.shader3d, rl.ShaderLocationIndex(lt.loc_view_pos), &view, .VEC3)
	rl.SetShaderValue(lt.shader3d, rl.ShaderLocationIndex(lt.loc_fog_color), &fog, .VEC3)
	if count > 0 {
		rl.SetShaderValueV(lt.shader3d, rl.ShaderLocationIndex(lt.loc_pos), raw_data(pos[:]), .VEC4, count)
		rl.SetShaderValueV(lt.shader3d, rl.ShaderLocationIndex(lt.loc_color), raw_data(col[:]), .VEC3, count)
		rl.SetShaderValueV(lt.shader3d, rl.ShaderLocationIndex(lt.loc_radius), raw_data(rad[:]), .FLOAT, count)
	}
}

// Directional aim: entity rot (euler degrees) applied to straight-down.
light_direction :: proc(rot: rl.Vector3) -> rl.Vector3 {
	m := rl.MatrixRotateXYZ({rot.x * rl.DEG2RAD, rot.y * rl.DEG2RAD, rot.z * rl.DEG2RAD})
	return rl.Vector3Transform({0, -1, 0}, m)
}

@(private = "file")
scale_rgb :: proc(c: rl.Color, f: f32) -> rl.Color {
	return {u8(f32(c.r) * f), u8(f32(c.g) * f), u8(f32(c.b) * f), 255}
}

// White rgb with quadratic alpha falloff (zero at rim) — works with the
// ADDITIVE blend (SRC_ALPHA, ONE) and bilinear filtering without dark fringes.
@(private = "file")
gen_falloff_image :: proc(res: i32) -> rl.Image {
	img := rl.GenImageColor(res, res, rl.BLANK)
	pixels := ([^]rl.Color)(img.data)
	c := f32(res) / 2
	for y in 0 ..< res {
		for x in 0 ..< res {
			dx := (f32(x) + 0.5 - c) / c
			dy := (f32(y) + 0.5 - c) / c
			t := clamp(1 - math.sqrt(dx*dx + dy*dy), 0, 1)
			pixels[y*res + x] = {255, 255, 255, u8(t * t * 255)}
		}
	}
	return img
}

// The vertex shader is required because raylib's default VS does not output
// world position/normal; attribute and matrix uniform names match raylib's
// auto-bound locations (rlgl computes matNormal and supplies a white default
// vertexColor when the mesh has no colors).
@(private = "file")
LIT_VS :: `#version 330
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;
uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;
out vec3 fragPosition;
out vec2 fragTexCoord;
out vec3 fragNormal;
out vec4 fragColor;

void main() {
    fragPosition = vec3(matModel * vec4(vertexPosition, 1.0));
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    fragNormal = normalize(vec3(matNormal * vec4(vertexNormal, 0.0)));
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
`

@(private = "file")
LIT_FS :: `#version 330
in vec3 fragPosition;
in vec2 fragTexCoord;
in vec3 fragNormal;
in vec4 fragColor;
uniform sampler2D texture0;
uniform vec4 colDiffuse;
#define MAX_LIGHTS 8
uniform int lightCount;
uniform vec4 lightPos[MAX_LIGHTS];   // w=1: point (xyz=pos), w=0: directional (xyz=dir)
uniform vec3 lightColor[MAX_LIGHTS]; // intensity premultiplied
uniform float lightRadius[MAX_LIGHTS];
uniform vec3 ambient;
uniform vec3 viewPos;
uniform vec3 fogColor;
out vec4 finalColor;

void main() {
    vec4 albedo = texture(texture0, fragTexCoord) * colDiffuse * fragColor;
    vec3 n = normalize(fragNormal);
    // Derive subtle micro-normal detail from the bound albedo. This is not a
    // replacement for authored tangent-space normal maps, but it gives photo
    // materials convincing grazing response without expanding the asset API.
    vec2 texel = 1.0 / vec2(max(textureSize(texture0, 0), ivec2(1)));
    float hc = dot(texture(texture0, fragTexCoord).rgb, vec3(0.299, 0.587, 0.114));
    float hx = dot(texture(texture0, fragTexCoord + vec2(texel.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
    float hy = dot(texture(texture0, fragTexCoord + vec2(0.0, texel.y)).rgb, vec3(0.299, 0.587, 0.114));
    vec3 dpdx = dFdx(fragPosition), dpdy = dFdy(fragPosition);
    vec2 duvdx = dFdx(fragTexCoord), duvdy = dFdy(fragTexCoord);
    vec3 T = normalize(dpdx * duvdy.y - dpdy * duvdx.y);
    vec3 B = normalize(-dpdx * duvdy.x + dpdy * duvdx.x);
    n = normalize(n + (hc - hx) * T * 1.35 + (hc - hy) * B * 1.35);
    vec3 light = ambient * (0.78 + 0.22 * max(n.y, 0.0));
    float specular = 0.0;
    vec3 V = normalize(viewPos - fragPosition);
    for (int i = 0; i < lightCount; i++) {
        vec3 L;
        float att = 1.0;
        if (lightPos[i].w > 0.5) {
            vec3 to = lightPos[i].xyz - fragPosition;
            float dist = length(to);
            L = to / max(dist, 0.0001);
            att = clamp(1.0 - dist / lightRadius[i], 0.0, 1.0);
            att *= att; // smooth quadratic-ish falloff, zero at radius
        } else {
            L = normalize(-lightPos[i].xyz);
        }
        light += lightColor[i] * (max(dot(n, L), 0.0) * att);
        vec3 H = normalize(L + V);
        float gloss = pow(max(dot(n, H), 0.0), 48.0);
        float albedoLightness = dot(albedo.rgb, vec3(0.299, 0.587, 0.114));
        float materialGloss = smoothstep(0.52, 0.92, albedoLightness);
        specular += gloss * att * dot(lightColor[i], vec3(0.333)) * (0.12 + materialGloss * 0.52);
    }
    vec3 lit = albedo.rgb * light + vec3(specular);
    float distanceToCamera = length(viewPos - fragPosition);
    float fog = 1.0 - exp(-distanceToCamera * distanceToCamera * 0.000055);
    lit = mix(lit, fogColor, clamp(fog, 0.0, 0.72));
    finalColor = vec4(lit, albedo.a);
}
`
