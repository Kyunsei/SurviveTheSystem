class_name Pilot
extends RefCounted
## One controlled agent, and everything about how it is being played. Owned by PilotSystem.
## Several pilots can play agents of the same species (one agent = at most one pilot).
## species.pilot_id[index] == id while this pilot controls it.

var id := -1                      # slot in PilotSystem.pilots
var peer_id := 1                  # who plays it (1 = solo / host, else a network peer)
var species = null                # ALIFE
var index := -1                   # local index in the species
var input := PlayerInput.new()    # latest input
## Local player: called every frame for a fresh PlayerInput (network pilots: null,
## PilotSystem.receive_input() fills `input` instead).
var poll := Callable()

# --- Movement: read / written by the species in its chunk tick ---------------------------
var vy := 0.0                     # vertical speed (jump / fall)
var air_time := 0.0               # time since leaving the ground (coyote time)
var jump_buffer := 0.0            # > 0: jump pressed recently
var dash_left := 0.0              # dash time remaining
var facing := Vector3.FORWARD     # last direction faced (arrow, carried item, attacks)

# --- Cooldowns (real seconds) ------------------------------------------------------------
var dash_cd := 0.0
var attack_cd := 0.0

# --- Actions in progress ------------------------------------------------------------------
var charging := false             # throw held
var charge := 0.0                 # 0..1 throw power
var eating := false               # eat held
var eat_progress := 0.0           # 0..1, eats at 1
var struggle := 0                 # jump presses while carried (breaks free at a count)

# --- What is in reach (outline, pick up, use) ----------------------------------------------
var target_species = null
var target_index := -1
var target_machine = null

# --- Network: client authority (host side, see NetSession) ------------------------------------
var net_allow := false            # its client may move it now (flag sent in the snapshots)
var client_driven := false        # positions arrive: the species leaves it in place
var net_pos := Vector3.ZERO       # last position its client sent
var net_has_pos := false          # a new one arrived since the last check
var net_time := 0.0               # real time of the last check
var net_corrections := 0          # positions refused (the client snaps back on a change)

# --- Last attack (the debug box): attack_serial goes up by one per attack -------------------
var attack_serial := 0
var attack_origin := Vector3.ZERO
var attack_basis := Basis()


## The agent still exists, is alive, and is still played by this pilot.
func is_valid() -> bool:
	if species == null or index < 0 or index >= species.entity_count:
		return false
	return species.active_alife_array[index] != 0 and species.alive_array[index] != 0 \
			and species.pilot_id[index] == id


func position() -> Vector3:
	return species.position_array[index]


## Flat direction to aim: the input's aim (camera views), else where the agent faces.
func aim_dir() -> Vector3:
	var d := Vector3(input.aim.x, 0.0, input.aim.y)
	if d.length_squared() < 1e-6:
		d = Vector3(facing.x, 0.0, facing.z)
	return d.normalized() if d.length_squared() > 1e-6 else Vector3.FORWARD
