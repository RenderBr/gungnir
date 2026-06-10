package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"
import "editor"
import "engine"
import "script"

main :: proc() {
	game_dir := "examples/hello"
	shot_path: string // dev flag: screenshot after ~1s, then exit
	editor_flag := false
	view3d_flag := false
	for arg in os.args[1:] {
		if strings.has_prefix(arg, "--shot=") {
			shot_path = strings.trim_prefix(arg, "--shot=")
		} else if arg == "--editor" {
			editor_flag = true
		} else if arg == "--3d" {
			view3d_flag = true
		} else if !strings.has_prefix(arg, "-") {
			game_dir = arg
		}
	}
	main_lua, _ := filepath.join({game_dir, "main.lua"})
	if !os.exists(main_lua) {
		fmt.eprintfln("no main.lua found in %q", game_dir)
		os.exit(1)
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.SetTraceLogLevel(.WARNING)
	rl.InitWindow(960, 600, "odin-engine")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	rl.SetExitKey(.KEY_NULL) // esc belongs to games, not the window
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	eng: engine.Engine
	engine.init(&eng, game_dir)
	defer engine.destroy(&eng)

	engine.load_default_level(&eng)

	scr: script.Script
	script.init(&scr, &eng, main_lua, start = !editor_flag)
	defer script.destroy(&scr)

	ed: editor.Editor
	editor.init(&ed, editor_flag)
	ed.view_3d = view3d_flag
	defer editor.destroy(&ed)

	frame := 0
	for !rl.WindowShouldClose() && !eng.should_quit {
		frame += 1
		dt := min(rl.GetFrameTime(), 0.1)
		editing := ed.enabled && !ed.playing
		running := !editing

		if editing {
			editor.update(&ed, &eng, dt)
		} else {
			script.tick_hot_reload(&scr, dt)
			if restart_requested() {
				script.restart(&scr)
			}
			if !ed.enabled && rl.IsKeyPressed(.F1) {
				ed.enabled = true // editor over a running game; Stop pauses it
				ed.playing = true
			}
			script.call_update(&scr, dt)
		}

		engine.begin_frame(&eng)
		if editing && ed.view_3d {
			rl.BeginMode3D(editor.orbit_camera(ed.orbit))
		} else {
			engine.begin_3d(&eng)
		}
		engine.draw_entities_3d(&eng)
		if running {
			script.call_draw_3d(&scr)
		} else if ed.view_3d {
			editor.draw_world_3d(&ed, &eng)
		}
		engine.end_3d(&eng)

		if editing {
			rl.BeginMode2D(ed.cam)
		} else {
			engine.begin_2d(&eng)
		}
		engine.draw_entities_2d(&eng)
		if running {
			script.call_draw(&scr)
		} else {
			editor.draw_world(&ed, &eng)
		}
		engine.end_2d(&eng)

		if running {
			script.call_gui(&scr)
		}
		if ed.enabled {
			editor.draw_panels(&ed, &eng, &scr)
		}
		draw_overlay(&scr)
		engine.end_frame(&eng)

		if shot_path != "" && frame == 60 {
			rl.TakeScreenshot(strings.clone_to_cstring(shot_path, context.temp_allocator))
			eng.should_quit = true
		}
	}
}

restart_requested :: proc() -> bool {
	super := rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER)
	return super && rl.IsKeyPressed(.R)
}

// Screen-space status layer: script error banner and reload toasts.
draw_overlay :: proc(s: ^script.Script) {
	if s.broken {
		w := rl.GetScreenWidth()
		rl.DrawRectangle(0, 0, w, 40, {180, 30, 30, 230})
		rl.DrawText("script error (fix + save to reload, cmd+r to restart)", 12, 10, 20, rl.RAYWHITE)

		msg := strings.clone_to_cstring(s.last_error, context.temp_allocator)
		rl.DrawRectangle(0, 40, w, 24 + 18 * count_lines(s.last_error), {0, 0, 0, 170})
		rl.DrawText(msg, 12, 52, 16, {255, 200, 200, 255})
	}
	if s.toast_timer > 0 {
		msg := strings.clone_to_cstring(s.toast, context.temp_allocator)
		rl.DrawText(msg, 12, rl.GetScreenHeight() - 28, 18, {140, 220, 140, 255})
	}
	free_all(context.temp_allocator)
}

count_lines :: proc(s: string) -> i32 {
	n: i32 = 1
	for ch in s {
		if ch == '\n' {
			n += 1
		}
	}
	return n
}
