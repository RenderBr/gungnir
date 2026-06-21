package script

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import "../engine"

CONSOLE_MAX :: 64

LogEntry :: struct {
	message: string,
	level:   string,
}

console_log:   [CONSOLE_MAX]LogEntry;
console_count: int;
console_head:  int; // ring buffer write index

// Append a message to the ring buffer. Overwrites oldest on overflow.
console_push :: proc(msg, level: string) {
	console_log[console_head] = {msg, level};
	console_head = (console_head + 1) %% CONSOLE_MAX;
	if console_count < CONSOLE_MAX {
		console_count += 1;
	}
}

// Toggle the console overlay.
toggle_console :: proc(s: ^Script, hot_reload: bool) {
	s.console_visible = !s.console_visible;
}

// Draw the console overlay: last 8 lines in a dark panel at the bottom.
draw_console :: proc(e: ^engine.Engine, s: ^Script) {
	if !s.console_visible {
		return;
	}
	w, h := engine.logical_size(e);
	lines_to_show := min(console_count, 8);
	panel_h: i32 = 24 + 18 * i32(lines_to_show);

	rl.DrawRectangle(0, h - panel_h, w, panel_h, {0, 0, 0, 200});
	rl.DrawText("Console (`)", 12, h - panel_h + 4, 14, {100, 100, 120, 255});

	start := (console_head - lines_to_show) %% CONSOLE_MAX;
	for i in 0 ..< lines_to_show {
		idx := (start + i) %% CONSOLE_MAX;
		entry := console_log[idx];
		y := h - panel_h + 24 + 18 * i32(i);

		color: rl.Color;
		switch entry.level {
		case "error":
			color = {255, 120, 120, 255};
		case "warn":
			color = {255, 200, 100, 255};
		case: // "info"
			color = {180, 180, 200, 255};
		}

		msg := strings.clone_to_cstring(entry.message, context.temp_allocator);
		rl.DrawText(msg, 12, y, 16, color);
	}
}

// Draw the FPS/debug overlay: FPS, dt, entity count. Toggled by F3.
draw_debug_overlay :: proc(e: ^engine.Engine, scr: ^Script, ed_enabled: bool) {
	if !scr.debug_visible {
		return;
	}
	w, h := engine.logical_size(e);
	fps := rl.GetFPS();
	fps_str := fmt.ctprintf("FPS: %d", fps);
	rl.DrawText(fps_str, w - 120, 10, 18, rl.RAYWHITE);

	entity_count := engine.alive_count(&e.scene);
	ent_str := fmt.ctprintf("Entities: %d", entity_count);
	rl.DrawText(ent_str, w - 140, 32, 18, rl.RAYWHITE);

	ts := scr.time_scale;
	if scr.paused {
		rl.DrawText("PAUSED (F5: step, F6: unpause)", w - 280, 54, 16, {255, 200, 80, 255});
	} else if ts != 1.0 {
		ts_str := fmt.ctprintf("Time: %.2fx", ts);
		rl.DrawText(ts_str, w - 120, 54, 18, {180, 220, 255, 255});
	}

	if ed_enabled {
		rl.DrawText("Editor (F1)", w - 130, h - 24, 14, {100, 100, 120, 255});
	}
}
