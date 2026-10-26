#!/usr/bin/env python3
"""Summarize `claude plugin eval --json` results into the plan's metrics.

    python3 -I evals/score.py evals/results/run.json [more.json ...] [--unlabeled out.md]

Grader naming conventions (see evals/README.md):
  bug-<id>           a labeled bug; its body states "labeled severity Px"
  trap-<n> / trap-*  a known-safe pattern that must not be reported at P0–P2
  no-high-findings   clean case: no P0/P1 findings (read from the JSON report when
                     there is one; the LLM verdict only for markdown reports)
  others             process checks (json-valid, *-dispatched), reported separately

Metrics per input file:
  recall (all labels / labeled P0–P1), trap pass rate, clean-case P0/P1 false-positive
  rate, cost and duration per run, and — when --keep-temp sandboxes are readable —
  P0–P2 finding counts from review.json with a precision lower bound
  (labels found / P0–P2 findings). Unlabeled findings are listed for manual
  adjudication with --unlabeled.

Reads only local files; never uploads anything.
"""

import argparse
import json
import os
import re
import statistics
import sys
from pathlib import Path

SEV_RE = re.compile(r"labeled severity (P[0-3])")


def grader_severity(case, name):
    for g in case.get("graders", []):
        if g.get("name") == name:
            m = SEV_RE.search(g.get("graderMarkdown") or g.get("config", {}).get("criteria") or "")
            return m.group(1) if m else None
    return None


def review_json(run):
    """review.json from a --keep-temp sandbox, if still on disk and readable."""
    trace = run.get("tracePath")
    if not trace:
        return None
    root = Path(trace).parent.parent
    # plugin eval seals home/ and tmp/ of a kept sandbox (mode 000) and makes the
    # kept dir read-only; reopen just those two directories to read the report.
    # Never run git inside a kept sandbox (it could load the plugin's config).
    for d in (root, root / "sealed"):
        try:
            os.chmod(d, 0o700)
        except OSError:
            pass
    for cand in (root / "home" / "cwd" / "review.json", root / "sealed" / "home" / "cwd" / "review.json"):
        try:
            return json.loads(cand.read_text())
        except (OSError, ValueError):
            continue
    return None


def evidence_json(grader):
    """The review.json a file-focused grader saw, when its evidence is a whole JSON report."""
    try:
        rep = json.loads(grader.get("evidence") or "")
    except ValueError:
        return None
    return rep if isinstance(rep, dict) and "findings" in rep else None


def summarize(path, unlabeled):
    data = json.loads(Path(path).read_text())
    rows = []
    for case in data["cases"]:
        for run in case["arms"].get("with", []):
            rows.append((case, run))

    bug_total = bug_hit = hi_total = hi_hit = 0
    trap_total = trap_ok = 0
    clean_runs = clean_fp = 0
    findings_p012 = labels_found_with_report = 0
    costs, durations, errors = [], [], []
    per_case = {}

    for case, run in rows:
        name = case["name"]
        costs.append(run.get("costUsd") or 0)
        durations.append(run.get("durationSeconds") or 0)
        if run.get("error"):
            errors.append(f"{name}: {run['error']}")
        hits_this_run = 0
        report = review_json(run)
        for g in run.get("graders", []):
            gname, ok = g.get("name", ""), bool(g.get("passed"))
            if gname.startswith("bug-"):
                sev = grader_severity(case, gname)
                bug_total += 1
                bug_hit += ok
                hits_this_run += ok
                if sev in ("P0", "P1"):
                    hi_total += 1
                    hi_hit += ok
                per_case.setdefault(name, []).append((gname, ok))
            elif gname.startswith("trap"):
                trap_total += 1
                trap_ok += ok
            elif gname == "no-high-findings":
                # A JSON report states its severities, so read them instead of trusting
                # the LLM judge, which has failed reports with no P0/P1 finding at all.
                rep = report if report is not None else evidence_json(g)
                if rep is not None:
                    ok = not any(f.get("severity") in ("P0", "P1") for f in rep.get("findings", []))
                clean_runs += 1
                clean_fp += not ok
        if report is not None:
            sev_ok = [f for f in report.get("findings", []) if f.get("severity") in ("P0", "P1", "P2")]
            findings_p012 += len(sev_ok)
            labels_found_with_report += hits_this_run
            if unlabeled is not None and len(sev_ok) > hits_this_run:
                unlabeled.append((name, sev_ok, [g for g, ok in per_case.get(name, []) if ok]))

    def pct(a, b):
        return f"{a}/{b} ({100 * a / b:.0f}%)" if b else "n/a"

    def spread(xs):
        if not xs:
            return "n/a"
        return f"mean {statistics.mean(xs):.2f}, min {min(xs):.2f}, max {max(xs):.2f}"

    print(f"## {path}")
    print(f"- runs: {len(rows)} across {len(data['cases'])} cases; claude {data.get('claudeVersion')}")
    print(f"- recall (all labels): {pct(bug_hit, bug_total)}")
    print(f"- recall (labeled P0/P1): {pct(hi_hit, hi_total)}")
    print(f"- trap pass rate: {pct(trap_ok, trap_total)}")
    print(f"- clean-case runs with a P0/P1 finding: {pct(clean_fp, clean_runs)}")
    if findings_p012:
        print(f"- P0–P2 findings in readable reports: {findings_p012}; "
              f"precision lower bound (labels found / findings): {pct(labels_found_with_report, findings_p012)}")
    else:
        print("- precision: no readable review.json (run with --keep-temp, cr-homie arm only)")
    print(f"- cost per run (USD, list price): {spread(costs)}; total {sum(costs):.2f}")
    print(f"- duration per run (s): {spread(durations)}")
    if errors:
        print(f"- run errors ({len(errors)}): " + "; ".join(errors))
    print()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("results", nargs="+")
    ap.add_argument("--unlabeled", help="write unlabeled P0–P2 findings to this markdown file for adjudication")
    args = ap.parse_args()
    unlabeled = [] if args.unlabeled else None
    for p in args.results:
        summarize(p, unlabeled)
    if unlabeled is not None:
        out = ["# Unlabeled P0–P2 findings — adjudicate: real issue / false positive\n"]
        for name, findings, hit in unlabeled:
            out.append(f"## {name} (labels hit: {', '.join(hit) or 'none'})\n")
            for f in findings:
                out.append(f"- [ ] `{f.get('id')}` {f.get('severity')} `{f.get('file')}:{f.get('line')}` — {f.get('title')}")
            out.append("")
        Path(args.unlabeled).write_text("\n".join(out))
        os.chmod(args.unlabeled, 0o600)
        print(f"wrote {args.unlabeled}", file=sys.stderr)


if __name__ == "__main__":
    main()
