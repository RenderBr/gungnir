package main

import "core:fmt"
import "core:os"
import rl "vendor:raylib"
import lua "vendor:lua/5.4"

main :: proc() {
	lua_smoke_test()

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(960, 600, "odin-engine")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground({24, 24, 32, 255})
		rl.DrawText("odin-engine: phase 0", 20, 20, 28, rl.RAYWHITE)
		rl.EndDrawing()
	}
}

lua_smoke_test :: proc() {
	L := lua.L_newstate()
	if L == nil {
		fmt.eprintln("failed to create lua state")
		os.exit(1)
	}
	defer lua.close(L)
	lua.L_openlibs(L)

	if lua.L_dostring(L, "return 1 + 1") != 0 {
		fmt.eprintln("lua smoke test failed:", lua.tostring(L, -1))
		os.exit(1)
	}
	fmt.println("lua smoke test: 1 + 1 =", lua.tointeger(L, -1))
}
