class_name OverdriveMode
extends RefCounted

# Player-toggleable global mode. When enabled, every fight starts in
# OVERDRIVE immediately (re-triggers at the start of every phase so it
# persists through multi-phase fights like APEX). Mostly an unbeatable
# spectacle mode -- intentional design choice.

static var enabled: bool = false

static func toggle() -> void:
	enabled = not enabled

static func label() -> String:
	return "OVERDRIVE: ON" if enabled else "OVERDRIVE: OFF"

static func color() -> Color:
	return Color("#ff3a3a") if enabled else Color("#666688")
