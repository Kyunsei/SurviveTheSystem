class_name PlayerInput
extends RefCounted
## What one player asks for, this frame. The same for every species: each species decides
## what the keys do (speed, jump or not, which actions exist). Built by PlayerController
## from the keys, or received from the network (to_bytes / from_bytes).

# Buttons (bits). `held` = down right now, `pressed` = went down since the last input.
const JUMP    := 1 << 0
const SPRINT  := 1 << 1
const DASH    := 1 << 2
const ATTACK  := 1 << 3
const ACTION  := 1 << 4     # interact (talk, shake a tree...)
const USE     := 1 << 5     # machine / carried tool
const PICK_UP := 1 << 6
const THROW   := 1 << 7     # hold to charge, release to throw
const DROP    := 1 << 8
const EAT     := 1 << 9     # hold to eat
const ALL     := (1 << 10) - 1

## Input Map action of each button (PlayerController reads these).
const ACTIONS := {
	JUMP: "jump", SPRINT: "sprint", DASH: "dash", ATTACK: "attack", ACTION: "Action",
	USE: "use", PICK_UP: "pick_up", THROW: "throw", DROP: "Drop", EAT: "eat",
}

## Movement in WORLD space, length 0..1: x = +X (east), y = +Z (south). The controller
## already turned it from the camera, so species never need to know about views.
var move := Vector2.ZERO
## Flat direction to aim attacks / throws (camera views). Zero = the agent's facing.
var aim := Vector2.ZERO
var held := 0
var pressed := 0
var seq := 0                 # network: order of the packets


func is_held(button: int) -> bool:
	return held & button != 0


func was_pressed(button: int) -> bool:
	return pressed & button != 0


# --- Network (12 bytes) ---------------------------------------------------------------

func to_bytes() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(12)
	b.encode_u32(0, seq)
	b.encode_u16(4, held)
	b.encode_u16(6, pressed)
	b.encode_s8(8, roundi(clampf(move.x, -1.0, 1.0) * 127.0))
	b.encode_s8(9, roundi(clampf(move.y, -1.0, 1.0) * 127.0))
	var a := aim.normalized() if aim.length_squared() > 1e-6 else Vector2.ZERO
	b.encode_s8(10, roundi(a.x * 127.0))
	b.encode_s8(11, roundi(a.y * 127.0))
	return b


static func from_bytes(b: PackedByteArray) -> PlayerInput:
	var p := PlayerInput.new()
	if b.size() < 12:
		return p
	p.seq = b.decode_u32(0)
	p.held = b.decode_u16(4)
	p.pressed = b.decode_u16(6)
	p.move = Vector2(b.decode_s8(8), b.decode_s8(9)) / 127.0
	p.aim = Vector2(b.decode_s8(10), b.decode_s8(11)) / 127.0
	return p
