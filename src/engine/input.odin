package engine

import rl "vendor:raylib"

// Maps friendly script-facing names ("up", "space", "a", "1") to raylib keys.
// Returns .KEY_NULL for unknown names.
key_from_name :: proc(name: string) -> rl.KeyboardKey {
	if len(name) == 1 {
		c := name[0]
		switch {
		case c >= 'a' && c <= 'z':
			return rl.KeyboardKey(i32(rl.KeyboardKey.A) + i32(c - 'a'))
		case c >= 'A' && c <= 'Z':
			return rl.KeyboardKey(i32(rl.KeyboardKey.A) + i32(c - 'A'))
		case c >= '0' && c <= '9':
			return rl.KeyboardKey(i32(rl.KeyboardKey.ZERO) + i32(c - '0'))
		}
	}
	switch name {
	case "up":        return .UP
	case "down":      return .DOWN
	case "left":      return .LEFT
	case "right":     return .RIGHT
	case "space":     return .SPACE
	case "enter", "return": return .ENTER
	case "escape", "esc":   return .ESCAPE
	case "tab":       return .TAB
	case "backspace": return .BACKSPACE
	case "shift":     return .LEFT_SHIFT
	case "ctrl":      return .LEFT_CONTROL
	case "alt":       return .LEFT_ALT
	case "cmd", "super":    return .LEFT_SUPER
	}
	return .KEY_NULL
}

mouse_button_from_name :: proc(name: string) -> rl.MouseButton {
	switch name {
	case "right":  return .RIGHT
	case "middle": return .MIDDLE
	}
	return .LEFT
}
