#!/usr/bin/env python3
"""
VivaDicta LOC accounting: working-tree breakdown + production/test history chart.

Two jobs in one place:

  breakdown  - count current working-tree Swift LOC, grouped into SPM modules,
               the main app, app extensions, and the watch app (prod vs test).
               Answers "how many LOC do we have, and where?"
  chart      - walk git history, sample the last commit of each calendar day,
               count prod vs test Swift LOC, render the growth chart embedded in
               documentation/Module-Architecture.md (CSV -> SVG -> PNG).

Counting rule (shared by both lenses): a "line of code" is a non-blank Swift
source line that does not start with `//`. Package.swift manifests are ignored.
A file counts as "test" when it sits under a `*Tests` directory, under the
TestUtilities module, or its name ends Tests.swift / Spec(s).swift; otherwise
"prod". Because both lenses share this rule, the breakdown's grand total
reconciles with the chart's latest data point.

No third-party deps; the PNG step shells out to rsvg-convert. Run:
    python3 scripts/loc/loc_history.py            # breakdown, then refresh chart
    python3 scripts/loc/loc_history.py breakdown  # snapshot only (read-only)
    python3 scripts/loc/loc_history.py chart      # refresh CSV + SVG + PNG only
"""
import math
import os
import subprocess
import sys
from datetime import date, timedelta

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOC_DIR = os.path.join(REPO, "scripts", "loc")
CSV_PATH = os.path.join(LOC_DIR, "loc_history.csv")
SVG_PATH = os.path.join(LOC_DIR, "loc_history.svg")
PNG_PATH = os.path.join(REPO, "documentation", "assets", "loc_history.png")
PNG_WIDTH = 1600  # 1360x460 SVG -> 1600x542 PNG, matching the committed chart

# Directory names pruned while walking the working tree for the breakdown.
SKIP_DIRS = {
    ".git", ".build", ".build-benchmark", ".swiftpm", "DerivedData", "build",
    "llmtemp", "node_modules", "Pods", ".claude", ".agents", "logs",
}
# App-extension target directories (everything here is production code).
EXTENSION_DIRS = {
    "ActionExtension", "ShareExtension", "VivaDictaKeyboard",
    "VivaDictaWidget", "VivaDictaWatchWidget",
}


def git_text(args):
    return subprocess.run(
        ["git", "-C", REPO, *args], capture_output=True, check=True, text=True
    ).stdout


def classify(path):
    """prod / test / None (ignored) for a repo-relative .swift path."""
    if not path.endswith(".swift"):
        return None
    segs = path.replace(os.sep, "/").split("/")
    name = segs[-1]
    if name == "Package.swift":
        return None
    if "TestUtilities" in segs:
        return "test"
    if any(s.endswith("Tests") for s in segs[:-1]):
        return "test"
    if name.endswith(("Tests.swift", "Spec.swift", "Specs.swift")):
        return "test"
    return "prod"


def code_lines(blob: bytes) -> int:
    n = 0
    for raw in blob.split(b"\n"):
        t = raw.strip()
        if not t or t.startswith(b"//"):
            continue
        n += 1
    return n


# --------------------------------------------------------------------------- #
# Working-tree breakdown (snapshot)
# --------------------------------------------------------------------------- #

def area(rel):
    """Map a repo-relative path to (group, label) for the breakdown table."""
    segs = rel.split(os.sep)
    top = segs[0]
    if top == "Modules" and len(segs) > 1:
        return ("modules", segs[1])
    if top == "VivaDicta":
        return ("app", "VivaDicta (app source)")
    if top == "VivaDictaTests":
        return ("app", "VivaDictaTests")
    if top in EXTENSION_DIRS:
        return ("extensions", top)
    if top == "VivaDictaWatch Watch App":
        return ("watch", "Watch App")
    if top == "VivaDictaWatch Watch AppTests":
        return ("watch", "Watch AppTests")
    return ("other", top)


def breakdown():
    """Walk the working tree, returning group -> {label: [prod, test]}."""
    tally = {}
    for root, dirs, files in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fname in files:
            if not fname.endswith(".swift"):
                continue
            full = os.path.join(root, fname)
            rel = os.path.relpath(full, REPO)
            cls = classify(rel)
            if cls is None:
                continue
            with open(full, "rb") as f:
                n = code_lines(f.read())
            group, label = area(rel)
            slot = tally.setdefault(group, {}).setdefault(label, [0, 0])
            slot[0 if cls == "prod" else 1] += n
    return tally


def print_breakdown(tally):
    order = [
        ("modules", "SPM MODULES"),
        ("app", "MAIN APP"),
        ("extensions", "EXTENSIONS"),
        ("watch", "WATCH APP"),
        ("other", "OTHER"),
    ]
    grand = [0, 0]
    width = 26
    print(f"{'':<{width}}{'prod':>9}{'test':>9}")
    print("=" * (width + 18))
    for group, title in order:
        rows = tally.get(group)
        if not rows:
            continue
        sub = [0, 0]
        print(f"{title}")
        for label in sorted(rows, key=lambda k: -sum(rows[k])):
            prod, test = rows[label]
            sub[0] += prod
            sub[1] += test
            print(f"  {label:<{width-2}}{_n(prod):>9}{_n(test):>9}")
        print(f"  {'-' * (width + 14)}")
        print(f"  {'subtotal':<{width-2}}{sub[0]:>9}{sub[1]:>9}\n")
        grand[0] += sub[0]
        grand[1] += sub[1]
    print("=" * (width + 18))
    print(f"{'TOTAL':<{width}}{grand[0]:>9}{grand[1]:>9}")
    print(f"\nproduction: {grand[0]:,}    test: {grand[1]:,}    "
          f"total: {grand[0] + grand[1]:,}")


def _n(v):
    return str(v) if v else "-"


# --------------------------------------------------------------------------- #
# Git-history chart
# --------------------------------------------------------------------------- #

def blob_line_counts(shas):
    """One `git cat-file --batch` pass over the unique blob set."""
    proc = subprocess.Popen(
        ["git", "-C", REPO, "cat-file", "--batch"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
    )
    out, _ = proc.communicate(("\n".join(shas) + "\n").encode())
    counts, i, total = {}, 0, len(out)
    while i < total:
        j = out.index(b"\n", i)
        header = out[i:j].decode()
        i = j + 1
        parts = header.split(" ")
        sha = parts[0]
        if len(parts) < 3:  # "<sha> missing"
            counts[sha] = 0
            continue
        size = int(parts[2])
        counts[sha] = code_lines(out[i : i + size])
        i += size + 1  # content + trailing newline
    return counts


def collect():
    log = git_text(["log", "--reverse", "--pretty=format:%H|%cd", "--date=short"])
    last_of_day = {}
    for line in log.splitlines():
        sha, day = line.split("|")
        last_of_day[day] = sha  # reverse order -> last write is end of day
    days = sorted(last_of_day)

    per_day, all_shas = {}, set()
    for day in days:
        items = []
        for line in git_text(["ls-tree", "-r", last_of_day[day]]).splitlines():
            meta, path = line.split("\t", 1)
            _mode, typ, bsha = meta.split()
            if typ != "blob":
                continue
            cls = classify(path)
            if cls is None:
                continue
            items.append((bsha, cls))
            all_shas.add(bsha)
        per_day[day] = items

    counts = blob_line_counts(all_shas)
    rows = []
    for day in days:
        prod = sum(counts[s] for s, c in per_day[day] if c == "prod")
        test = sum(counts[s] for s, c in per_day[day] if c == "test")
        rows.append((day, prod, test))
    # drop leading all-zero days so the curve starts at first real code
    while len(rows) > 1 and rows[0][1] == 0 and rows[0][2] == 0:
        rows.pop(0)
    return rows


def nice_step(maxval):
    target = max(maxval / 10.0, 1)
    mag = 10 ** math.floor(math.log10(target))
    for m in (1, 2, 2.5, 5, 10):
        if mag * m >= target:
            return mag * m
    return mag * 10


def render_svg(rows, path):
    W, H, L, R, T, B = 1360, 460, 70, 24, 46, 46
    pw, ph = W - L - R, H - T - B
    start, end = date.fromisoformat(rows[0][0]), date.fromisoformat(rows[-1][0])
    span = (end - start).days or 1
    maxval = max(max(p, t) for _, p, t in rows)
    step = nice_step(maxval)
    ymax = math.ceil(maxval / step) * step
    fmt = (lambda v: str(int(v))) if step == int(step) else (lambda v: f"{v:g}")

    def X(d):
        return L + (date.fromisoformat(d) - start).days / span * pw

    def Y(v):
        return T + ph - (v / ymax) * ph

    BLUE, GREEN = "#2e8bce", "#7cb342"
    s = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
        f'font-family="-apple-system,Helvetica,Arial,sans-serif" font-size="11">',
        f'<rect width="{W}" height="{H}" fill="white"/>',
    ]
    v = 0.0
    while v <= ymax + 1e-6:
        y = Y(v)
        s.append(
            f'<line x1="{L}" y1="{y:.1f}" x2="{W-R}" y2="{y:.1f}" '
            f'stroke="#cfcfcf" stroke-width="0.5" stroke-dasharray="2,3"/>'
        )
        s.append(
            f'<text x="{L-8}" y="{y+3:.1f}" text-anchor="end" fill="#888">{fmt(v)}</text>'
        )
        v += step
    nlab = 10
    for k in range(nlab + 1):
        dd = start + timedelta(days=round(span * k / nlab))
        x = L + pw * k / nlab
        s.append(
            f'<text x="{x:.1f}" y="{H-B+16:.0f}" text-anchor="middle" '
            f'fill="#888">{dd.isoformat()}</text>'
        )
    s.append(
        f'<line x1="{L}" y1="{T+ph:.0f}" x2="{W-R}" y2="{T+ph:.0f}" stroke="#444" stroke-width="1"/>'
    )
    test_pts = " ".join(f"{X(d):.1f},{Y(t):.1f}" for d, _p, t in rows)
    prod_pts = " ".join(f"{X(d):.1f},{Y(p):.1f}" for d, p, _t in rows)
    s.append(f'<polyline fill="none" stroke="{GREEN}" stroke-width="2" points="{test_pts}"/>')
    s.append(f'<polyline fill="none" stroke="{BLUE}" stroke-width="2" points="{prod_pts}"/>')
    cx = W / 2
    s += [
        f'<line x1="{cx-160}" y1="22" x2="{cx-128}" y2="22" stroke="{BLUE}" stroke-width="2"/>',
        f'<text x="{cx-122}" y="26" fill="#333">loc_prod</text>',
        f'<line x1="{cx+44}" y1="22" x2="{cx+76}" y2="22" stroke="{GREEN}" stroke-width="2"/>',
        f'<text x="{cx+82}" y="26" fill="#333">loc_test</text>',
        "</svg>",
    ]
    with open(path, "w") as f:
        f.write("\n".join(s))


def render_png():
    try:
        subprocess.run(
            ["rsvg-convert", "-w", str(PNG_WIDTH), SVG_PATH, "-o", PNG_PATH],
            check=True,
        )
        return True
    except (FileNotFoundError, subprocess.CalledProcessError) as e:
        print(f"  PNG skipped ({e}). Render manually with:")
        print(f"    rsvg-convert -w {PNG_WIDTH} {SVG_PATH} -o {PNG_PATH}")
        return False


def refresh_chart():
    rows = collect()
    with open(CSV_PATH, "w") as f:
        f.write("date,loc_prod,loc_test\n")
        for d, p, t in rows:
            f.write(f"{d},{p},{t}\n")
    render_svg(rows, SVG_PATH)
    png_ok = render_png()
    last = rows[-1]
    print(f"days: {len(rows)}  range: {rows[0][0]}..{last[0]}")
    print(f"latest: loc_prod={last[1]}  loc_test={last[2]}  "
          f"ratio={last[2] / max(last[1], 1):.2f}")
    print(f"wrote: {os.path.relpath(CSV_PATH, REPO)}")
    print(f"       {os.path.relpath(SVG_PATH, REPO)}")
    if png_ok:
        print(f"       {os.path.relpath(PNG_PATH, REPO)}  (embedded in "
              f"documentation/Module-Architecture.md)")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode not in {"all", "breakdown", "chart"}:
        sys.exit(f"usage: {os.path.basename(__file__)} [breakdown|chart]")
    if mode in {"all", "breakdown"}:
        print_breakdown(breakdown())
    if mode == "all":
        print()
    if mode in {"all", "chart"}:
        refresh_chart()


if __name__ == "__main__":
    main()
