#!/usr/bin/env python3
"""Run the private baseline one case at a time, resumably, within a budget.

    python3 -I evals/batch.py [--cases M3 M4 ...] [--runs 3] [-j 2] [--budget 35]
    python3 -I evals/batch.py --merge

For each case it runs the cr-homie arm (run.sh --private) and then the
/code-review arm (run.sh --private-baseline), so every finished case has both
arms. Each (case, arm) result is written to <out>/<case>.<arm>.json once all of
its runs finished without error; later invocations skip those, so a run that
stops on a subscription session limit, an expired login or the budget picks up
where it left off.

Stops (exit 3) as soon as a run fails on a usage limit or authentication error:
retrying before the window resets would only burn more failed runs. Stops
(exit 4) on any other run error, keeping the result as <case>.<arm>.partial.json
for inspection. Stops (exit 0) before starting a case once --budget USD of list
price has been spent in this invocation.

--merge combines the finished per-case files into <out>/../baseline-<arm>.json
for evals/score.py.

Reads and writes only local files under evals-private/; never uploads anything.
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRIVATE = Path(os.environ.get("CR_HOMIE_PRIVATE_ROOT", Path.home() / "cr-homie-evals-private"))
ARMS = (("crhomie", "--private"), ("codereview", "--private-baseline"))
LIMIT_MARKERS = ("session limit", "usage limit", "rate limit", "Failed to authenticate", "hit your")


def runs_of(result):
    return [r for c in result["cases"] for r in c["arms"].get("with", [])]


def finished(path, runs):
    if not path.exists():
        return False
    rs = runs_of(json.loads(path.read_text()))
    return len(rs) == runs and not any(r.get("error") for r in rs)


def run_arm(case, flag, runs, jobs, out):
    tmp = out.with_suffix(".tmp.json")
    cmd = [str(ROOT / "evals" / "run.sh"), flag, "--case", case, "--runs", str(runs),
           "--ablation", "none", "--keep-temp", "-j", str(jobs), "--json", str(tmp.relative_to(ROOT))]
    log = out.with_suffix(".log")
    with log.open("w") as fh:
        subprocess.run(cmd, cwd=ROOT, stdout=fh, stderr=subprocess.STDOUT)
    if not tmp.exists():
        sys.exit(f"{case}: no result written; see {log}")
    result = json.loads(tmp.read_text())
    errors = [r["error"] for r in runs_of(result) if r.get("error")]
    if not errors and len(runs_of(result)) == runs:
        tmp.replace(out)
    else:
        tmp.replace(out.with_name(out.name.replace(".json", ".partial.json")))
    return result, errors


def merge(out_dir):
    for arm, _ in ARMS:
        cases, cost = [], 0.0
        for p in sorted(out_dir.glob(f"*.{arm}.json")):
            data = json.loads(p.read_text())
            cases += data["cases"]
            cost += data.get("costUsd") or 0
        if not cases:
            continue
        dest = out_dir.parent / f"baseline-{arm}.json"
        dest.write_text(json.dumps({"schemaVersion": data["schemaVersion"], "claudeVersion": data["claudeVersion"],
                                    "costUsd": cost, "partial": False, "cases": cases}, ensure_ascii=False))
        print(f"{dest}: {len(cases)} cases, ${cost:.2f}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cases", nargs="*", help="case names (default: every case under $CR_HOMIE_PRIVATE_ROOT/cases)")
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("-j", "--jobs", type=int, default=2)
    ap.add_argument("--budget", type=float, default=35.0, help="stop before the next case once this much (USD, list price) is spent")
    ap.add_argument("--out", default="evals-private/results/baseline")
    ap.add_argument("--merge", action="store_true")
    args = ap.parse_args()

    out_dir = ROOT / args.out
    out_dir.mkdir(parents=True, exist_ok=True)
    if args.merge:
        return merge(out_dir)

    cases = args.cases or sorted(p.name for p in (PRIVATE / "cases").iterdir() if (p / "case.yaml").exists())
    spent = 0.0
    for case in cases:
        todo = [(arm, flag) for arm, flag in ARMS if not finished(out_dir / f"{case}.{arm}.json", args.runs)]
        if not todo:
            continue
        if spent >= args.budget:
            print(f"budget reached (${spent:.2f}); next case: {case}")
            return
        for arm, flag in todo:
            result, errors = run_arm(case, flag, args.runs, args.jobs, out_dir / f"{case}.{arm}.json")
            spent += result.get("costUsd") or 0
            print(f"{case} {arm}: ${result.get('costUsd') or 0:.2f}, {len(errors)} errored run(s); spent ${spent:.2f}", flush=True)
            if any(m in e for e in errors for m in LIMIT_MARKERS):
                print(f"stopped on a usage limit / login error: {errors[0][:160]}")
                sys.exit(3)
            if errors:
                print(f"stopped on a run error: {errors[0][:160]}")
                sys.exit(4)
    print(f"all cases finished; spent ${spent:.2f}")


if __name__ == "__main__":
    main()
