package engine

import rl "vendor:raylib"

// Frame pass order is strict: 3D first, then 2D, then screen space.
// The 2D pass disables depth writes, so 3D after 2D produces sorting
// artifacts. main.odin composes these; nothing else may open rl modes.

begin_frame :: proc(e: ^Engine) {
	rl.BeginDrawing()
	rl.ClearBackground(e.clear_color)
}

end_frame :: proc(e: ^Engine) {
	rl.EndDrawing()
}

begin_2d :: proc(e: ^Engine) {
	rl.BeginMode2D(e.cam2d)
}

end_2d :: proc(e: ^Engine) {
	rl.EndMode2D()
}

begin_3d :: proc(e: ^Engine) {
	rl.BeginMode3D(e.cam3d)
}

end_3d :: proc(e: ^Engine) {
	rl.EndMode3D()
}
