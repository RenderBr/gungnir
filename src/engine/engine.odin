package engine

import rl "vendor:raylib"

Engine :: struct {
	game_dir:    string,
	should_quit: bool,
	clear_color: rl.Color,
	draw_color:  rl.Color,
	cam2d:       rl.Camera2D,
	cam3d:       rl.Camera3D,
	scene:       Scene,
	assets:      Assets,
	postfx:      Postfx,
}

// Requires an open window (textures need a GL context) and audio device.
init :: proc(e: ^Engine, game_dir: string) {
	e.game_dir = game_dir
	e.clear_color = {24, 24, 32, 255}
	e.draw_color = rl.RAYWHITE
	e.cam2d = {zoom = 1}
	e.cam3d = {
		position   = {10, 10, 10},
		target     = {0, 0, 0},
		up         = {0, 1, 0},
		fovy       = 60,
		projection = .PERSPECTIVE,
	}
	assets_init(&e.assets)
}

destroy :: proc(e: ^Engine) {
	scene_destroy(&e.scene)
	assets_destroy(&e.assets)
	postfx_destroy(e)
}
