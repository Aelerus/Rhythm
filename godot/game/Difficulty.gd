class_name Difficulty
extends RefCounted

# Player-selectable difficulty. Every bullet does exactly 1 damage on
# every fight, so difficulty is purely "how many hits before defeat".

enum Mode { EASY, MEDIUM, HARD, INSANE, IMPOSSIBLE }

static var current: int = Mode.MEDIUM

static func player_hp() -> float:
	match current:
		Mode.EASY:       return 10.0
		Mode.MEDIUM:     return 7.0
		Mode.HARD:       return 5.0
		Mode.INSANE:     return 3.0
		Mode.IMPOSSIBLE: return 1.0
	return 7.0

static func label() -> String:
	match current:
		Mode.EASY:       return "EASY"
		Mode.MEDIUM:     return "MEDIUM"
		Mode.HARD:       return "HARD"
		Mode.INSANE:     return "INSANE"
		Mode.IMPOSSIBLE: return "IMPOSSIBLE"
	return ""

static func color() -> Color:
	match current:
		Mode.EASY:       return Color("#5dffae")
		Mode.MEDIUM:     return Color("#5dd6ff")
		Mode.HARD:       return Color("#ffd25d")
		Mode.INSANE:     return Color("#ff8a5d")
		Mode.IMPOSSIBLE: return Color("#ff3a3a")
	return Color.WHITE

static func cycle_next() -> void:
	current = (current + 1) % 5

static func cycle_prev() -> void:
	current = (current - 1 + 5) % 5
