package script

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import lua "vendor:lua/5.4"
import "../engine"

// Single-engine globals: Lua CFunctions are proc "c" and cannot capture.
// Set once in init(); g_ctx carries the real allocator/logger into callbacks.
g_eng: ^engine.Engine
g_ctx: runtime.Context
g_scr: ^Script

RELOAD_POLL_INTERVAL :: 0.25
TOAST_DURATION :: 2.0

// Clears game-local modules from package.loaded so require() re-reads changed
// files on soft reload. Standard library entries are preserved.
@(private)
CLEAR_PACKAGE_LOADED :: `
local _keep = { _G = true, package = true, coroutine = true, table = true, io = true, os = true, math = true, utf8 = true, debug = true }
for k in pairs(package.loaded) do
	if not _keep[k] then package.loaded[k] = nil end
end
`

Script :: struct {
	L:          ^lua.State,
	main_path:  string, // owned
	broken:     bool,
	last_error: string, // owned
	last_mtime: i64, // newest .lua mtime in game dir (unix ns); 0 = unreadable
	poll_timer: f32,
	toast:      string, // static literal, never freed
	toast_timer: f32,
	hot_reload: bool, // file-watching reload; enabled by --hot
	time_scale: f32, // game speed multiplier; 0 = paused
	paused:     bool,
	prev_time_scale: f32, // saved before pause for restore
	step_count: i32, // frames to advance while paused
	console_visible: bool,
	debug_visible:   bool, // F3 toggle: FPS + entity count
}

// start=false defers the first script run (editor mode starts paused; the
// state is created on Play).
init :: proc(s: ^Script, eng: ^engine.Engine, main_path: string, start := true) -> bool {
	g_eng = eng
	g_ctx = context
	g_scr = s
	s.time_scale = 1.0
	s.prev_time_scale = 1.0
	s.main_path = strings.clone(main_path)
	s.last_mtime = scan_newest_lua_mtime(g_eng.game_dir)
	if !start {
		return true
	}
	return start_state(s)
}

destroy :: proc(s: ^Script) {
	if s.L != nil {
		lua.close(s.L)
		s.L = nil
	}
	delete(s.main_path)
	delete(s.last_error)
}

// Fresh lua state + run file + on_init, leaving the scene as the caller
// prepared it. The editor uses this for Play (scene already authored).
play_start :: proc(s: ^Script) -> bool {
	return start_state(s)
}

// Fresh state + run file + on_init. Used at startup and for full restarts.
@(private)
start_state :: proc(s: ^Script) -> bool {
	if s.L != nil {
		lua.close(s.L)
	}
	s.L = lua.L_newstate()
	if s.L == nil {
		fmt.eprintln("fatal: could not create lua state")
		return false
	}
	lua.L_openlibs(s.L)

	// Prepend <game_dir>/?.lua to package.path so require("module") finds
	// <game_dir>/module.lua — lets games split logic across multiple files.
	lua.getglobal(s.L, "package")
	lua.getfield(s.L, -1, "path")
	existing := string(lua.tostring(s.L, -1))
	new_path := fmt.tprintf("%s/?.lua;%s", g_eng.game_dir, existing)
	cpath := strings.clone_to_cstring(new_path, context.temp_allocator)
	lua.pushstring(s.L, cpath)
	lua.setfield(s.L, -3, "path")
	lua.pop(s.L, 2)

	// Traceback message handler lives permanently at stack index 1; every
	// pcall passes errfunc=1.
	lua.pushcfunction(s.L, l_traceback)

	register_api(s.L)
	s.broken = false

	if !run_main_file(s) {
		return false
	}
	return call_callback(s, "on_init")
}

// Full restart: fresh scene, re-loaded level (if any), fresh lua state.
restart :: proc(s: ^Script) {
	engine.clear_scene(&g_eng.scene)
	engine.load_default_level(g_eng)
	if start_state(s) {
		set_toast(s, "restarted")
	}
}

@(private)
run_main_file :: proc(s: ^Script) -> bool {
	path := strings.clone_to_cstring(s.main_path)
	defer delete(path)
	if lua.L_loadfile(s.L, path) != .OK {
		capture_error(s)
		return false
	}
	if lua.pcall(s.L, 0, 0, 1) != 0 {
		capture_error(s)
		return false
	}
	return true
}

// Re-runs the chunk in the SAME state: globals (game state) survive,
// function definitions update, on_init is not re-called.
soft_reload :: proc(s: ^Script) {
	was_broken := s.broken
	s.broken = false
	// Clear game-local modules from package.loaded so require() re-reads
	// changed files instead of returning the cached module.
	lua.L_dostring(s.L, CLEAR_PACKAGE_LOADED)
	if run_main_file(s) {
		set_toast(s, was_broken ? "reloaded (error fixed)" : "reloaded")
		call_callback(s, "on_reload")
	}
}

// Scans the game directory for .lua files and returns the newest modification
// time as unix nanoseconds. Lets hot reload detect changes in any game file,
// not just main.lua. Returns 0 if the directory can't be read.
@(private)
scan_newest_lua_mtime :: proc(dir: string) -> i64 {
	entries, err := os.read_directory_by_path(dir, -1, context.temp_allocator)
	if err != nil {
		return 0
	}
	defer os.file_info_slice_delete(entries, context.temp_allocator)
	newest: i64
	for fi in entries {
		if fi.type == .Regular && strings.has_suffix(fi.name, ".lua") {
			ns := time.to_unix_nanoseconds(fi.modification_time)
			if ns > newest {
				newest = ns
			}
		}
	}
	return newest
}

tick_hot_reload :: proc(s: ^Script, dt: f32) {
	s.toast_timer = max(0, s.toast_timer - dt)
	if !s.hot_reload {
		return
	}
	s.poll_timer += dt
	if s.L == nil || s.poll_timer < RELOAD_POLL_INTERVAL {
		return
	}
	s.poll_timer = 0
	// Check for Lua file changes
	mtime := scan_newest_lua_mtime(g_eng.game_dir)
	if mtime != 0 && mtime != s.last_mtime {
		s.last_mtime = mtime
		soft_reload(s)
	}
	// Check for asset file changes
	asset_mtime := engine.scan_assets_mtime(g_eng)
	if asset_mtime != 0 && asset_mtime != g_eng.assets_mtime {
		g_eng.assets_mtime = asset_mtime
		engine.reload_assets(g_eng)
	}
}

set_toast :: proc(s: ^Script, msg: string) {
	s.toast = msg
	s.toast_timer = TOAST_DURATION
	fmt.println("[script]", msg)
}

@(private)
capture_error :: proc(s: ^Script) {
	msg := string(lua.tostring(s.L, -1))
	delete(s.last_error)
	s.last_error = strings.clone(msg)
	s.broken = true
	lua.pop(s.L, 1)
	fmt.eprintln("[script error]", s.last_error)
}

// All entry into Lua funnels through here. A broken script is never
// called again until a reload clears the flag; errors never propagate.
call_callback :: proc(s: ^Script, name: cstring, args: ..f64) -> bool {
	if s.broken || s.L == nil {
		return false
	}
	lua.getglobal(s.L, name)
	if !lua.isfunction(s.L, -1) {
		lua.pop(s.L, 1)
		return true // callbacks are optional
	}
	for a in args {
		lua.pushnumber(s.L, lua.Number(a))
	}
	if lua.pcall(s.L, c.int(len(args)), 0, 1) != 0 {
		capture_error(s)
		return false
	}
	return true
}

// The prelude dispatcher (components, parenting, pruning) calls the user's
// on_update itself; fall back to plain on_update when it is absent so old
// games run unmodified even if the prelude failed to load.
call_update :: proc(s: ^Script, dt: f32) {
	if s.broken || s.L == nil {
		return
	}
	lua.getglobal(s.L, "__gungnir_update")
	has_hook := lua.isfunction(s.L, -1)
	lua.pop(s.L, 1)
	call_callback(s, has_hook ? "__gungnir_update" : "on_update", f64(dt))
}
call_draw :: proc(s: ^Script)            { call_callback(s, "on_draw") }
call_draw_3d :: proc(s: ^Script)         { call_callback(s, "on_draw_3d") }
call_gui :: proc(s: ^Script)             { call_callback(s, "on_gui") }

l_traceback :: proc "c" (L: ^lua.State) -> c.int {
	msg := lua.tostring(L, 1)
	lua.L_traceback(L, L, msg, 1)
	return 1
}
