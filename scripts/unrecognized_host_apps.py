#!/usr/bin/env python3
"""Pull `unrecognized_host_app` bundle IDs from Google Analytics and diff them
against the mapping tables in VivaDicta/VivaDictaApp.swift.

Data source: `gog ga report` (GA4 Analytics Data API) for the VivaDicta
property. The stored gog token needs the analytics.readonly scope once:

    see Prerequisites in .agents/skills/analyze-unrecognized-apps/SKILL.md
    (a bare `gog auth add --services analytics` narrows the token and is
    refused by Google because of stale YouTube grants on gog's OAuth client)

Usage:
    scripts/unrecognized_host_apps.py                 # last 28 days, actionable rows
    scripts/unrecognized_host_apps.py --days 90 --all # every row incl. mapped/noScheme
    scripts/unrecognized_host_apps.py --json out.json # machine-readable result
    scripts/unrecognized_host_apps.py --report-json r.json   # reuse a saved gog report

Categories:
    new            real app, not in knownURLs / knownNoSchemeHosts -> research it
    apple-new      com.apple.* not in either table -> usually noScheme, check first
    variant:<id>   team-ID prefix, regional build or extension of a mapped app
    mapped         already in knownURLs (old app versions still report it)
    noscheme       already in knownNoSchemeHosts
    not-actionable (not set) = data from before custom dimensions were registered
Exit code 3 = nothing actionable.
"""
from __future__ import annotations

import argparse, json, os, re, subprocess, sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# GA4 property ID: kept out of the public repo. $GA_PROPERTY_ID wins, else the
# gitignored internal/ga_property_id file.
PROPERTY_FILE = os.path.join(REPO_ROOT, "internal", "ga_property_id")
SWIFT = os.path.join(REPO_ROOT, "VivaDicta", "VivaDictaApp.swift")
NOT_ACTIONABLE = {"(not set)", ""}


def ga_property() -> str:
    prop = os.environ.get("GA_PROPERTY_ID", "").strip()
    if not prop and os.path.exists(PROPERTY_FILE):
        prop = open(PROPERTY_FILE).read().strip()
    if not prop:
        sys.exit("no GA4 property ID: set $GA_PROPERTY_ID or write it to internal/ga_property_id")
    return prop


def ga_report(days: int, report_json: str | None) -> dict:
    if report_json:
        return json.load(open(report_json))
    cmd = ["gog", "ga", "report", ga_property(),
           "--dimensions", "eventName,customEvent:bundle_id",
           "--metrics", "eventCount", "--from", f"{days}daysAgo",
           "--max", "5000", "-j"]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        msg = out.stderr.strip()[:400]
        if "insufficient" in msg.lower() or "scope" in msg.lower():
            msg += ("\n-> the gog token lacks analytics.readonly. See Prerequisites in "
                    ".agents/skills/analyze-unrecognized-apps/SKILL.md (a bare "
                    "`gog auth add --services analytics` narrows the token and is refused by Google)")
        sys.exit(f"gog failed: {msg}")
    return json.loads(out.stdout)


def unrecognized_rows(report: dict):
    rows = []
    for r in report.get("rows", []):
        dv = [x.get("value", "") for x in r["dimensionValues"]]
        mv = [x.get("value", "") for x in r["metricValues"]]
        if dv[0] == "unrecognized_host_app":
            rows.append((dv[1], int(mv[0] or 0)))
    rows.sort(key=lambda x: (-x[1], x[0]))
    return rows


def bracket_block(src: str, pattern: str) -> str:
    m = re.search(pattern, src)
    if not m:
        return ""
    depth = 0
    for k in range(m.end() - 1, len(src)):
        if src[k] == "[":
            depth += 1
        elif src[k] == "]":
            depth -= 1
            if depth == 0:
                return src[m.end() - 1:k + 1]
    return ""


def load_tables(path: str):
    src = open(path).read()
    known = dict(re.findall(r'"([^"]+)"\s*:\s*"([^"]*)"',
                            bracket_block(src, r"let knownURLs[^=]*=\s*\[")))
    noscheme = set(re.findall(r'"([^"]+)"',
                              bracket_block(src, r"let knownNoSchemeHosts[^=]*=\s*\[")))
    if not known or not noscheme:
        sys.exit(f"could not parse knownURLs / knownNoSchemeHosts from {path}")
    return known, noscheme


def categorize(b: str, known: dict, noscheme: set) -> str:
    if b in known:
        return "mapped"
    if b in noscheme:
        return "noscheme"
    if b in NOT_ACTIONABLE:
        return "not-actionable"
    stripped = re.sub(r"^[A-Z0-9]{10}\.", "", b)  # team-ID prefixed bundle id
    for k in known:
        if b.startswith(k + ".") or stripped == k:
            return f"variant:{k}"
    if b.startswith("com.apple."):
        return "apple-new"
    return "new"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--days", type=int, default=28)
    ap.add_argument("--min-events", type=int, default=1)
    ap.add_argument("--all", action="store_true", help="print mapped/noscheme rows too")
    ap.add_argument("--json", help="write the full result to this file")
    ap.add_argument("--swift", default=SWIFT, help="path to VivaDictaApp.swift")
    ap.add_argument("--report-json", help="use a saved `gog ga report -j` file instead of calling gog")
    a = ap.parse_args()

    rows = unrecognized_rows(ga_report(a.days, a.report_json))
    known, noscheme = load_tables(a.swift)
    result = [{"bundle_id": b, "events": n, "category": categorize(b, known, noscheme)} for b, n in rows]
    actionable = [r for r in result
                  if r["category"] not in ("mapped", "noscheme", "not-actionable") and r["events"] >= a.min_events]

    if a.json:
        json.dump({"days": a.days, "property": PROPERTY, "known": len(known), "noscheme": len(noscheme),
                   "rows": result, "actionable": actionable}, open(a.json, "w"), indent=1)

    print(f"# unrecognized_host_app, last {a.days} days: {len(rows)} bundle IDs, "
          f"{sum(n for _, n in rows)} events | tables: {len(known)} mapped, {len(noscheme)} noScheme")
    print(f"{'EVENTS':>6}  {'BUNDLE ID':50s} CATEGORY")
    for r in (result if a.all else actionable):
        print(f"{r['events']:6d}  {r['bundle_id']:50s} {r['category']}")
    if not actionable:
        print("nothing new")
        sys.exit(3)


if __name__ == "__main__":
    main()
