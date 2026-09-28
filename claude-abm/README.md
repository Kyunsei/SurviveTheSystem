# Claude ABM: a GPU-evolved ecosystem with 1M agents

A Godot 4.6 agent-based model where up to **1,000,000 agents** live, eat, hunt, flee,
breed and evolve on a toroidal island world, alongside **millions of individually
simulated plants** that grow, compete for light, flower, get pollinated and spread
their seeds (by wind, or in the guts of the animals that eat their fruit). Every
agent runs its own brain, either a
**utility AI** or a **neural network**, and you can run either kind alone or have
both compete in the same world.

The whole simulation runs in GLSL compute shaders ([shaders/sim.comp](shaders/sim.comp)).
GDScript only dispatches kernels and reads back small buffers.

There are two views of the same simulation, chosen from a launcher menu:

- **2D Overview**: the whole world from above, with every agent as a pixel, live
  graphs and ecology sliders.
- **3D Explorer**: walk the world in first or third person among the creatures, and
  scare, lure, feed, hunt, breed or follow them.

**There are no population caps.** Sunlight falls on every square metre of land,
plants turn it into biomass, animals eat the plants and each other, and every
living thing pays energy for the GPU work it causes. Populations settle where the
energy runs out (see [Energy](#energy-sunlight-in-gpu-work-out)); the GPU storage
simply grows when they approach it. In the default 8.2 km world a typical run
settles around 75k-130k animals and 5.7M plants. Measured on an Intel integrated
GPU (Vulkan): 50-120 ticks/s for that world, and ~60 ticks/s with 1M live agents
(animals only). A discrete GPU should be several times faster.

## Running

Open the folder in Godot 4.6 and press Play. The launcher lets you pick the brain
type, world size, population and seed, and then open either view. **Esc** returns to
the launcher from both views. To skip the menu:

```bash
godot --path . -- --view=3d --pop=400000 --mode=mixed
```

Command-line options (after `--`):

| Option | Meaning |
|---|---|
| `--view=2d\|3d` | open a view directly instead of the menu |
| `--capacity=N` | starting animal storage (default 300,000; grows as needed, up to 2M) |
| `--plants=N` | starting plant storage (default 6,000,000; grows as needed, up to 12M; the world starts with half) |
| `--sun_energy=X` | sunlight per m2 of land per tick (default 0.001) |
| `--compute_cost=X` | energy per unit of GPU work (default 0.0006) |
| `--world=N` | grid size in cells per side, 512 to 4096 (default 1024) |
| `--cell=M` | metres per cell (default 8, so an 8.2 km world) |
| `--pop=N` | starting animal population (default 60,000) |
| `--mode=utility\|neural\|mixed` | brain type(s) of the founders |
| `--steps=N` | simulation ticks per rendered frame |
| `--seed=N` | world/founder seed |
| `--<param>=X` | any ecology parameter, e.g. `--plant_growth=0.2` |
| `--bench=SECONDS` | print stats to stdout, save a screenshot, then quit |
| `--profile=1` | print GPU timings |
| `--autotest=1` | (3D, with `--bench`) follow, feed, breed and strike the nearest agent and print the results |
| `--hide=creatures,grass,trees,shadows,terrain,sim` | (3D) switch parts off to measure their cost |
| `--seektree=1` | (3D, with `--bench`) move next to the nearest inland tree after 3 s |
| `--savetest=1`, `--growtest=1`, `--switchtest=1` | dev checks: save/load, storage growth, view switching |

**Starting from an evolved world**: in the launcher, **Pre-evolve** fast-forwards a
new world (2k to 20k ticks, about 75 ticks/s) before the view opens. You can also
**Save world** at any time (2D panel, or the 3D Esc menu). A save holds the live
agents with their genomes and brains, plants and carrion, settings and tick, as one
compressed file in `user://worlds` (~120 MB with 6M plants, about 1 s). The launcher
lists saved worlds with **Load in 2D / 3D**, and a loaded world resumes at its saved
tick. (Saves from before individual plants, format 1, no longer load.)

**Switching views during a run**: there is one simulation (owned by the `Launch`
autoload) and the views only look at it, so switching never restarts the world.
Press **Tab** in 2D to walk the centre of the map in 3D; press **Tab** in 3D to return
to the map, centred on where you stood. The world also keeps running in the menu.
Opening a view from the menu continues it, unless you changed the settings there,
which starts a new world. (`--switchtest=1` is a scripted 2D to 3D to 2D check.)

**2D controls**: drag to pan, mouse wheel to zoom, `F` to fit the view, `Space` to
pause, `R` to reset, `1` to `5` to change the colour mode, `+`/`-` to change ticks per
frame. The side panel has live sliders for the ecology and evolution parameters.

**3D controls**

| Key | Action |
|---|---|
| WASD / Shift / Space | walk / sprint / jump (you swim across lakes) |
| Mouse, wheel | look, zoom the third-person camera |
| V | first / third person |
| Left click | strike the creature under the crosshair (within 6 m); it dies and leaves carrion |
| Right click | feed it (+4 energy) |
| C | breed 8 mutated clones of it (within 20 m), i.e. selective breeding |
| T | follow it (orbit camera that survives the GPU re-sorting); T again to stop |
| E | sow grass and flowers around you (24 seedlings within 8 m) |
| G | presence: invisible, **predator** (they flee), **lure** (the last inspected species treats you as kin and flocks to you), **prey** (predators hunt you, and you have health) |
| 1 to 5 | colour mode (species, diet, brain, action, energy) |
| `[` `]` / P | simulation speed / pause |
| Tab | switch to the 2D map (the world keeps running) |
| H / Esc | help / menu (sim speed, view distance, colours, reset, main menu) |

Aiming at a creature shows its card: diet class, brain type, what it is doing, energy,
age, generation and its genes (plus the utility weights for utility agents).
Carnivores grow horns, and hunting creatures have glowing red eyes. Every plant you
see is a simulated individual: its size is its biomass, flowers open in its bloom
season and fruit hangs on it when ripe.

> The project uses the **Vulkan** backend on Windows. Godot's D3D12 backend fails to
> create some of these compute pipelines (`CreateComputePipelineState` returns
> E_INVALIDARG).

## The world

- **Scale**: the world is a grid of 8 m cells (1024 x 1024, 8.2 km across by default)
  used for terrain, fertility, carrion and the plant index. Animals and plants have
  continuous positions in metres.
- **Terrain**: seamless fractal noise generates lakes and hills (relief grows with the
  world size). Lakes block movement and create barriers for speciation. Land
  fertility varies, and shores are fertile.
- **Carrion**: dead agents leave their body energy as meat, which slowly decays.

### Plants: every individual is simulated

Plants are a second, immobile population. Each has a position, biomass, root
reserve, age and eight genes. A grass or flower individual is one clonal patch
(genet) about 4 m across, a bush ~5 m and a tree ~8 m, which is what lets several
million individuals cover an 8 km world:

| Gene | Effect |
|---|---|
| stature | growth form: **grass** (< 0.25), **flowers**, **bushes** (0.45+), **trees** (0.7+). Taller forms store far more, live far longer and mature later |
| growth | growth rate (fast growers stay smaller) |
| defence | chemical defence: slows growth, and makes the plant worth less to animals whose **detox** gene is lower |
| hue | lineage colour (leaf tint, petal colour, conifer vs broadleaf) |
| seed size | big seeds cope with shade and crowding; small ones fly further |
| dispersal | wind seeds, or **fruit** eaten by animals |
| bloom phase | when in the season the plant flowers |
| roots | share of growth stored below ground, to resprout after grazing |

**Life cycle** (1/8 of the plants are updated each tick):
- **Sunlight**: every m2 of land receives **Sun energy** per tick (more in summer).
  Each cell keeps a 3-layer canopy map (ground, shrub, tree) built from every
  plant's crown. A plant captures the light that reaches its layer over its crown
  area, shared out when its layer is over-full; small plants are also limited by
  their leaf mass. It pays respiration on its biomass (fast growers respire more,
  wood less) and the energy of its GPU work; the rest goes to roots and shoots.
  In too much shade the balance turns negative: the plant lives on its roots, then
  shrinks and dies.
- **Grazing and resprouting**: animals eat plants they can reach (browse height grows
  with body size, so grown trees are out of reach but saplings are not). A grazed
  plant regrows from its root reserve. It dies of old age, or when nothing is left
  above or below ground.
- **Flowering and pollination**: mature plants flower in their own part of the season.
  Grass and trees are **wind-pollinated** by a compatible neighbour in bloom within
  15 m. Showy flowers mostly rely on **animals**, which drink nectar and carry pollen
  from flower to flower. Unpollinated seeds rarely work.
- **Seeds**: wind seeds land 2-32 m away (small seeds further). **Fruit** ripens on
  the plant; animals eat it, carry the seed in their gut and drop it somewhere else.
- **Clonal spread**: grasses (and, more slowly, flowers) also send out new plants
  next to themselves, with no pollen needed.
- **Establishment**: a seed only sprouts on land, with enough light and free ground.
- **Offspring** mix the mother's and the pollen donor's genes, and mutate.

The result is succession and a shifting mosaic of grassland, meadows, shrubland and
forest, with co-evolution between plant defence and animal detox. In 3D every plant
near you is drawn as a grass tussock, flowering plant, bush, or broadleaf or conifer
tree, scaled by its biomass.

## Agents

Each agent has a 24-gene genome:

| Gene | Effect |
|---|---|
| size | strength, bite size, lifespan, metabolic cost, body cost at birth |
| max speed | movement (cost grows with speed^2 x size) |
| diet | 0 = herbivore, 1 = carnivore. Digestion efficiency is `(1-diet)^1.25` for plants and `diet^1.25` for meat |
| repro threshold | energy needed to breed |
| mutation rate | evolvable mutation size |
| hue | neutral species marker (it drifts, and is used for kin recognition) |
| sense | vision of 5 + 8 x sense metres (9-29 m, costs energy) |
| detox | tolerance to plant defences (costs energy) |
| child fraction | share of energy given to each offspring |
| 12 utility weights + hunger curve | the utility AI's personality |
| alarm | how loudly a utility agent calls when it flees or hides |
| care | how much energy a parent gives its young |

Plus an int8 **neural network** (23 inputs + bias, 7 tanh hidden, 8 outputs, recurrent memory).

**Interactions**
- **Energy**: metabolism grows with size (resting costs 40% less), movement costs
  speed² x size, vision and detox are paid for, and so is the GPU work of thinking
  (see below). Digestion is asymmetric like in nature: plant biomass gives 50% of its
  energy, meat 100%.
- **Predation**: attacks deal damage scaled by power (`size x (0.4 + diet)`). Capture odds
  depend on predator vs prey *current* speed, and fall when many prey are in view
  (confusion effect, so herds protect). Satiated predators don't hunt.
- **Kin and species**: genetic distance (hue, diet, size) decides who is kin. Kin don't
  attack each other, can flock together, and can mate.
- **Reproduction**: sexual with a compatible neighbour (uniform crossover of genes *and*
  network weights), otherwise asexual. Mutation applies to both genes and weights. The
  parent pays for the child's energy and body.
- **Competition** for plants and carrion, and in mixed mode between brain types.

### Brains

**Utility AI**: twelve actions (graze, hunt, flee, flock, wander, rest, scavenge, hide,
care, mark, home, recall). Each is scored from considerations such as hunger, food,
threat and prey proximity, kin, carrion, alarm calls, young in need, scent marks and
remembered places, weighted by *evolvable* genes. The highest score wins.

**Neural network**: the inputs are energy, plant food (here/ahead/gradient, from the
individual plants in the nearest cells), carrion, threat/prey/kin proximity and bearing,
memory, age, noise, the loudest call heard and its bearing, family (for a young one its
parent, for a parent its young in need) and its bearing, a foreign scent ahead, our own
scent here, and the bearings of the remembered food place and home. The outputs are
turn, speed, attack, memory, call, posture, give and mark. Founders start with weak
hand-wired "instincts" (follow food, turn away from threats, chase prey if carnivorous,
call a little when afraid) plus noise, so they are viable from tick 0. Evolution is
free to rewrite them.

### Social behaviour

Five behaviour primitives, available to both brain types, each with a cost:

| Primitive | What it does | Behaviours it enables |
|---|---|---|
| **Call** | a call (0-1) heard by every agent within 1.5x vision; costs energy, and predators go for callers first | alarm calls (kin flee away from the caller), contact calls |
| **Posture** | hide: only noticed within 35 % of the usual range, cheap, slow. Display: looks 40 % stronger to others, costs energy | freezing, ambush, hiding from predators, bluffing |
| **Give** | a parent hands energy to its own young within 6 m (10 % lost) | feeding the young, parental care |
| **Scent mark** | leaves a mark of its lineage on the ground (fades over time); others sense foreign marks ahead | territories, patrolling; utility agents keep out of foreign ground |
| **Places** | remembers a home (den) and the last good food place; the young inherit the parent's food place | going home to rest (resting in the den is cheaper and hidden), returning to good food |

Young ones (their first 200 ticks) recognise their parent by its id and follow it;
parents recognise their young the same way. In a first run (seed 5, 3500 ticks) about
3 % of agents were calling at any time, 5 % hiding, 3 % displaying, 23 000 young
followed a parent, parents made ~60 gifts and ~25 scent marks per tick, and several
hundred agents were heading for a remembered food place or home. Colour mode *Action*
shows the new actions, and hiding creatures crouch in 3D. Saves are format 3; older
saves no longer load.

Brain type is inherited, and mating only happens within a brain type. In **Mixed**
mode, each of the 16 founder species is utility or neural (including one predator
species of each), so the two approaches compete directly.

## What you'll see

Typical runs show predator/prey oscillations, predator outbreaks and crashes, a speed
and size **arms race** when predators are strong, speciation by colour drift across
lakes, and brain types displacing each other. Colour modes: species hue, diet, brain
type, current action, energy.

Useful knobs: **Attack power** and **Meat efficiency** set how strong predators are
(too low and they go extinct; too high and they suppress prey and trigger an arms
race). **Sun energy** sets how much life the world holds; **Compute cost** sets how
much thinking costs; **Plant efficiency** sets how much of the plants reaches the animals. **Mutation scale** and **Species
distance** control evolution speed and how easily species split.

## Energy: sunlight in, GPU work out

Every tick the world receives `Sun energy x land area` (about 51k energy units in
the default world). Plants capture it (in a settled world ~95% of it), animals eat
part of the plants (plant biomass is worth 50% as animal energy), predators eat
animals, and everything pays upkeep. Nothing else creates energy, so the sunlight
sets how many plants and animals the world can hold.

**Thinking costs energy.** Each agent's THINK pass counts the GPU work it causes, in
units of about 1 ns of GPU time measured on an Intel iGPU:

| Work | Units |
|---|---|
| fixed part (load/store the agent and genome, move, register in the grid) | 8 |
| each plant record read while looking for food | 0.25 |
| each neighbour record read in the 3x3 bucket scan | 0.25 |
| utility brain (7 scores) | 0.5 |
| neural brain (36 weight words, 140 multiply-adds) | 8 |
| giving birth (mate search, genome copy; + weights for neural agents) | 25 / 40 |

This matches the measurement: ~18 ns per utility agent and ~26 per neural one per
tick. The agent pays `Compute cost x units` in energy, on top of metabolism,
movement, vision and detox. So a big vision range (more neighbours to scan), a
crowd, or a neural brain all cost food. A plant update costs 3 units (+0.2 per
neighbour checked for pollen, +1 per seed or clone placed), paid in biomass.

In a typical run animals spend ~20% of their energy on GPU work and plants ~3%.
Neural lineages, whose brains cost ~40% more GPU time, tend to lose ground to
utility ones unless their smarter behaviour earns it back.

The 2D panel shows the budget live: sun on land, how much plants capture and spend
on GPU work, and how much animals eat and spend on living and on GPU work.

**Storage grows by itself.** Agents and plants live in fixed-size GPU buffers, but
they are not a population limit: when a population passes 85% of its storage, the
world takes an in-memory snapshot and rebuilds its buffers 1.5x larger (a short
pause), up to safety limits of 2M agents and 12M plants for GPU memory. With the
default sunlight the plants grow from 6M to 9M slots once and then settle.

## How it reaches 1M agents

One tick is `THINK -> BIRTH -> FINALIZE -> COMMIT -> PLANT_TICK -> PLANT_FINALIZE ->
PLANT_COMMIT -> FIELD`:

- **One fat pass**: `THINK` is the only kernel that touches every agent. It handles
  damage, ageing and death, senses, the brain, movement, feeding and attacks, and
  registers the agent in the next tick's spatial hash. Deaths and breeders go to
  compact lists, so `BIRTH` and `FINALIZE` only touch those.
- **Spatial hash**: buckets sized to cover the longest vision (32 m), with 4-8 slots each. A slot stores
  `(index, packed position, phenotype, half2(energy, speed))`, so a neighbour scan is
  9 coherent bucket reads that never touch the agent array. There are two grids,
  swapped every tick.
- **Periodic spatial sort**: every 32 ticks, all agent storage is counting-sorted by
  bucket (prefix sum, then scatter). Consecutive threads then handle neighbouring
  agents, so memory access stays coherent. This alone made the brain pass about 3-4x
  faster at 1M agents.
- **Register-only brains**: the network is packed int8 `vec4` dot products with no local
  arrays, which avoids register spills on the GPU.
- **Slot allocation**: a free-slot stack with claim/commit phases; the sort also
  compacts live agents to the front.
- **Stats** use workgroup-shared reductions and are read back asynchronously.
- **Plants** use the same free-slot scheme. Every 16 ticks a counting sort orders
  them by cell and rebuilds a per-cell index, so animals find the plants in the
  cells around them (and wind pollination finds neighbours) with a few coherent
  reads. In 3D the index rebuild is spread over frames.

Memory at 1M capacity in a 2048^2 world is about 570 MB of GPU buffers: neural weights
144 MB, spatial-hash grids 136 MB, sort scratch 112 MB, genes 64 MB, agents 48 MB,
fields 48 MB. The largest single buffer is 112 MB. Going well above 1M may exceed
per-buffer limits on some GPUs. Plants add about 50 bytes each (about 300 MB for 6M,
including the sort scratch).

### The 3D explorer

- **No CPU work per agent.** Each frame a `NEARBY` kernel scans the agents, and writes
  those within the view distance (up to 32k) straight into the creature `MultiMesh`'s
  GPU buffer (`RenderingServer.multimesh_get_buffer_rd_rid`), with a transform
  interpolated between ticks, a colour and animation data. The CPU only reads back a
  short list of agents within 30 m for picking, the inspected agent, and the damage
  the player took. It also sets `visible_instance_count`, so unused instances cost
  nothing.
- **Smooth motion.** Every agent keeps its pose from before its last move, and the
  3D view interpolates from that to the current pose (position and heading) on a
  clock that follows the chunked ticks. It never extrapolates, so turns don't
  overshoot and snap back. The spatial sort rewrites these poses for the agents'
  new chunks so nothing jumps, and in 3D the sort runs every 128 ticks.
  (`--motiontest=1` with `--bench` follows an agent and reports frame-to-frame
  steps.)
- **Smooth frames.** In 3D each tick's `THINK` pass is split into 4 chunks run on
  different frames, and the periodic sort runs one step per frame, so no single frame
  carries a whole 1M-agent tick.
- **The player is part of the simulation.** At each tick start the `PLAYER` kernel
  registers the player in the spatial hash within 10 m, with a phenotype that makes
  agents see you as a predator, as kin (lure) or as prey. It also executes your
  command (strike, feed, food, follow, or clones via `SPAWN`). Commands carry the
  target's position, so an index that went stale after a sort is ignored.
- **Plants** work the same way: a `P_NEARBY` kernel walks the plant index in the
  cells around the player and writes grass (up to 70 m), flowers (90 m), bushes
  (120 m) and trees (260 m) into four GPU-filled MultiMeshes, sized by biomass.
- **Terrain and water** are flat grids that follow the player. Their shaders
  displace and colour them from the height map and the live field texture (ground
  cover, carrion). The player follows the CPU copy of the height map, and the world wraps
  like the simulation's torus.

Measured on the same Intel GPU: ~110 fps in 3D in open grassland and ~75 fps in
woodland (up to ~9k plants drawn), with the default world running.

## Unified Life (experimental)

A separate simulation, opened from its own card in the launcher (or
`--view=life`, `--view=life3d`, with `--life=seeded`). It has no plants and
animals: there is **one kind of organism**, and its body develops from a
body-plan genome.

**One body grammar for plants and animals.** Every body is an axis of 1-6
segments carrying up to 4 pairs of appendages, surfaces, feeding modules,
protection and sensors. Five continuous switches decide what that becomes:

| Switch | 0 | 1 |
|---|---|---|
| anchorage | free | rooted |
| axis | horizontal (moves forward) | vertical (grows up) |
| symmetry | bilateral | radial |
| growth | indeterminate (grows with energy) | determinate (adult form) |
| actuation | rigid appendages (branches) | muscular (legs, tentacles) |

So the same modules read as a branch or a leg, a leaf or a sail, a trap or a
jaw, bark or armour. A tree is rooted, upright, radial, indeterminate and rigid;
a grazer is free, horizontal, bilateral, determinate and muscular; creeping
vines, anemones (rooted, radial, muscular, with traps), walking trees and leafy
slugs are in between.

**Abilities come from the developed body.** Each update `develop()` turns genome,
age and energy into abilities: movement = muscular appendage power / (mass x
anchorage), sunlight = surfaces (upright bodies reach the higher canopy layers,
creeping ones spread wide), bite = feeding modules, defence = protection, vision
= sensors. Juveniles are smaller and weaker (determinate bodies grow up; the
others track their energy). Every module has an upkeep, and the GPU work is paid
in energy.

**Plant <-> animal transitions, both ways:**
- *gradually*: the switches and appendage genes drift every generation;
- *suddenly*: a rare macro-mutation (`organ_jump`) adds or removes a module (surfaces,
  feeding, sensors, brain), flips a switch (rooted <-> free, rigid <-> muscular,
  horizontal <-> vertical, bilateral <-> radial, determinate <-> indeterminate),
  adds an appendage pair, or adds / removes a life cycle;
- *within a life*: metamorphosis. At a genetic age anchorage and actuation take
  adult values, so a free larva settles and roots (like a coral or sea squirt), or a
  rooted juvenile breaks free.

Whenever a developed body crosses the movement threshold it takes legs (and a
brain, if its genes have one) from their pools, or gives them back. In a first
primordial run, rooted life-cycle lineages appeared that uproot as adults (about 3
organisms per tick broke free by tick 9000), and creeping forms spread widely.

**Only what an organism has costs memory and GPU time.** The core is 64 bytes
(position, energy, age and development, flags, 16 life-history genes, 16 body-plan
genes). Legs (24 bytes) and brains (144 bytes) come from pools. Mobile organisms
are processed every tick, sessile ones every 8 ticks; a brainless body skips the
network and an eyeless one only feels what touches it. A new brain starts wired
from the reflexes, so it is not worse than the reflexes it replaces.

**Starts.** *Primordial*: 2M small rooted sun-eaters, loosely radial and rigid.
*Seeded*: a grown landscape of rooted upright bodies plus 60k free, muscular,
bilateral founders (herbivores, a few carnivores, half with brains).

**Views.** The 2D map shows the canopy and draws mobile organisms and unusual
sessile ones as dots; colour modes: lifestyle, lineage, organs, energy and
**body plan** (green rooted upright, teal creeping, orange free and muscular,
purple tint radial). The panel counts body plans and in-life transitions.
The 3D view (Tab) draws **every organism with one universal body rig**
([scripts/life/rig.gd](scripts/life/rig.gd), [shaders/organism.gdshader](shaders/organism.gdshader)):
the vertex shader bends the axis between horizontal and vertical, places
appendages bilaterally or radially as legs or branches (legs swing with speed,
rooted bodies sway), grows leaves along branches or sails on backs, jaws at the
head or a trap on top, roots, eyes and thorns, and hides what the body does not
have. (`--seekmobile=1` with `--bench` moves the 3D player next to a mobile organism.)

### Ecology: diversity and robustness

Mechanisms that keep the world diverse and stable (all live parameters):
- **Janzen-Connell** (`jc_strength`): seeds germinate less often near adults of their
  own lineage (their specialist pests), which holds common lineages back.
- **Climate** (`climate_strength`): temperature falls with latitude and altitude, and a
  preferred-temperature gene makes growth and upkeep best near it, so different
  places favour different lineages.
- **Fire** (`fire_rate`): random patches with enough fuel burn; big bodies lose most,
  opening gaps for pioneers (burnt ground shows dark in 2D).
- **Trampling** (`trample_strength`): running animals damage low plants, so creeping
  ground cover is not free.
- **Litter**: dead sessile organisms become litter, eaten by grazers and absorbed by
  sessile feeders (decomposers), recycling energy and giving small mouths a niche.
- **Sexual reproduction**: a compatible mate nearby (in view for mobile organisms,
  within 20 m for sessile ones) - genes and body plans cross over, brains are
  combined word by word; without a mate the child is a mutated clone.
- **Predation**: refuges in dense cover, a closing sprint and lunge, predators eat
  their kill before hunting again, and only fear clearly stronger carnivores.

**Measuring it.** The 2D panel and `--log=FILE` (a CSV row per stats read) report
guilds (upright plants, creepers, traps, sessile feeders, grazers, predators,
omnivores, leafy walkers), lineages (colour clusters), lineage entropy and
body-plan diversity (spread of the five switches). `--stop=TICKS` ends a run.

**Tuning it.** [tools/life_experiment.py](tools/life_experiment.py) runs seeds and
settings, scores each run (guilds present + lineage entropy + body-plan diversity,
minus guilds lost after mid-run and population swings) and can search at random:

```bash
python tools/life_experiment.py --ticks 6000 --seeds 1 2 --mode both --search 24
```

The current defaults come from such a search (24 settings x 2 seeds x both starts):
the combined score went from 5.9 to 8.2; seeded worlds keep six guilds and
primordial ones five, with lineage entropy around 0.9 of the maximum. Sunlight
was the strongest lever. Still open: predators and omnivores do not persist in the
long run, and primordial worlds do not yet evolve grazers.

## Files

- [shaders/sim.comp](shaders/sim.comp): all GPU kernels (one source, compiled once per kernel)
- [scripts/simulation.gd](scripts/simulation.gd): RenderingDevice setup, phase scheduling, sort, readbacks
- [scripts/launch.gd](scripts/launch.gd): autoload that owns the running simulation, shared settings, command line, view switching
- [menu.tscn](menu.tscn) / [scripts/menu.gd](scripts/menu.gd): the launcher (main scene)
- [main.tscn](main.tscn) / [scripts/main.gd](scripts/main.gd) / [scripts/ui.gd](scripts/ui.gd): 2D overview
- [explorer.tscn](explorer.tscn) / [scripts/explorer.gd](scripts/explorer.gd): 3D explorer (world, picking, interactions)
- [scripts/player.gd](scripts/player.gd), [scripts/hud.gd](scripts/hud.gd), [scripts/meshes.gd](scripts/meshes.gd): walker, HUD, procedural meshes
- [shaders/terrain.gdshader](shaders/terrain.gdshader), [water](shaders/water.gdshader), [plant](shaders/plant.gdshader), [creature](shaders/creature.gdshader): 3D visuals
- [shaders/life.comp](shaders/life.comp), [scripts/life/](scripts/life/) (`life_sim.gd`, `life_main.gd`, `life_ui.gd`, `life_explorer.gd`, `rig.gd`), [shaders/organism.gdshader](shaders/organism.gdshader), [life_main.tscn](life_main.tscn), [life_explorer.tscn](life_explorer.tscn): Unified Life
