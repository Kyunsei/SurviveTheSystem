extends Control
## =============================================================================
##  AI BENCHMARK — Agent-Based Model (one species, food + danger entities)
##  Neural Network  vs  Utility AI  vs  Decision Tree
## -----------------------------------------------------------------------------
##  HOW TO USE
##   1. New scene -> root node "Control" (Full Rect) -> attach this script.
##   2. Press F6. Click "Start benchmark".
##   3. Tweak everything from the Inspector (exported vars below).
##
##  Everything (UI, world, AIs, result tables) is built in code — one node only.
##
##  "AI system size" per AI type:
##   - Neural Net    : neurons per hidden layer (layers = nn_hidden_layers = "cascade" depth)
##   - Utility AI    : number of considerations (response curves) per action (1..4)
##   - Decision Tree : max depth of the tree
##
##  NN and Decision Tree are first trained by imitation of a hand-written "oracle"
##  policy, so they start sensible. The Utility AI is hand-designed. Then, during
##  the run, dead agents respawn as a mutated copy of a fit survivor (optional
##  neuro-evolution / parameter evolution, identical mechanism for all 3 AIs).
## =============================================================================

# ----------------------------------------------------------------- constants
enum AI { NEURAL_NET, UTILITY, DECISION_TREE }
const AI_NAMES := ["Neural Net", "Utility AI", "Decision Tree"]
const AI_COLORS := [Color(0.95, 0.6, 0.95), Color(1.0, 0.82, 0.35), Color(0.45, 0.88, 1.0)]

enum Act { WANDER, FLOCK, SEEK_FOOD, FLEE, REST }
const N_ACT := 5
const ACT_NAMES := ["Wander", "Flock", "Seek food", "Flee", "Rest"]
const ACT_SHORT := ["W", "F", "S", "X", "R"]
const ACT_COLORS := [
	Color(0.78, 0.78, 0.84), # wander
	Color(0.35, 0.62, 1.0),  # flock
	Color(0.4, 0.95, 0.45),  # seek food
	Color(1.0, 0.55, 0.2),   # flee
	Color(0.72, 0.5, 1.0),   # rest
]
const ACT_SPEED := [0.6, 0.8, 1.0, 1.5, 0.0] # fraction of BASE_SPEED

# Sensor vector (all normalised 0..1) — the same inputs for every AI
const S_HUNGER := 0  # 0 = full, 1 = starving (dies at 1)
const S_ENERGY := 1  # stamina, sprinting drains it, resting refills it
const S_FOOD := 2    # proximity of nearest food in sense radius (0 = none)
const S_DANGER := 3  # proximity of nearest danger in sense radius (0 = none)
const S_CROWD := 4   # neighbour density
const N_IN := 5

# Agent / world tuning
const DT := 1.0 / 30.0
const BASE_SPEED := 90.0
const SENSE_R := 150.0
const NEIGH_R := 60.0
const SEP_R := 18.0
const EAT_R := 10.0
const KILL_R := 13.0
const FOOD_VALUE := 0.5
const HUNGER_RATE := 1.0 / 45.0  # ~45 s to starve from full

# Utility AI design: per action, ranked list of considerations
# [sensor, curve(0 = power, 1 = logistic), invert(0/1), p1 (exponent | steepness), p2 (logistic midpoint)]
# "size" k = only the first k considerations of each action are used.
const UTILITY_DESIGN := [
	[[S_ENERGY, 0, 0, 0.5, 0.0], [S_DANGER, 0, 1, 2.0, 0.0], [S_HUNGER, 0, 1, 1.0, 0.0], [S_CROWD, 0, 1, 1.0, 0.0]],     # WANDER
	[[S_CROWD, 1, 0, 12.0, 0.12], [S_DANGER, 0, 1, 1.0, 0.0], [S_HUNGER, 0, 1, 1.0, 0.0], [S_ENERGY, 0, 0, 0.5, 0.0]],  # FLOCK
	[[S_HUNGER, 1, 0, 10.0, 0.4], [S_FOOD, 1, 0, 8.0, 0.15], [S_DANGER, 0, 1, 2.0, 0.0], [S_ENERGY, 0, 0, 0.3, 0.0]],   # SEEK_FOOD
	[[S_DANGER, 1, 0, 12.0, 0.35], [S_ENERGY, 1, 0, 15.0, 0.08], [S_HUNGER, 0, 1, 0.5, 0.0], [S_CROWD, 0, 1, 0.5, 0.0]], # FLEE
	[[S_ENERGY, 1, 1, 10.0, 0.65], [S_DANGER, 0, 1, 3.0, 0.0], [S_HUNGER, 0, 1, 1.0, 0.0], [S_CROWD, 1, 0, 4.0, 0.0]],  # REST
]
const UTILITY_WEIGHTS := [0.35, 0.55, 1.0, 1.3, 0.9]

# ----------------------------------------------------------------- exports
@export_group("Benchmark")
@export var agent_counts: Array[int] = [20, 60, 150]
@export var run_neural_net := true
@export var run_utility_ai := true
@export var run_decision_tree := true
@export var sim_seconds := 90.0       ## simulated seconds per configuration
@export var warmup_seconds := 10.0    ## metrics ignored during warm-up
@export var repeats := 1              ## runs per configuration (different seeds, averaged)
@export var base_seed := 1234
@export var death_penalty := 4.0      ## score = food/agent/min - penalty * deaths/agent/min
@export var max_steps_per_frame := 60

@export_group("AI system size")
@export var nn_hidden_layers := 2                   ## "cascade" depth of the network
@export var nn_neurons: Array[int] = [4, 12, 32]    ## neurons per hidden layer (one run each)
@export var utility_considerations: Array[int] = [1, 2, 4] ## considerations per action (max 4)
@export var tree_depths: Array[int] = [2, 4, 8]     ## max tree depth
@export var imitation_samples := 2000
@export var nn_epochs := 6
@export var nn_learning_rate := 0.03

@export_group("Evolution on respawn")
@export var evolve_on_respawn := true
@export var mutation_chance := 0.1
@export var mutation_sigma := 0.2

@export_group("World")
@export var world_size := Vector2(1400, 900)
@export var food_cap := 90
@export var food_spawn_per_sec := 4.0
@export var food_drift_speed := 10.0
@export var danger_count := 5
@export var danger_speed := 105.0
@export var danger_chase_radius := 170.0
@export var danger_lifetime := Vector2(15, 35) ## dangers despawn and respawn at an edge

# ----------------------------------------------------------------- state
enum Phase { IDLE, PREPARE, RUN, DONE }
var phase := Phase.IDLE
var paused := false
var plan: Array = []
var plan_i := 0
var cfg: Dictionary = {}
var cfg_key := ""
var results: Array = []
var templates: Dictionary = {}

var X: Array = []                 # imitation inputs (PackedFloat32Array)
var Y := PackedInt32Array()       # oracle labels

var train_net: NeuralNet
var train_order: Array = []
var train_cursor := 0
var train_total := 0

var rng := RandomNumberGenerator.new()
var agents: Array[Agent] = []
var dangers: Array[Danger] = []
var food_pos := PackedVector2Array()
var food_vel := PackedVector2Array()
var food_timer := 0.0
var sim_time := 0.0
var grid: Dictionary = {}

# metrics (measured after warm-up)
var m_food := 0
var m_d_pred := 0
var m_d_starve := 0
var m_agent_secs := 0.0
var m_hunger := 0.0
var m_crowd := 0.0
var m_act := PackedFloat32Array()
var m_us := 0
var m_dec := 0
# live counters (whole run)
var live_food := 0
var live_pred := 0
var live_starve := 0

# UI
var sim_view: Control
var start_btn: Button
var pause_btn: Button
var render_chk: CheckBox
var speed_slider: HSlider
var speed_lbl: Label
var progress: ProgressBar
var status_lbl: Label
var live_lbl: Label
var tabs: TabContainer
var summary_box: VBoxContainer
var details_box: VBoxContainer
var live_timer := 0.0


# =============================================================================
#  INNER CLASSES
# =============================================================================
class Agent:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var hunger := 0.0
	var energy := 1.0
	var age := 0.0
	var food := 0
	var action := 0
	var wander := 0.0
	var brain = null
	var sensors := PackedFloat32Array()
	var neighbors: Array = []
	var near_food := -1
	var flee_dir := Vector2.ZERO


class Danger:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var heading := 0.0
	var life := 20.0
	var cooldown := 0.0


## Multi-layer perceptron: tanh hidden layers, linear output, argmax = action.
class NeuralNet:
	var sizes := PackedInt32Array()
	var w := PackedFloat32Array()
	var off := PackedInt32Array()

	func init_random(s: PackedInt32Array, r: RandomNumberGenerator) -> void:
		sizes = s
		off.clear()
		var total := 0
		for l in sizes.size() - 1:
			off.append(total)
			total += (sizes[l] + 1) * sizes[l + 1]
		w.resize(total)
		for l in sizes.size() - 1:
			var nin := sizes[l]
			var nout := sizes[l + 1]
			var sd := 1.0 / sqrt(float(nin))
			for j in nout:
				var base := off[l] + j * (nin + 1)
				for i in nin:
					w[base + i] = r.randfn(0.0, sd)
				w[base + nin] = 0.0

	func forward_all(x: PackedFloat32Array) -> Array:
		var acts: Array = [x]
		var a := x
		var last := sizes.size() - 2
		for l in sizes.size() - 1:
			var nin := sizes[l]
			var nout := sizes[l + 1]
			var o := off[l]
			var out := PackedFloat32Array()
			out.resize(nout)
			for j in nout:
				var base := o + j * (nin + 1)
				var s := w[base + nin]
				for i in nin:
					s += w[base + i] * a[i]
				out[j] = tanh(s) if l < last else s
			acts.append(out)
			a = out
		return acts

	func decide(x: PackedFloat32Array) -> int:
		var acts := forward_all(x)
		var out: PackedFloat32Array = acts[acts.size() - 1]
		var best := 0
		for j in range(1, out.size()):
			if out[j] > out[best]:
				best = j
		return best

	## One SGD step, softmax cross-entropy.
	func train_one(x: PackedFloat32Array, y: int, lr: float) -> void:
		var acts := forward_all(x)
		var L := sizes.size() - 1
		var logits: PackedFloat32Array = acts[L]
		var mx := logits[0]
		for v in logits:
			mx = maxf(mx, v)
		var delta := PackedFloat32Array()
		delta.resize(logits.size())
		var sum := 0.0
		for j in logits.size():
			delta[j] = exp(logits[j] - mx)
			sum += delta[j]
		for j in logits.size():
			delta[j] /= sum
		delta[y] -= 1.0
		for l in range(L - 1, -1, -1):
			var nin := sizes[l]
			var nout := sizes[l + 1]
			var a_in: PackedFloat32Array = acts[l]
			var prev := PackedFloat32Array()
			if l > 0:
				prev.resize(nin)
				for j in nout:
					var base := off[l] + j * (nin + 1)
					var dj := delta[j]
					for i in nin:
						prev[i] += w[base + i] * dj
				for i in nin:
					prev[i] *= (1.0 - a_in[i] * a_in[i])
			for j in nout:
				var base := off[l] + j * (nin + 1)
				var g := delta[j] * lr
				for i in nin:
					w[base + i] -= g * a_in[i]
				w[base + nin] -= g
			delta = prev

	func copy() -> NeuralNet:
		var n := NeuralNet.new()
		n.sizes = sizes.duplicate()
		n.off = off.duplicate()
		n.w = w.duplicate()
		return n

	func mutate(r: RandomNumberGenerator, chance: float, sigma: float) -> void:
		for i in w.size():
			if r.randf() < chance:
				w[i] += r.randfn(0.0, sigma)

	func param_count() -> int:
		return w.size()


## Utility AI: score(action) = weight * product of response curves (with
## Dave Mark's compensation factor), pick the highest score.
class UtilityAI:
	const MAXC := 4
	const NA := 5
	var k := 1
	var weights := PackedFloat32Array()
	var c_in := PackedInt32Array()
	var c_type := PackedInt32Array()
	var c_inv := PackedInt32Array()
	var c_p1 := PackedFloat32Array()
	var c_p2 := PackedFloat32Array()

	func setup(k_: int, design: Array, w: Array) -> void:
		k = clampi(k_, 1, MAXC)
		weights = PackedFloat32Array(w)
		for a in NA:
			var cons: Array = design[a]
			for c in MAXC:
				var d: Array = cons[c]
				c_in.append(d[0])
				c_type.append(d[1])
				c_inv.append(d[2])
				c_p1.append(d[3])
				c_p2.append(d[4])

	func decide(x: PackedFloat32Array) -> int:
		var best := 0
		var best_s := -1.0
		var mod := 1.0 - 1.0 / float(k)
		for a in NA:
			var s := weights[a]
			for c in k:
				var i := a * MAXC + c
				var v := x[c_in[i]]
				if c_inv[i] == 1:
					v = 1.0 - v
				var y: float
				if c_type[i] == 0:
					y = pow(maxf(v, 0.0), c_p1[i])
				else:
					y = 1.0 / (1.0 + exp(-c_p1[i] * (v - c_p2[i])))
				y = y + (1.0 - y) * mod * y
				s *= y
			if s > best_s:
				best_s = s
				best = a
		return best

	func copy() -> UtilityAI:
		var u := UtilityAI.new()
		u.k = k
		u.weights = weights.duplicate()
		u.c_in = c_in.duplicate()
		u.c_type = c_type.duplicate()
		u.c_inv = c_inv.duplicate()
		u.c_p1 = c_p1.duplicate()
		u.c_p2 = c_p2.duplicate()
		return u

	func mutate(r: RandomNumberGenerator, chance: float, sigma: float) -> void:
		for a in NA:
			if r.randf() < chance:
				weights[a] *= exp(r.randfn(0.0, sigma))
			for c in k:
				var i := a * MAXC + c
				if r.randf() < chance:
					c_p1[i] = maxf(0.05, c_p1[i] * exp(r.randfn(0.0, sigma)))
				if r.randf() < chance and c_type[i] == 1:
					c_p2[i] = clampf(c_p2[i] + r.randfn(0.0, sigma * 0.3), 0.0, 1.0)

	func param_count() -> int:
		return NA + NA * k * 2


## Binary decision tree trained with CART (gini) to imitate the oracle.
class DecisionTree:
	const NTHR := 20
	var feat := PackedInt32Array()
	var thr := PackedFloat32Array()
	var lo := PackedInt32Array()
	var hi := PackedInt32Array()
	var leaf := PackedInt32Array()

	func decide(x: PackedFloat32Array) -> int:
		var n := 0
		while feat[n] >= 0:
			n = lo[n] if x[feat[n]] < thr[n] else hi[n]
		return leaf[n]

	func fit(xs: Array, ys: PackedInt32Array, max_depth: int, nf: int, nc: int) -> void:
		feat.clear(); thr.clear(); lo.clear(); hi.clear(); leaf.clear()
		_build(xs, ys, PackedInt32Array(range(xs.size())), 0, max_depth, nf, nc)

	func _new_node() -> int:
		feat.append(-1); thr.append(0.0); lo.append(-1); hi.append(-1); leaf.append(0)
		return feat.size() - 1

	static func _gini(counts: PackedInt32Array, n: int) -> float:
		if n == 0:
			return 0.0
		var g := 1.0
		for c in counts:
			var p := float(c) / n
			g -= p * p
		return g

	func _build(xs: Array, ys: PackedInt32Array, idx: PackedInt32Array, depth: int, maxd: int, nf: int, nc: int) -> int:
		var node := _new_node()
		var counts := PackedInt32Array()
		counts.resize(nc)
		for i in idx:
			counts[ys[i]] += 1
		var maj := 0
		for c in nc:
			if counts[c] > counts[maj]:
				maj = c
		leaf[node] = maj
		if depth >= maxd or idx.size() < 6 or counts[maj] == idx.size():
			return node
		var n := idx.size()
		var best_g := _gini(counts, n) - 1e-6
		var bf := -1
		var bt := 0.0
		var cl := PackedInt32Array()
		var cr := PackedInt32Array()
		cl.resize(nc)
		cr.resize(nc)
		for f in nf:
			for t in range(1, NTHR):
				var th := float(t) / NTHR
				cl.fill(0)
				cr.fill(0)
				var nl := 0
				for i in idx:
					var xi: PackedFloat32Array = xs[i]
					if xi[f] < th:
						cl[ys[i]] += 1
						nl += 1
					else:
						cr[ys[i]] += 1
				if nl == 0 or nl == n:
					continue
				var g := (nl * _gini(cl, nl) + (n - nl) * _gini(cr, n - nl)) / n
				if g < best_g:
					best_g = g
					bf = f
					bt = th
		if bf < 0:
			return node
		var li := PackedInt32Array()
		var ri := PackedInt32Array()
		for i in idx:
			var xi: PackedFloat32Array = xs[i]
			if xi[bf] < bt:
				li.append(i)
			else:
				ri.append(i)
		feat[node] = bf
		thr[node] = bt
		var l := _build(xs, ys, li, depth + 1, maxd, nf, nc)
		lo[node] = l
		var r := _build(xs, ys, ri, depth + 1, maxd, nf, nc)
		hi[node] = r
		return node

	func copy() -> DecisionTree:
		var t := DecisionTree.new()
		t.feat = feat.duplicate()
		t.thr = thr.duplicate()
		t.lo = lo.duplicate()
		t.hi = hi.duplicate()
		t.leaf = leaf.duplicate()
		return t

	func mutate(r: RandomNumberGenerator, chance: float, sigma: float) -> void:
		for i in feat.size():
			if feat[i] >= 0:
				if r.randf() < chance:
					thr[i] = clampf(thr[i] + r.randfn(0.0, sigma * 0.25), 0.0, 1.0)
			elif r.randf() < chance * 0.2:
				leaf[i] = r.randi_range(0, 4)

	func param_count() -> int:
		return feat.size()


# =============================================================================
#  LIFECYCLE
# =============================================================================
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	m_act.resize(N_ACT)
	_build_ui()
	_make_imitation_set()
	_build_plan()
	_rebuild_tables()
	_set_status("Ready — %d runs planned (%d simulated seconds each). Press Start." % [plan.size(), int(sim_seconds)])


func _process(delta: float) -> void:
	if not paused:
		match phase:
			Phase.PREPARE:
				_process_training()
			Phase.RUN:
				_process_run()
	live_timer += delta
	if live_timer > 0.2:
		live_timer = 0.0
		_update_live()
	sim_view.queue_redraw()


func _process_run() -> void:
	var t0 := Time.get_ticks_msec()
	var budget := 14 if render_chk.button_pressed else 40
	var steps := 0
	while steps < int(speed_slider.value) and Time.get_ticks_msec() - t0 < budget:
		_sim_step(DT)
		steps += 1
		if sim_time >= sim_seconds:
			_finish_run()
			return


# =============================================================================
#  ORACLE + IMITATION DATA
# =============================================================================
## Hand-written reference policy used as teacher for NN and Decision Tree.
static func _oracle(s: PackedFloat32Array) -> int:
	var hunger := s[S_HUNGER]
	var energy := s[S_ENERGY]
	var food := s[S_FOOD]
	var danger := s[S_DANGER]
	var crowd := s[S_CROWD]
	if danger > 0.4 and energy > 0.08:
		return Act.FLEE
	if hunger > 0.6:
		return Act.SEEK_FOOD  # seeking with no food in sight = exploring
	if energy < 0.3 and danger < 0.05:
		return Act.REST
	if hunger > 0.3 and food > 0.25:
		return Act.SEEK_FOOD
	if crowd > 0.12:
		return Act.FLOCK
	return Act.WANDER


func _make_imitation_set() -> void:
	X.clear()
	Y.clear()
	var r := RandomNumberGenerator.new()
	r.seed = base_seed + 999
	for i in imitation_samples:
		var x := PackedFloat32Array([
			r.randf(),
			r.randf(),
			0.0 if r.randf() < 0.4 else r.randf(),
			0.0 if r.randf() < 0.5 else r.randf(),
			0.0 if r.randf() < 0.35 else r.randf() * 0.8,
		])
		X.append(x)
		Y.append(_oracle(x))


# =============================================================================
#  BENCHMARK PLAN
# =============================================================================
func _sizes_for(ai: int) -> Array[int]:
	match ai:
		AI.NEURAL_NET:
			return nn_neurons
		AI.UTILITY:
			return utility_considerations
	return tree_depths


func _size_label(ai: int, size: int) -> String:
	match ai:
		AI.NEURAL_NET:
			return "%d×%d neurons" % [maxi(1, nn_hidden_layers), size]
		AI.UTILITY:
			return "%d consid./action" % clampi(size, 1, 4)
	return "depth %d" % size


func _build_plan() -> void:
	plan.clear()
	var enabled := [run_neural_net, run_utility_ai, run_decision_tree]
	for ai in 3:
		if not enabled[ai]:
			continue
		var sizes := _sizes_for(ai)
		for si in sizes.size():
			for n in agent_counts:
				for rep in maxi(1, repeats):
					plan.append({"ai": ai, "size_i": si, "size": sizes[si], "agents": n, "rep": rep})


func _on_start() -> void:
	templates.clear()
	results.clear()
	_build_plan()
	_rebuild_tables()
	if plan.is_empty():
		_set_status("Nothing to run — enable at least one AI and one agent count.")
		return
	paused = false
	pause_btn.text = "Pause"
	start_btn.text = "↻ Restart"
	plan_i = 0
	_begin_config()


func _begin_config() -> void:
	cfg = plan[plan_i]
	var ai: int = cfg["ai"]
	var size: int = cfg["size"]
	cfg_key = "%d|%d" % [ai, cfg["size_i"]]
	if templates.has(cfg_key):
		_start_world()
		return
	match ai:
		AI.NEURAL_NET:
			var sizes := PackedInt32Array([N_IN])
			for l in maxi(1, nn_hidden_layers):
				sizes.append(size)
			sizes.append(N_ACT)
			var r := RandomNumberGenerator.new()
			r.seed = base_seed + 77
			train_net = NeuralNet.new()
			train_net.init_random(sizes, r)
			train_order = range(X.size())
			train_cursor = 0
			train_total = X.size() * maxi(1, nn_epochs)
			phase = Phase.PREPARE
			return
		AI.UTILITY:
			var u := UtilityAI.new()
			u.setup(size, UTILITY_DESIGN, UTILITY_WEIGHTS)
			_store_template(u)
		AI.DECISION_TREE:
			var t := DecisionTree.new()
			t.fit(X, Y, size, N_IN, N_ACT)
			_store_template(t)
	_start_world()


func _process_training() -> void:
	var t0 := Time.get_ticks_msec()
	var n := X.size()
	var r := RandomNumberGenerator.new()
	r.seed = base_seed + train_cursor
	while train_cursor < train_total and Time.get_ticks_msec() - t0 < 30:
		var k := train_cursor % n
		if k == 0:
			# Fisher–Yates shuffle each epoch
			for i in range(n - 1, 0, -1):
				var j := r.randi_range(0, i)
				var tmp = train_order[i]
				train_order[i] = train_order[j]
				train_order[j] = tmp
		var idx: int = train_order[k]
		train_net.train_one(X[idx], Y[idx], nn_learning_rate)
		train_cursor += 1
	if train_cursor >= train_total:
		_store_template(train_net)
		_start_world()


func _store_template(brain) -> void:
	var agree := 0
	for i in X.size():
		if brain.decide(X[i]) == Y[i]:
			agree += 1
	templates[cfg_key] = {
		"brain": brain,
		"agree": float(agree) / maxi(1, X.size()),
		"params": brain.param_count(),
	}


# =============================================================================
#  WORLD
# =============================================================================
func _start_world() -> void:
	var n: int = cfg["agents"]
	rng.seed = base_seed + int(cfg["rep"]) * 7919  # same world seed for every AI
	sim_time = 0.0
	food_timer = 0.0
	agents.clear()
	dangers.clear()
	food_pos.clear()
	food_vel.clear()
	var tmpl = templates[cfg_key]["brain"]
	for i in n:
		var a := Agent.new()
		a.brain = tmpl.copy() if evolve_on_respawn else tmpl
		_reset_agent(a)
		a.hunger = rng.randf_range(0.0, 0.5)
		agents.append(a)
	for i in danger_count:
		var d := Danger.new()
		_reset_danger(d, false)
		dangers.append(d)
	for i in food_cap / 2:
		_spawn_food()
	m_food = 0; m_d_pred = 0; m_d_starve = 0
	m_agent_secs = 0.0; m_hunger = 0.0; m_crowd = 0.0
	m_act.fill(0.0)
	m_us = 0; m_dec = 0
	live_food = 0; live_pred = 0; live_starve = 0
	phase = Phase.RUN


func _reset_agent(a: Agent) -> void:
	a.pos = Vector2(rng.randf() * world_size.x, rng.randf() * world_size.y)
	a.wander = rng.randf() * TAU
	a.vel = Vector2.from_angle(a.wander) * 20.0
	a.hunger = rng.randf_range(0.0, 0.2)
	a.energy = 1.0
	a.age = 0.0
	a.food = 0
	a.action = Act.WANDER
	a.near_food = -1
	a.flee_dir = Vector2.ZERO
	a.sensors = PackedFloat32Array([a.hunger, a.energy, 0.0, 0.0, 0.0])


func _reset_danger(d: Danger, at_edge: bool) -> void:
	if at_edge:
		if rng.randf() < 0.5:
			d.pos = Vector2(rng.randf() * world_size.x, 0.0 if rng.randf() < 0.5 else world_size.y)
		else:
			d.pos = Vector2(0.0 if rng.randf() < 0.5 else world_size.x, rng.randf() * world_size.y)
	else:
		d.pos = Vector2(rng.randf() * world_size.x, rng.randf() * world_size.y)
	d.heading = rng.randf() * TAU
	d.vel = Vector2.ZERO
	d.life = rng.randf_range(danger_lifetime.x, danger_lifetime.y)
	d.cooldown = 1.0


func _spawn_food() -> void:
	food_pos.append(Vector2(rng.randf() * world_size.x, rng.randf() * world_size.y))
	food_vel.append(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 1.0) * food_drift_speed)


func _wrap(p: Vector2) -> Vector2:
	return Vector2(fposmod(p.x, world_size.x), fposmod(p.y, world_size.y))


func _sim_step(dt: float) -> void:
	sim_time += dt
	var measuring := sim_time > warmup_seconds
	_update_food(dt)
	_update_dangers(dt)
	_build_grid()
	for a in agents:
		_perceive(a)
	# --- the only part that is timed: the AI decisions
	var t0 := Time.get_ticks_usec()
	for a in agents:
		a.action = a.brain.decide(a.sensors)
	var t1 := Time.get_ticks_usec()
	# ---
	var taken := PackedByteArray()
	taken.resize(food_pos.size())
	for i in agents.size():
		_act(i, dt, measuring, taken)
	for fi in range(food_pos.size() - 1, -1, -1):
		if taken[fi] == 1:
			food_pos.remove_at(fi)
			food_vel.remove_at(fi)
	if measuring:
		m_us += t1 - t0
		m_dec += agents.size()
		m_agent_secs += agents.size() * dt


func _update_food(dt: float) -> void:
	food_timer += dt * food_spawn_per_sec
	while food_timer >= 1.0:
		food_timer -= 1.0
		if food_pos.size() < food_cap:
			_spawn_food()
	for k in food_pos.size():
		food_pos[k] = _wrap(food_pos[k] + food_vel[k] * dt)


func _update_dangers(dt: float) -> void:
	for d in dangers:
		d.life -= dt
		d.cooldown = maxf(0.0, d.cooldown - dt)
		if d.life <= 0.0:
			_reset_danger(d, true)
			continue
		var has := false
		var target := Vector2.ZERO
		if d.cooldown <= 0.0:
			var best := danger_chase_radius * danger_chase_radius
			for a in agents:
				var d2: float = d.pos.distance_squared_to(a.pos)
				if d2 < best:
					best = d2
					target = a.pos
					has = true
		var desired: Vector2
		if has:
			desired = (target - d.pos).normalized() * danger_speed
		else:
			d.heading += rng.randf_range(-2.0, 2.0) * dt
			desired = Vector2.from_angle(d.heading) * danger_speed * 0.45
		d.vel = d.vel.lerp(desired, minf(1.0, 2.5 * dt))
		d.pos = _wrap(d.pos + d.vel * dt)


func _build_grid() -> void:
	grid.clear()
	for i in agents.size():
		var p: Vector2 = agents[i].pos
		var key := Vector2i(floori(p.x / NEIGH_R), floori(p.y / NEIGH_R))
		if grid.has(key):
			grid[key].append(i)
		else:
			grid[key] = [i]


func _perceive(a: Agent) -> void:
	a.neighbors.clear()
	var cx := floori(a.pos.x / NEIGH_R)
	var cy := floori(a.pos.y / NEIGH_R)
	for gx in range(cx - 1, cx + 2):
		for gy in range(cy - 1, cy + 2):
			var cell = grid.get(Vector2i(gx, gy))
			if cell == null:
				continue
			for j in cell:
				var o: Agent = agents[j]
				if o != a and a.pos.distance_squared_to(o.pos) < NEIGH_R * NEIGH_R:
					a.neighbors.append(j)
	# nearest food
	var best := SENSE_R * SENSE_R
	a.near_food = -1
	for fi in food_pos.size():
		var d2: float = a.pos.distance_squared_to(food_pos[fi])
		if d2 < best:
			best = d2
			a.near_food = fi
	var food_prox := 0.0 if a.near_food < 0 else 1.0 - sqrt(best) / SENSE_R
	# dangers
	a.flee_dir = Vector2.ZERO
	var dprox := 0.0
	for d in dangers:
		var off: Vector2 = a.pos - d.pos
		var dist := off.length()
		if dist < SENSE_R and dist > 0.001:
			var p := 1.0 - dist / SENSE_R
			dprox = maxf(dprox, p)
			a.flee_dir += off / dist * p
	a.sensors = PackedFloat32Array([a.hunger, a.energy, food_prox, dprox, minf(1.0, a.neighbors.size() / 8.0)])


func _wander_dir(a: Agent, dt: float) -> Vector2:
	a.wander += rng.randf_range(-3.0, 3.0) * dt
	return Vector2.from_angle(a.wander)


func _flock_dir(a: Agent, dt: float) -> Vector2:
	var n := a.neighbors.size()
	if n == 0:
		return _wander_dir(a, dt)
	var sep := Vector2.ZERO
	var ali := Vector2.ZERO
	var coh := Vector2.ZERO
	for j in a.neighbors:
		var o: Agent = agents[j]
		var d: Vector2 = a.pos - o.pos
		var dist := d.length()
		if dist < SEP_R and dist > 0.01:
			sep += d / dist * (1.0 - dist / SEP_R)
		ali += o.vel.normalized()
		coh += o.pos
	ali = (ali / n).normalized()
	coh = (coh / n - a.pos).normalized()
	var dir := sep * 2.0 + ali + coh * 0.8
	a.wander = dir.angle()
	return dir.normalized()


func _act(i: int, dt: float, measuring: bool, taken: PackedByteArray) -> void:
	var a: Agent = agents[i]
	var mult: float = ACT_SPEED[a.action]
	var dir := Vector2.ZERO
	match a.action:
		Act.WANDER:
			dir = _wander_dir(a, dt)
		Act.FLOCK:
			dir = _flock_dir(a, dt)
		Act.SEEK_FOOD:
			if a.near_food >= 0:
				dir = (food_pos[a.near_food] - a.pos).normalized()
				a.wander = dir.angle()
			else:
				dir = _wander_dir(a, dt)  # explore
		Act.FLEE:
			if a.flee_dir.length_squared() > 0.0001:
				dir = a.flee_dir.normalized()
				a.wander = dir.angle()
			else:
				dir = _wander_dir(a, dt)
		Act.REST:
			dir = Vector2.ZERO
	if a.energy < 0.05:
		mult = minf(mult, 0.5)
	a.vel = a.vel.lerp(dir * BASE_SPEED * mult, minf(1.0, 5.0 * dt))
	a.pos = _wrap(a.pos + a.vel * dt)
	var sr := a.vel.length() / BASE_SPEED
	var regen := 0.25 if a.action == Act.REST else 0.03
	a.energy = clampf(a.energy + (regen - 0.10 * sr * sr) * dt, 0.0, 1.0)
	a.hunger += HUNGER_RATE * (0.7 + 0.3 * sr) * dt
	a.age += dt
	# eat
	if a.near_food >= 0 and taken[a.near_food] == 0 and a.hunger > 0.1 \
			and a.pos.distance_to(food_pos[a.near_food]) < EAT_R:
		taken[a.near_food] = 1
		a.hunger = maxf(0.0, a.hunger - FOOD_VALUE)
		a.food += 1
		live_food += 1
		if measuring:
			m_food += 1
	# death
	var cause := 0
	for d in dangers:
		if d.cooldown <= 0.0 and a.pos.distance_squared_to(d.pos) < KILL_R * KILL_R:
			d.cooldown = 2.0  # predator "eats" then pauses
			cause = 1
			break
	if cause == 0 and a.hunger >= 1.0:
		cause = 2
	if measuring:
		m_hunger += a.hunger * dt
		m_crowd += a.neighbors.size() * dt
		m_act[a.action] += dt
	if cause != 0:
		if cause == 1:
			live_pred += 1
			if measuring:
				m_d_pred += 1
		else:
			live_starve += 1
			if measuring:
				m_d_starve += 1
		_respawn(i)


func _respawn(i: int) -> void:
	var a: Agent = agents[i]
	var n := agents.size()
	if evolve_on_respawn and n > 1:
		# tournament selection (size 3) on fitness = food*10 + age
		var parent: Agent = null
		var best_fit := -1.0
		for t in 3:
			var j := rng.randi_range(0, n - 1)
			if j == i:
				j = (j + 1) % n
			var o: Agent = agents[j]
			var fit := o.food * 10.0 + o.age
			if fit > best_fit:
				best_fit = fit
				parent = o
		a.brain = parent.brain.copy()
		a.brain.mutate(rng, mutation_chance, mutation_sigma)
	_reset_agent(a)


func _finish_run() -> void:
	var deaths := m_d_pred + m_d_starve
	var agent_min := maxf(m_agent_secs / 60.0, 0.0001)
	var secs := maxf(m_agent_secs, 0.0001)
	var tot_act := 0.0
	for v in m_act:
		tot_act += v
	var mix := PackedFloat32Array()
	for v in m_act:
		mix.append(v / maxf(tot_act, 0.0001))
	var food_rate := m_food / agent_min
	var death_rate := deaths / agent_min
	var tmpl: Dictionary = templates[cfg_key]
	results.append({
		"ai": cfg["ai"], "size_i": cfg["size_i"], "size": cfg["size"],
		"agents": cfg["agents"], "rep": cfg["rep"],
		"params": tmpl["params"], "agree": tmpl["agree"],
		"score": food_rate - death_penalty * death_rate,
		"food_rate": food_rate,
		"death_rate": death_rate,
		"pred_pct": 100.0 * m_d_pred / maxi(1, deaths),
		"lifespan": m_agent_secs / maxi(1, deaths),
		"no_deaths": deaths == 0,
		"hunger": m_hunger / secs,
		"crowd": m_crowd / secs,
		"us": float(m_us) / maxi(1, m_dec),
		"mix": mix,
	})
	_rebuild_tables()
	plan_i += 1
	if plan_i >= plan.size():
		phase = Phase.DONE
		progress.value = 100.0
		start_btn.text = "▶ Start benchmark"
		tabs.current_tab = 0
		_set_status("Done — %d runs. See Summary / Details, or Export CSV." % results.size())
	else:
		_begin_config()


# =============================================================================
#  UI
# =============================================================================
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.045, 0.05, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	sim_view = Control.new()
	sim_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sim_view.size_flags_stretch_ratio = 1.2
	sim_view.clip_contents = true
	sim_view.draw.connect(_draw_sim)
	root.add_child(sim_view)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 540
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.085, 0.095, 0.115)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "AI benchmark — Neural Net vs Utility AI vs Decision Tree"
	title.add_theme_font_size_override("font_size", 18)
	v.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	start_btn = _button("▶ Start benchmark", _on_start)
	row.add_child(start_btn)
	pause_btn = _button("Pause", _on_pause)
	row.add_child(pause_btn)
	row.add_child(_button("Export CSV", _on_export))
	render_chk = CheckBox.new()
	render_chk.text = "Render"
	render_chk.button_pressed = true
	row.add_child(render_chk)

	var srow := HBoxContainer.new()
	v.add_child(srow)
	var sl := Label.new()
	sl.text = "Sim steps / frame"
	srow.add_child(sl)
	speed_slider = HSlider.new()
	speed_slider.min_value = 1
	speed_slider.max_value = 400
	speed_slider.value = max_steps_per_frame
	speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	srow.add_child(speed_slider)
	speed_lbl = Label.new()
	speed_lbl.custom_minimum_size.x = 40
	speed_lbl.text = str(int(speed_slider.value))
	speed_slider.value_changed.connect(func(val: float) -> void: speed_lbl.text = str(int(val)))
	srow.add_child(speed_lbl)

	progress = ProgressBar.new()
	progress.max_value = 100.0
	v.add_child(progress)

	status_lbl = Label.new()
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(status_lbl)

	live_lbl = Label.new()
	live_lbl.add_theme_font_size_override("font_size", 13)
	live_lbl.add_theme_color_override("font_color", Color(0.7, 0.74, 0.8))
	live_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(live_lbl)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)

	var s1 := ScrollContainer.new()
	s1.name = "Summary"
	tabs.add_child(s1)
	summary_box = VBoxContainer.new()
	summary_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_box.add_theme_constant_override("separation", 6)
	s1.add_child(summary_box)

	var s2 := ScrollContainer.new()
	s2.name = "Details"
	tabs.add_child(s2)
	details_box = VBoxContainer.new()
	s2.add_child(details_box)

	var s3 := ScrollContainer.new()
	s3.name = "About"
	s3.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(s3)
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 13)
	info.text = _about_text()
	s3.add_child(info)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _on_pause() -> void:
	paused = not paused
	pause_btn.text = "Resume" if paused else "Pause"


func _set_status(t: String) -> void:
	status_lbl.text = t


func _update_live() -> void:
	match phase:
		Phase.PREPARE:
			var p := float(train_cursor) / maxi(1, train_total)
			_set_status("Run %d/%d — training %s %s by imitation… %d%%" % [
				plan_i + 1, plan.size(), AI_NAMES[cfg["ai"]],
				_size_label(cfg["ai"], cfg["size"]), int(p * 100)])
			progress.value = 100.0 * (plan_i + p * 0.1) / plan.size()
		Phase.RUN:
			var counts := PackedInt32Array()
			counts.resize(N_ACT)
			for a in agents:
				counts[a.action] += 1
			var mix := ""
			for k in N_ACT:
				mix += "%s %d%%  " % [ACT_SHORT[k], int(100.0 * counts[k] / maxi(1, agents.size()))]
			_set_status("Run %d/%d — %s · %s · %d agents · seed %d" % [
				plan_i + 1, plan.size(), AI_NAMES[cfg["ai"]],
				_size_label(cfg["ai"], cfg["size"]), cfg["agents"], cfg["rep"]])
			live_lbl.text = "t = %.0f / %.0f s%s · food eaten %d · deaths: danger %d, starvation %d\nDecision cost %.2f µs/agent · actions now: %s" % [
				sim_time, sim_seconds, " (warm-up)" if sim_time <= warmup_seconds else "",
				live_food, live_pred, live_starve,
				float(m_us) / maxi(1, m_dec), mix]
			progress.value = 100.0 * (plan_i + sim_time / sim_seconds) / plan.size()
		_:
			live_lbl.text = ""


# ----------------------------------------------------------------- drawing
func _draw_sim() -> void:
	var vs := sim_view.size
	var sc := minf(vs.x / world_size.x, vs.y / world_size.y) * 0.97
	var o := (vs - world_size * sc) * 0.5
	var font := ThemeDB.fallback_font
	sim_view.draw_rect(Rect2(o, world_size * sc), Color(0.07, 0.08, 0.1))
	sim_view.draw_rect(Rect2(o, world_size * sc), Color(0.2, 0.22, 0.27), false, 1.0)
	if phase != Phase.RUN or not render_chk.button_pressed:
		var msg := "Rendering off (faster)" if phase == Phase.RUN else \
			("Training…" if phase == Phase.PREPARE else "Press  ▶ Start benchmark")
		sim_view.draw_string(font, o + Vector2(20, 40), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 0.72, 0.78))
		return
	var s := maxf(sc, 0.6)
	for p in food_pos:
		sim_view.draw_circle(o + p * sc, 3.5 * s, Color(0.35, 0.85, 0.3))
	for d in dangers:
		var c := o + d.pos * sc
		sim_view.draw_arc(c, danger_chase_radius * sc, 0.0, TAU, 40, Color(1, 0.25, 0.2, 0.12), 1.0)
		sim_view.draw_circle(c, 11.0 * s, Color(0.9, 0.18, 0.15) if d.cooldown <= 0.0 else Color(0.5, 0.15, 0.15))
	for a in agents:
		var c := o + a.pos * sc
		var f := a.vel.normalized() if a.vel.length_squared() > 1.0 else Vector2.from_angle(a.wander)
		var r := 6.0 * s
		var pts := PackedVector2Array([c + f * r * 1.5, c + f.rotated(2.5) * r, c + f.rotated(-2.5) * r])
		var col: Color = ACT_COLORS[a.action]
		sim_view.draw_colored_polygon(pts, col.darkened(a.hunger * 0.6))
	# legend
	var lp := o + Vector2(10, world_size.y * sc - 12)
	for k in N_ACT:
		sim_view.draw_rect(Rect2(lp + Vector2(0, -10), Vector2(10, 10)), ACT_COLORS[k])
		sim_view.draw_string(font, lp + Vector2(14, 0), ACT_NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.85))
		lp.x += 90
	sim_view.draw_circle(lp + Vector2(5, -5), 5, Color(0.35, 0.85, 0.3))
	sim_view.draw_string(font, lp + Vector2(14, 0), "Food", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.85))
	lp.x += 60
	sim_view.draw_circle(lp + Vector2(5, -5), 5, Color(0.9, 0.18, 0.15))
	sim_view.draw_string(font, lp + Vector2(14, 0), "Danger", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.85))
	sim_view.draw_string(font, o + Vector2(10, 22), "%s · %s · %d agents   (darker = hungrier)" % [
		AI_NAMES[cfg["ai"]], _size_label(cfg["ai"], cfg["size"]), agents.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.9, 0.9, 0.95))


# ----------------------------------------------------------------- tables
func _cell(g: GridContainer, text: String, col := Color(0.85, 0.87, 0.9), tip := "") -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", col)
	if tip != "":
		l.tooltip_text = tip
		l.mouse_filter = Control.MOUSE_FILTER_PASS
	g.add_child(l)


func _new_grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 3)
	return g


func _rebuild_tables() -> void:
	for c in summary_box.get_children():
		c.queue_free()
	for c in details_box.get_children():
		c.queue_free()
	_add_pivot("Score  = food/agent/min − %.0f × deaths/agent/min   (higher = better)" % death_penalty, "score", "%.2f", true)
	_add_pivot("Estimated lifespan (s)   (higher = better)", "lifespan", "%.0f", true)
	_add_pivot("Food eaten per agent per minute   (higher = better)", "food_rate", "%.2f", true)
	_add_pivot("Deaths per agent per minute   (lower = better)", "death_rate", "%.3f", false)
	_add_pivot("Decision cost — µs per agent decision   (lower = better)", "us", "%.2f", false)
	_add_details()


func _add_pivot(title: String, metric: String, fmt: String, higher_better: bool) -> void:
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
	summary_box.add_child(t)

	# mean over repeats
	var sums := {}
	var cnts := {}
	for r in results:
		var k := "%d|%d|%d" % [r["ai"], r["size_i"], r["agents"]]
		sums[k] = sums.get(k, 0.0) + float(r[metric])
		cnts[k] = cnts.get(k, 0) + 1
	var rows: Array = []
	for p in plan:
		var rk := [p["ai"], p["size_i"], p["size"]]
		if not rows.has(rk):
			rows.append(rk)

	var g := _new_grid(3 + agent_counts.size())
	_cell(g, "AI", Color(0.6, 0.62, 0.68))
	_cell(g, "Size", Color(0.6, 0.62, 0.68))
	for n in agent_counts:
		_cell(g, "N=%d" % n, Color(0.6, 0.62, 0.68))
	_cell(g, "Avg", Color(0.6, 0.62, 0.68))

	# best / worst per column
	var best := {}
	var worst := {}
	for n in agent_counts:
		for rk in rows:
			var k := "%d|%d|%d" % [rk[0], rk[1], n]
			if not sums.has(k):
				continue
			var val: float = sums[k] / cnts[k]
			if not best.has(n) or (val > best[n] if higher_better else val < best[n]):
				best[n] = val
			if not worst.has(n) or (val < worst[n] if higher_better else val > worst[n]):
				worst[n] = val

	for rk in rows:
		_cell(g, AI_NAMES[rk[0]], AI_COLORS[rk[0]])
		_cell(g, _size_label(rk[0], rk[2]))
		var tot := 0.0
		var cnt := 0
		for n in agent_counts:
			var k := "%d|%d|%d" % [rk[0], rk[1], n]
			if sums.has(k):
				var val: float = sums[k] / cnts[k]
				tot += val
				cnt += 1
				var col := Color(0.85, 0.87, 0.9)
				if rows.size() > 1 and is_equal_approx(val, best[n]):
					col = Color(0.4, 1.0, 0.5)
				elif rows.size() > 1 and is_equal_approx(val, worst[n]):
					col = Color(1.0, 0.45, 0.4)
				_cell(g, fmt % val, col)
			else:
				_cell(g, "·", Color(0.4, 0.42, 0.46))
		_cell(g, (fmt % (tot / cnt)) if cnt > 0 else "·", Color(1, 1, 1) if cnt > 0 else Color(0.4, 0.42, 0.46))
	summary_box.add_child(g)
	var sp := Control.new()
	sp.custom_minimum_size.y = 8
	summary_box.add_child(sp)


const DETAIL_HEADERS := ["AI", "Size", "Params", "Agents", "Seed", "Score", "Food/ag/min",
	"Deaths/ag/min", "% by danger", "Lifespan s", "Hunger", "Neighbours",
	"µs/decision", "Oracle agree", "Action mix W/F/S/X/R %"]


func _add_details() -> void:
	var g := _new_grid(DETAIL_HEADERS.size())
	for h in DETAIL_HEADERS:
		_cell(g, h, Color(0.6, 0.62, 0.68))
	for r in results:
		var mix: PackedFloat32Array = r["mix"]
		var ms := ""
		for k in N_ACT:
			ms += "%d " % int(round(mix[k] * 100.0))
		_cell(g, AI_NAMES[r["ai"]], AI_COLORS[r["ai"]])
		_cell(g, _size_label(r["ai"], r["size"]))
		_cell(g, str(r["params"]))
		_cell(g, str(r["agents"]))
		_cell(g, str(r["rep"]))
		_cell(g, "%.2f" % r["score"])
		_cell(g, "%.2f" % r["food_rate"])
		_cell(g, "%.3f" % r["death_rate"])
		_cell(g, "%.0f%%" % r["pred_pct"])
		_cell(g, ("≥%.0f" if r["no_deaths"] else "%.0f") % r["lifespan"])
		_cell(g, "%.2f" % r["hunger"])
		_cell(g, "%.1f" % r["crowd"])
		_cell(g, "%.2f" % r["us"])
		_cell(g, "%.0f%%" % (r["agree"] * 100.0), Color(0.85, 0.87, 0.9),
			"Share of %d test situations where this AI picks the same action as the oracle policy" % X.size())
		_cell(g, ms)
	details_box.add_child(g)


func _on_export() -> void:
	var path := "user://ai_benchmark_results.csv"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_set_status("Could not write %s" % path)
		return
	f.store_line("ai,size_label,size,params,agents,seed,score,food_per_agent_min,deaths_per_agent_min,pct_by_danger,lifespan_s,avg_hunger,avg_neighbours,us_per_decision,oracle_agree,wander,flock,seek,flee,rest")
	for r in results:
		var mix: PackedFloat32Array = r["mix"]
		f.store_line("%s,%s,%d,%d,%d,%d,%.4f,%.4f,%.4f,%.1f,%.1f,%.4f,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f" % [
			AI_NAMES[r["ai"]], _size_label(r["ai"], r["size"]), r["size"], r["params"],
			r["agents"], r["rep"], r["score"], r["food_rate"], r["death_rate"],
			r["pred_pct"], r["lifespan"], r["hunger"], r["crowd"], r["us"], r["agree"],
			mix[0], mix[1], mix[2], mix[3], mix[4]])
	f.close()
	_set_status("Saved %s" % ProjectSettings.globalize_path(path))


func _about_text() -> String:
	return """ACTIONS (one species)
• Wander — random walk at 60% speed.
• Flock — boids: separation + alignment + cohesion with neighbours.
• Seek food — steer to nearest food; with none in sight it explores.
• Flee — sprint (150% speed) away from nearby dangers; drains energy.
• Rest — stop and recover energy (extra action: stamina trade-off).

WORLD (no AI)
• Food spawns regularly up to a cap and drifts slowly. Eating lowers hunger.
• Dangers wander, chase the nearest agent in range, pause after a kill,
  and despawn / respawn at the map edge after a random lifetime.
• Agents die by danger contact or starvation; they respawn immediately so the
  population stays constant (needed to compare agent counts).

SENSORS (identical for every AI): hunger, energy, food proximity,
danger proximity, neighbour density.

AI SIZE
• Neural Net: hidden layers × neurons. Trained by imitation of the oracle.
• Utility AI: number of response-curve considerations per action (1–4).
• Decision Tree: max depth, trained by CART imitation of the oracle.

EVOLUTION: when an agent dies it respawns as a mutated copy of the fittest of
3 random survivors (same mechanism for all AIs). Toggle in Inspector.

METRICS (after warm-up)
• Score = food/agent/min − penalty × deaths/agent/min.
• Lifespan = agent-seconds ÷ deaths (≥ means no death was observed).
• µs/decision = wall-clock time of the decide() call only (sensors excluded).
• Oracle agree = how closely the AI matches the hand-written reference policy.
Every AI faces the same world seed for a given repeat.
"""
