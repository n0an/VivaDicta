#!/usr/bin/env bash
#
# VivaDicta code coverage from the terminal.
#
#   coverage.sh app [File.swift ...]   Full test plan in the simulator (canonical).
#                                      Prints overall + per-target, plus per-file rows
#                                      for any named files (e.g. ChatViewModel.swift).
#   coverage.sh module <Module>        One SPM module via `swift test` (fast, macOS host).
#   coverage.sh full                   Clean build + full plan, then auto-fill any module
#                                      whose per-target row dropped (or came back 0/0) from
#                                      the `module` path. A number for EVERY module, every
#                                      run. Filled rows are own-tests-only floors (labeled).
#
# Env:
#   DESTINATION   override the simulator destination
#                 (default 'platform=iOS Simulator,name=iPhone 17 Pro Max').
#   RESULT        override the .xcresult path (default /tmp/vivadicta-cov.xcresult).
#
# Coverage is a RUNTIME metric: this runs the tests, then reads the result. There is
# no way to get real coverage by reading the codebase (that is the LOC ratio - see the
# loc-report skill).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro Max}"
RESULT="${RESULT:-/tmp/vivadicta-cov.xcresult}"
MODE="${1:-app}"

# Run the full test plan with coverage. A failing/flaky test run must NOT abort
# the whole report (coverage for the tests that ran is still useful), so capture
# the status, warn, and continue. "xctest (PID) encountered an error" across many
# PIDs is usually simulator/parallel flakiness on a cold clean run, not a real
# regression - re-running on a warm sim typically passes.
run_test_plan() {
  set +e
  xcodebuild test -scheme VivaDicta \
    -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
    -testPlan VivaDictaTestPlan \
    -destination "$DESTINATION" \
    -enableCodeCoverage YES -resultBundlePath "$RESULT" 2>&1 | tail -3
  local st=${PIPESTATUS[0]}
  set -e
  if [ "$st" -ne 0 ]; then
    echo "WARNING: test run reported failures (xcodebuild exit $st)."
    echo "  Often a flaky simulator/parallel-run issue on a cold clean build, not a"
    echo "  code regression. Coverage below may be partial or empty - re-run if the"
    echo "  numbers look wrong (a warm simulator usually passes)."
  fi
}

# Print the first-party overall % from the result bundle. Sums ONLY the 16
# modules + app + 4 extensions, so it stays meaningful even when the test plan
# gathers coverage for ALL targets (Firebase/Google/KeyboardKit/etc., which
# would otherwise inflate the raw bundle total).
first_party_overall() {
  xcrun xccov view --report --json "$RESULT" | python3 -c '
import json, sys
d = json.load(sys.stdin)
FP = {"AICore","AIKit","AIProviders","Analytics","AppGroup","AudioRecording",
      "CloudTranscription","DesignSystem","Keychain","LocalTranscription",
      "Networking","OAuth","Presets","TextProcessing","TranscriptionCore","TranscriptionKit",
      "VivaDicta.app","ActionExtension.appex","ShareExtension.appex",
      "VivaDictaKeyboard.appex","VivaDictaWidgetExtension.appex"}
c = sum(t["coveredLines"] for t in d["targets"] if t["name"] in FP)
e = sum(t["executableLines"] for t in d["targets"] if t["name"] in FP)
print("%.2f%% (%d/%d lines)" % (100.0*c/e if e else 0, c, e))
rc, re_ = d["coveredLines"], d["executableLines"]
if re_ != e:
    print("(raw bundle incl. third-party/test targets: %.2f%% (%d/%d) - ignore)"
          % (100.0*rc/re_ if re_ else 0, rc, re_))
'
}

case "$MODE" in
  app)
    shift || true
    rm -rf "$RESULT"
    echo "Running full test plan with coverage..."
    run_test_plan

    echo
    echo "=== OVERALL (first-party only) ==="
    first_party_overall

    echo
    echo "=== PER-TARGET ==="
    xcrun xccov view --report --only-targets "$RESULT"

    if [ "$#" -gt 0 ]; then
      echo
      echo "=== PER-FILE ==="
      for f in "$@"; do
        xcrun xccov view --report "$RESULT" 2>/dev/null | grep -i "$f" \
          || echo "  (no row for '$f' - it may be statically merged into another target; see caveats)"
      done
    fi
    ;;

  module)
    MODULE="${2:?usage: coverage.sh module <Module>}"
    cd "Modules/$MODULE"
    # Capture swift test's own exit status (not the pipe's) so a failing build
    # aborts instead of silently reporting stale coverage from a prior .build.
    log="${TMPDIR:-/tmp}/coverage-module-$$.log"
    if ! xcrun swift test --enable-code-coverage > "$log" 2>&1; then
      grep -iE "error:|Test run with" "$log" >&2 || true
      echo "swift test failed for $MODULE - aborting so coverage is not reported from a stale build." >&2
      rm -f "$log"
      exit 1
    fi
    grep -iE "Test run with" "$log" || true
    rm -f "$log"
    BIN="$(find .build -name "${MODULE}PackageTests" -type f -path '*MacOS*' | head -1)"
    PROF="$(find .build -name default.profdata | head -1)"
    if [ -z "$BIN" ] || [ -z "$PROF" ]; then
      echo "Could not locate test binary / profdata under .build (did the build fail?)." >&2
      exit 1
    fi
    echo
    echo "=== $MODULE (production sources only) ==="
    xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
      -ignore-filename-regex='Tests|\.build|Mocks' "Sources/$MODULE/"
    ;;

  full)
    # The most complete per-module table the toolchain allows.
    #
    # WHY: an SPM module is a static library, not a standalone binary. Its object
    # code is linked into the app AND its own test bundle, and when xccov rolls
    # coverage up per target the linker's cross-binary dedup sometimes leaves a
    # module without a clean one-to-one mapping, so its row is dropped (or comes
    # back 0/0). A CLEAN build relinks consistently and recovers most rows
    # (~18/21 vs ~13/21 incremental); for the few that still drop, the `module`
    # path reads that module's own test bundle directly and never drops. So:
    # clean canonical run + module-path fill = a number for every module.

    echo "Clearing VivaDicta DerivedData for a clean relink (best attribution)..."
    find "$HOME/Library/Developer/Xcode/DerivedData" -mindepth 1 -maxdepth 1 -iname 'vivadicta-*' -exec rm -rf {} + 2>/dev/null || true
    rm -rf "$RESULT"
    echo "Running clean build + full test plan (slow - rebuilds all targets)..."
    run_test_plan

    # Snapshot the xccov JSON once; every step below reads this file (no piping
    # into a heredoc-program, which would collide on stdin).
    covjson="${TMPDIR:-/tmp}/cov-json-$$.json"
    tsv="${TMPDIR:-/tmp}/cov-merge-$$.tsv"
    fillfile="${TMPDIR:-/tmp}/cov-fill-$$.txt"
    : > "$tsv"
    xcrun xccov view --report --json "$RESULT" > "$covjson"

    echo
    echo "=== OVERALL (first-party only) ==="
    first_party_overall

    echo
    echo "=== APP + EXTENSIONS (canonical) ==="
    python3 - "$covjson" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
hosts = {'VivaDicta.app','ActionExtension.appex','ShareExtension.appex','VivaDictaKeyboard.appex','VivaDictaWidgetExtension.appex'}
for t in d['targets']:
    if t['name'] in hosts:
        print('%-32s %6.2f%%  (%d/%d)' % (t['name'], t['lineCoverage']*100, t['coveredLines'], t['executableLines']))
PY

    # Canonical module rows + the list of modules that need a module-path fill.
    python3 - "$covjson" "$tsv" "$fillfile" <<'PY'
import json, sys
json_path, tsv_path, fill_path = sys.argv[1], sys.argv[2], sys.argv[3]
MODULES = ["AICore","AIKit","AIProviders","Analytics","AppGroup","AudioRecording",
           "CloudTranscription","DesignSystem","Keychain","LocalTranscription",
           "Networking","OAuth","Presets","TextProcessing","TranscriptionCore","TranscriptionKit"]
d = json.load(open(json_path))
by = {t["name"]: t for t in d["targets"]}
rows, fill = [], []
for m in MODULES:
    t = by.get(m)
    if t and t["executableLines"] > 0:
        rows.append("%s\t%.2f\t%d\t%d\tcanonical" % (m, t["lineCoverage"]*100, t["coveredLines"], t["executableLines"]))
    else:
        fill.append(m)
with open(tsv_path, "w") as f:
    f.write("\n".join(rows) + ("\n" if rows else ""))
with open(fill_path, "w") as f:
    f.write(" ".join(fill))
PY

    # A module's `swift test` can return non-zero (build hiccup, no host-testable
    # code, etc.); that must NOT abort the report. Drop set -e for the fill loop
    # and merge - each step tolerates failure and we just skip a row.
    set +e
    FILL="$(cat "$fillfile")"
    if [ -n "$FILL" ]; then
      echo
      echo "Filling dropped/empty rows from the module path: $FILL"
      for M in $FILL; do
        ROW="$( cd "Modules/$M" 2>/dev/null \
          && xcrun swift test --enable-code-coverage >/dev/null 2>&1 \
          && BIN="$(find .build -name "${M}PackageTests" -type f -path '*MacOS*' | head -1)" \
          && PROF="$(find .build -name default.profdata | head -1)" \
          && [ -n "$BIN" ] && [ -n "$PROF" ] \
          && xcrun llvm-cov report "$BIN" -instr-profile="$PROF" -ignore-filename-regex='Tests|\.build|Mocks' "Sources/$M/" 2>/dev/null \
             | awk -v m="$M" '/^TOTAL/{cov=$8-$9; printf "%s\t%.2f\t%d\t%d\tmodule-floor\n", m, $10+0, cov, $8}' )"
        if [ -n "$ROW" ]; then printf '%s\n' "$ROW" >> "$tsv"; else echo "  $M: no host coverage (entitlement-gated or no tests) - left out"; fi
      done
    fi

    echo
    echo "=== PER-MODULE (merged, sorted) ==="
    sort -t"$(printf '\t')" -k2 -nr "$tsv" | awk -F"$(printf '\t')" '{printf "%-20s %6.2f%%  (%d/%d)  %s\n", $1, $2, $3, $4, $5}'
    set -e
    echo
    echo "Note: 'module-floor' rows are that module's OWN unit tests only - a floor."
    echo "App-exercised modules read low there vs their all-tests canonical number"
    echo "(TextProcessing is the big one); Keychain's impl is entitlement-gated so its"
    echo "host floor is ~0 - its real coverage comes from the app-target sim tests."
    rm -f "$tsv" "$fillfile" "$covjson"
    ;;

  *)
    echo "usage: coverage.sh app [File.swift ...] | coverage.sh module <Module> | coverage.sh full" >&2
    exit 2
    ;;
esac
