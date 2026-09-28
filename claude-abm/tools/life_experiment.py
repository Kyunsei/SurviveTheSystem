"""Unified Life experiments: run the simulation for several seeds and settings,
log its statistics, and score the ecosystem on diversity and robustness.

    python tools/life_experiment.py --ticks 8000 --seeds 1 2 --mode seeded
    python tools/life_experiment.py --ticks 8000 --seeds 1 2 --param sun_energy=0.0012
    python tools/life_experiment.py --ticks 6000 --seeds 1 2 --search 20 --out runs/search1

Each run opens the 2D Unified Life view (it needs the GPU), runs to --ticks and
writes a CSV (one row per stats read). The score, higher is better:

    guilds present (0-8, over the last third of the run)
  + 2 x lineage entropy (normalised 0-1)
  + 4 x body-plan diversity (mean standard deviation of the five switches, ~0-0.5)
  - 2 x guilds lost after mid-run (present at the half, gone at the end)
  - 1 x swings of the mobile population (coefficient of variation, capped at 1)
"""
import argparse
import csv
import json
import math
import os
import random
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", r"C:\Users\iib21\Documents\Godot_v4.6-stable_win64_console.exe")
# Guilds that count for diversity, with the abundance that makes them "present".
GUILDS = {"plants": 2000, "creepers": 2000, "traps": 500, "sessile_feeders": 500,
          "grazers": 30, "predators": 30, "omnivores": 30, "mobile_leafy": 30}
# Search space: parameter -> (low, high, log scale)
SPACE = {
    "sun_energy": (0.0006, 0.002, True),
    "compute_cost": (0.0002, 0.0012, True),
    "organ_jump": (0.001, 0.01, True),
    "metabolism": (0.008, 0.025, False),
    "plant_efficiency": (0.3, 0.8, False),
    "meat_efficiency": (0.6, 1.4, False),
    "attack_power": (0.4, 1.4, False),
    "mutation_scale": (0.5, 2.0, False),
    "kin_distance": (0.06, 0.2, False),
    "fire_rate": (0.0, 0.08, False),
    "jc_strength": (0.0, 0.5, False),
    "trample_strength": (0.0, 2.0, False),
    "climate_strength": (0.2, 0.9, False),
}


def run(ticks, seed, mode, params, out_csv, steps=16, timeout=1800):
    args = [GODOT, "--path", ROOT, "--", "--view=life", "--life=" + mode, "--seed=%d" % seed,
            "--steps=%d" % steps, "--stop=%d" % ticks, "--log=" + os.path.abspath(out_csv)]
    args += ["--%s=%s" % (k, v) for k, v in params.items()]
    t0 = time.time()
    subprocess.run(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=timeout)
    return time.time() - t0


def load(path):
    with open(path, newline="") as f:
        return [{k: float(v) for k, v in row.items()} for row in csv.DictReader(f)]


def score(rows):
    if len(rows) < 6:
        return {"score": -99.0, "note": "too short"}
    n = len(rows)
    last = rows[n * 2 // 3:]
    mid = rows[n // 2 - 2: n // 2 + 2]
    end = rows[-4:]

    def mean(rs, k):
        return sum(r[k] for r in rs) / len(rs)

    present = [g for g, t in GUILDS.items() if mean(last, g) >= t]
    lost = [g for g, t in GUILDS.items() if mean(mid, g) >= t and mean(end, g) < t]
    ent = mean(last, "lineage_entropy") / math.log(32)
    div = mean(last, "bodyplan_diversity")
    mob = [r["mobile"] for r in rows[n // 2:]]
    mu = sum(mob) / len(mob)
    cv = min(math.sqrt(sum((x - mu) ** 2 for x in mob) / len(mob)) / mu, 1.0) if mu > 0 else 1.0
    s = len(present) + 2 * ent + 4 * div - 2 * len(lost) - cv
    return {"score": round(s, 3), "present": present, "lost": lost, "entropy": round(ent, 3),
            "bodyplan": round(div, 3), "cv": round(cv, 3), "mobile_end": int(mean(end, "mobile")),
            "sessile_end": int(mean(end, "sessile")), "tick_end": int(rows[-1]["tick"])}


def evaluate(params, args, tag):
    results = []
    modes = ["seeded", "primordial"] if args.mode == "both" else [args.mode]
    for mode, seed in [(m, s) for m in modes for s in args.seeds]:
        path = os.path.join(args.out, "%s_%s_seed%d.csv" % (tag, mode, seed))
        secs = run(args.ticks, seed, mode, params, path)
        r = score(load(path)) if os.path.exists(path) else {"score": -99.0, "note": "no log"}
        if r.get("note"):  # the run died early (e.g. a GPU / driver crash): try once more
            print("  seed %d failed (%s), retrying" % (seed, r["note"]), flush=True)
            secs = run(args.ticks, seed, mode, params, path)
            r = score(load(path)) if os.path.exists(path) else {"score": -99.0, "note": "no log"}
            r["retried"] = True
        r["seed"] = seed
        r["mode"] = mode
        r["secs"] = round(secs)
        results.append(r)
        print("  %s seed %d: %s" % (mode, seed, json.dumps(r)), flush=True)
    return sum(r["score"] for r in results) / len(results), results


def sample(rng):
    p = {}
    for k, (lo, hi, logscale) in SPACE.items():
        u = rng.random()
        p[k] = round(math.exp(math.log(lo) + u * (math.log(hi) - math.log(lo))) if logscale else lo + u * (hi - lo), 6)
    return p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ticks", type=int, default=8000)
    ap.add_argument("--seeds", type=int, nargs="+", default=[1, 2])
    ap.add_argument("--mode", default="seeded", choices=["seeded", "primordial", "both"])
    ap.add_argument("--param", nargs="*", default=[], help="name=value overrides")
    ap.add_argument("--search", type=int, default=0, help="random settings to try")
    ap.add_argument("--out", default=os.path.join(ROOT, "runs", time.strftime("%Y%m%d_%H%M%S")))
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    base = dict(kv.split("=", 1) for kv in args.param)
    summary = []
    print("baseline %s" % base, flush=True)
    s, res = evaluate(base, args, "base")
    summary.append({"params": base, "score": s, "runs": res})
    rng = random.Random(12345)
    for i in range(args.search):
        p = dict(base)
        p.update(sample(rng))
        print("candidate %d %s" % (i, p), flush=True)
        s, res = evaluate(p, args, "c%03d" % i)
        summary.append({"params": p, "score": s, "runs": res})
        best = max(summary, key=lambda e: e["score"])
        print("  -> %.3f   (best so far %.3f)" % (s, best["score"]), flush=True)
    summary.sort(key=lambda e: -e["score"])
    with open(os.path.join(args.out, "summary.json"), "w") as f:
        json.dump(summary, f, indent=1)
    print("best: %.3f %s" % (summary[0]["score"], summary[0]["params"]))


if __name__ == "__main__":
    sys.exit(main())
